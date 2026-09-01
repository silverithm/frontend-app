import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../seed/seed_avatar.dart';

/// 채팅 버블 왼쪽 열 — 아바타 → 이름 → 직종을 세로로 쌓는다(카톡 배치).
///
/// 연속 메시지 그룹에서는 첫 메시지에만 [visible]을 true로 줘서 내용을 그리고,
/// 이어지는 메시지는 [visible]을 false로 줘서 내용 없이 같은 [width]만
/// 차지하게 한다 — 그래야 버블들이 세로로 정렬된다.
///
/// 폭([width])은 "사회복지사"·"요양보호사"·"간호조무사" 같은 흔한 5글자
/// 직종명이 한 줄에 들어가도록 잡혀 있어야 한다(그렇지 않으면 말줄임된다).
/// `test/chat_sender_header_test.dart`가 실제 렌더 결과로 이를 검증한다.
class ChatSenderHeader extends StatelessWidget {
  final bool visible;
  final String senderName;
  final String? senderPosition;
  final String? imageUrl;
  final double width;

  const ChatSenderHeader({
    super.key,
    required this.visible,
    required this.senderName,
    this.senderPosition,
    this.imageUrl,
    this.width = 64,
  });

  static const Key nameTextKey = Key('chat_sender_header_name');
  static const Key positionTextKey = Key('chat_sender_header_position');

  @override
  Widget build(BuildContext context) {
    final trimmedPosition = senderPosition?.trim();
    final hasPosition = trimmedPosition != null && trimmedPosition.isNotEmpty;

    return SizedBox(
      width: width,
      child: !visible
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SeedAvatar(
                  name: senderName,
                  imageUrl: imageUrl,
                  size: SeedAvatarSize.small,
                ),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  senderName,
                  key: nameTextKey,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppSemanticColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // 흔한 5글자 직종("사회복지사" 등)은 한 줄에 들어가지만
                // 더 긴 것("주간보호센터장" 등)은 2줄까지 허용하고
                // 그래도 넘치면 말줄임한다.
                if (hasPosition)
                  Text(
                    trimmedPosition,
                    key: positionTextKey,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppSemanticColors.textTertiary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
    );
  }
}
