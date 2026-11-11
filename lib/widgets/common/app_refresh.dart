import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../utils/app_haptics.dart';

/// 당겨서 새로고침 — `RefreshIndicator` 자리에 그대로 넣는다(B안).
///
/// - 당김이 걸려 새로고침이 시작되는 순간 impact 햅틱이 한 번 울린다
///   (당기는 동안·끝났을 때는 울리지 않는다).
/// - 동그라미는 흰 바탕에 틸 — 화면마다 색을 따로 주지 않는다.
///
/// ```dart
/// AppRefreshIndicator(
///   onRefresh: _load,
///   child: ListView(...),
/// )
/// ```
class AppRefreshIndicator extends StatelessWidget {
  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.displacement = 40,
    this.edgeOffset = 0,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.triggerMode = RefreshIndicatorTriggerMode.onEdge,
    this.haptic = true,
  });

  final RefreshCallback onRefresh;
  final Widget child;
  final double displacement;
  final double edgeOffset;
  final ScrollNotificationPredicate notificationPredicate;
  final RefreshIndicatorTriggerMode triggerMode;

  /// false면 울리지 않는다(화면이 스스로 새로고침을 띄우는 드문 경우).
  final bool haptic;

  Future<void> _handleRefresh() {
    if (haptic) AppHaptics.impact();
    return onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppSemanticColors.interactivePrimaryDefault,
      backgroundColor: AppSemanticColors.surfaceCard,
      displacement: displacement,
      edgeOffset: edgeOffset,
      notificationPredicate: notificationPredicate,
      triggerMode: triggerMode,
      child: child,
    );
  }
}
