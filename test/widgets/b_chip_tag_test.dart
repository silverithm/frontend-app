import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/utils/app_haptics.dart';
import 'package:frontend_app/widgets/common/app_tag.dart';
import 'package:frontend_app/widgets/seed/seed_chip.dart';

/// B안 칩·꼬리표 — 테두리 없는 알약. 칩은 고르면 틸 + 흰 글자, 44 높이·48 터치, selection 햅틱.
void main() {
  Widget host(Widget child, {double textScale = 1.0}) => MaterialApp(
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: c!,
        ),
        home: Scaffold(
          body: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [child])),
        ),
      );

  BoxDecoration chipDeco(WidgetTester tester) => tester
      .widget<AnimatedContainer>(find.descendant(
        of: find.byType(SeedChip),
        matching: find.byType(AnimatedContainer),
      ))
      .decoration! as BoxDecoration;

  testWidgets('칩: 고르기 전 회색·고르면 틸, 테두리 없음, 높이 36·터치 48, selection 햅틱',
      (tester) async {
    final heard = <AppHapticKind>[];
    AppHaptics.debugPerformOverride = (k) async => heard.add(k);
    addTearDown(() => AppHaptics.debugPerformOverride = null);

    var taps = 0;
    await tester.pumpWidget(host(SeedChip(label: '대기', onTap: () => taps++)));
    expect(chipDeco(tester).color, AppSemanticColors.fillDefault);
    expect(chipDeco(tester).border, isNull);
    expect(
      tester.getSize(find.descendant(
        of: find.byType(SeedChip),
        matching: find.byType(AnimatedContainer),
      )).height,
      36,
    );
    expect(tester.getSize(find.byType(SeedChip)).height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('대기'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(heard, [AppHapticKind.selection]);

    await tester.pumpWidget(host(SeedChip(label: '전체', selected: true, onTap: () {})));
    expect(chipDeco(tester).color, AppSemanticColors.brandDefault);
    expect(tester.widget<Text>(find.text('전체')).style!.color, AppSemanticColors.textInverse);

    await tester.pumpWidget(host(SeedChip(label: '승인', onCanvas: true, onTap: () {})));
    expect(chipDeco(tester).color, AppSemanticColors.surfaceCard);
  });

  testWidgets('칩: 고른 것과 안 고른 것 글자 굵기가 같다', (tester) async {
    await tester.pumpWidget(host(SeedChip(label: '반려', onTap: () {})));
    final off = tester.widget<Text>(find.text('반려')).style!.fontWeight;
    await tester.pumpWidget(host(SeedChip(label: '반려', selected: true, onTap: () {})));
    expect(tester.widget<Text>(find.text('반려')).style!.fontWeight, off);
  });

  testWidgets('꼬리표: 테두리 없는 알약 11/w600, 높이 22 이상, 폭 제한 없는 Row 안에서도 된다',
      (tester) async {
    await tester.pumpWidget(host(const AppTag(label: '승인', tone: AppTagTone.success)));
    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(find.text('승인'));
    expect(text.style!.fontSize, 11);
    expect(text.style!.color, AppSemanticColors.statusSuccessText);
    expect(tester.getSize(find.byType(AppTag)).height, greaterThanOrEqualTo(22));
  });

  testWidgets('글자 1.6배에서도 넘치지 않는다', (tester) async {
    await tester.pumpWidget(host(
      Row(mainAxisSize: MainAxisSize.min, children: [
        SeedChip(label: '내 차례 0', onTap: () {}),
        const AppTag(label: '대기', tone: AppTagTone.warning, icon: Icons.schedule),
      ]),
      textScale: 1.6,
    ));
    expect(tester.takeException(), isNull);
  });
}
