import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 당근 Seed 디자인 시스템 — Action Button.
/// 스펙 참조: docs/seed-component-specs.md §1 Action Button
/// (사이즈별 height/padding/radius/font, variant별 상태 색, pressed scale)
enum SeedButtonVariant {
  /// High emphasis — 브랜드 배경 + 흰 텍스트
  brandSolid,

  /// Medium emphasis — 브랜드 weak 배경 + 브랜드 텍스트
  brandWeak,

  /// Medium emphasis — 뉴트럴 weak 배경
  neutralWeak,

  /// Low emphasis — 투명 배경 + 뉴트럴 보더
  neutralOutline,

  /// 위험 액션 — critical solid
  critical,
}

enum SeedButtonSize { xsmall, small, medium, large }

class SeedButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final SeedButtonVariant variant;
  final SeedButtonSize size;
  final bool isLoading;
  final bool isDisabled;
  final IconData? prefixIcon;

  const SeedButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = SeedButtonVariant.brandSolid,
    this.size = SeedButtonSize.medium,
    this.isLoading = false,
    this.isDisabled = false,
    this.prefixIcon,
  });

  @override
  State<SeedButton> createState() => _SeedButtonState();
}

class _SeedButtonState extends State<SeedButton> {
  bool _pressed = false;

  bool get _isInteractive =>
      !widget.isDisabled && !widget.isLoading && widget.onPressed != null;

  // 사이즈별 height — spec §1 표 (dimension.x8/x9/x10/x13 실측값)
  double get _height {
    switch (widget.size) {
      case SeedButtonSize.xsmall:
        return 32;
      case SeedButtonSize.small:
        return 36;
      case SeedButtonSize.medium:
        return 40;
      case SeedButtonSize.large:
        return 48;
    }
  }

