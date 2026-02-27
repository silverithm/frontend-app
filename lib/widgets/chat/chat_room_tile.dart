import 'package:flutter/material.dart';
import '../../models/chat_room.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_theme.dart';

class ChatRoomTile extends StatelessWidget {
  final ChatRoom room;
  final VoidCallback onTap;
  final bool isAdmin;

  const ChatRoomTile({
    super.key,
    required this.room,
    required this.onTap,
    this.isAdmin = false,
  });

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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space3,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppSemanticColors.borderDefault.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Row(
          children: [
            // 채팅방 아이콘/썸네일
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isAdmin
                    ? AppSemanticColors.interactiveSecondaryDefault.withValues(alpha: 0.1)
                    : AppSemanticColors.interactivePrimaryDefault.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppBorderRadius.xl),
              ),
              child: room.thumbnailUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                      child: Image.network(
                        room.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildDefaultIcon(),
                      ),
                    )
                  : _buildDefaultIcon(),
            ),
            const SizedBox(width: AppSpacing.space3),

            // 채팅방 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.name,
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: room.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                            color: AppSemanticColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (room.participantCount > 0) ...[
                        const SizedBox(width: AppSpacing.space1),
                        Text(
                          '${room.participantCount}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppSemanticColors.textTertiary,
                          ),
                        ),
                      ],
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

  Widget _buildDefaultIcon() {
    return Center(
      child: Icon(
        Icons.chat_bubble_rounded,
        color: isAdmin
            ? AppSemanticColors.textSecondary
            : AppSemanticColors.interactivePrimaryDefault,
        size: 24,
      ),
    );
  }
}
