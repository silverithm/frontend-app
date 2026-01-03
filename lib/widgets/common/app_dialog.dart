import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'app_button.dart';
import 'app_input.dart';

class AppDialog {
  static Future<bool?> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = '확인',
    String cancelText = '취소',
    AppButtonVariant confirmVariant = AppButtonVariant.primary,
    AppButtonVariant cancelVariant = AppButtonVariant.outline,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: AppTypography.heading5.copyWith(
            color: AppSemanticColors.textPrimary,
          ),
        ),
        content: Text(
          message,
          style: AppTypography.bodyMedium.copyWith(
            color: AppSemanticColors.textSecondary,
          ),
        ),
        actions: [
          AppButton(
            text: cancelText,
            variant: cancelVariant,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          const SizedBox(width: AppSpacing.space2),
          AppButton(
            text: confirmText,
            variant: confirmVariant,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
        actionsAlignment: MainAxisAlignment.end,
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.space6,
          0,
          AppSpacing.space6,
          AppSpacing.space6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        ),
        backgroundColor: AppSemanticColors.surfaceDefault,
      ),
    );
  }

  static Future<void> showAlert(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = '확인',
    AppButtonVariant buttonVariant = AppButtonVariant.primary,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: AppTypography.heading5.copyWith(
            color: AppSemanticColors.textPrimary,
          ),
        ),
        content: Text(
          message,
          style: AppTypography.bodyMedium.copyWith(
            color: AppSemanticColors.textSecondary,
          ),
        ),
        actions: [
          AppButton(
            text: buttonText,
            variant: buttonVariant,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        actionsAlignment: MainAxisAlignment.end,
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.space6,
          0,
          AppSpacing.space6,
          AppSpacing.space6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        ),
        backgroundColor: AppSemanticColors.surfaceDefault,
      ),
    );
  }

  static Future<String?> showInput(
    BuildContext context, {
    required String title,
    String? message,
    String? hintText,
    String? initialValue,
    String confirmText = '확인',
    String cancelText = '취소',
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: AppTypography.heading5.copyWith(
            color: AppSemanticColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message != null) ...[
              Text(
                message,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppSemanticColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
            ],
            Form(
              key: formKey,
              child: AppInput(
                controller: controller,
                hintText: hintText,
                keyboardType: keyboardType,
                maxLines: maxLines,
                maxLength: maxLength,
                validator: validator,
                autofocus: true,
              ),
            ),
          ],
        ),
        actions: [
          AppButton(
            text: cancelText,
            variant: AppButtonVariant.outline,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: AppSpacing.space2),
          AppButton(
            text: confirmText,
            variant: AppButtonVariant.primary,
            onPressed: () {
              if (formKey.currentState?.validate() ?? true) {
                Navigator.of(context).pop(controller.text);
              }
            },
          ),
        ],
        actionsAlignment: MainAxisAlignment.end,
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.space6,
          0,
          AppSpacing.space6,
          AppSpacing.space6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        ),
        backgroundColor: AppSemanticColors.surfaceDefault,
      ),
    );
  }

  static Future<T?> showCustom<T>(
    BuildContext context, {
    required Widget child,
    bool barrierDismissible = true,
    Color? barrierColor,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        ),
        backgroundColor: AppSemanticColors.surfaceDefault,
        child: child,
      ),
    );
  }
}

class AppBottomSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    bool isDismissible = true,
    bool enableDrag = true,
    double? height,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: height != null,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: AppColors.transparent,
      builder: (context) => Container(
        height: height,
        decoration: const BoxDecoration(
          color: AppSemanticColors.surfaceDefault,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppBorderRadius.xl),
            topRight: Radius.circular(AppBorderRadius.xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
              decoration: BoxDecoration(
                color: AppSemanticColors.borderDefault,
                borderRadius: BorderRadius.circular(AppBorderRadius.full),
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
