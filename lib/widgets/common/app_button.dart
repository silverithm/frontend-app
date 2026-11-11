import 'package:flutter/material.dart';
import '../../utils/app_haptics.dart';
import '../seed/seed_button.dart';

enum AppButtonSize { small, medium, large }
enum AppButtonVariant { primary, secondary, outline, text }

/// 예전 shadcn 단추를 감싸던 단추. B안(2026-11-12)부터는 SeedButton과 같은 모양을 그린다
/// (앱 안에서 쓰는 곳은 없지만 API는 그대로 둔다). 새로 쓸 때는 SeedButton을 쓴다.
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonSize size;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;
  final Widget? icon;
  final EdgeInsets? padding;

  /// 눌렀을 때 울릴 햅틱. 기본 tap(약함), null이면 울리지 않는다.
  final AppHapticKind? haptic;

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
    this.haptic = AppHapticKind.tap,
  });

  SeedButtonSize get _seedSize {
    switch (size) {
      case AppButtonSize.small:
        return SeedButtonSize.small;
      case AppButtonSize.medium:
        return SeedButtonSize.medium;
      case AppButtonSize.large:
        return SeedButtonSize.large;
    }
  }

  SeedButtonVariant get _seedVariant {
    switch (variant) {
      case AppButtonVariant.primary:
        return SeedButtonVariant.brandSolid;
      case AppButtonVariant.secondary:
        return SeedButtonVariant.neutralWeak;
      case AppButtonVariant.outline:
        return SeedButtonVariant.neutralOutline;
      case AppButtonVariant.text:
        return SeedButtonVariant.brandGhost;
    }
  }

  @override
  Widget build(BuildContext context) {
    final button = SeedButton(
      label: text,
      onPressed: onPressed,
      size: _seedSize,
      variant: _seedVariant,
      isLoading: isLoading,
      leading: isLoading ? null : icon,
      haptic: haptic,
    );
    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
