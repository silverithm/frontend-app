import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat_room.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/admin_utils.dart';
import '../widgets/seed/seed_avatar.dart';
import '../widgets/seed/seed_button.dart';
import 'chat_room_screen.dart';
import 'create_chat_room_screen.dart';

class ChatRoomListScreen extends StatefulWidget {
  const ChatRoomListScreen({super.key});

  @override
  State<ChatRoomListScreen> createState() => _ChatRoomListScreenState();
}

class _ChatRoomListScreenState extends State<ChatRoomListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChatRooms();
      _connectWebSocket();
    });
  }

  Future<void> _loadChatRooms() async {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();

    if (authProvider.currentUser != null) {
      final companyId = authProvider.currentUser!.company?.id ?? '1';
      final userId = authProvider.currentUser!.id;

      await chatProvider.loadChatRooms(companyId: companyId, userId: userId);
    }
  }

  Future<void> _connectWebSocket() async {
    final chatProvider = context.read<ChatProvider>();
    await chatProvider.connectWebSocket();
  }

  void _navigateToChatRoom(ChatRoom room) {
    final chatProvider = context.read<ChatProvider>();
    chatProvider.selectRoom(room);

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ChatRoomScreen(room: room)));
  }

  void _navigateToCreateChatRoom() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CreateChatRoomScreen()))
        .then((created) {
          if (created == true) {
            _loadChatRooms();
          }
        });
  }

  String _formatLastMessageTime(DateTime? time) {
    if (time == null) return '';

    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 0) {
      if (diff.inDays == 1) return '어제';
      if (diff.inDays < 7) return '${diff.inDays}일 전';
      return '${time.month}/${time.day}';
    }

    if (diff.inHours > 0) return '${diff.inHours}시간 전';
    if (diff.inMinutes > 0) return '${diff.inMinutes}분 전';
    return '방금';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isAdmin = AdminUtils.canAccessAdminPages(authProvider.currentUser);

    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: Text('채팅', style: AppTypography.heading5),
        backgroundColor: AppSemanticColors.backgroundPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: AppSemanticColors.textPrimary),
            onPressed: _navigateToCreateChatRoom,
            tooltip: '새 채팅방',
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          if (chatProvider.isLoading && chatProvider.chatRooms.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (chatProvider.errorMessage.isNotEmpty &&
              chatProvider.chatRooms.isEmpty) {
            return _buildErrorState();
          }

          if (chatProvider.chatRooms.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: _loadChatRooms,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
              itemCount: chatProvider.chatRooms.length,
              itemBuilder: (context, index) {
                final room = chatProvider.chatRooms[index];
                return _buildChatRoomTile(room, isAdmin);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: AppSpacing.space16,
            color: AppSemanticColors.textDisabled,
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            '아직 채팅방이 없어요',
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.space1_5),
          Text(
            '+ 버튼으로 첫 채팅을 시작해보세요',
            style: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: AppSpacing.space12,
            color: AppSemanticColors.statusErrorIcon,
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            '채팅방 목록을 불러오지 못했습니다',
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          SeedButton(
            label: '다시 시도',
            variant: SeedButtonVariant.neutralWeak,
            size: SeedButtonSize.small,
            onPressed: _loadChatRooms,
          ),
        ],
      ),
    );
  }

  Widget _buildChatRoomTile(ChatRoom room, bool isAdmin) {
    return InkWell(
      onTap: () => _navigateToChatRoom(room),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space3,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppSemanticColors.borderSubtle),
          ),
        ),
        child: Row(
          children: [
            // 채팅방 아바타/썸네일
            SeedAvatar(
              name: room.name,
              imageUrl: room.thumbnailUrl,
              size: SeedAvatarSize.large,
            ),
            const SizedBox(width: AppSpacing.space3),

            // 채팅방 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                room.name,
                                style: AppTypography.bodyLarge.copyWith(
                                  fontWeight: room.unreadCount > 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: AppSemanticColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (room.participantCount > 0) ...[
                              const SizedBox(width: AppSpacing.space1),
                              Text(
                                '${room.participantCount}명',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppSemanticColors.textTertiary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space1),
                  if (room.lastMessage != null)
                    Text(
                      room.lastMessage!.displayContent,
                      style: AppTypography.bodyMedium.copyWith(
                        color: room.unreadCount > 0
                            ? AppSemanticColors.textSecondary
                            : AppSemanticColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      '새로운 채팅방',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppSemanticColors.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),

            // 시간 및 안읽은 수
            const SizedBox(width: AppSpacing.space2),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatLastMessageTime(room.lastMessageAt ?? room.createdAt),
                  style: AppTypography.labelSmall.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space1),
                if (room.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space2,
                      vertical: AppSpacing.space1,
                    ),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.interactivePrimaryDefault,
                      borderRadius: BorderRadius.circular(AppBorderRadius.full),
                    ),
                    child: Text(
                      room.unreadCount > 99 ? '99+' : '${room.unreadCount}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppSemanticColors.textInverse,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
