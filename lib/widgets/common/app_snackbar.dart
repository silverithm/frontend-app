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

    // B안(2026-11-12, 시안 .toast): 짙은 반투명 띠 + 흰 글자 15, 모서리 14, 테두리 없음.
    // 뜻(성공·실패·주의·안내)은 앞 아이콘 색으로 — 짙은 바탕 위에서 보이는 밝은 점 색.
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getStatusIcon(type),
              color: colors.icon,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.space2_5),
            Expanded(
              child: Text(
                message,
                style: AppTypography.labelLarge.copyWith(
                  color: AppSemanticColors.textInverse,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppSemanticColors.toastBackground,
        duration: duration ?? const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.control),
        ),
        action: action,
        margin: const EdgeInsets.all(AppSpacing.space4),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space3,
        ),
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

  // 짙은 알림 띠 위 아이콘 색(3:1 이상) — 바탕·글자는 띠가 정한다
  static _StatusColors _getStatusColors(AppStatusType type) {
    switch (type) {
      case AppStatusType.success:
        return _StatusColors(icon: AppColors.okDot);
      case AppStatusType.warning:
        return _StatusColors(icon: AppColors.waitDot);
      case AppStatusType.error:
        return _StatusColors(icon: AppColors.rejDot);
      case AppStatusType.info:
        return _StatusColors(icon: AppColors.teal300);
    }
  }

  static IconData _getStatusIcon(AppStatusType type) {
    switch (type) {
      case AppStatusType.success:
        return Icons.check_circle_rounded;
      case AppStatusType.warning:
        return Icons.warning_rounded;
      case AppStatusType.error:
        return Icons.error_rounded;
      case AppStatusType.info:
        return Icons.info_rounded;
    }
  }
}

class _StatusColors {
  final Color icon;

  _StatusColors({required this.icon});
}
