import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_motion.dart';
import '../../utils/app_haptics.dart';
import '../common/app_pressable.dart';

/// 앱 공통 단추 — B안(2026-11-12, 시안 .btn).
/// 큰 54·보통 48·작은 40·아주 작은 32, 모서리 14(작은 12·아주 작은 알약), 글자 17·16·15·14 w600.
/// 누르면 0.97로 줄었다 스프링으로 돌아오고 색이 짙어진다(AppPressable). 터치 영역은 늘 48 이상.
enum SeedButtonVariant {
  /// High emphasis — 브랜드 배경 + 흰 텍스트
  brandSolid,

  /// Medium emphasis — 브랜드 weak 배경 + 브랜드 텍스트
  brandWeak,

  /// Medium emphasis — 뉴트럴 weak 배경
  neutralWeak,

  /// Low emphasis — 투명 배경 + 뉴트럴 보더
  neutralOutline,

  /// 위험 액션 — critical solid (확인 창의 마지막 '삭제'처럼 한 번 더 묻는 자리)
  critical,

  /// 목록 줄마다 붙는 위험 액션 — 투명 바탕 + 뉴트럴 보더 + 빨간 글자.
  /// 줄마다 진한 빨강을 깔면 '승인' 같은 주 동작보다 눈에 먼저 띈다.
  criticalOutline,

  /// 글자만 있는 틸 단추 — 바탕 없음, 누르면 옅은 틸.
  brandGhost,
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

  /// 아이콘 대신 넣을 앞 위젯(AppButton 호환). [prefixIcon]보다 우선한다.
  final Widget? leading;

  /// 눌렀을 때 울릴 햅틱. 기본 tap(약함), null이면 울리지 않는다.
  final AppHapticKind? haptic;

  const SeedButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = SeedButtonVariant.brandSolid,
    this.size = SeedButtonSize.medium,
    this.isLoading = false,
    this.isDisabled = false,
    this.prefixIcon,
    this.leading,
    this.haptic = AppHapticKind.tap,
  });

  @override
  State<SeedButton> createState() => _SeedButtonState();
}

class _SeedButtonState extends State<SeedButton> {
  bool _pressed = false;

  bool get _isInteractive =>
      !widget.isDisabled && !widget.isLoading && widget.onPressed != null;

  // B안(2026-11-12, 시안 .btn): 큰 54 / 보통 48 / 작은 40 / 아주 작은 32.
  // 보이는 높이가 48보다 작아도 터치 영역은 48(AppPressable 최소 터치).
  double get _height {
    switch (widget.size) {
      case SeedButtonSize.xsmall:
        return AppSpacing.space8;
      case SeedButtonSize.small:
        return AppSpacing.space10;
      case SeedButtonSize.medium:
        return AppSpacing.buttonHeight;
      case SeedButtonSize.large:
        return AppSpacing.buttonHeightLarge;
    }
  }

