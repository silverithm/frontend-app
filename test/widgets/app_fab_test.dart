import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/utils/app_haptics.dart';
import 'package:frontend_app/widgets/common/app_fab.dart';

/// B안 알약 FAB — 높이 56, 접으면 동그라미만, 누르면 impact, 접혀도 이름을 읽는다.
void main() {
  Widget host({bool collapsed = false, VoidCallback? onPressed}) => MaterialApp(
        home: Scaffold(
          floatingActionButton: AppFab(
            icon: Icons.add,
            label: '휴무 신청',
            collapsed: collapsed,
            onPressed: onPressed ?? () {},
          ),
        ),
      );

  testWidgets('펼침 → 접힘: 폭이 줄고 이름은 그대로 읽힌다', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host());
    final wide = tester.getSize(find.byType(AppFab));
    expect(wide.height, 56);
    expect(find.text('휴무 신청'), findsOneWidget);
    await tester.pumpWidget(host(collapsed: true));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AppFab)).width, lessThan(wide.width));
    expect(tester.getSize(find.byType(AppFab)).width, 56);
    expect(find.bySemanticsLabel('휴무 신청'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets("'동작 줄이기'면 접힐 때 오류 없이 바로 바뀐다", (tester) async {
    // 예전에는 AnimatedSize에 0초를 줘서 접히는 순간
    // 'RenderAnimatedSize was mutated in its own performLayout'이 났다.
    Widget reduced({required bool collapsed}) => MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: host(collapsed: collapsed),
        );
    await tester.pumpWidget(reduced(collapsed: false));
    final wide = tester.getSize(find.byType(AppFab));
    expect(find.text('휴무 신청'), findsOneWidget);

    await tester.pumpWidget(reduced(collapsed: true));
    await tester.pump();
    expect(tester.takeException(), isNull);
    // 글자는 한 프레임에 바로 사라진다(크기 연출 없음)
    expect(find.text('휴무 신청'), findsNothing);
    expect(find.byType(AnimatedSize), findsNothing);
    // 오른쪽 여백(20 → 16)만 누름 시간만큼 따라온다
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getSize(find.byType(AppFab)).width, 56);

    await tester.pumpWidget(reduced(collapsed: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AppFab)).width, wide.width);
  });

  testWidgets('누르면 impact 햅틱', (tester) async {
    final heard = <AppHapticKind>[];
    AppHaptics.debugPerformOverride = (k) async => heard.add(k);
    addTearDown(() => AppHaptics.debugPerformOverride = null);
    var taps = 0;
    await tester.pumpWidget(host(onPressed: () => taps++));
    await tester.tap(find.byType(AppFab));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(heard, [AppHapticKind.impact]);
  });
}
