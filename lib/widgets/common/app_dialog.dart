import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../seed/seed_button.dart';
import 'app_input.dart';
import 'app_sheet_frame.dart';

/// 확인·알림·입력 창 — B안(2026-11-12): 가운데 대화상자 대신 아래에서 올라오는 시트(엄지 닿는 곳)
/// + 큰 단추(52). 돌려주는 값은 예전과 같다 — 확인 true, 취소 false, 바깥을 눌러 닫으면 null.
class AppDialog {
  /// 확인 창. 되돌릴 수 없는 행위(삭제·탈퇴)만 [confirmVariant]에
  /// [SeedButtonVariant.critical]을 넘긴다 — 반려·거절·로그아웃은 파괴적 행위가 아니다.
  ///
  /// 창이 뜰 때 [haptic]을 울린다. 안 넘기면 critical(삭제)은 warning, 나머지는 울리지 않는다.
  /// 반려·거절 확인처럼 빨간 단추는 아니지만 경고가 필요한 자리는 warning을 넘긴다.
  /// warning이 울리는 창은 제목 위에 경고 아이콘이 붙는다.
  static Future<bool?> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = '확인',
    String cancelText = '취소',
    SeedButtonVariant confirmVariant = SeedButtonVariant.brandSolid,
    SeedButtonVariant cancelVariant = SeedButtonVariant.neutralWeak,
    AppHapticKind? haptic,
  }) {
    final openHaptic = haptic ??
        (confirmVariant == SeedButtonVariant.critical
            ? AppHapticKind.warning
            : null);
    if (openHaptic != null) AppHaptics.play(openHaptic);
    return showAppSheet<bool>(
      context,
      builder: (sheetContext) => AppSheetFrame(
        title: title,
        message: message,
        warning: openHaptic == AppHapticKind.warning,
        actions: AppSheetActions(
          cancel: SeedButton(
            label: cancelText,
            size: SeedButtonSize.large,
            variant: cancelVariant,
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
          confirm: SeedButton(
            label: confirmText,
            size: SeedButtonSize.large,
            variant: confirmVariant,
            onPressed: () => Navigator.of(sheetContext).pop(true),
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
    return showAppSheet<void>(
      context,
      builder: (sheetContext) => AppSheetFrame(
        title: title,
        message: message,
        actions: SizedBox(
          width: double.infinity,
          child: SeedButton(
            label: buttonText,
            size: SeedButtonSize.large,
            variant: buttonVariant,
            onPressed: () => Navigator.of(sheetContext).pop(),
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

    return showAppSheet<String>(
      context,
      builder: (sheetContext) => AppSheetFrame(
        title: title,
        message: message,
        warning: haptic == AppHapticKind.warning,
        actions: AppSheetActions(
          cancel: SeedButton(
            label: cancelText,
            size: SeedButtonSize.large,
            variant: SeedButtonVariant.neutralWeak,
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
          confirm: SeedButton(
            label: confirmText,
            size: SeedButtonSize.large,
            onPressed: () {
              if (formKey.currentState?.validate() ?? true) {
                Navigator.of(sheetContext).pop(controller.text);
              }
            },
          ),
        ),
        children: [
          const SizedBox(height: AppSpacing.space5),
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
      // 맞춤 창은 내용이 제각각이라 가운데 창으로 둔다(모서리 24, 뒤 어둠은 테마).
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.sheet),
        ),
        backgroundColor: AppSemanticColors.surfaceCard,
        surfaceTintColor: AppColors.transparent,
        child: child,
      ),
    );
  }
}

class AppBottomSheet {
  /// B안(2026-11-12, 시안 .sheet): 손잡이 40×5 + (제목 18/w700, 왼쪽) + 내용, 위 모서리 24.
  /// 예전의 연한 틸 제목 띠·아래 선은 없앴다. 뒤 어둠은 테마(rgba(11,15,20,.45)).
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
          color: AppSemanticColors.surfaceCard,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppBorderRadius.sheet),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(
                top: AppSpacing.space2_5,
                bottom: AppSpacing.space2,
              ),
              child: Center(child: AppSheetHandle()),
            ),
            if (hasTitle)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space5,
                  AppSpacing.space2,
                  AppSpacing.space5,
                  AppSpacing.space3,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.heading5.copyWith(
                      color: AppSemanticColors.textPrimary,
                    ),
                  ),
                ),
              ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
