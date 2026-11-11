import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_pressable.dart';

/// 카드·구역 머리 — B안(2026-11-12, 시안 .card-h).
///
/// 제목 19/w700 + (숫자 알약) + 부제 14 회색, 오른쪽에 틸 글자 링크("전체보기 ›").
/// 회색 머리띠·아래 선 없이 카드 안 맨 위에 둔다. 링크는 높이 48 터치.
class SeedSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 제목 옆 옅은 틸 숫자 알약(예: 처리할 결재 0). null이면 그리지 않는다.
  final int? count;

  const SeedSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.space2,
                runSpacing: AppSpacing.space1,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: AppTypography.heading6.copyWith(
                        color: AppSemanticColors.textPrimary,
                      ),
                    ),
                  ),
                  if (count != null) SeedCountPill(count: count!),
                ],
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space0_5),
                Text(
                  subtitle!,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          // 시안: 높이 40 링크를 위·오른쪽으로 살짝 끌어올려 제목 줄과 맞춘다. 터치는 48.
          Transform.translate(
            offset: const Offset(AppSpacing.space2, -AppSpacing.space2),
            child: AppPressable(
              onTap: onAction,
              pressedScale: 0.97,
              semanticLabel: '$title $actionLabel',
              focusBorderRadius: BorderRadius.circular(AppBorderRadius.xl),
              child: Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.space2_5,
                  right: AppSpacing.space1_5,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel!,
                      style: AppTypography.titleSmall.copyWith(
                        color: AppSemanticColors.textLink,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppSemanticColors.textLink,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 옅은 틸 숫자 알약(시안 .count) — 제목 옆 건수.
class SeedCountPill extends StatelessWidget {
  const SeedCountPill({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 26, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppSemanticColors.brandWeak,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
      ),
      child: Text(
        '$count',
        style: AppTypography.titleSmall.copyWith(
          color: AppSemanticColors.brandWeakForeground,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
