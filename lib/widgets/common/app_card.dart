import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderRadius;
  final double? elevation;
  final bool hasBorder;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.elevation,
    this.hasBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin ?? const EdgeInsets.all(AppSpacing.space4),
      padding: padding ?? const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(borderRadius ?? AppBorderRadius.xl),
        border: hasBorder
            ? Border.all(
                color: borderColor ?? AppSemanticColors.borderDefault,
                width: 1,
              )
            : null,
        boxShadow: elevation != null && elevation! > 0
            ? [
                BoxShadow(
                  color: AppColors.black.withValues(alpha:0.1),
                  blurRadius: elevation!,
                  offset: Offset(0, elevation! / 2),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius ?? AppBorderRadius.xl),
          child: card,
        ),
      );
    }

    return card;
  }
}

class AppStatusCard extends StatelessWidget {
  final Widget child;
  final AppStatusType status;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;

  const AppStatusCard({
    super.key,
    required this.child,
    required this.status,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getStatusColors();

    return AppCard(
      backgroundColor: colors.background,
      borderColor: colors.border,
      padding: padding,
      margin: margin,
      onTap: onTap,
      child: child,
    );
  }

  _StatusColors _getStatusColors() {
    switch (status) {
      case AppStatusType.success:
        return _StatusColors(
          background: AppSemanticColors.statusSuccessBackground,
          border: AppSemanticColors.statusSuccessBorder,
          text: AppSemanticColors.statusSuccessText,
          icon: AppSemanticColors.statusSuccessIcon,
        );
      case AppStatusType.warning:
        return _StatusColors(
          background: AppSemanticColors.statusWarningBackground,
          border: AppSemanticColors.statusWarningBorder,
          text: AppSemanticColors.statusWarningText,
          icon: AppSemanticColors.statusWarningIcon,
        );
      case AppStatusType.error:
        return _StatusColors(
          background: AppSemanticColors.statusErrorBackground,
          border: AppSemanticColors.statusErrorBorder,
          text: AppSemanticColors.statusErrorText,
          icon: AppSemanticColors.statusErrorIcon,
        );
      case AppStatusType.info:
        return _StatusColors(
          background: AppSemanticColors.statusInfoBackground,
          border: AppSemanticColors.statusInfoBorder,
          text: AppSemanticColors.statusInfoText,
          icon: AppSemanticColors.statusInfoIcon,
        );
    }
  }
}

enum AppStatusType { success, warning, error, info }

class _StatusColors {
  final Color background;
  final Color border;
  final Color text;
  final Color icon;

  _StatusColors({
    required this.background,
    required this.border,
    required this.text,
    required this.icon,
  });
}