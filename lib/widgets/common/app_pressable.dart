import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../utils/app_haptics.dart';

/// 누르면 0.97로 줄었다가 스프링으로 돌아오는 감싸개. 물결(잉크)은 없다.
///
/// - 햅틱은 손을 뗀 '진짜 탭'에서만 울린다([haptic]). 눌렀다가 스크롤로 넘어가면
///   탭이 취소되고 진동도 없다. 줄어드는 것도 탭 인식기의 짧은 대기(100ms) 뒤라,
///   바로 쓸어 올리면 줄어들지도 않는다.
/// - 길게 누르기([onLongPress])는 impact 햅틱이 기본이다.
/// - 접근성: 버튼으로 읽히고([semanticLabel]), 키보드·스위치 제어로 포커스를 받아
///   Enter/Space로 누를 수 있다. 터치 영역은 [minTouchSize](기본 48×48)보다 작아지지 않는다 —
///   자식이 작으면 가운데에 두고 둘레를 눌러도 된다.
/// - '동작 줄이기'면 크기가 변하지 않는다.
class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.haptic,
    this.longPressHaptic = AppHapticKind.impact,
    this.pressedScale = AppMotion.pressedScale,
    this.minTouchSize = const Size(AppSpacing.space12, AppSpacing.space12),
    this.semanticLabel,
    this.isButton = true,
    this.focusNode,
    this.autofocus = false,
    this.focusBorderRadius,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 탭에 울릴 햅틱. null이면 울리지 않는다(주요 버튼은 [AppHapticKind.tap]).
  final AppHapticKind? haptic;

  /// 길게 누르기에 울릴 햅틱. null이면 울리지 않는다.
  final AppHapticKind? longPressHaptic;

  /// 눌렸을 때 크기. 1.0이면 줄지 않는다.
  final double pressedScale;

  /// 최소 터치 영역. 화면 모양을 이미 정해 둔 자리에 감쌀 때는 [Size.zero]로 끈다.
  final Size minTouchSize;

  /// 화면 낭독기가 읽을 이름. 없으면 자식의 글자를 읽는다.
  final String? semanticLabel;

  /// 버튼으로 읽힐지. 줄(목록 한 칸)처럼 버튼이 아닌 것은 false.
  final bool isButton;

  final FocusNode? focusNode;
  final bool autofocus;

  /// 키보드 포커스 테두리의 모서리. 없으면 [AppBorderRadius.lg].
  final BorderRadius? focusBorderRadius;

  final HitTestBehavior behavior;

  bool get enabled => onTap != null || onLongPress != null;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable>
    with SingleTickerProviderStateMixin {
  // 0 = 제자리, 1 = 다 눌림. 스프링이 살짝 넘쳐 0 아래로 내려가도 되게 범위를 두지 않는다.
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );
  bool _focusHighlight = false;

  // '동작 줄이기'는 미리 읽어 둔다 — 화면이 사라지는 중에 오는 탭 취소(onTapCancel)에서
  // 조상 위젯(MediaQuery)을 찾으면 안 된다.
  bool _reduceMotion = false;

  bool get _allowsScale => widget.pressedScale != 1.0 && !_reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AppMotion.reduceMotion(context);
  }

  @override
  void didUpdateWidget(covariant AppPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _press.value != 0) {
      _press.stop();
      _press.value = 0;
    }
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _pressDown() {
    if (!_allowsScale) return;
    _press.animateTo(
      1,
      duration: AppMotion.press,
      curve: AppMotion.pressCurve,
    );
  }

  void _release() {
    if (!_allowsScale) {
      _press.value = 0;
      return;
    }
    _press.animateWith(
      SpringSimulation(
        AppMotion.pressSpring,
        _press.value,
        0,
        _press.velocity,
      ),
    );
  }

  void _handleTap() {
    final kind = widget.haptic;
    if (kind != null) AppHaptics.play(kind);
    widget.onTap?.call();
  }

  void _handleLongPress() {
    final kind = widget.longPressHaptic;
    if (kind != null) AppHaptics.play(kind);
    widget.onLongPress?.call();
  }

  void _activateFromKeyboard() {
    if (widget.onTap != null) {
      _handleTap();
    } else if (widget.onLongPress != null) {
      _handleLongPress();
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;

    Widget content = AnimatedBuilder(
      animation: _press,
      builder: (context, child) {
        final scale = 1 - (1 - widget.pressedScale) * _press.value;
        return Transform.scale(scale: scale, child: child);
      },
      child: widget.child,
    );

    if (_focusHighlight) {
      content = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: AppSemanticColors.borderFocus, width: 2),
          borderRadius: widget.focusBorderRadius ??
              BorderRadius.circular(AppBorderRadius.lg),
        ),
        child: content,
      );
    }

    final min = widget.minTouchSize;
    if (min.width > 0 || min.height > 0) {
      content = _MinTouchSize(minSize: min, child: content);
    }

    return Semantics(
      container: true,
      button: widget.isButton,
      enabled: enabled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: enabled,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        mouseCursor:
            enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onShowFocusHighlight: (value) {
          if (_focusHighlight != value) setState(() => _focusHighlight = value);
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => _activateFromKeyboard(),
          ),
        },
        child: GestureDetector(
          behavior: widget.behavior,
          onTapDown: widget.onTap != null ? (_) => _pressDown() : null,
          onTapUp: widget.onTap != null ? (_) => _release() : null,
          onTapCancel: widget.onTap != null ? _release : null,
          onTap: widget.onTap != null ? _handleTap : null,
          onLongPressStart:
              widget.onLongPress != null && widget.onTap == null
                  ? (_) => _pressDown()
                  : null,
          onLongPressEnd: widget.onLongPress != null ? (_) => _release() : null,
          onLongPressCancel: widget.onLongPress != null ? _release : null,
          onLongPress: widget.onLongPress != null ? _handleLongPress : null,
          child: content,
        ),
      ),
    );
  }
}

