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
import '../widgets/common/app_dialog.dart';
import '../widgets/seed/seed_avatar.dart';
import '../widgets/seed/seed_button.dart';
import '../utils/document_open.dart';
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
    await chatProvider.loadParticipants(widget.room.id);
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
      if (success && mounted) {
        // 채팅방 화면과 정보 화면 모두 닫기
        Navigator.of(context).popUntil((route) => route.isFirst);
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
      await chatProvider.removeParticipant(
        widget.room.id,
        participant.userId,
        isKicked: true,
      );
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
            color: AppSemanticColors.textPrimary,
          ),
        ),
        backgroundColor: AppSemanticColors.surfaceDefault,
        foregroundColor: AppSemanticColors.textPrimary,
        iconTheme: IconThemeData(color: AppSemanticColors.textPrimary),
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
                    color: isAdmin
                        ? AppSemanticColors.interactiveSecondaryDefault
                              .withValues(alpha: 0.1)
                        : AppSemanticColors.interactivePrimaryDefault
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
                Text(
                  widget.room.name,
                  style: AppTypography.heading5.copyWith(
                    color: AppSemanticColors.textPrimary,
                  ),
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

          // 탭바
          Container(
            color: AppSemanticColors.surfaceDefault,
            child: TabBar(
              controller: _tabController,
              labelColor: AppSemanticColors.interactivePrimaryDefault,
              unselectedLabelColor: AppSemanticColors.textTertiary,
              indicatorColor: AppSemanticColors.interactivePrimaryDefault,
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
            if (isRoomAdmin)
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
                      child: Text(
                        '참가자 정보를 불러오는 중...',
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

                        return ListTile(
                          leading: SeedAvatar(
                            name: participant.userName,
                            imageUrl: participant.profileImageUrl,
                            size: SeedAvatarSize.medium,
                          ),
                          title: Row(
                            children: [
                              Text(
                                participant.userName +
                                    (isCurrentUser ? ' (나)' : ''),
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppSemanticColors.textPrimary,
                                ),
                              ),
                              if (participant.role == ParticipantRole.admin)
                                Container(
                                  margin: const EdgeInsets.only(
                                    left: AppSpacing.space2,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.space2,
                                    vertical: AppSpacing.space1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isAdmin
                                        ? AppSemanticColors
                                              .interactiveSecondaryDefault
                                              .withValues(alpha: 0.1)
                                        : AppSemanticColors
                                              .interactivePrimaryDefault
                                              .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                      AppBorderRadius.base,
                                    ),
                                  ),
                                  child: Text(
                                    '방장',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppSemanticColors
                                          .interactivePrimaryDefault,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: participantMeta.isNotEmpty
                              ? Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSpacing.space0_5,
                                  ),
                                  child: Text(
                                    participantMeta.join(' • '),
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppSemanticColors.textTertiary,
                                    ),
                                  ),
                                )
                              : null,
                          trailing: isRoomAdmin && !isCurrentUser
                              ? IconButton(
                                  icon: Icon(
                                    Icons.remove_circle_outline,
                                    color: AppSemanticColors.statusErrorIcon,
                                  ),
                                  onPressed: () =>
                                      _kickParticipant(participant),
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
                    return GestureDetector(
                      onTap: () => _openMedia(image),
                      child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                      child: Image.network(
                        image.fileUrl ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppSemanticColors.backgroundTertiary,
                          child: Icon(
                            Icons.broken_image,
                            color: AppSemanticColors.textTertiary,
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
                    return ListTile(
                      leading: Container(
                        width: AppSpacing.space10,
                        height: AppSpacing.space10,
                        decoration: BoxDecoration(
                          color: AppSemanticColors.backgroundTertiary,
                          borderRadius: BorderRadius.circular(
                            AppBorderRadius.lg,
                          ),
                        ),
                        child: Icon(
                          Icons.insert_drive_file,
                          color: AppSemanticColors.textTertiary,
                        ),
                      ),
                      title: Text(
                        file.fileName ?? '파일',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppSemanticColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        _formatFileSize(file.fileSize),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppSemanticColors.textTertiary,
                        ),
                      ),
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
