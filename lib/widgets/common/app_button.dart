import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

enum AppButtonSize { small, medium, large }
enum AppButtonVariant { primary, secondary, outline, text }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonSize size;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;
  final Widget? icon;
  final EdgeInsets? padding;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = false,
    this.icon,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = _getButtonStyle();
    final textStyle = _getTextStyle();
    final minSize = _getMinSize();
    final buttonPadding = padding ?? _getPadding();

    Widget child = isLoading
        ? SizedBox(
            width: _getLoadingSize(),
            height: _getLoadingSize(),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getLoadingColor(),
              ),
            ),
          )
        : Row(
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                icon!,
                const SizedBox(width: AppSpacing.space2),
              ],
              Text(text, style: textStyle),
            ],
          );

    if (isFullWidth) {
      child = SizedBox(width: double.infinity, child: child);
    }

    switch (variant) {
      case AppButtonVariant.primary:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle.copyWith(
            minimumSize: WidgetStateProperty.all(minSize),
            padding: WidgetStateProperty.all(buttonPadding),
          ),
          child: child,
        );
      case AppButtonVariant.secondary:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle.copyWith(
            minimumSize: WidgetStateProperty.all(minSize),
            padding: WidgetStateProperty.all(buttonPadding),
          ),
          child: child,
        );
      case AppButtonVariant.outline:
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle.copyWith(
            minimumSize: WidgetStateProperty.all(minSize),
            padding: WidgetStateProperty.all(buttonPadding),
          ),
          child: child,
        );
      case AppButtonVariant.text:
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle.copyWith(
            minimumSize: WidgetStateProperty.all(minSize),
            padding: WidgetStateProperty.all(buttonPadding),
          ),
          child: child,
        );
    }
  }

  ButtonStyle _getButtonStyle() {
    switch (variant) {
      case AppButtonVariant.primary:
        return ElevatedButton.styleFrom(
          backgroundColor: AppSemanticColors.interactivePrimaryDefault,
          foregroundColor: AppSemanticColors.textInverse,
          disabledBackgroundColor: AppSemanticColors.interactivePrimaryDisabled,
          disabledForegroundColor: AppSemanticColors.textDisabled,
          elevation: 0,
          shadowColor: Colors.transparent,
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppSemanticColors.interactivePrimaryDisabled;
            }
            if (states.contains(WidgetState.pressed)) {
              return AppSemanticColors.interactivePrimaryActive;
            }
            if (states.contains(WidgetState.hovered)) {
              return AppSemanticColors.interactivePrimaryHover;
            }
            return AppSemanticColors.interactivePrimaryDefault;
          }),
        );
      case AppButtonVariant.secondary:
        return ElevatedButton.styleFrom(
          backgroundColor: AppSemanticColors.interactiveSecondaryDefault,
          foregroundColor: AppSemanticColors.textInverse,
          disabledBackgroundColor: AppSemanticColors.interactiveSecondaryDisabled,
          disabledForegroundColor: AppSemanticColors.textDisabled,
          elevation: 0,
          shadowColor: Colors.transparent,
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppSemanticColors.interactiveSecondaryDisabled;
            }
            if (states.contains(WidgetState.pressed)) {
              return AppSemanticColors.interactiveSecondaryActive;
            }
            if (states.contains(WidgetState.hovered)) {
              return AppSemanticColors.interactiveSecondaryHover;
            }
            return AppSemanticColors.interactiveSecondaryDefault;
          }),
        );
      case AppButtonVariant.outline:
        return OutlinedButton.styleFrom(
          foregroundColor: AppSemanticColors.interactivePrimaryDefault,
          disabledForegroundColor: AppSemanticColors.textDisabled,
          side: const BorderSide(
            color: AppSemanticColors.borderDefault,
            width: 1,
          ),
        ).copyWith(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppSemanticColors.textDisabled;
            }
            return AppSemanticColors.interactivePrimaryDefault;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const BorderSide(
                color: AppSemanticColors.borderDisabled,
                width: 1,
              );
            }
            if (states.contains(WidgetState.hovered)) {
              return const BorderSide(
                color: AppSemanticColors.borderHover,
                width: 1,
              );
            }
            return const BorderSide(
              color: AppSemanticColors.borderDefault,
              width: 1,
            );
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return AppSemanticColors.surfaceHover;
            }
            if (states.contains(WidgetState.pressed)) {
              return AppSemanticColors.surfaceActive;
            }
            return Colors.transparent;
          }),
        );
      case AppButtonVariant.text:
        return TextButton.styleFrom(
          foregroundColor: AppSemanticColors.interactivePrimaryDefault,
          disabledForegroundColor: AppSemanticColors.textDisabled,
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return AppSemanticColors.surfaceHover;
            }
            if (states.contains(WidgetState.pressed)) {
              return AppSemanticColors.surfaceActive;
            }
            return Colors.transparent;
          }),
        );
    }
  }

  TextStyle _getTextStyle() {
    switch (size) {
      case AppButtonSize.small:
        return AppTypography.buttonSmall;
      case AppButtonSize.medium:
        return AppTypography.buttonMedium;
      case AppButtonSize.large:
        return AppTypography.buttonLarge;
    }
  }

  Size _getMinSize() {
    switch (size) {
      case AppButtonSize.small:
        return const Size(0, 36);
      case AppButtonSize.medium:
        return const Size(0, 44);
      case AppButtonSize.large:
        return const Size(0, 52);
    }
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space2,
        );
      case AppButtonSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.space6,
          vertical: AppSpacing.space3,
        );
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.space8,
          vertical: AppSpacing.space4,
        );
    }
  }

  double _getLoadingSize() {
    switch (size) {
      case AppButtonSize.small:
        return 16;
      case AppButtonSize.medium:
        return 20;
      case AppButtonSize.large:
        return 24;
    }
  }

  Color _getLoadingColor() {
    switch (variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.secondary:
        return AppSemanticColors.textInverse;
      case AppButtonVariant.outline:
      case AppButtonVariant.text:
        return AppSemanticColors.interactivePrimaryDefault;
    }
  }
}