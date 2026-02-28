import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
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
      barrierColor: AppColors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        ),
        backgroundColor: AppSemanticColors.surfaceDefault,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTypography.heading5.copyWith(
                  color: AppSemanticColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.space3),
              Text(
                message,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppSemanticColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.space6),
              Row(
                children: [
                  Expanded(
                    child: shadcn.OutlineButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(cancelText),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: shadcn.PrimaryButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(confirmText),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
      barrierColor: AppColors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        ),
        backgroundColor: AppSemanticColors.surfaceDefault,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTypography.heading5.copyWith(
                  color: AppSemanticColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.space3),
              Text(
                message,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppSemanticColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.space6),
              SizedBox(
                width: double.infinity,
                child: shadcn.PrimaryButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(buttonText),
                ),
              ),
            ],
          ),
        ),
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
      barrierColor: AppColors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        ),
        backgroundColor: AppSemanticColors.surfaceDefault,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  title,
                  style: AppTypography.heading5.copyWith(
                    color: AppSemanticColors.textPrimary,
                  ),
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.space3),
                Center(
                  child: Text(
                    message,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.space4),
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
              const SizedBox(height: AppSpacing.space6),
              Row(
                children: [
                  Expanded(
                    child: shadcn.OutlineButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(cancelText),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: shadcn.PrimaryButton(
                      onPressed: () {
                        if (formKey.currentState?.validate() ?? true) {
                          Navigator.of(context).pop(controller.text);
                        }
                      },
                      child: Text(confirmText),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
