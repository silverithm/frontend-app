import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../utils/app_haptics.dart';

/// 완료(승인·전송·저장) 표시 — 둥근 바탕이 커지고 체크가 그려진다(500ms) + 성공 진동.
///
/// 화면에 붙는 순간 한 번 재생한다. 다시 재생하려면 key를 바꾼다.
/// '동작 줄이기'면 그리지 않고 다 그려진 모양을 바로 보인다(진동은 그대로 — 움직임이 아니다).
class AppSuccessCheck extends StatefulWidget {
  const AppSuccessCheck({
    super.key,
    this.size = AppSpacing.space14,
    this.color = AppSemanticColors.statusSuccessIcon,
    this.backgroundColor = AppSemanticColors.statusSuccessBackground,
    this.haptic = true,
    this.duration = AppMotion.check,
    this.semanticLabel = '완료',
    this.onCompleted,
  });

  final double size;

  /// 체크 선 색.
  final Color color;

  /// 둥근 바탕 색. 투명으로 두면 체크만 그린다.
  final Color backgroundColor;

  /// 재생을 시작할 때 success 햅틱을 울릴지.
  final bool haptic;
  final Duration duration;
  final String semanticLabel;
  final VoidCallback? onCompleted;

  @override
  State<AppSuccessCheck> createState() => _AppSuccessCheckState();
}

class _AppSuccessCheckState extends State<AppSuccessCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  // 바탕은 앞 40% 동안 커지고, 체크는 30%부터 끝까지 그려진다.
  late final CurvedAnimation _circle = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.4, curve: Curves.easeOutBack),
  );
  late final CurvedAnimation _check = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.3, 1, curve: AppMotion.enterCurve),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.haptic) AppHaptics.success();
    if (AppMotion.allowsMovement(context)) {
      _controller.forward().whenCompleteOrCancel(() {
        if (mounted && _controller.isCompleted) widget.onCompleted?.call();
      });
    } else {
      _controller.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onCompleted?.call();
      });
    }
  }

  @override
  void dispose() {
    _circle.dispose();
    _check.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _SuccessCheckPainter(
            circle: _circle,
            check: _check,
            color: widget.color,
            backgroundColor: widget.backgroundColor,
          ),
        ),
      ),
    );
  }
}

class _SuccessCheckPainter extends CustomPainter {
  _SuccessCheckPainter({
    required this.circle,
    required this.check,
    required this.color,
    required this.backgroundColor,
  }) : super(repaint: Listenable.merge([circle, check]));

  final Animation<double> circle;
  final Animation<double> check;
  final Color color;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    final c = circle.value;
    if (c > 0 && backgroundColor.a > 0) {
      canvas.drawCircle(
        center,
        radius * c,
        Paint()..color = backgroundColor,
      );
    }

    final t = check.value.clamp(0.0, 1.0);
    if (t <= 0) return;
    final s = size.shortestSide;
    final path = Path()
      ..moveTo(center.dx - s * 0.22, center.dy + s * 0.01)
      ..lineTo(center.dx - s * 0.06, center.dy + s * 0.17)
      ..lineTo(center.dx + s * 0.24, center.dy - s * 0.15);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, s * 0.08)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (sum, m) => sum + m.length);
    var remaining = total * t;
    final drawn = Path();
    for (final PathMetric metric in metrics) {
      if (remaining <= 0) break;
      final len = math.min(remaining, metric.length);
      drawn.addPath(metric.extractPath(0, len), Offset.zero);
      remaining -= len;
    }
    canvas.drawPath(drawn, stroke);
  }

  @override
  bool shouldRepaint(_SuccessCheckPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.circle != circle ||
      oldDelegate.check != check;
}
