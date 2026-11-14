import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_lines.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import 'app_pressable.dart';

/// 여럿 중 하나 고르기 — 같은 폭 칸을 [columns]개씩 줄 세운다(크로박스 기분 고르기 칸, 2026-11-14).
///
/// 예전엔 글자 길이대로 폭이 다른 알약(SeedChip)을 Wrap으로 흘려, 줄 끝이 들쭉날쭉하고
/// 둘째 줄이 반만 찼다. 칸 폭을 똑같이 나누면 줄이 시트 폭을 꽉 채운다.
/// 고르기 전은 흰 바탕 + 1px 테두리, 고르면 옅은 틸 바탕 + 틸 테두리 + 굵은 틸 글자.
/// 한 칸 높이 48 이상, 글자를 키우면 칸이 같이 커진다(줄의 칸 높이는 서로 맞춘다).
class AppChoiceGrid<T> extends StatelessWidget {
  final List<T> values;
  final T? selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;
  final int columns;

  const AppChoiceGrid({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.columns = 3,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <List<T>>[];
    for (var i = 0; i < values.length; i += columns) {
      rows.add(values.sublist(i, (i + columns).clamp(0, values.length)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: AppSpacing.space2),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: c < rows[r].length
                        ? _ChoiceTile(
                            label: labelOf(rows[r][c]),
                            selected: rows[r][c] == selected,
                            onTap: () => onSelected(rows[r][c]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: AppPressable(
        onTap: onTap,
        haptic: AppHapticKind.selection,
        minTouchSize: Size.zero,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          constraints: const BoxConstraints(minHeight: AppSpacing.space12),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space1,
            vertical: AppSpacing.space2_5,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppSemanticColors.brandWeak
                : AppSemanticColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppBorderRadius.control),
            border: selected
                ? Border.all(color: AppSemanticColors.brandDefault, width: 1.5)
                : Border.all(color: AppLines.cardColor),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: AppTypography.fontWeightSemibold,
              color: selected
                  ? AppSemanticColors.brandWeakForeground
                  : AppSemanticColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