  EdgeInsets get _padding {
    switch (widget.size) {
      case SeedButtonSize.xsmall:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space1,
        );
      case SeedButtonSize.small:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3_5,
          vertical: AppSpacing.space1_5,
        );
      case SeedButtonSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space2,
        );
      case SeedButtonSize.large:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.space5,
          vertical: AppSpacing.space2_5,
        );
    }
  }

  double get _radius {
    switch (widget.size) {
      case SeedButtonSize.xsmall:
        return AppBorderRadius.full;
      case SeedButtonSize.small:
        return AppBorderRadius.xl; // 12
      case SeedButtonSize.medium:
      case SeedButtonSize.large:
        return AppBorderRadius.control; // 14
    }
  }

  TextStyle get _textStyle {
    switch (widget.size) {
      case SeedButtonSize.xsmall:
        return AppTypography.buttonSmall; // 14
      case SeedButtonSize.small:
        return AppTypography.titleSmall; // 15
      case SeedButtonSize.medium:
        return AppTypography.buttonMedium; // 16
      case SeedButtonSize.large:
        return AppTypography.buttonLarge; // 17
    }
  }

  double get _iconSize {
    switch (widget.size) {
      case SeedButtonSize.xsmall:
        return 16;
      case SeedButtonSize.small:
        return 18;
      case SeedButtonSize.medium:
        return 20;
      case SeedButtonSize.large:
        return 22;
    }
  }

  double get _iconGap => widget.size == SeedButtonSize.xsmall
      ? AppSpacing.space1
      : AppSpacing.space1_5;

  double get _loadingSize {
    switch (widget.size) {
      case SeedButtonSize.xsmall:
        return 14;
      case SeedButtonSize.small:
        return 16;
      case SeedButtonSize.medium:
        return 18;
      case SeedButtonSize.large:
        return 20;
    }
  }

  _SeedButtonColors get _colors {
    final disabled = widget.isDisabled;
    const disabledFill = _SeedButtonColors(
      background: AppSemanticColors.surfaceDisabled,
      border: null,
      foreground: AppSemanticColors.textDisabled,
    );
    switch (widget.variant) {
      case SeedButtonVariant.brandSolid:
        if (disabled) return disabledFill;
        return _SeedButtonColors(
          background: _pressed
              ? AppSemanticColors.brandPressed
              : AppSemanticColors.brandDefault,
          border: null,
          foreground: AppSemanticColors.textInverse,
        );
      case SeedButtonVariant.brandWeak:
        if (disabled) return disabledFill;
        return _SeedButtonColors(
          background: _pressed
              ? AppSemanticColors.brandWeakPressed
              : AppSemanticColors.brandWeak,
          border: null,
          foreground: AppSemanticColors.brandWeakForeground,
        );
      case SeedButtonVariant.neutralWeak:
        if (disabled) return disabledFill;
        // 시안 .btn.tonal — 회색(#F2F4F6) 바탕, 눌리면 한 단계 짙게
        return _SeedButtonColors(
          background: _pressed
              ? AppSemanticColors.fillStrong
              : AppSemanticColors.fillDefault,
          border: null,
          foreground: AppSemanticColors.textPrimary,
        );
      case SeedButtonVariant.neutralOutline:
        return _SeedButtonColors(
          background: _pressed
              ? AppSemanticColors.surfacePressed
              : AppColors.transparent,
          border: disabled
              ? AppSemanticColors.borderDisabled
              : AppSemanticColors.borderDefault,
          foreground: disabled
              ? AppSemanticColors.textDisabled
              : AppSemanticColors.textPrimary,
        );
      case SeedButtonVariant.criticalOutline:
        return _SeedButtonColors(
          background: _pressed
              ? AppSemanticColors.statusErrorBackground
              : AppColors.transparent,
          border: disabled
              ? AppSemanticColors.borderDisabled
              : AppSemanticColors.borderDefault,
          foreground: disabled
              ? AppSemanticColors.textDisabled
              : AppSemanticColors.statusErrorText,
        );
      case SeedButtonVariant.brandGhost:
        return _SeedButtonColors(
          background: _pressed ? AppSemanticColors.brandWeak : AppColors.transparent,
          border: null,
          foreground: disabled
              ? AppSemanticColors.textDisabled
              : AppSemanticColors.textLink,
        );
      case SeedButtonVariant.critical:
        if (disabled) return disabledFill;
        // 시안 .btn.danger #C8281E(흰 글자 5.6:1) — 예전 #FA342C는 3.6:1이었다
        return _SeedButtonColors(
          background: _pressed
              ? AppSemanticColors.dangerPressed
              : AppSemanticColors.dangerDefault,
          border: null,
          foreground: AppSemanticColors.textInverse,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    final textStyle = _textStyle.copyWith(color: colors.foreground);

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
              if (widget.leading != null) ...[
                IconTheme.merge(
                  data: IconThemeData(size: _iconSize, color: colors.foreground),
                  child: widget.leading!,
                ),
                SizedBox(width: _iconGap),
              ] else if (widget.prefixIcon != null) ...[
                Icon(widget.prefixIcon, size: _iconSize, color: colors.foreground),
                SizedBox(width: _iconGap),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  style: textStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );

    final surface = AnimatedContainer(
      duration: AppMotion.press,
      // 높이는 최소값이다 — 글자를 키워도 '승인'·'거절' 아래가 잘리지 않게(2026-10 제보).
      constraints: BoxConstraints(minHeight: _height),
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
    );

    return Semantics(
      // 불러오는 중에도 무슨 단추인지 읽힌다
      label: widget.isLoading ? widget.label : null,
      child: AppPressable(
        onTap: _isInteractive ? widget.onPressed : null,
        haptic: widget.haptic,
        focusBorderRadius: BorderRadius.circular(_radius),
        onHighlightChanged: (down) {
          if (mounted) setState(() => _pressed = down);
        },
        child: surface,
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
