import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_lines.dart';
import '../../theme/app_spacing.dart';
import '../common/app_skeleton.dart';

/// 채팅 목록(대화방·직원) 첫 불러오기 뼈대 — B안.
///
/// 실제 목록([ChatCardSlice] + [ChatListRow])과 같은 바깥 여백(좌우 16·위 8)·카드 안쪽 여백(8)·
/// 줄 여백(좌우 12·위아래 10)·아바타 크기라 내용이 떠도 자리가 덜 튄다.
/// [groups]는 흰 카드마다 줄 수 — 직원 목록은 `[1, 6]`(나 + 나머지)에 [groupLabel]로 그 사이
/// "직원 n명" 줄 자리를 비워 둔다. 스크롤되지 않는다.
class ChatListSkeleton extends StatelessWidget {
  const ChatListSkeleton({
    super.key,
    this.groups = const [6],
    this.avatarSize = 48,
    this.groupLabel = false,
    this.fullBleed = false,
  });

  /// 대화·직원 탭처럼 카드 없이 화면 끝까지 채우는 목록의 뼈대면 true.
  final bool fullBleed;

  final List<int> groups;
  final double avatarSize;

  /// 카드 사이에 짧은 안내 줄 자리를 둘지(직원 목록의 "직원 n명 · 접속 중 n명").
  final bool groupLabel;

  @override
  Widget build(BuildContext context) {
    var row = 0;
    return AppSkeleton(
      // 흰 카드 안의 뼈는 한 단계 옅은 색
      baseColor: AppSemanticColors.skeletonBaseOnCard,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: fullBleed
            ? const EdgeInsets.only(bottom: AppSpacing.space6)
            : const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.space2,
                AppSpacing.screenGutter,
                AppSpacing.space6,
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var g = 0; g < groups.length; g++) ...[
              // 안내 줄 자리(위아래 8 + 글자 한 줄)는 비워 둔다 — 회색 바탕 위라 카드 안 뼈 색이 안 보인다
              if (g > 0 && groupLabel)
                const SizedBox(
                  height: AppSpacing.space2 * 2 + AppSpacing.space5,
                ),
              Container(
                margin: EdgeInsets.only(
                  bottom: fullBleed ? 0 : AppSpacing.cardGap,
                ),
                padding: fullBleed
                    ? const EdgeInsets.symmetric(horizontal: AppSpacing.space1)
                    : const EdgeInsets.all(AppSpacing.space2),
                decoration: fullBleed
                    ? const BoxDecoration(color: AppSemanticColors.surfaceCard)
                    : BoxDecoration(
                        color: AppSemanticColors.surfaceCard,
                        borderRadius: BorderRadius.circular(
                          AppBorderRadius.card,
                        ),
                        border: AppLines.cardBorder,
                      ),
                child: Column(
                  children: [
                    for (var i = 0; i < groups[g]; i++)
                      ChatSkeletonRow(avatarSize: avatarSize, index: row++),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 채팅 목록 뼈대의 한 줄 — [ChatListRow]와 같은 줄 여백(좌우 12·위아래 10)에 동그라미 + 두 줄.
/// 바깥에 [AppSkeleton]이 있어야 빛이 돈다. [index]마다 줄 길이를 조금씩 달리한다.
class ChatSkeletonRow extends StatelessWidget {
  const ChatSkeletonRow({super.key, this.avatarSize = 48, this.index = 0});

  final double avatarSize;
  final int index;

  static const List<double> _titleWidths = [0.5, 0.38, 0.62, 0.44, 0.56, 0.34];
  static const List<double> _subtitleWidths = [
    0.78,
    0.6,
    0.7,
    0.52,
    0.66,
    0.74,
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space2_5,
      ),
      child: Row(
        children: [
          AppSkeletonCircle(size: avatarSize),
          const SizedBox(width: AppSpacing.space3_5),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonLine(
                  widthFactor: _titleWidths[index % _titleWidths.length],
                  height: AppSpacing.space4,
                ),
                const SizedBox(height: AppSpacing.space2),
                AppSkeletonLine(
                  widthFactor: _subtitleWidths[index % _subtitleWidths.length],
                  height: AppSpacing.space3_5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
