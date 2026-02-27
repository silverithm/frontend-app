import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../../theme/app_colors.dart';
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

  shadcn.ButtonSize _getShadcnSize() {
    switch (size) {
      case AppButtonSize.small:
        return shadcn.ButtonSize.small;
      case AppButtonSize.medium:
        return shadcn.ButtonSize.normal;
      case AppButtonSize.large:
        return shadcn.ButtonSize.large;
    }
  }

  Widget _buildLoadingIndicator() {
    final loadingSize = _getLoadingSize();
    return SizedBox(
      width: loadingSize,
      height: loadingSize,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(_getLoadingColor()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shadcnSize = _getShadcnSize();
    final effectiveOnPressed = isLoading ? null : onPressed;
    final labelChild = isLoading
        ? _buildLoadingIndicator()
        : Text(text, style: _getTextStyle());

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
        button = shadcn.PrimaryButton(
          onPressed: effectiveOnPressed,
          size: shadcnSize,
          leading: !isLoading ? icon : null,
          child: labelChild,
        );
        break;
      case AppButtonVariant.secondary:
        button = shadcn.SecondaryButton(
          onPressed: effectiveOnPressed,
          size: shadcnSize,
          leading: !isLoading ? icon : null,
          child: labelChild,
        );
        break;
      case AppButtonVariant.outline:
        button = shadcn.OutlineButton(
          onPressed: effectiveOnPressed,
          size: shadcnSize,
          leading: !isLoading ? icon : null,
          child: labelChild,
        );
        break;
      case AppButtonVariant.text:
        button = shadcn.GhostButton(
          onPressed: effectiveOnPressed,
          size: shadcnSize,
          leading: !isLoading ? icon : null,
          child: labelChild,
        );
        break;
    }

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
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
        return AppSemanticColors.textInverse;
      case AppButtonVariant.secondary:
        return AppSemanticColors.textPrimary;
      case AppButtonVariant.outline:
      case AppButtonVariant.text:
        return AppSemanticColors.interactivePrimaryDefault;
    }
  }
}