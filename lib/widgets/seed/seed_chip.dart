import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 당근 Seed 디자인 시스템 — Filter Chip.
/// 스펙 참조: docs/seed-component-specs.md §7 Chip
/// (사이즈별 height/padding-x/prefix 아이콘 크기, selected 시 brand weak 배경+텍스트/보더)
enum SeedChipSize { small, medium }

class SeedChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDisabled;
  final SeedChipSize size;
  final VoidCallback? onTap;
  final IconData? prefixIcon;

  const SeedChip({
    super.key,
    required this.label,
    this.selected = false,
    this.isDisabled = false,
    this.size = SeedChipSize.medium,
    this.onTap,
    this.prefixIcon,
  });

  // Height — spec §7: Small 32 / Medium 36
  double get _height => size == SeedChipSize.small ? 32 : 36;

  // Padding X — spec §7: Small x1.5 / Medium x2
  double get _paddingX =>
      size == SeedChipSize.small ? AppSpacing.space1_5 : AppSpacing.space2;

  // Prefix icon — spec §7: Small x3.5(14) / Medium x4(16)
  double get _iconSize => size == SeedChipSize.small ? 14 : 16;

  @override
  Widget build(BuildContext context) {
    final background = isDisabled
        ? AppSemanticColors.surfaceDisabled
        : selected
            ? AppSemanticColors.brandWeak
            : AppSemanticColors.interactiveSecondaryDefault;
    final border = (selected && !isDisabled) ? AppSemanticColors.brandDefault : null;
    final foreground = isDisabled
        ? AppSemanticColors.textDisabled
        : selected
            ? AppSemanticColors.brandPressed
            : AppSemanticColors.textSecondary;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1,
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: Container(
          height: _height,
          padding: EdgeInsets.symmetric(horizontal: _paddingX),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppBorderRadius.full),
            border: border != null ? Border.all(color: border, width: 1) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (prefixIcon != null) ...[
                Icon(prefixIcon, size: _iconSize, color: foreground),
                const SizedBox(width: AppSpacing.space1),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: AppTypography.fontSizeBase, // t4
                  fontWeight: AppTypography.fontWeightMedium,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