/// 자식은 받은 제약 그대로 배치하고(늘이거나 줄이지 않는다), 자기 크기만 [minSize]까지 키워
/// 자식을 가운데에 둔다. Material 버튼의 터치 여백(_InputPadding)과 같은 방식 —
/// `ConstrainedBox`+`Center`로 하면 꽉 채우라는 제약이 느슨해져 늘어나야 할 카드가 줄어든다.
class _MinTouchSize extends SingleChildRenderObjectWidget {
  const _MinTouchSize({required this.minSize, required Widget super.child});

  final Size minSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMinTouchSize(minSize);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMinTouchSize renderObject,
  ) {
    renderObject.minSize = minSize;
  }
}

class _RenderMinTouchSize extends RenderShiftedBox {
  _RenderMinTouchSize(this._minSize) : super(null);

  Size _minSize;
  Size get minSize => _minSize;
  set minSize(Size value) {
    if (_minSize == value) return;
    _minSize = value;
    markNeedsLayout();
  }

  Size _sizeFor(Size childSize, BoxConstraints constraints) {
    return constraints.constrain(
      Size(
        childSize.width > _minSize.width ? childSize.width : _minSize.width,
        childSize.height > _minSize.height ? childSize.height : _minSize.height,
      ),
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final w = child?.getMinIntrinsicWidth(height) ?? 0;
    return w > _minSize.width ? w : _minSize.width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final w = child?.getMaxIntrinsicWidth(height) ?? 0;
    return w > _minSize.width ? w : _minSize.width;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final h = child?.getMinIntrinsicHeight(width) ?? 0;
    return h > _minSize.height ? h : _minSize.height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final h = child?.getMaxIntrinsicHeight(width) ?? 0;
    return h > _minSize.height ? h : _minSize.height;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final childSize = child?.getDryLayout(constraints) ?? Size.zero;
    return _sizeFor(childSize, constraints);
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = _sizeFor(Size.zero, constraints);
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    size = _sizeFor(child.size, constraints);
    final parentData = child.parentData! as BoxParentData;
    parentData.offset = Alignment.center.alongOffset(size - child.size as Offset);
  }
}
