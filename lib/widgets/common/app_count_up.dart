import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../theme/app_motion.dart';

/// 숫자가 세어 올라가며 바뀐다(400ms, 끝에서 부드럽게 멈춤).
///
/// 처음 나타날 때는 [from](기본 0)에서, 그 뒤로는 바로 전 값에서 새 값까지 센다.
/// 화면 낭독기는 세는 중간값이 아니라 마지막 값만 읽는다.
/// '동작 줄이기'면 세지 않고 바로 마지막 값을 보인다.
///
/// 글자 폭이 숫자마다 달라 흔들리지 않게 기본으로 고정폭 숫자(tabular)를 쓴다.
class AppCountUp extends StatefulWidget {
  const AppCountUp({
    super.key,
    required this.value,
    this.from = 0,
    this.style,
    this.format,
    this.duration = AppMotion.number,
    this.curve = AppMotion.countCurve,
    this.animateOnFirstBuild = true,
    this.tabularFigures = true,
    this.textAlign,
    this.semanticsLabel,
  });

  final int value;

  /// 처음 나타날 때 세기 시작하는 값.
  final int from;
  final TextStyle? style;

  /// 숫자를 글자로 — 예: `(n) => '$n건'`. 없으면 숫자만.
  final String Function(int value)? format;
  final Duration duration;
  final Curve curve;

  /// false면 처음에는 바로 [value]를 보이고, 값이 바뀔 때만 센다.
  final bool animateOnFirstBuild;
  final bool tabularFigures;
  final TextAlign? textAlign;

  /// 화면 낭독기가 읽을 글. 없으면 [format]한 마지막 값.
  final String? semanticsLabel;

  @override
  State<AppCountUp> createState() => _AppCountUpState();
}

class _AppCountUpState extends State<AppCountUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _controller,
    curve: widget.curve,
  );
  late double _begin;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _begin = widget.from.toDouble();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.animateOnFirstBuild &&
        widget.from != widget.value &&
        AppMotion.allowsMovement(context)) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant AppCountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    _curved.curve = widget.curve;
    if (oldWidget.value == widget.value) return;
    // 세는 중에 값이 또 바뀌면 지금 보이는 값에서 이어서 센다.
    _begin = _currentValue(oldWidget.value);
    if (AppMotion.allowsMovement(context)) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 1;
    }
  }

  double _currentValue(int target) =>
      lerpDouble(_begin, target.toDouble(), _curved.value) ?? target.toDouble();

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _format(int value) => widget.format?.call(value) ?? '$value';

  @override
  Widget build(BuildContext context) {
    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final style = widget.tabularFigures
        ? baseStyle.copyWith(
            fontFeatures: [
              ...?baseStyle.fontFeatures,
              const FontFeature.tabularFigures(),
            ],
          )
        : baseStyle;
    final label = widget.semanticsLabel ?? _format(widget.value);

    return AnimatedBuilder(
      animation: _curved,
      builder: (context, _) {
        final shown = _currentValue(widget.value).round();
        return Text(
          _format(shown),
          style: style,
          textAlign: widget.textAlign,
          semanticsLabel: label,
        );
      },
    );
  }
}
