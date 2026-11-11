import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../common/app_skeleton.dart';
import 'chat_sender_header.dart';

/// 채팅방 첫 불러오기 뼈대 — 남의 말풍선(왼쪽 아바타 32 + 이름 줄 + 말풍선)과 내 말풍선(오른쪽)을
/// 번갈아 둔다. 메시지 목록과 같은 바깥 여백 16·아바타 자리·말풍선 모서리 20.
class ChatMessagesSkeleton extends StatelessWidget {
  const ChatMessagesSkeleton({super.key});

  /// (내 말풍선인지, 말풍선 폭 비율, 같은 사람의 이어지는 말풍선인지)
  static const List<(bool, double, bool)> _bubbles = [
    (false, 0.62, false),
    (false, 0.4, true),
    (true, 0.5, false),
    (false, 0.7, false),
    (true, 0.36, false),
    (true, 0.56, true),
    (false, 0.48, false),
    (true, 0.42, false),
  ];

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (mine, factor, follow) in _bubbles)
                  Padding(
                    padding: EdgeInsets.only(
                      top: follow ? AppSpacing.space1 : AppSpacing.space4,
                    ),
                    child: mine
                        ? Align(
                            alignment: Alignment.centerRight,
                            child: AppSkeletonBox(
                              width: width * factor,
                              height: AppSpacing.space10,
                              radius: AppBorderRadius.card,
                            ),
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(width: AppSpacing.space1),
                              SizedBox(
                                width: ChatAvatarSlot.width,
                                child: follow
                                    ? null
                                    : const AppSkeletonCircle(
                                        size: ChatAvatarSlot.width,
                                      ),
                              ),
                              const SizedBox(width: AppSpacing.space2),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!follow) ...[
                                    const AppSkeletonLine(
                                      width: AppSpacing.space16,
                                      height: AppSpacing.space3,
                                    ),
                                    const SizedBox(height: AppSpacing.space1_5),
                                  ],
                                  AppSkeletonBox(
                                    width: width * factor,
                                    height: AppSpacing.space10,
                                    radius: AppBorderRadius.card,
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
