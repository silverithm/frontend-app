import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../common/app_pressable.dart';

/// 거르기 칩 — B안(2026-11-12, 시안 .chip).
/// 테두리 없는 알약, 높이 44(작은 36)·좌우 16, 글자 15/w600. 고르면 틸 바탕 + 흰 글자.
/// 고르기 전 바탕은 흰 카드 안이면 회색(기본), 회색 화면 바탕 위면 흰색([onCanvas]).
/// 누르면 selection 햅틱, 터치는 48 이상. 고른 것·안 고른 것 굵기가 같아 폭이 흔들리지 않는다.
enum SeedChipSize { small, medium }

class SeedChip extends StatefulWidget {
  final String label;
  final bool selected;
  final bool isDisabled;
  final SeedChipSize size;
  final VoidCallback? onTap;
  final IconData? prefixIcon;

  /// 회색 화면 바탕 위에 바로 놓인 칩이면 true(고르기 전 바탕이 흰색).
  final bool onCanvas;

  const SeedChip({
    super.key,
    required this.label,
    this.selected = false,
    this.isDisabled = false,
    this.size = SeedChipSize.medium,
    this.onTap,
    this.prefixIcon,
    this.onCanvas = false,
  });

  @override
  State<SeedChip> createState() => _SeedChipState();
}

class _SeedChipState extends State<SeedChip> {
  bool _pressed = false;

  double get _height => widget.size == SeedChipSize.small ? 36 : 44;

  double get _paddingX => widget.size == SeedChipSize.small
      ? AppSpacing.space3
      : AppSpacing.space4;

  double get _iconSize => widget.size == SeedChipSize.small ? 16 : 18;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final Color background;
    if (widget.isDisabled) {
      background = AppSemanticColors.surfaceDisabled;
    } else if (selected) {
      background = _pressed
          ? AppSemanticColors.brandPressed
          : AppSemanticColors.brandDefault;
    } else if (_pressed) {
      background = widget.onCanvas
          ? AppSemanticColors.surfacePressed
          : AppSemanticColors.fillStrong;
    } else {
      background = widget.onCanvas
          ? AppSemanticColors.surfaceCard
          : AppSemanticColors.fillDefault;
    }
    final foreground = widget.isDisabled
        ? AppSemanticColors.textDisabled
        : selected
            ? AppSemanticColors.textInverse
            : AppSemanticColors.textSecondary;

    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      constraints: BoxConstraints(minHeight: _height),
      padding: EdgeInsets.symmetric(horizontal: _paddingX),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.prefixIcon != null) ...[
            Icon(widget.prefixIcon, size: _iconSize, color: foreground),
            const SizedBox(width: AppSpacing.space1),
          ],
          Text(
            widget.label,
            maxLines: 1,
            style: AppTypography.titleSmall.copyWith(color: foreground),
          ),
        ],
      ),
    );

    return Semantics(
      selected: selected,
      child: AppPressable(
        onTap: widget.isDisabled ? null : widget.onTap,
        haptic: AppHapticKind.selection,
        focusBorderRadius: BorderRadius.circular(AppBorderRadius.full),
        onHighlightChanged: (down) {
          if (mounted) setState(() => _pressed = down);
        },
        child: chip,
      ),
    );
  }
}
