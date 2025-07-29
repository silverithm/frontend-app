import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'app_card.dart';

class AppSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    AppStatusType type = AppStatusType.info,
    Duration? duration,
    SnackBarAction? action,
  }) {
    final colors = _getStatusColors(type);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getStatusIcon(type),
              color: colors.icon,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.space3),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.text,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: colors.background,
        duration: duration ?? const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          side: BorderSide(
            color: colors.border,
            width: 1,
          ),
        ),
        action: action,
        margin: const EdgeInsets.all(AppSpacing.space4),
      ),
    );
  }

  static void showSuccess(
    BuildContext context, {
    required String message,
    Duration? duration,
    SnackBarAction? action,
  }) {
    show(
      context,
      message: message,
      type: AppStatusType.success,
      duration: duration,
      action: action,
    );
  }

  static void showError(
    BuildContext context, {
    required String message,
    Duration? duration,
    SnackBarAction? action,
  }) {
    show(
      context,
      message: message,
      type: AppStatusType.error,
      duration: duration,
      action: action,
    );
  }

  static void showWarning(
    BuildContext context, {
    required String message,
    Duration? duration,
    SnackBarAction? action,
  }) {
    show(
      context,
      message: message,
      type: AppStatusType.warning,
      duration: duration,
      action: action,
    );
  }

  static void showInfo(
    BuildContext context, {
    required String message,
    Duration? duration,
    SnackBarAction? action,
  }) {
    show(
      context,
      message: message,
      type: AppStatusType.info,
      duration: duration,
      action: action,
    );
  }

  static _StatusColors _getStatusColors(AppStatusType type) {
    switch (type) {
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

  static IconData _getStatusIcon(AppStatusType type) {
    switch (type) {
      case AppStatusType.success:
        return Icons.check_circle_outline;
      case AppStatusType.warning:
        return Icons.warning_amber_outlined;
      case AppStatusType.error:
        return Icons.error_outline;
      case AppStatusType.info:
        return Icons.info_outline;
    }
  }
}

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