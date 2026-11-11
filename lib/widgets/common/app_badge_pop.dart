import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../theme/app_motion.dart';

/// [value]가 바뀌면 자식(배지)이 톡 튄다 — 1.2배로 커졌다가 스프링으로 돌아온다.
///
/// 처음 나타날 때는 튀지 않는다. 값이 0이 되어 배지가 사라지는 경우처럼 튀지 않게 하려면
/// [popWhen]으로 거른다(기본: 새 값이 null·0·false가 아닐 때만). 크기 변화는 그리기에만
/// 들어가 둘레 배치는 움직이지 않는다. '동작 줄이기'면 튀지 않는다.
///
/// ```dart
/// AppBadgePop(value: unreadCount, child: CountBadge(unreadCount))
/// ```
class AppBadgePop extends StatefulWidget {
  const AppBadgePop({
    super.key,
    required this.value,
    required this.child,
    this.popWhen,
    this.scale = AppMotion.badgePopScale,
    this.alignment = Alignment.center,
  });

  final Object? value;
  final Widget child;

  /// (전 값, 새 값) → 튈지. 없으면 새 값이 null·0·false·''가 아닐 때 튄다.
  final bool Function(Object? previous, Object? next)? popWhen;

  /// 가장 커지는 배율.
  final double scale;
  final Alignment alignment;

  @override
  State<AppBadgePop> createState() => _AppBadgePopState();
}

class _AppBadgePopState extends State<AppBadgePop>
    with SingleTickerProviderStateMixin {
  // 0 = 제자리, 1 = 가장 큼. 스프링이 0 아래로 살짝 넘쳐도 되게 범위를 두지 않는다.
  late final AnimationController _pop = AnimationController.unbounded(
    vsync: this,
  );

  static bool _defaultPopWhen(Object? previous, Object? next) {
    if (next == null || next == false || next == 0 || next == '') return false;
    return true;
  }

  @override
  void didUpdateWidget(covariant AppBadgePop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    final shouldPop =
        (widget.popWhen ?? _defaultPopWhen)(oldWidget.value, widget.value);
    if (!shouldPop || !AppMotion.allowsMovement(context)) return;
    _play();
  }

  Future<void> _play() async {
    // 빠르게 커졌다가(스프링 길이의 1/3) 튀며 돌아온다.
    await _pop.animateTo(
      1,
      duration: AppMotion.badgePop ~/ 3,
      curve: AppMotion.enterCurve,
    );
    if (!mounted) return;
    await _pop.animateWith(
      SpringSimulation(AppMotion.badgeSpring, _pop.value, 0, 0),
    );
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pop,
      child: widget.child,
      builder: (context, child) {
        final s = 1 + (widget.scale - 1) * _pop.value;
        return Transform.scale(
          scale: s,
          alignment: widget.alignment,
          child: child,
        );
      },
    );
  }
}
