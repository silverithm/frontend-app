import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/app_haptics.dart';
import 'app_pressable.dart';

/// 카드 — B안(2026-11-12): 회색 바탕 위 흰 상자, 테두리·그림자 없음, 모서리 16, 안쪽 여백 16.
/// 카드끼리는 선 대신 간격(AppSpacing.cardGap 10)으로 나눈다.
/// [onTap]이 있으면 눌렀을 때 살짝 줄었다가(0.98) 돌아오고 tap 햅틱이 울린다.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  /// 바깥 여백. 없으면 0 — 목록에서는 감싸는 쪽이 간격을 정한다.
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderRadius;
  final double? elevation;

  /// B안 기본은 테두리 없음. 흰 바탕 위에 카드를 겹쳐 놓는 드문 자리에서만 true.
  final bool hasBorder;

  /// 화면 낭독기가 읽을 이름(누를 수 있는 카드일 때).
  final String? semanticLabel;

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
    this.hasBorder = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius ?? AppBorderRadius.card);
    final shadowElevation = elevation ?? 0;
    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppSemanticColors.surfaceCard,
        borderRadius: radius,
        border: hasBorder
            ? Border.all(color: borderColor ?? AppSemanticColors.borderHairline)
            : null,
        boxShadow: shadowElevation > 0
            ? [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.08),
                  blurRadius: shadowElevation,
                  offset: Offset(0, shadowElevation / 2),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
        child: child,
      ),
    );

    if (onTap != null) {
      card = AppPressable(
        onTap: onTap,
        haptic: AppHapticKind.tap,
        pressedScale: 0.98,
        isButton: true,
        semanticLabel: semanticLabel,
        focusBorderRadius: radius,
        minTouchSize: Size.zero,
        child: card,
      );
    }

    final m = margin;
    return m == null ? card : Padding(padding: m, child: card);
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

    // B안: 상태 카드도 테두리 없이 옅은 상태색 바탕만
    return AppCard(
      backgroundColor: colors.background,
      padding: padding,
      // 예전 AppCard 기본 바깥 여백(16)을 그대로 둔다 — 쓰는 곳(프로필)의 배치가 바뀌지 않게.
      margin: margin ?? const EdgeInsets.all(AppSpacing.space4),
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