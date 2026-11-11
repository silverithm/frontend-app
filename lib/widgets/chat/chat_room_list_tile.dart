import 'package:flutter/material.dart';

import '../../models/chat_room.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'chat_list_row.dart';
import 'chat_room_avatar_stack.dart';

/// 채팅 목록의 방 한 줄 — B안: 흰 카드 안 줄([ChatCardSlice] 안에 둔다), 높이 68(위아래 10 + 아바타 48),
/// 구분선 없음.
///
/// 제목 titleMedium(16/w600, 읽음 여부로 굵기를 바꾸지 않는다) · 미리보기 bodyMedium 16 ·
/// 시간·인원 bodySmall 14. 시간은 제목 줄 오른쪽, 안 읽은 수는 미리보기 줄 오른쪽 —
/// 높이를 못 박지 않아 글자를 크게 해도 넘치지 않는다. 고정 핀은 제목 앞이 아니라 시간 옆에 둬서
/// 제목이 모든 줄에서 같은 x에서 시작한다.
class ChatRoomListTile extends StatelessWidget {
  const ChatRoomListTile({
    super.key,
    required this.room,
    required this.timeLabel,
    required this.onTap,
    required this.onLongPress,
  });

  final ChatRoom room;

  /// 마지막 대화 시각을 이미 줄여 쓴 글('방금'·'3시간 전'·'어제' 등). 계산은 화면이 한다.
  final String timeLabel;
  final VoidCallback onTap;

  /// 길게 누르면 방 메뉴(고정·나가기·삭제).
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    const avatarSize = 48.0;
    return ChatListRow(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        children: [
          // 채팅방 아바타/썸네일
          // 참여자 얼굴을 모아 보여준다 (카카오톡과 같은 방식).
          // 참여자를 못 받은 방은 위젯이 알아서 방 이름 첫 글자로 그린다.
          ChatRoomAvatarStack(
            roomName: room.name,
            avatars: room.avatars,
            size: avatarSize,
          ),
          const SizedBox(width: AppSpacing.space3_5),

          // 채팅방 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              room.name,
                              style: AppTypography.titleMedium.copyWith(
                                color: AppSemanticColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (room.participantCount > 0) ...[
                            const SizedBox(width: AppSpacing.space1_5),
                            Text(
                              '${room.participantCount}명',
                              maxLines: 1,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppSemanticColors.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    if (room.pinned) ...[
                      Icon(
                        Icons.push_pin,
                        size: AppSpacing.space3_5,
                        color: AppSemanticColors.brandDefault,
                      ),
                      const SizedBox(width: AppSpacing.space1),
                    ],
                    Text(
                      timeLabel,
                      maxLines: 1,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppSemanticColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space0_5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 안 읽은 방은 굵기가 아니라 빨간 숫자 하나로만 알린다
                    Expanded(
                      child: Text(
                        room.lastMessage?.displayContent ?? '새로운 채팅방',
                        style: AppTypography.bodyMedium.copyWith(
                          color: room.unreadCount > 0
                              ? AppSemanticColors.textSecondary
                              : AppSemanticColors.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (room.unreadCount > 0) ...[
                      const SizedBox(width: AppSpacing.space2),
                      _UnreadBadge(count: room.unreadCount),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 안 읽은 수 — 아래 탭·알림 종·웹 채팅 목록과 같은 빨강(틸은 '누르라'는 단추 색이다).
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: AppSpacing.space5,
        minHeight: AppSpacing.space5,
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space1_5),
      decoration: BoxDecoration(
        color: AppSemanticColors.badgeBackground,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        maxLines: 1,
        style: AppTypography.labelStrong.copyWith(
          color: AppSemanticColors.textInverse,
          height: 1.2,
        ),
      ),
    );
  }
}
