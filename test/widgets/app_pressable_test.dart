import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/theme/app_motion.dart';
import 'package:frontend_app/theme/app_spacing.dart';
import 'package:frontend_app/utils/app_haptics.dart';
import 'package:frontend_app/widgets/common/app_pressable.dart';

/// 누름 감싸개: 탭을 그대로 전달하고, 진짜 탭에서만 햅틱을 울리고, 누르는 동안 0.97로 줄었다
/// 돌아오며, '동작 줄이기'면 줄지 않는다. 스크롤로 넘어가면 탭도 햅틱도 없다.
void main() {
  final heard = <AppHapticKind>[];

  setUp(() {
    heard.clear();
    AppHaptics.enabled.value = true;
    AppHaptics.debugPerformOverride = (kind) async => heard.add(kind);
  });

  tearDown(() {
    AppHaptics.debugPerformOverride = null;
    AppHaptics.enabled.value = true;
  });

  Widget host(Widget child, {bool reduceMotion = false}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }

  double currentScale(WidgetTester tester) {
    final transform = tester.widget<Transform>(
      find.descendant(
        of: find.byType(AppPressable),
        matching: find.byType(Transform),
      ),
    );
    // Transform.scale은 x·y만 바꾼다(z는 1) — x축 배율을 본다.
    return transform.transform.storage[0];
  }

  testWidgets('탭을 전달하고 지정한 햅틱을 한 번 울린다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(AppPressable(
      onTap: () => taps++,
      haptic: AppHapticKind.tap,
      child: const SizedBox(width: 120, height: 60, child: Text('승인')),
    )));

    await tester.tap(find.text('승인'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(heard, [AppHapticKind.tap]);
  });

  testWidgets('햅틱을 정하지 않으면 울리지 않는다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(AppPressable(
      onTap: () => taps++,
      child: const SizedBox(width: 120, height: 60),
    )));
    await tester.tap(find.byType(AppPressable));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(heard, isEmpty);
  });

  testWidgets('진동 반응을 꺼 두면 탭은 되고 햅틱은 없다', (tester) async {
    AppHaptics.enabled.value = false;
    var taps = 0;
    await tester.pumpWidget(host(AppPressable(
      onTap: () => taps++,
      haptic: AppHapticKind.tap,
      child: const SizedBox(width: 120, height: 60),
    )));
    await tester.tap(find.byType(AppPressable));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(heard, isEmpty);
  });

  testWidgets('누르는 동안 0.97로 줄고, 떼면 1로 돌아온다', (tester) async {
    await tester.pumpWidget(host(AppPressable(
      onTap: () {},
      child: const SizedBox(width: 120, height: 60),
    )));
    expect(currentScale(tester), 1.0);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AppPressable)),
    );
    // 탭 인식기의 짧은 대기(kPressTimeout) 뒤에 줄기 시작한다.
    await tester.pump(kPressTimeout);
    await tester.pump(AppMotion.press);
    await tester.pump(const Duration(milliseconds: 20));
    expect(currentScale(tester), closeTo(AppMotion.pressedScale, 0.002));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(currentScale(tester), closeTo(1.0, 0.0001));
  });

  testWidgets('누른 채로 화면이 사라져도 오류 없이 정리된다', (tester) async {
    await tester.pumpWidget(host(AppPressable(
      onTap: () {},
      child: const SizedBox(width: 120, height: 60),
    )));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AppPressable)),
    );
    await tester.pump(kPressTimeout);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    await gesture.up();
  });

  testWidgets('동작 줄이기면 눌러도 크기가 그대로다(탭·햅틱은 된다)', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(
      AppPressable(
        onTap: () => taps++,
        haptic: AppHapticKind.tap,
        child: const SizedBox(width: 120, height: 60),
      ),
      reduceMotion: true,
    ));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AppPressable)),
    );
    await tester.pump(kPressTimeout + AppMotion.press);
    expect(currentScale(tester), 1.0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(heard, [AppHapticKind.tap]);
  });

  testWidgets('목록을 쓸어 올리면 눌림·탭·햅틱이 없다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            for (var i = 0; i < 30; i++)
              AppPressable(
                onTap: () => taps++,
                haptic: AppHapticKind.tap,
                child: SizedBox(height: 64, child: Text('줄 $i')),
              ),
          ],
        ),
      ),
    ));

    await tester.drag(find.text('줄 2'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(taps, 0);
    expect(heard, isEmpty);
  });

  testWidgets('길게 누르면 impact 햅틱과 함께 전달한다', (tester) async {
    var longPresses = 0;
    await tester.pumpWidget(host(AppPressable(
      onLongPress: () => longPresses++,
      child: const SizedBox(width: 120, height: 60),
    )));
    await tester.longPress(find.byType(AppPressable));
    await tester.pumpAndSettle();
    expect(longPresses, 1);
    expect(heard, [AppHapticKind.impact]);
  });

  testWidgets('작은 자식도 터치 영역은 48×48, 넓게 늘이라는 자리는 그대로 늘어난다',
      (tester) async {
    await tester.pumpWidget(host(AppPressable(
      onTap: () {},
      child: const SizedBox(width: 20, height: 20),
    )));
    expect(
      tester.getSize(find.byType(AppPressable)),
      const Size(AppSpacing.space12, AppSpacing.space12),
    );
    // 자식 크기는 그대로(가운데)
    expect(
      tester.getSize(find.byType(SizedBox).last),
      const Size(20, 20),
    );

    // 꽉 채우는 제약(Column stretch)에서 자식이 줄어들지 않는다.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPressable(
                onTap: () {},
                child: Container(height: 72, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    ));
    expect(tester.getSize(find.byType(Container)).width, 300);
    expect(tester.getSize(find.byType(AppPressable)), const Size(300, 72));
  });

  testWidgets('화면 낭독기에는 버튼으로, 누를 수 있게 읽힌다', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(AppPressable(
      onTap: () {},
      semanticLabel: '결재 승인',
      child: const SizedBox(width: 120, height: 60),
    )));
    expect(
      tester.getSemantics(find.byType(AppPressable)),
      matchesSemantics(
        label: '결재 승인',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('키보드로 포커스를 옮겨 Enter로 누를 수 있다', (tester) async {
    var taps = 0;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(host(AppPressable(
      onTap: () => taps++,
      haptic: AppHapticKind.tap,
      focusNode: focusNode,
      child: const SizedBox(width: 120, height: 60),
    )));
    focusNode.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
    expect(heard, [AppHapticKind.tap]);
  });

  testWidgets('누를 곳이 없으면(onTap·onLongPress 없음) 반응하지 않는다', (tester) async {
    await tester.pumpWidget(host(const AppPressable(
      haptic: AppHapticKind.tap,
      child: SizedBox(width: 120, height: 60),
    )));
    await tester.tap(find.byType(AppPressable), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(heard, isEmpty);
    expect(currentScale(tester), 1.0);
  });
}
