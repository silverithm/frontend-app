import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import 'app_pressable.dart';

/// 여러 개 중 하나를 고르는 타일(우선순위·게시 상태 등).
///
/// B안(2026-11-12): 테두리 없이 칩과 같은 문법 — 고르면 틸 바탕 + 흰 아이콘·글자,
/// 고르기 전엔 회색 바탕 + 회색 글자. 긴급 같은 의미 색은 [accentColor]로 고르기 전 아이콘에만 쓴다
/// (틸 위에 빨강을 얹으면 읽기 어렵다). 라벨 굵기는 선택 여부와 상관없이 같아 폭이 흔들리지 않는다.
/// 누르면 selection 햅틱.
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
    final contentColor =
        selected ? AppSemanticColors.textInverse : AppSemanticColors.textSecondary;
    final iconColor = selected
        ? AppSemanticColors.textInverse
        : (accentColor ?? AppSemanticColors.iconSubtle);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AppPressable(
        onTap: onTap,
        haptic: AppHapticKind.selection,
        isButton: false,
        minTouchSize: Size.zero,
        focusBorderRadius: BorderRadius.circular(AppBorderRadius.control),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
          decoration: BoxDecoration(
            color: selected
                ? AppSemanticColors.brandDefault
                : AppSemanticColors.fillDefault,
            borderRadius: BorderRadius.circular(AppBorderRadius.control),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(height: AppSpacing.space1),
              Text(
                label,
                style: AppTypography.labelStrong.copyWith(color: contentColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
