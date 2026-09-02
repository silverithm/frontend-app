import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../seed/seed_avatar.dart';

/// 채팅 버블 왼쪽의 아바타 자리.
///
/// 연속 메시지 그룹의 첫 메시지에만 [visible]을 true로 줘서 아바타를 그리고,
/// 이어지는 메시지는 false로 줘서 같은 폭만 차지하게 한다 — 그래야 버블들이
/// 세로로 정렬된다.
class ChatAvatarSlot extends StatelessWidget {
  final bool visible;
  final String senderName;
  final String? imageUrl;

  /// SeedAvatarSize.small의 지름(32)과 같다.
  static const double width = AppSpacing.space8;

  const ChatAvatarSlot({
    super.key,
    required this.visible,
    required this.senderName,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: visible
          ? SeedAvatar(
              name: senderName,
              imageUrl: imageUrl,
              size: SeedAvatarSize.small,
            )
          : null,
    );
  }
}

/// 말풍선 위에 한 줄로 놓이는 발신자 표시 — "이름 (직종)".
///
/// 아바타 오른쪽, 말풍선 위에 놓이므로 화면 가로폭 대부분을 쓸 수 있다.
/// 예전에는 아바타 아래 64px 열에 세로로 쌓여 "사회복지사" 같은 직종이
/// 툭하면 잘렸는데, 이 배치에서는 남는 폭 전부를 쓰므로 현실적인 길이의
/// 직종명은 잘리지 않는다. 정말 화면을 넘길 때만 말줄임된다.
///
/// 이름과 직종은 **하나의 문단**(Text.rich)으로 그린다. 두 위젯으로 나누면
/// Row가 폭을 나눠 갖느라 긴 직종이 먼저 잘리기 때문이다.
/// `test/chat_sender_header_test.dart`가 실제 렌더 결과로 이를 검증한다.
class ChatSenderHeader extends StatelessWidget {
  final String senderName;
  final String? senderPosition;

  const ChatSenderHeader({
    super.key,
    required this.senderName,
    this.senderPosition,
  });

  /// 이름·직종을 담은 문단의 키(잘림 검증용).
  static const Key textKey = Key('chat_sender_header_text');

  @override
  Widget build(BuildContext context) {
    final trimmedPosition = senderPosition?.trim();
    final hasPosition = trimmedPosition != null && trimmedPosition.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space1),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: senderName,
              style: AppTypography.labelSmall.copyWith(
                color: AppSemanticColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hasPosition)
              TextSpan(
                text: ' ($trimmedPosition)',
                style: AppTypography.labelSmall.copyWith(
                  color: AppSemanticColors.textTertiary,
                ),
              ),
          ],
        ),
        key: textKey,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
