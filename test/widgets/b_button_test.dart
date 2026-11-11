import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/widgets/common/app_pressable.dart';
import 'package:frontend_app/widgets/seed/seed_button.dart';

/// B안 단추 — 큰 54·보통 48·작은 40, 모서리 14, 눌리면 짙어지고 0.97, 터치 48 이상.
void main() {
  Widget host(Widget child, {double textScale = 1.0}) => MaterialApp(
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: c!,
        ),
        // 세로 제약이 없는 자리(목록·Column)에 놓인 단추 — 실제로 쓰는 모양
        home: Scaffold(
          body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [child]),
          ),
        ),
      );

  BoxDecoration surfaceOf(WidgetTester tester) => tester
      .widget<AnimatedContainer>(find.descendant(
        of: find.byType(SeedButton),
        matching: find.byType(AnimatedContainer),
      ))
      .decoration! as BoxDecoration;

  for (final (size, height) in [
    (SeedButtonSize.large, 54.0),
    (SeedButtonSize.medium, 48.0),
    (SeedButtonSize.small, 40.0),
  ]) {
    testWidgets('${size.name}: 보이는 높이 $height, 터치는 48 이상', (tester) async {
      await tester.pumpWidget(host(SeedButton(label: '승인', size: size, onPressed: () {})));
      final surface = find.descendant(
        of: find.byType(SeedButton),
        matching: find.byType(AnimatedContainer),
      );
      expect(tester.getSize(surface).height, height);
      expect(tester.getSize(find.byType(SeedButton)).height, greaterThanOrEqualTo(48));
    });
  }

  testWidgets('주 단추는 틸, 누르면 짙은 틸', (tester) async {
    await tester.pumpWidget(host(SeedButton(label: '신청하기', onPressed: () {})));
    expect(surfaceOf(tester).color, AppSemanticColors.brandDefault);
    expect(surfaceOf(tester).borderRadius, BorderRadius.circular(14));
    final g = await tester.startGesture(tester.getCenter(find.text('신청하기')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(surfaceOf(tester).color, AppSemanticColors.brandPressed);
    await g.up();
    await tester.pumpAndSettle();
    expect(surfaceOf(tester).color, AppSemanticColors.brandDefault);
  });

  testWidgets('위험 단추는 #C8281E(흰 글자 4.5:1 이상), 보조 단추는 회색 바탕', (tester) async {
    await tester.pumpWidget(host(SeedButton(
      label: '반려',
      variant: SeedButtonVariant.critical,
      onPressed: () {},
    )));
    expect(surfaceOf(tester).color, AppSemanticColors.dangerDefault);
    await tester.pumpWidget(host(SeedButton(
      label: '취소',
      variant: SeedButtonVariant.neutralWeak,
      onPressed: () {},
    )));
    expect(surfaceOf(tester).color, AppSemanticColors.fillDefault);
    expect(surfaceOf(tester).border, isNull);
  });

  testWidgets('화면 낭독기에는 버튼으로 읽히고, 꺼진 단추는 누를 수 없다', (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(host(SeedButton(label: '저장', onPressed: () => taps++)));
    expect(
      tester.getSemantics(find.descendant(
        of: find.byType(SeedButton),
        matching: find.byType(AppPressable),
      )),
      matchesSemantics(
        label: '저장',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await tester.pumpWidget(host(SeedButton(label: '저장', isDisabled: true, onPressed: () => taps++)));
    await tester.tap(find.text('저장'), warnIfMissed: false);
    expect(taps, 0);
    semantics.dispose();
  });

  testWidgets('글자 1.6배에서도 넘치지 않는다(좁은 두 단추 줄)', (tester) async {
    await tester.pumpWidget(host(
      SizedBox(
        width: 328,
        child: Row(children: [
          Expanded(child: SeedButton(label: '취소', variant: SeedButtonVariant.neutralWeak, size: SeedButtonSize.large, onPressed: () {})),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: SeedButton(label: '그래도 신청', size: SeedButtonSize.large, onPressed: () {})),
        ]),
      ),
      textScale: 1.6,
    ));
    expect(tester.takeException(), isNull);
  });
}
