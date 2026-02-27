import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
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
    final effectivePadding =
        padding ?? const EdgeInsets.all(AppSpacing.space4);
    final effectiveRadius = borderRadius ?? AppBorderRadius.xl;

    Widget card = shadcn.Card(
      padding: effectivePadding,
      filled: backgroundColor != null,
      fillColor: backgroundColor,
      borderRadius: BorderRadius.circular(effectiveRadius),
      borderColor: hasBorder
          ? (borderColor ?? AppSemanticColors.borderDefault)
          : Colors.transparent,
      borderWidth: hasBorder ? 1 : 0,
      boxShadow: elevation != null && elevation! > 0
          ? [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.1),
                blurRadius: elevation!,
                offset: Offset(0, elevation! / 2),
              ),
            ]
          : null,
      child: child,
    );

    // Apply margin via Container wrapper
    if (margin != null || onTap == null) {
      card = Container(
        margin: margin ?? const EdgeInsets.all(AppSpacing.space4),
        child: card,
      );
    }

    if (onTap != null) {
      return Container(
        margin: margin ?? const EdgeInsets.all(AppSpacing.space4),
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(effectiveRadius),
            child: shadcn.Card(
              padding: effectivePadding,
              filled: backgroundColor != null,
              fillColor: backgroundColor,
              borderRadius: BorderRadius.circular(effectiveRadius),
              borderColor: hasBorder
                  ? (borderColor ?? AppSemanticColors.borderDefault)
                  : Colors.transparent,
              borderWidth: hasBorder ? 1 : 0,
              boxShadow: elevation != null && elevation! > 0
                  ? [
                      BoxShadow(
                        color: AppColors.black.withValues(alpha: 0.1),
                        blurRadius: elevation!,
                        offset: Offset(0, elevation! / 2),
                      ),
                    ]
                  : null,
              child: child,
            ),
          ),
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