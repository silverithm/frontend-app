import 'package:flutter/widgets.dart';

/// 하단 탭 화면이 지금 보이는지 — MainTabStack이 탭마다 씌운다.
///
/// 하단 탭은 IndexedStack으로 모두 살려 두고 애니메이션도 멈추지 않아서(TickerMode가 켜진 채)
/// 화면이 스스로는 가려졌는지 알 수 없다. 보일 때만 띄울 것(일정 탭 근무조정 안내 등)이 이 값을 본다.
class MainTabVisibility extends InheritedWidget {
  const MainTabVisibility({
    super.key,
    required this.visible,
    required super.child,
  });

  final bool visible;

  /// 하단 탭 묶음 밖(알림에서 이 화면만 따로 열었을 때 등)이면 늘 보이는 것으로 본다.
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<MainTabVisibility>()
          ?.visible ??
      true;

  @override
  bool updateShouldNotify(MainTabVisibility oldWidget) =>
      oldWidget.visible != visible;
}
