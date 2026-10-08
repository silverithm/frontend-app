import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/common/app_snackbar.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat_room.dart';
import '../models/chat_message.dart';
import '../models/chat_participant.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/admin_utils.dart';
import '../utils/chat_image_url.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/seed/seed_avatar.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_list_cell.dart';
import '../utils/constants.dart';
import '../utils/document_open.dart';
import '../utils/file_download_open.dart';
import '../widgets/chat/chat_image_viewer.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatRoomInfoScreen extends StatefulWidget {
  final ChatRoom room;

  const ChatRoomInfoScreen({super.key, required this.room});

  @override
  State<ChatRoomInfoScreen> createState() => _ChatRoomInfoScreenState();
}

class _ChatRoomInfoScreenState extends State<ChatRoomInfoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // 이름을 바꾸면 이 화면에서 바로 새 이름을 보여 준다
  late String _roomName = widget.room.name;

  // 참가자 목록을 처음 불러오는 중인지 / 실패했는지 ('불러오는 중...'에 영원히 머물지 않게)
  bool _participantsLoading = true;
  bool _participantsFailed = false;

  // 참가자 초대 화면이 아직 없다 — 구현되기 전까지 단추를 숨긴다.
  static const bool _showInviteButton = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadParticipants();
      _loadSharedMedia();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadParticipants() async {
    final chatProvider = context.read<ChatProvider>();
    setState(() {
      _participantsLoading = true;
      _participantsFailed = false;
    });
    final ok = await chatProvider.loadParticipants(widget.room.id);
    if (!mounted) return;
    setState(() {
      _participantsLoading = false;
      _participantsFailed = !ok;
    });
  }

  Future<void> _loadSharedMedia() async {
    final chatProvider = context.read<ChatProvider>();
    await chatProvider.loadSharedMedia(widget.room.id);
  }

  Future<void> _leaveRoom() async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: '채팅방 나가기',
      message: '이 채팅방을 나가시겠습니까?\n나가면 대화 내용을 더 이상 볼 수 없습니다.',
      confirmText: '나가기',
      cancelText: '취소',
    );

    if (confirmed == true && mounted) {
      final authProvider = context.read<AuthProvider>();
      final chatProvider = context.read<ChatProvider>();
      final userId = authProvider.currentUser?.chatUserId ?? '';

      final success = await chatProvider.leaveRoom(widget.room.id, userId);
      if (!mounted) return;
      if (success) {
        // 채팅방 화면과 정보 화면 모두 닫기
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        // 채팅방 화면의 나가기 처리와 같은 문구
        AppSnackBar.showError(context, message: '채팅방 나가기에 실패했습니다.');
      }
    }
  }

  Future<void> _kickParticipant(ChatParticipant participant) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: '강제 퇴장',
      message: '${participant.userName}님을 강제 퇴장시키겠습니까?',
      confirmText: '퇴장',
      cancelText: '취소',
      confirmVariant: SeedButtonVariant.critical,
    );

    if (confirmed == true && mounted) {
      final chatProvider = context.read<ChatProvider>();
      final ok = await chatProvider.removeParticipant(
        widget.room.id,
        participant.userId,
        isKicked: true,
      );
      if (!ok && mounted) {
        AppSnackBar.showError(
          context,
          message: '${participant.userName}님을 내보내지 못했습니다. 잠시 후 다시 시도해 주세요',
        );
      }
    }
  }

  /// 사진·파일을 채팅 말풍선과 같은 방식으로 연다 (이미지는 전체화면, 문서는 앱 내 뷰어).
  void _openMedia(ChatMessage media) {
    final url = media.fileUrl;
    final name = media.fileName ?? '파일';
    if (media.type == MessageType.image) {
      if (url == null || url.isEmpty) return;
      ChatImageViewer.open(
        context,
        imageUrl: url,
        fileName: name,
        onDownload: () => _openExternally(url),
      );
      return;
    }
    // 동영상은 채팅방 말풍선과 같이 내려받아 기기 기본 플레이어로 연다.
    if (media.isVideoMessage) {
      downloadAndOpenFile(context, url, name);
      return;
    }
    openServerDocument(
      context,
      filePath: url,
      fileName: name,
      onDownloadFallback: () => _openExternally(url),
    );
  }

  Future<void> _openExternally(String? url) async {
    if (url == null || url.isEmpty) {
      AppSnackBar.showError(context, message: '파일 URL이 없습니다');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) AppSnackBar.showError(context, message: '파일을 열 수 없습니다');
    }
  }

  /// 이름은 방 사람 모두의 목록에 보이므로 서버와 같은 규칙으로 가린다 —
  /// 관리자 계정·관리자 역할 직원, 또는 방을 만든 사람만.
  bool _canRename(AuthProvider auth) {
    final user = auth.currentUser;
    if (user == null) return false;
    if (user.isAdminAccount || AdminUtils.isAdmin(user)) return true;
    return widget.room.createdBy.isNotEmpty &&
        widget.room.createdBy == user.chatUserId;
  }

  Future<void> _renameRoom() async {
    final input = await AppDialog.showInput(
      context,
      title: '채팅방 이름 바꾸기',
      message: '바꾼 이름은 이 방 사람 모두에게 보입니다',
      initialValue: _roomName,
      confirmText: '저장',
      maxLength: Constants.maxChatRoomNameLength,
      validator: (value) =>
          (value ?? '').trim().isEmpty ? '이름을 입력해 주세요' : null,
    );
    final name = input?.trim();
    if (!mounted || name == null || name.isEmpty || name == _roomName) return;

    final ok = await context.read<ChatProvider>().updateChatRoom(
      roomId: widget.room.id,
      name: name,
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _roomName = name);
      AppSnackBar.showSuccess(context, message: '채팅방 이름을 바꿨습니다');
    } else {
      AppSnackBar.showError(context, message: '이름을 바꾸지 못했습니다. 잠시 후 다시 시도해 주세요');
    }
  }

  Future<void> _inviteParticipants() async {
    // TODO: 참가자 초대 화면으로 이동
    AppSnackBar.showInfo(context, message: '참가자 초대 기능은 추후 구현됩니다');
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isAdmin = AdminUtils.canAccessAdminPages(authProvider.currentUser);
    final currentUserId = authProvider.currentUser?.chatUserId ?? '';

    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: Text(
          '채팅방 정보',
          style: AppTypography.heading6.copyWith(
            color: AppSemanticColors.headerForeground,
          ),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 채팅방 기본 정보
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.space4),
            color: AppSemanticColors.surfaceDefault,
            child: Column(
              children: [
                // 채팅방 아이콘
                Container(
                  width: AppSpacing.space20,
                  height: AppSpacing.space20,
                  decoration: BoxDecoration(
                    // 배경과 아이콘색이 한 짝(둘 다 primary)이 되도록 — 관리자 여부로 배경만 바뀌지 않게
                    color: AppSemanticColors.interactivePrimaryDefault
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_rounded,
                    color: AppSemanticColors.interactivePrimaryDefault,
                    size: 40,
                  ),
                ),
                const SizedBox(height: AppSpacing.space3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        _roomName,
                        textAlign: TextAlign.center,
                        style: AppTypography.heading5.copyWith(
                          color: AppSemanticColors.textPrimary,
                        ),
                      ),
                    ),
                    if (_canRename(authProvider))
                      IconButton(
                        tooltip: '채팅방 이름 바꾸기',
                        onPressed: _renameRoom,
                        icon: Icon(
                          Icons.edit_outlined,
                          size: AppSpacing.space5,
                          color: AppSemanticColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                if (widget.room.description != null &&
                    widget.room.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.space1),
                    child: Text(
                      widget.room.description!,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppSemanticColors.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),

          Divider(height: 1, thickness: 1, color: AppSemanticColors.borderSubtle),

          _buildPinRow(),

          Divider(height: 1, thickness: 1, color: AppSemanticColors.borderSubtle),

          // 탭바 — 화면 안쪽 머리(연한 틸 면 + 아래 연한 틸 선)
          Container(
            decoration: const BoxDecoration(
              color: AppSemanticColors.subheaderBackground,
              border: Border(
                bottom: BorderSide(color: AppSemanticColors.subheaderBorder),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              // 연한 안쪽 머리(subheader) 위라 상단 바 글자색(흰색)이 아니라 본문 글자색
              labelColor: AppSemanticColors.textPrimary,
              unselectedLabelColor: AppSemanticColors.textSecondary,
              indicatorColor: AppSemanticColors.sectionMarker,
              labelStyle: AppTypography.labelLarge.copyWith(
                fontWeight: AppTypography.fontWeightBold,
              ),
              unselectedLabelStyle: AppTypography.labelLarge,
              dividerColor: AppColors.transparent,
              tabs: [
                Tab(text: '참가자 (${widget.room.participantCount})'),
                const Tab(text: '미디어'),
              ],
            ),
          ),

          // 탭 내용
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildParticipantsTab(isAdmin, currentUserId),
                _buildMediaTab(isAdmin),
              ],
            ),
          ),

          // 하단 버튼
          Container(
            padding: EdgeInsets.only(
              left: AppSpacing.space4,
              right: AppSpacing.space4,
              top: AppSpacing.space3,
              bottom: AppSpacing.space3 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: AppSemanticColors.surfaceDefault,
              border: Border(
                top: BorderSide(color: AppSemanticColors.borderSubtle),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: SeedButton(
                label: '채팅방 나가기',
                variant: SeedButtonVariant.neutralOutline,
                onPressed: _leaveRoom,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// '상단 고정' 스위치 줄 — 채팅 목록 길게 누르기와 같은 ChatProvider.togglePin을 쓴다.
  Widget _buildPinRow() {
    final provider = context.watch<ChatProvider>();
    var pinned = widget.room.pinned;
    ChatRoom? current;
    for (final r in provider.chatRooms) {
      if (r.id == widget.room.id) {
        current = r;
        pinned = r.pinned;
        break;
      }
    }
    return Container(
      color: AppSemanticColors.surfaceDefault,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space1,
      ),
      child: Row(
        children: [
          Icon(
            Icons.push_pin_outlined,
            size: AppSpacing.space5,
            color: AppSemanticColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Text(
              '상단 고정',
              style: AppTypography.bodyLarge.copyWith(
                color: AppSemanticColors.textPrimary,
              ),
            ),
          ),
          Switch(
            value: pinned,
            onChanged: (_) => _togglePin(current ?? widget.room),
            activeTrackColor: AppSemanticColors.interactivePrimaryDefault,
            activeThumbColor: AppSemanticColors.textInverse,
          ),
        ],
      ),
    );
  }

  Future<void> _togglePin(ChatRoom room) async {
    final provider = context.read<ChatProvider>();
    final success = await provider.togglePin(room);
    if (!mounted || success) return;
    AppSnackBar.showError(
      context,
      message: provider.errorMessage.isNotEmpty
          ? provider.errorMessage
          : '상단 고정 변경에 실패했습니다.',
    );
  }

  Widget _buildParticipantsTab(bool isAdmin, String currentUserId) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final participants = chatProvider.participants;

        // 현재 사용자가 방장인지 확인
        final isRoomAdmin = participants.any(
          (p) => p.userId == currentUserId && p.role == ParticipantRole.admin,
        );

        return Column(
          children: [
            // 참가자 초대 버튼
            if (_showInviteButton && isRoomAdmin)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.space4),
                child: SeedButton(
                  label: '참가자 초대',
                  variant: SeedButtonVariant.neutralWeak,
                  prefixIcon: Icons.person_add,
                  onPressed: _inviteParticipants,
                ),
              ),

            // 참가자 목록
            Expanded(
              child: participants.isEmpty
                  ? Center(
                      child: _participantsFailed
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '참가자 정보를 불러오지 못했습니다',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppSemanticColors.textTertiary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.space2),
                                SeedButton(
                                  label: '다시 시도',
                                  variant: SeedButtonVariant.neutralOutline,
                                  size: SeedButtonSize.small,
                                  onPressed: _loadParticipants,
                                ),
                              ],
                            )
                          : Text(
                              _participantsLoading
                                  ? '참가자 정보를 불러오는 중...'
                                  : '참가자가 없습니다',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppSemanticColors.textTertiary,
                              ),
                            ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.space2,
                      ),
                      itemCount: participants.length,
                      itemBuilder: (context, index) {
                        final participant = participants[index];
                        final isCurrentUser =
                            participant.userId == currentUserId;
                        final participantMeta = [
                          if (participant.position?.trim().isNotEmpty ?? false)
                            participant.position!.trim(),
                          if (participant.memberRoleText?.isNotEmpty ?? false)
                            participant.memberRoleText!,
                        ];

                        final showAdminBadge =
                            participant.role == ParticipantRole.admin;
                        final showRemoveAction =
                            isRoomAdmin && !isCurrentUser;

                        return SeedListCell(
                          leading: SeedAvatar(
                            name: participant.userName,
                            imageUrl: participant.profileImageUrl,
                            size: SeedAvatarSize.medium,
                          ),
                          title: participant.userName +
                              (isCurrentUser ? ' (나)' : ''),
                          description: participantMeta.isNotEmpty
                              ? participantMeta.join(' • ')
                              : null,
                          showChevron: false,
                          trailing: (showAdminBadge || showRemoveAction)
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (showAdminBadge)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.space2,
                                          vertical: AppSpacing.space1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppSemanticColors
                                              .interactivePrimaryDefault
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            AppBorderRadius.base,
                                          ),
                                        ),
                                        child: Text(
                                          '방장',
                                          style: AppTypography.labelSmall
                                              .copyWith(
                                            color: AppSemanticColors
                                                .interactivePrimaryDefault,
                                          ),
                                        ),
                                      ),
                                    if (showRemoveAction)
                                      IconButton(
                                        tooltip: '참가자 내보내기',
                                        icon: Icon(
                                          Icons.remove_circle_outline,
                                          color: AppSemanticColors
                                              .statusErrorIcon,
                                        ),
                                        onPressed: () =>
                                            _kickParticipant(participant),
                                      ),
                                  ],
                                )
                              : null,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMediaTab(bool isAdmin) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final media = chatProvider.sharedMedia;

        if (media.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 48,
                  color: AppSemanticColors.textDisabled,
                ),
                const SizedBox(height: AppSpacing.space3),
                Text(
                  '공유된 미디어가 없습니다',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        // 이미지와 파일 분리
        final images = media.where((m) => m.type == MessageType.image).toList();
        final files = media.where((m) => m.type == MessageType.file).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 이미지
              if (images.isNotEmpty) ...[
                Text(
                  '사진 (${images.length})',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppSemanticColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space2),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: AppSpacing.space2,
                    crossAxisSpacing: AppSpacing.space2,
                  ),
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    final image = images[index];
                    // 썸네일을 누르면 말풍선과 같은 전체화면 원본 보기
                    return Semantics(
                      button: true,
                      label: '사진 확대 보기',
                      child: GestureDetector(
                        onTap: () => _openMedia(image),
                        child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                        // 그리드는 목록 표시이므로 서버 썸네일이 있으면 그걸 쓰고
                        // (chat_room_screen.dart와 같은 단일 지점), 탭했을 때
                        // 열리는 전체화면(_openMedia)은 계속 원본 fileUrl을 쓴다.
                        child: CachedNetworkImage(
                          imageUrl: resolveChatImageUrl(image) ?? '',
                          fit: BoxFit.cover,
                          // 3열 그리드 썸네일 크기에 맞춰 원본 디코드를 제한
                          memCacheWidth: 300,
                          errorWidget: (_, __, ___) => Container(
                            color: AppSemanticColors.backgroundTertiary,
                            child: Icon(
                              Icons.broken_image,
                              color: AppSemanticColors.textTertiary,
                            ),
                          ),
                        ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.space6),
              ],

              // 파일
              if (files.isNotEmpty) ...[
                Text(
                  '파일 (${files.length})',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppSemanticColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space2),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    return SeedListCell(
                      leadingIcon: file.isVideoMessage
                          ? Icons.videocam_outlined
                          : Icons.insert_drive_file,
                      title: file.fileName ?? '파일',
                      description: _formatFileSize(file.fileSize),
                      showChevron: false,
                      onTap: () => _openMedia(file),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
