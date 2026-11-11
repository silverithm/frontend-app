import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/theme/app_motion.dart';
import 'package:frontend_app/theme/app_spacing.dart';
import 'package:frontend_app/utils/app_haptics.dart';
import 'package:frontend_app/widgets/common/app_badge_pop.dart';
import 'package:frontend_app/widgets/common/app_count_up.dart';
import 'package:frontend_app/widgets/common/app_list_entrance.dart';
import 'package:frontend_app/widgets/common/app_success_check.dart';

/// 작은 연출 위젯 — 숫자 세기·배지 튐·목록 첫 등장·완료 체크.
/// 모두 '동작 줄이기'면 움직임 없이 마지막 모습을 바로 보인다.
void main() {
  final heard = <AppHapticKind>[];

  setUp(() {
    heard.clear();
    AppHaptics.enabled.value = true;
    AppHaptics.debugPerformOverride = (kind) async => heard.add(kind);
  });

  tearDown(() => AppHaptics.debugPerformOverride = null);

  Widget host(Widget child, {bool reduceMotion = false}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }

  test('토큰은 AppTransitions와 어긋나지 않는다', () {
    expect(AppMotion.tabSwitch, AppTransitions.normal);
    expect(AppMotion.listItem, AppTransitions.slow);
    expect(AppMotion.fade, AppTransitions.fast);
    expect(AppMotion.check, AppTransitions.slowest);
    expect(AppMotion.press, const Duration(milliseconds: 110));
    expect(AppMotion.page, const Duration(milliseconds: 320));
    expect(AppMotion.number, const Duration(milliseconds: 400));
    expect(AppMotion.bar, const Duration(milliseconds: 600));
    expect(AppMotion.listStagger, const Duration(milliseconds: 30));
    expect(AppMotion.listStaggerMaxItems, 8);
    expect(AppMotion.listRise, 12);
  });

  testWidgets('동작 줄이기 도우미는 MediaQuery를 읽는다', (tester) async {
    late bool reduced;
    late Duration duration;
    for (final reduce in [false, true]) {
      await tester.pumpWidget(host(
        Builder(builder: (context) {
          reduced = AppMotion.reduceMotion(context);
          duration = AppMotion.durationOf(context, AppMotion.page);
          return const SizedBox();
        }),
        reduceMotion: reduce,
      ));
      expect(reduced, reduce);
      expect(duration, reduce ? AppMotion.fade : AppMotion.page);
    }
    // MediaQuery가 없으면 꺼진 것으로 본다.
    await tester.pumpWidget(Builder(builder: (context) {
      reduced = AppMotion.reduceMotion(context);
      return const SizedBox();
    }));
    expect(reduced, isFalse);
  });

  group('AppCountUp', () {
    int shown(WidgetTester tester) => int.parse(
          tester.widget<Text>(find.byType(Text)).data!.replaceAll('건', ''),
        );

    testWidgets('0에서 세어 올라가 400ms에 멈춘다', (tester) async {
      await tester.pumpWidget(host(
        AppCountUp(value: 120, format: (n) => '$n건'),
      ));
      expect(shown(tester), 0);
      await tester.pump(AppMotion.number ~/ 4);
      final middle = shown(tester);
      expect(middle, greaterThan(0));
      expect(middle, lessThan(120));
      await tester.pump(AppMotion.number);
      expect(shown(tester), 120);
    });

    testWidgets('값이 바뀌면 전 값에서 새 값까지 센다', (tester) async {
      await tester.pumpWidget(host(
        AppCountUp(value: 10, animateOnFirstBuild: false, format: (n) => '$n건'),
      ));
      expect(shown(tester), 10);
      await tester.pumpWidget(host(
        AppCountUp(value: 20, animateOnFirstBuild: false, format: (n) => '$n건'),
      ));
      await tester.pump(AppMotion.number ~/ 4);
      expect(shown(tester), inExclusiveRange(10, 20));
      await tester.pumpAndSettle();
      expect(shown(tester), 20);
    });

    testWidgets('화면 낭독기는 마지막 값만 읽는다', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host(
        AppCountUp(value: 7, format: (n) => '$n건'),
      ));
      await tester.pump(AppMotion.number ~/ 4);
      expect(find.bySemanticsLabel('7건'), findsOneWidget);
      semantics.dispose();
      await tester.pumpAndSettle();
    });

    testWidgets('동작 줄이기면 바로 마지막 값', (tester) async {
      await tester.pumpWidget(host(
        AppCountUp(value: 42, format: (n) => '$n건'),
        reduceMotion: true,
      ));
      expect(shown(tester), 42);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('AppBadgePop', () {
    double scaleOf(WidgetTester tester) => tester
        .widget<Transform>(find.descendant(
          of: find.byType(AppBadgePop),
          matching: find.byType(Transform),
        ))
        .transform
        .storage[0];

    Widget badge(int count, {bool reduceMotion = false}) => host(
          AppBadgePop(value: count, child: Text('$count')),
          reduceMotion: reduceMotion,
        );

    testWidgets('처음에는 튀지 않고, 값이 늘면 커졌다가 제자리로', (tester) async {
      await tester.pumpWidget(badge(1));
      expect(scaleOf(tester), 1.0);
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pumpWidget(badge(2));
      await tester.pump(AppMotion.badgePop ~/ 3);
      expect(scaleOf(tester), greaterThan(1.1));
      await tester.pumpAndSettle();
      expect(scaleOf(tester), closeTo(1.0, 0.001));
    });

    testWidgets('0이 되거나 동작 줄이기면 튀지 않는다', (tester) async {
      await tester.pumpWidget(badge(3));
      await tester.pumpWidget(badge(0));
      await tester.pump(AppMotion.badgePop ~/ 3);
      expect(scaleOf(tester), 1.0);

      await tester.pumpWidget(badge(3, reduceMotion: true));
      await tester.pumpWidget(badge(4, reduceMotion: true));
      await tester.pump(AppMotion.badgePop ~/ 3);
      expect(scaleOf(tester), 1.0);
    });
  });

  group('AppListEntrance', () {
    List<double> opacities(WidgetTester tester, int count) => [
          for (var i = 0; i < count; i++)
            tester
                .widget<FadeTransition>(find.descendant(
                  of: find.byKey(ValueKey('row$i')),
                  matching: find.byType(FadeTransition),
                ))
                .opacity
                .value,
        ];

    Widget list({int count = 12, bool reduceMotion = false, Key? key}) => host(
          AppListEntrance(
            key: key,
            child: ListView.builder(
              itemCount: count,
              itemBuilder: (context, i) => AppListEntranceItem(
                key: ValueKey('row$i'),
                index: i,
                child: SizedBox(height: 40, child: Text('줄 $i')),
              ),
            ),
          ),
          reduceMotion: reduceMotion,
        );

    testWidgets('처음 8줄은 차례로 떠오르고, 9번째부터는 바로 보인다', (tester) async {
      await tester.pumpWidget(list());
      await tester.pump(const Duration(milliseconds: 100));
      final o = opacities(tester, 8);
      // 앞줄이 뒷줄보다 먼저 나타난다.
      expect(o.first, greaterThan(o.last));
      // 앞줄은 아래(12px)에서 올라오는 중이다.
      final firstTop = tester.getTopLeft(find.text('줄 0')).dy;
      // 9번째 줄은 연출 없음 — FadeTransition이 없다.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('row8')),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(opacities(tester, 8), everyElement(1.0));
      expect(tester.getTopLeft(find.text('줄 0')).dy, lessThan(firstTop));
    });

    testWidgets('다시 지어져도 한 번 나온 줄은 다시 연출하지 않는다', (tester) async {
      await tester.pumpWidget(list());
      await tester.pumpAndSettle();
      // 같은 목록을 다시 짓는다(새로고침으로 줄 위젯이 새로 만들어진 경우와 같다).
      await tester.pumpWidget(list(count: 13));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('동작 줄이기면 떠오르지 않고 짧게 겹쳐 나타난다', (tester) async {
      await tester.pumpWidget(list(reduceMotion: true));
      final restTop = tester.getTopLeft(find.text('줄 3')).dy;
      await tester.pump(AppMotion.fade ~/ 2);
      expect(tester.getTopLeft(find.text('줄 3')).dy, restTop);
      await tester.pump(AppMotion.fade);
      expect(opacities(tester, 8), everyElement(1.0));
    });
  });

  group('AppSuccessCheck', () {
    testWidgets('나타나면 success 햅틱 한 번, 다 그리면 알려 준다', (tester) async {
      var completed = 0;
      await tester.pumpWidget(host(
        AppSuccessCheck(onCompleted: () => completed++),
      ));
      await tester.pump();
      expect(heard, [AppHapticKind.success]);
      expect(tester.hasRunningAnimations, isTrue);
      // 시간이 정확히 500ms인 프레임에서는 아직 '끝'이 아니다(Flutter는 초과해야 끝으로 본다).
      await tester.pump(AppMotion.check + const Duration(milliseconds: 20));
      await tester.pump();
      expect(completed, 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('동작 줄이기면 그리지 않고 바로 다 된 모습(진동은 그대로)', (tester) async {
      var completed = 0;
      await tester.pumpWidget(host(
        AppSuccessCheck(onCompleted: () => completed++),
        reduceMotion: true,
      ));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(completed, 1);
      expect(heard, [AppHapticKind.success]);
    });

    testWidgets('haptic: false면 울리지 않고, 화면 낭독기에는 "완료"', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host(const AppSuccessCheck(haptic: false)));
      await tester.pumpAndSettle();
      expect(heard, isEmpty);
      expect(find.bySemanticsLabel('완료'), findsOneWidget);
      semantics.dispose();
    });
  });
}
