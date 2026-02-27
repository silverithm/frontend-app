import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat_room.dart';
import '../models/chat_message.dart';
import '../models/chat_participant.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/admin_utils.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

class ChatRoomInfoScreen extends StatefulWidget {
  final ChatRoom room;

  const ChatRoomInfoScreen({super.key, required this.room});

  @override
  State<ChatRoomInfoScreen> createState() => _ChatRoomInfoScreenState();
}

class _ChatRoomInfoScreenState extends State<ChatRoomInfoScreen> with SingleTickerProviderStateMixin {
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => shadcn.AlertDialog(
        title: const Text('채팅방 나가기'),
        content: const Text('이 채팅방을 나가시겠습니까?\n나가면 대화 내용을 더 이상 볼 수 없습니다.'),
        actions: [
          shadcn.OutlineButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          shadcn.DestructiveButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = context.read<AuthProvider>();
      final chatProvider = context.read<ChatProvider>();
      final userId = authProvider.currentUser?.id ?? '';

      final success = await chatProvider.leaveRoom(widget.room.id, userId);
      if (success && mounted) {
        // 채팅방 화면과 정보 화면 모두 닫기
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _kickParticipant(ChatParticipant participant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => shadcn.AlertDialog(
        title: const Text('강제 퇴장'),
        content: Text('${participant.userName}님을 강제 퇴장시키겠습니까?'),
        actions: [
          shadcn.OutlineButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          shadcn.DestructiveButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('퇴장'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final chatProvider = context.read<ChatProvider>();
      await chatProvider.removeParticipant(widget.room.id, participant.userId, isKicked: true);
    }
  }

  Future<void> _inviteParticipants() async {
    // TODO: 참가자 초대 화면으로 이동
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('참가자 초대 기능은 추후 구현됩니다')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isAdmin = AdminUtils.canAccessAdminPages(authProvider.currentUser);
    final currentUserId = authProvider.currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: Text(
          '채팅방 정보',
          style: AppTypography.heading6.copyWith(
            color: isAdmin ? AppSemanticColors.textInverse : AppSemanticColors.textPrimary,
          ),
        ),
        backgroundColor: isAdmin
            ? AppSemanticColors.interactivePrimaryDefault
            : AppSemanticColors.surfaceDefault,
        foregroundColor: isAdmin ? AppSemanticColors.textInverse : AppSemanticColors.textPrimary,
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
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isAdmin
                        ? AppSemanticColors.interactiveSecondaryDefault.withValues(alpha: 0.1)
                        : AppSemanticColors.interactivePrimaryDefault.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_rounded,
                    color: isAdmin
                        ? AppSemanticColors.interactiveSecondaryDefault
                        : AppSemanticColors.interactivePrimaryDefault,
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
                if (widget.room.description != null && widget.room.description!.isNotEmpty)
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

          // 탭바
          Container(
            color: AppSemanticColors.surfaceDefault,
            child: TabBar(
              controller: _tabController,
              labelColor: isAdmin
                  ? AppSemanticColors.interactiveSecondaryDefault
                  : AppSemanticColors.interactivePrimaryDefault,
              unselectedLabelColor: AppSemanticColors.textTertiary,
              indicatorColor: isAdmin
                  ? AppSemanticColors.interactiveSecondaryDefault
                  : AppSemanticColors.interactivePrimaryDefault,
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
                top: BorderSide(
                  color: AppSemanticColors.borderDefault.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: shadcn.DestructiveButton(
                onPressed: _leaveRoom,
                child: const Text('채팅방 나가기'),
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
                child: shadcn.OutlineButton(
                  onPressed: _inviteParticipants,
                  leading: const Icon(Icons.person_add),
                  child: const Text('참가자 초대'),
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
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
                      itemCount: participants.length,
                      itemBuilder: (context, index) {
                        final participant = participants[index];
                        final isCurrentUser = participant.userId == currentUserId;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isAdmin
                                ? AppSemanticColors.interactiveSecondaryDefault.withValues(alpha: 0.1)
                                : AppSemanticColors.interactivePrimaryDefault.withValues(alpha: 0.1),
                            child: Text(
                              participant.userName.isNotEmpty
                                  ? participant.userName[0]
                                  : '?',
                              style: AppTypography.bodyLarge.copyWith(
                                color: isAdmin
                                    ? AppSemanticColors.interactiveSecondaryDefault
                                    : AppSemanticColors.interactivePrimaryDefault,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                participant.userName + (isCurrentUser ? ' (나)' : ''),
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppSemanticColors.textPrimary,
                                ),
                              ),
                              if (participant.role == ParticipantRole.admin)
                                Container(
                                  margin: const EdgeInsets.only(left: AppSpacing.space2),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.space2,
                                    vertical: AppSpacing.space1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isAdmin
                                        ? AppSemanticColors.interactiveSecondaryDefault.withValues(alpha: 0.1)
                                        : AppSemanticColors.interactivePrimaryDefault.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppBorderRadius.base),
                                  ),
                                  child: Text(
                                    '방장',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: isAdmin
                                          ? AppSemanticColors.interactiveSecondaryDefault
                                          : AppSemanticColors.interactivePrimaryDefault,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: isRoomAdmin && !isCurrentUser
                              ? IconButton(
                                  icon: Icon(
                                    Icons.remove_circle_outline,
                                    color: AppSemanticColors.statusErrorIcon,
                                  ),
                                  onPressed: () => _kickParticipant(participant),
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
                    return ClipRRect(
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
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppSemanticColors.backgroundTertiary,
                          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
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
                      onTap: () {
                        // TODO: 파일 다운로드
                      },
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
