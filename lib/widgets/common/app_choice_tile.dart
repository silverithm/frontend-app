import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 여러 개 중 하나를 고르는 타일(우선순위·게시 상태 등).
///
/// 선택 모양은 한 가지다 — brandWeak 바탕 + 틸 테두리 1.5px. 긴급 같은 의미 색은
/// [accentColor]로 아이콘·글자에만 쓰고 테두리·바탕에는 쓰지 않는다.
/// 라벨 굵기는 선택 여부와 상관없이 같아서 고르는 순간 글자 폭이 흔들리지 않는다.
class AppChoiceTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color? accentColor;

  const AppChoiceTile({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor =
        accentColor ?? AppSemanticColors.interactivePrimaryDefault;
    final contentColor =
        selected ? activeColor : AppSemanticColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
          decoration: BoxDecoration(
            color: selected
                ? AppSemanticColors.brandWeak
                : AppSemanticColors.surfaceDefault,
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            border: Border.all(
              color: selected
                  ? AppSemanticColors.interactivePrimaryDefault
                  : AppSemanticColors.borderDefault,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? contentColor : AppSemanticColors.textTertiary,
                size: 20,
              ),
              const SizedBox(height: AppSpacing.space1),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(color: contentColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
