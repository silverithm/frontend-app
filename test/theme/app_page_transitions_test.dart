import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/theme/app_motion.dart';
import 'package:frontend_app/theme/app_page_transitions.dart';
import 'package:frontend_app/theme/app_theme.dart';

/// 화면 넘김이 테마 한 곳(AppTheme.withAppChrome)에서 앱 전체에 걸리는지,
/// Android·iOS 모두 "오른쪽에서 밀려 들어오고 뒤 화면은 살짝 밀린다"인지,
/// 그리고 iOS 쓸어 넘기기·Android 예측형 뒤로가 그대로 되는지.
void main() {
  Widget app({
    TargetPlatform platform = TargetPlatform.android,
    bool reduceMotion = false,
    bool fullscreenDialog = false,
  }) {
    return MaterialApp(
      theme: AppTheme.withAppChrome(ThemeData(platform: platform)),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  fullscreenDialog: fullscreenDialog,
                  builder: (_) => const Scaffold(body: _CounterPage()),
                ),
              ),
              child: const Text('첫 화면'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> sendBackGesture(
    WidgetTester tester,
    String method, [
    Map<String, Object?>? args,
  ]) async {
    final ByteData message =
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, args));
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/backgesture',
      message,
      (ByteData? _) {},
    );
  }

  double leftOf(WidgetTester tester, Finder finder) =>
      tester.getTopLeft(finder).dx;

  testWidgets('withAppChrome에 넘김이 들어 있다(앱 전체 MaterialPageRoute가 쓴다)',
      (tester) async {
    final theme = AppTheme.withAppChrome(ThemeData());
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      expect(
        theme.pageTransitionsTheme.builders[platform],
        isA<AppPageTransitionsBuilder>(),
      );
    }
    expect(const AppPageTransitionsBuilder().transitionDuration, AppMotion.page);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('${platform.name}: 오른쪽에서 들어오고 뒤 화면은 왼쪽으로 살짝 밀린다',
        (tester) async {
      await tester.pumpWidget(app(platform: platform));
      await tester.tap(find.text('첫 화면'));
      await tester.pump();
      await tester.pump(AppMotion.page ~/ 3);

      final width = tester.getSize(find.byType(MaterialApp)).width;
      final newLeft = leftOf(tester, find.byType(_CounterPage));
      final oldLeft = leftOf(tester, find.text('첫 화면'));
      final oldCenterAtRest = width / 2;
      expect(newLeft, greaterThan(0));
      expect(newLeft, lessThan(width));
      // 뒤 화면 글자가 제자리(가운데)보다 왼쪽에 있다.
      expect(
        oldLeft + tester.getSize(find.text('첫 화면')).width / 2,
        lessThan(oldCenterAtRest),
      );

      // 320ms면 다 들어와 있다.
      await tester.pump(AppMotion.page);
      expect(leftOf(tester, find.byType(_CounterPage)), 0);
      await tester.pumpAndSettle();
      expect(find.text('첫 화면'), findsNothing);
    });
  }

  testWidgets('iOS: 왼쪽 가장자리에서 쓸어 넘기면 뒤로 간다', (tester) async {
    await tester.pumpWidget(app(platform: TargetPlatform.iOS));
    await tester.tap(find.text('첫 화면'));
    await tester.pumpAndSettle();
    expect(find.byType(_CounterPage), findsOneWidget);

    final gesture = await tester.startGesture(const Offset(5, 300));
    await gesture.moveBy(const Offset(50, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(350, 0));
    await tester.pump();
    // 쓸어 넘기는 중 — 손가락을 따라 오른쪽으로 밀려나 있다.
    expect(leftOf(tester, find.byType(_CounterPage)), greaterThan(100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(_CounterPage), findsNothing);
    expect(find.text('첫 화면'), findsOneWidget);
  });

  testWidgets('Android: 예측형 뒤로 제스처를 따라 밀려나고, 놓으면 뒤로 간다',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('첫 화면'));
    await tester.pumpAndSettle();

    await sendBackGesture(tester, 'startBackGesture', {
      'touchOffset': <double>[5.0, 300.0],
      'progress': 0.0,
      'swipeEdge': 0, // 왼쪽
    });
    await tester.pump();
    await sendBackGesture(tester, 'updateBackGestureProgress', {
      'x': 200.0,
      'y': 300.0,
      'progress': 0.5,
      'swipeEdge': 0,
    });
    await tester.pump();
    expect(leftOf(tester, find.byType(_CounterPage)), greaterThan(100));
    // 뒤 화면이 드러나 보인다.
    expect(find.text('첫 화면'), findsOneWidget);

    await sendBackGesture(tester, 'commitBackGesture');
    await tester.pumpAndSettle();
    expect(find.byType(_CounterPage), findsNothing);
    expect(find.text('첫 화면'), findsOneWidget);
  });

  testWidgets('Android: 예측형 뒤로를 취소하면 제자리로 돌아온다', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('첫 화면'));
    await tester.pumpAndSettle();

    await sendBackGesture(tester, 'startBackGesture', {
      'touchOffset': <double>[5.0, 300.0],
      'progress': 0.0,
      'swipeEdge': 0,
    });
    await sendBackGesture(tester, 'updateBackGestureProgress', {
      'x': 120.0,
      'y': 300.0,
      'progress': 0.3,
      'swipeEdge': 0,
    });
    await tester.pump();
    await sendBackGesture(tester, 'cancelBackGesture');
    await tester.pumpAndSettle();
    expect(leftOf(tester, find.byType(_CounterPage)), 0);
    expect(find.text('첫 화면'), findsNothing);
  });

  testWidgets('Android: 오른쪽 가장자리 제스처는 따라가지 않지만 뒤로는 간다',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('첫 화면'));
    await tester.pumpAndSettle();

    await sendBackGesture(tester, 'startBackGesture', {
      'touchOffset': <double>[795.0, 300.0],
      'progress': 0.0,
      'swipeEdge': 1, // 오른쪽
    });
    await sendBackGesture(tester, 'updateBackGestureProgress', {
      'x': 600.0,
      'y': 300.0,
      'progress': 0.5,
      'swipeEdge': 1,
    });
    await tester.pump();
    expect(leftOf(tester, find.byType(_CounterPage)), 0);

    await sendBackGesture(tester, 'commitBackGesture');
    await tester.pumpAndSettle();
    expect(find.byType(_CounterPage), findsNothing);
    expect(find.text('첫 화면'), findsOneWidget);
  });

  testWidgets('fullscreenDialog는 아래에서 올라오고, 뒤 화면은 움직이지 않는다',
      (tester) async {
    await tester.pumpWidget(app(fullscreenDialog: true));
    final restLeft = leftOf(tester, find.text('첫 화면'));
    await tester.tap(find.text('첫 화면'));
    await tester.pump();
    await tester.pump(AppMotion.page ~/ 3);
    expect(tester.getTopLeft(find.byType(_CounterPage)).dy, greaterThan(0));
    expect(leftOf(tester, find.byType(_CounterPage)), 0);
    expect(leftOf(tester, find.text('첫 화면')), restLeft);
    await tester.pumpAndSettle();

    // 뒤로 가기(시스템 버튼과 같은 길)
    final NavigatorState navigator = tester.state(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('첫 화면'), findsOneWidget);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('${platform.name}: 동작 줄이기면 밀리지 않고 겹쳐 바뀐다',
        (tester) async {
      await tester.pumpWidget(app(platform: platform, reduceMotion: true));
      final restLeft = leftOf(tester, find.text('첫 화면'));
      await tester.tap(find.text('첫 화면'));
      await tester.pump();
      await tester.pump(AppMotion.page ~/ 3);

      expect(leftOf(tester, find.byType(_CounterPage)), 0);
      expect(leftOf(tester, find.text('첫 화면')), restLeft);
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byType(_CounterPage),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, greaterThan(0));
      expect(fade.opacity.value, lessThan(1));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('iOS 동작 줄이기에서도 쓸어 넘기기는 되고, 화면 상태가 새로 만들어지지 않는다',
      (tester) async {
    _CounterPage.created = 0;
    await tester.pumpWidget(
      app(platform: TargetPlatform.iOS, reduceMotion: true),
    );
    await tester.tap(find.text('첫 화면'));
    await tester.pumpAndSettle();
    expect(_CounterPage.created, 1);

    final gesture = await tester.startGesture(const Offset(5, 300));
    await gesture.moveBy(const Offset(50, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(250, 0));
    await tester.pump();
    expect(leftOf(tester, find.byType(_CounterPage)), greaterThan(100));
    expect(_CounterPage.created, 1);

    // 반쯤에서 되돌려 놓으면 그대로 남는다.
    await gesture.moveBy(const Offset(-290, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(_CounterPage), findsOneWidget);
    expect(_CounterPage.created, 1);
  });

  testWidgets('넘기는 중 뒤 화면은 살짝 어두워지고, 다 넘어가 멈추면 어둠이 남지 않는다',
      (tester) async {
    await tester.pumpWidget(app(platform: TargetPlatform.iOS));
    await tester.tap(find.text('첫 화면'));
    await tester.pump();
    await tester.pump(AppMotion.page ~/ 2);

    final scrims = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .where((box) =>
            box.position == DecorationPosition.foreground &&
            box.decoration is BoxDecoration &&
            (box.decoration as BoxDecoration).color != null &&
            (box.decoration as BoxDecoration).color!.a > 0)
        .toList();
    expect(scrims, isNotEmpty);
    expect(
      (scrims.first.decoration as BoxDecoration).color!.a,
      lessThanOrEqualTo(AppMotion.pageScrimOpacity + 0.001),
    );

    await tester.pumpAndSettle();
    final NavigatorState navigator = tester.state(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();
    final leftover = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .where((box) =>
            box.position == DecorationPosition.foreground &&
            (box.decoration as BoxDecoration).color != null);
    expect(leftover, isEmpty);
  });

  test('기본 플랫폼(테스트 기본값 android)에서도 같은 넘김을 쓴다', () {
    expect(defaultTargetPlatform, TargetPlatform.android);
    expect(
      appPageTransitionsTheme.builders[defaultTargetPlatform],
      isA<AppPageTransitionsBuilder>(),
    );
  });
}

/// 쓸어 넘기기를 시작해도 화면 상태가 새로 만들어지지 않는지 세는 화면.
class _CounterPage extends StatefulWidget {
  const _CounterPage();

  static int created = 0;

  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  @override
  void initState() {
    super.initState();
    _CounterPage.created++;
  }

  @override
  Widget build(BuildContext context) => const Center(child: Text('둘째 화면'));
}