  // Padding X/Y — spec §1 표 (dimension.xN ≈ AppSpacing 동일 스텝)
  EdgeInsets get _padding {
    switch (widget.size) {
      case SeedButtonSize.xsmall:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3_5,
          vertical: AppSpacing.space1_5,
        );
      case SeedButtonSize.small:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3_5,
          vertical: AppSpacing.space2,
        );
      case SeedButtonSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space2_5,
        );
      case SeedButtonSize.large:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.space5,
          vertical: AppSpacing.space3_5,
        );
    }
  }

  // Radius — spec §1: XSmall full / Small·Medium r2 / Large r3
  double get _radius {
    switch (widget.size) {
      case SeedButtonSize.xsmall:
        return AppBorderRadius.full;
      case SeedButtonSize.small:
      case SeedButtonSize.medium:
        return AppBorderRadius.lg; // r2
      case SeedButtonSize.large:
        return AppBorderRadius.xl; // r3
    }
  }

  // Font-size — spec §1: XSmall t3 / Small·Medium t4 / Large t6
  double get _fontSize {
    switch (widget.size) {
      case SeedButtonSize.xsmall:
        return 13; // t3
      case SeedButtonSize.small:
      case SeedButtonSize.medium:
        return AppTypography.fontSizeBase; // t4 (14)
      case SeedButtonSize.large:
        return AppTypography.fontSizeLg; // t6 (16)
    }
  }

  double get _iconSize {
    switch (widget.size) {
      case SeedButtonSize.xsmall:
      case SeedButtonSize.small:
        return 14;
      case SeedButtonSize.medium:
        return 18;
      case SeedButtonSize.large:
        return 22;
    }
  }

  double get _iconGap {
    switch (widget.size) {
      case SeedButtonSize.xsmall:
      case SeedButtonSize.small:
        return AppSpacing.space1;
      case SeedButtonSize.medium:
        return AppSpacing.space1_5;
      case SeedButtonSize.large:
        return AppSpacing.space2;
    }
  }

  // Pressed 시 scale — spec §1: XSmall 0.95 / Small·Medium 0.97 / Large 0.98
  double get _pressedScale {
    switch (widget.size) {
      case SeedButtonSize.xsmall:
        return 0.95;
      case SeedButtonSize.small:
      case SeedButtonSize.medium:
        return 0.97;
      case SeedButtonSize.large:
        return 0.98;
    }
  }

  double get _loadingSize {
    switch (widget.size) {
      case SeedButtonSize.xsmall:
        return 14;
      case SeedButtonSize.small:
      case SeedButtonSize.medium:
        return 16;
      case SeedButtonSize.large:
        return 18;
    }
  }

  _SeedButtonColors get _colors {
    final disabled = widget.isDisabled;
    switch (widget.variant) {
      case SeedButtonVariant.brandSolid:
        if (disabled) {
          return const _SeedButtonColors(
            background: AppSemanticColors.surfaceDisabled,
            border: null,
            foreground: AppSemanticColors.textDisabled,
          );
        }
        return _SeedButtonColors(
          background: _pressed
              ? AppSemanticColors.brandPressed
              : AppSemanticColors.brandDefault,
          border: null,
          foreground: AppSemanticColors.textInverse,
        );
      case SeedButtonVariant.brandWeak:
        if (disabled) {
          return const _SeedButtonColors(
            background: AppSemanticColors.surfaceDisabled,
            border: null,
            foreground: AppSemanticColors.textDisabled,
          );
        }
        return _SeedButtonColors(
          background: _pressed
              ? AppSemanticColors.brandWeakPressed
              : AppSemanticColors.brandWeak,
          border: null,
          foreground: AppSemanticColors.brandPressed,
        );
      case SeedButtonVariant.neutralWeak:
        if (disabled) {
          return const _SeedButtonColors(
            background: AppSemanticColors.surfaceDisabled,
            border: null,
            foreground: AppSemanticColors.textDisabled,
          );
        }
        return _SeedButtonColors(
          background: _pressed
              ? AppSemanticColors.interactiveSecondaryActive
              : AppSemanticColors.interactiveSecondaryDefault,
          border: null,
          foreground: AppSemanticColors.textPrimary,
        );
      case SeedButtonVariant.neutralOutline:
        return _SeedButtonColors(
          background: _pressed
              ? AppSemanticColors.surfaceActive
              : AppColors.transparent,
          border: disabled
              ? AppSemanticColors.borderDisabled
              : AppSemanticColors.borderDefault,
          foreground: disabled
              ? AppSemanticColors.textDisabled
              : AppSemanticColors.textPrimary,
        );
      case SeedButtonVariant.critical:
        if (disabled) {
          return const _SeedButtonColors(
            background: AppSemanticColors.surfaceDisabled,
            border: null,
            foreground: AppSemanticColors.textDisabled,
          );
        }
        return _SeedButtonColors(
          background: _pressed
              ? AppSemanticColors.statusErrorText
              : AppSemanticColors.statusErrorIcon,
          border: null,
          foreground: AppColors.white,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    final textStyle = TextStyle(
      fontSize: _fontSize,
      fontWeight: AppTypography.fontWeightBold,
      color: colors.foreground,
    );

    final Widget content = widget.isLoading
        ? SizedBox(
            width: _loadingSize,
            height: _loadingSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colors.foreground),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.prefixIcon != null) ...[
                Icon(widget.prefixIcon, size: _iconSize, color: colors.foreground),
                SizedBox(width: _iconGap),
              ],
              Text(widget.label, style: textStyle),
            ],
          );

    return GestureDetector(
      onTapDown: _isInteractive ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: _isInteractive ? () => setState(() => _pressed = false) : null,
      onTapUp: _isInteractive ? (_) => setState(() => _pressed = false) : null,
      onTap: _isInteractive ? widget.onPressed : null,
      child: AnimatedScale(
        scale: (_pressed && _isInteractive) ? _pressedScale : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: _height,
          padding: _padding,
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(_radius),
            border: colors.border != null
                ? Border.all(color: colors.border!, width: 1)
                : null,
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }
}

class _SeedButtonColors {
  final Color background;
  final Color? border;
  final Color foreground;

  const _SeedButtonColors({
    required this.background,
    required this.border,
    required this.foreground,
  });
}
