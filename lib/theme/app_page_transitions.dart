import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_motion.dart';

/// 앱 전체 화면 넘김 — Android·iOS 같게 "오른쪽에서 밀려 들어오고, 뒤 화면은 살짝
/// 왼쪽으로 밀리며 어두워진다"(320ms).
///
/// `ThemeData.pageTransitionsTheme` 한 곳에 걸어 두면 `MaterialPageRoute`(앱의 화면 이동
/// 전부)가 이걸 쓴다 — 화면마다 고칠 필요가 없다. main.dart의 builder가 Navigator 위에
/// 테마를 씌우므로 모든 경로가 이 테마를 본다(theme/app_theme.dart `withAppChrome`).
///
/// 뒤로 가기
/// - iOS 왼쪽 가장자리 쓸어 넘기기: Flutter의 Cupertino 넘김을 그대로 쓰므로 그대로 된다.
/// - Android 예측형 뒤로(Android 14+ 시스템 제스처): 손가락을 따라 화면이 오른쪽으로 밀려난다.
///   제스처를 받지 못하는 경우(버튼 뒤로·오른쪽 가장자리·전체 화면 대화상자)에는 Flutter가
///   평소 뒤로 가기(pop)로 처리한다 — 뒤로 가기 자체가 막히는 일은 없다.
/// - `fullscreenDialog: true` 경로는 아래에서 올라오고(iOS 모달과 같음) 쓸어 넘기기는 없다.
///
/// '동작 줄이기'면 밀림·어두워짐 없이 겹쳐 바뀐다(쓸어 넘기는 동안에는 손가락을 따라간다).
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.page;

  @override
  Duration get reverseTransitionDuration => AppMotion.page;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      CupertinoPageTransition.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final bool reduce = AppMotion.reduceMotion(context);
    // 쓸어 넘기는 중에는 '동작 줄이기'여도 손가락을 따라가야 한다(직접 조작).
    final bool followGesture = route.popGestureInProgress;
    final bool simple = reduce && !followGesture;

    // 위젯 구조는 '동작 줄이기'·쓸어 넘기기 여부와 상관없이 늘 같다 — 애니메이션만 바꿔 끼운다.
    // 구조가 바뀌면 쓸어 넘기기를 시작하는 순간 화면 아래 위젯 상태가 새로 만들어진다.
    Widget page = FadeTransition(
      opacity: simple ? animation : kAlwaysCompleteAnimation,
      child: child,
    );
    if (!route.fullscreenDialog) {
      // 뒤 화면 어두워짐 — 다음 화면이 덮어 올 때(secondaryAnimation) 이 화면 위에 칠한다.
      page = _PageScrim(
        animation: simple ? kAlwaysDismissedAnimation : secondaryAnimation,
        child: page,
      );
    }

    Widget result = CupertinoRouteTransitionMixin.buildPageTransitions<T>(
      route,
      context,
      simple ? kAlwaysCompleteAnimation : animation,
      simple ? kAlwaysDismissedAnimation : secondaryAnimation,
      page,
    );

    if (Theme.of(context).platform == TargetPlatform.android &&
        !route.fullscreenDialog) {
      result = _AndroidBackGestureDetector(route: route, child: result);
    }
    return result;
  }
}

/// 앱 테마에 넣는 넘김 묶음. 데스크톱 플랫폼도 같게 둔다(테스트·디버그용).
const PageTransitionsTheme appPageTransitionsTheme = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: AppPageTransitionsBuilder(),
    TargetPlatform.iOS: AppPageTransitionsBuilder(),
    TargetPlatform.macOS: AppPageTransitionsBuilder(),
    TargetPlatform.fuchsia: AppPageTransitionsBuilder(),
    TargetPlatform.linux: AppPageTransitionsBuilder(),
    TargetPlatform.windows: AppPageTransitionsBuilder(),
  },
);

/// 다음 화면에 덮일 때 이 화면을 살짝 어둡게. 다 덮이면 보이지 않으니 정지 화면에는 영향이 없다.
class _PageScrim extends AnimatedWidget {
  const _PageScrim({required Animation<double> animation, required this.child})
      : super(listenable: animation);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double t = (listenable as Animation<double>).value;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: t <= 0
          ? const BoxDecoration()
          : BoxDecoration(
              color: AppColors.black
                  .withValues(alpha: AppMotion.pageScrimOpacity * t),
            ),
      child: child,
    );
  }
}

/// Android 예측형 뒤로 제스처를 받아 이 경로의 넘김을 손가락에 맞춰 되감는다.
///
/// Flutter 기본 PredictiveBackPageTransitionsBuilder 안의 감지기와 같은 일을 한다
/// (그쪽은 비공개라 그대로 쓸 수 없다). 넘김 모양만 Cupertino 밀림으로 바뀐다.
/// 받지 않은 제스처는 Flutter가 끝날 때 평소 뒤로 가기(handlePopRoute)로 처리한다.
class _AndroidBackGestureDetector extends StatefulWidget {
  const _AndroidBackGestureDetector({required this.route, required this.child});

  final PageRoute<dynamic> route;
  final Widget child;

  @override
  State<_AndroidBackGestureDetector> createState() =>
      _AndroidBackGestureDetectorState();
}

class _AndroidBackGestureDetectorState
    extends State<_AndroidBackGestureDetector> with WidgetsBindingObserver {
  bool _tracking = false;

  bool get _canTrack =>
      widget.route.isCurrent && widget.route.popGestureEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    // 버튼 뒤로·오른쪽 가장자리는 따라가지 않는다(화면이 손가락 반대로 밀려 보인다).
    if (backEvent.isButtonEvent ||
        backEvent.swipeEdge != SwipeEdge.left ||
        !_canTrack) {
      _tracking = false;
      return false;
    }
    _tracking = true;
    widget.route.handleStartBackGesture(progress: 1 - backEvent.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    if (!_tracking) return;
    widget.route.handleUpdateBackGestureProgress(progress: 1 - backEvent.progress);
  }

  @override
  void handleCancelBackGesture() {
    if (!_tracking) return;
    _tracking = false;
    widget.route.handleCancelBackGesture();
  }

  @override
  void handleCommitBackGesture() {
    if (!_tracking) return;
    _tracking = false;
    widget.route.handleCommitBackGesture();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
