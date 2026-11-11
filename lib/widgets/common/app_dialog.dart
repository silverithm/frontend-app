import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../seed/seed_button.dart';
import 'app_input.dart';

class AppDialog {
  /// 확인 다이얼로그. 되돌릴 수 없는 행위(삭제·탈퇴)만 [confirmVariant]에
  /// [SeedButtonVariant.critical]을 넘긴다 — 반려·거절·로그아웃은 파괴적 행위가 아니다.
  ///
  /// 창이 뜰 때 [haptic]을 울린다. 안 넘기면 critical(삭제)은 warning, 나머지는 울리지 않는다.
  /// 반려·거절 확인처럼 빨간 단추는 아니지만 경고가 필요한 자리는 warning을 넘긴다.
  static Future<bool?> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = '확인',
    String cancelText = '취소',
    SeedButtonVariant confirmVariant = SeedButtonVariant.brandSolid,
    SeedButtonVariant cancelVariant = SeedButtonVariant.neutralOutline,
    AppHapticKind? haptic,
  }) {
    final openHaptic = haptic ??
        (confirmVariant == SeedButtonVariant.critical
            ? AppHapticKind.warning
            : null);
    if (openHaptic != null) AppHaptics.play(openHaptic);
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
                    child: SeedButton(
                      label: cancelText,
                      variant: cancelVariant,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: SeedButton(
                      label: confirmText,
                      variant: confirmVariant,
                      onPressed: () => Navigator.of(context).pop(true),
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

  /// 알림 창. 실패를 알리는 창이면 [haptic]에 error를 넘긴다(기본은 울리지 않음).
  static Future<void> showAlert(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = '확인',
    SeedButtonVariant buttonVariant = SeedButtonVariant.brandSolid,
    AppHapticKind? haptic,
  }) {
    if (haptic != null) AppHaptics.play(haptic);
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
                child: SeedButton(
                  label: buttonText,
                  variant: buttonVariant,
                  onPressed: () => Navigator.of(context).pop(),
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
    // 창이 뜰 때 울릴 햅틱(반려 사유 입력처럼 경고가 필요한 자리는 warning). 기본은 울리지 않음.
    AppHapticKind? haptic,
  }) {
    if (haptic != null) AppHaptics.play(haptic);
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
                    child: SeedButton(
                      label: cancelText,
                      variant: SeedButtonVariant.neutralOutline,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: SeedButton(
                      label: confirmText,
                      onPressed: () {
                        if (formKey.currentState?.validate() ?? true) {
                          Navigator.of(context).pop(controller.text);
                        }
                      },
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
  /// [title]을 주면 showAppActionSheet와 같은 연한 틸 제목 띠(손잡이가 띠 맨 위)를 그린다.
  /// 안 주면 손잡이만 있는 시트. 모서리는 둘 다 16(xl2).
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    bool isDismissible = true,
    bool enableDrag = true,
    double? height,
    // 폼(텍스트 입력) 시트는 키보드가 올라올 때 시트가 함께 커져야 해서
    // 명시적으로 true를 넘긴다. 안 넘기면 기존과 동일하게 height 유무로 정한다.
    bool? isScrollControlled,
  }) {
    final hasTitle = title != null && title.isNotEmpty;
    final handle = Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: hasTitle
            ? AppSemanticColors.subheaderBorder
            : AppSemanticColors.borderDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
      ),
    );
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled ?? (height != null),
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: AppColors.transparent,
      builder: (context) => Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: AppSemanticColors.surfaceDefault,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppBorderRadius.xl2),
            topRight: Radius.circular(AppBorderRadius.xl2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasTitle)
              Container(
                decoration: const BoxDecoration(
                  color: AppSemanticColors.subheaderBackground,
                  border: Border(
                    bottom: BorderSide(color: AppSemanticColors.subheaderBorder),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space5,
                  AppSpacing.space2,
                  AppSpacing.space5,
                  AppSpacing.space3,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: handle),
                    const SizedBox(height: AppSpacing.space3),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.heading6.copyWith(
                        color: AppSemanticColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
                child: Center(child: handle),
              ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
