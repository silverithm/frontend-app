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
