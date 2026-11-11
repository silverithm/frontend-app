import 'package:flutter/material.dart';

import '../../theme/app_motion.dart';

/// 목록이 처음 나타날 때 줄마다 30ms씩 차를 두고 아래 12px에서 떠오르며 나타난다.
///
/// 처음 8줄([AppMotion.listStaggerMaxItems])만 연출하고 그 아래 줄은 바로 보인다.
/// 목록을 [AppListEntrance]로 감싸 두면, 스크롤로 내려갔다 돌아와 줄이 다시 만들어져도
/// 한 번 나온 줄은 다시 연출하지 않는다(감싸지 않으면 줄 하나가 만들어질 때마다 한 번).
/// 목록을 새로 불러와 다시 연출하고 싶으면 [AppListEntrance]의 key를 바꾼다.
/// '동작 줄이기'면 떠오름·시차 없이 짧게 겹쳐 나타난다.
///
/// ```dart
/// AppListEntrance(
///   child: ListView.builder(
///     itemCount: items.length,
///     itemBuilder: (context, i) =>
///         AppListEntranceItem(index: i, child: NoticeRow(items[i])),
///   ),
/// )
/// ```
class AppListEntrance extends StatefulWidget {
  const AppListEntrance({super.key, required this.child});

  final Widget child;

  @override
  State<AppListEntrance> createState() => _AppListEntranceState();
}

class _AppListEntranceState extends State<AppListEntrance> {
  final Set<int> _shown = <int>{};

  /// 이 줄을 연출할지 — 처음 묻는 줄만 true.
  bool _claim(int index) => _shown.add(index);

  @override
  Widget build(BuildContext context) {
    return _AppListEntranceScope(state: this, child: widget.child);
  }
}

class _AppListEntranceScope extends InheritedWidget {
  const _AppListEntranceScope({required this.state, required super.child});

  final _AppListEntranceState state;

  @override
  bool updateShouldNotify(_AppListEntranceScope oldWidget) =>
      state != oldWidget.state;
}

/// 목록 한 줄. [index]는 목록 안 순서(0부터).
class AppListEntranceItem extends StatefulWidget {
  const AppListEntranceItem({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<AppListEntranceItem> createState() => _AppListEntranceItemState();
}

class _AppListEntranceItemState extends State<AppListEntranceItem>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  CurvedAnimation? _curved;
  Animation<double>? _opacity;
  Animation<Offset>? _offset;
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;

    final index = widget.index;
    if (index < 0 || index >= AppMotion.listStaggerMaxItems) return;
    // getInherited… — 의존을 걸지 않는다(줄이 다시 지어질 필요가 없다).
    final scope = context
        .getInheritedWidgetOfExactType<_AppListEntranceScope>()
        ?.state;
    if (scope != null && !scope._claim(index)) return;

    final reduce = AppMotion.reduceMotion(context);
    final delay = reduce ? Duration.zero : AppMotion.listStagger * index;
    final run = reduce ? AppMotion.fade : AppMotion.listItem;
    final total = delay + run;
    final start = total.inMicroseconds == 0
        ? 0.0
        : delay.inMicroseconds / total.inMicroseconds;

    final controller = AnimationController(vsync: this, duration: total);
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(start, 1, curve: AppMotion.enterCurve),
    );
    _controller = controller;
    _curved = curved;
    _opacity = curved;
    if (!reduce) {
      // 위젯 크기로 비율을 정하면 줄 높이마다 거리가 달라진다 — 늘 12px로 둔다(그리기 때만 옮김).
      _offset = Tween<Offset>(
        begin: const Offset(0, AppMotion.listRise),
        end: Offset.zero,
      ).animate(curved);
    }
    controller.forward();
  }

  @override
  void dispose() {
    _curved?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = _opacity;
    if (opacity == null) return widget.child;
    final offset = _offset;
    Widget result = FadeTransition(opacity: opacity, child: widget.child);
    if (offset != null) {
      result = AnimatedBuilder(
        animation: offset,
        child: result,
        builder: (context, child) =>
            Transform.translate(offset: offset.value, child: child),
      );
    }
    return result;
  }
}
