import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import 'app_card.dart';

class AppSnackBar {
  /// [haptic]이 true면 뜻에 맞게 울린다 — 성공은 success, 실패는 error.
  /// 안내(info)·주의(warning)는 울리지 않는다: 주의 알림은 "입력해주세요" 같은 안내나
  /// 반려·거절을 마친 결과라, 경고 진동은 그 앞의 확인 창에서 이미 울렸다.
  static void show(
    BuildContext context, {
    required String message,
    AppStatusType type = AppStatusType.info,
    Duration? duration,
    SnackBarAction? action,
    bool haptic = true,
  }) {
    final colors = _getStatusColors(type);
    final messenger = ScaffoldMessenger.of(context);
    // 알림을 띄울 수 있을 때만 울린다(위에서 of가 실패하면 여기까지 오지 않는다).
    final hapticKind = haptic ? hapticFor(type) : null;
    if (hapticKind != null) AppHaptics.play(hapticKind);

    messenger.showSnackBar(
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

  /// 알림 종류 → 햅틱. 울리지 않는 종류는 null.
  static AppHapticKind? hapticFor(AppStatusType type) {
    switch (type) {
      case AppStatusType.success:
        return AppHapticKind.success;
      case AppStatusType.error:
        return AppHapticKind.error;
      case AppStatusType.warning:
      case AppStatusType.info:
        return null;
    }
  }

  static void showSuccess(
    BuildContext context, {
    required String message,
    Duration? duration,
    SnackBarAction? action,
    bool haptic = true,
  }) {
    show(
      context,
      message: message,
      type: AppStatusType.success,
      duration: duration,
      action: action,
      haptic: haptic,
    );
  }

  static void showError(
    BuildContext context, {
    required String message,
    Duration? duration,
    SnackBarAction? action,
    bool haptic = true,
  }) {
    show(
      context,
      message: message,
      type: AppStatusType.error,
      duration: duration,
      action: action,
      haptic: haptic,
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