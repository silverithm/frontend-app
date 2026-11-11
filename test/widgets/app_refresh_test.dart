import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/utils/app_haptics.dart';
import 'package:frontend_app/widgets/common/app_refresh.dart';

/// 당겨서 새로고침 — 걸리는 순간 impact 햅틱 한 번, 색은 부품이 정한다.
void main() {
  final played = <AppHapticKind>[];

  setUp(() {
    played.clear();
    AppHaptics.enabled.value = true;
    AppHaptics.debugPerformOverride = (kind) async => played.add(kind);
  });

  tearDown(() {
    AppHaptics.debugPerformOverride = null;
  });

  Widget host({required RefreshCallback onRefresh, bool haptic = true}) =>
      MaterialApp(
        home: Scaffold(
          body: AppRefreshIndicator(
            onRefresh: onRefresh,
            haptic: haptic,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80, child: Text('첫 줄')),
                SizedBox(height: 80, child: Text('둘째 줄')),
              ],
            ),
          ),
        ),
      );

  Future<void> pullDown(WidgetTester tester) async {
    await tester.fling(find.text('첫 줄'), const Offset(0, 320), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // 당김이 자리 잡음
    await tester.pump(const Duration(seconds: 1)); // 새로고침 시작
  }

  testWidgets('당김이 걸리면 onRefresh가 불리고 impact가 한 번 울린다', (tester) async {
    var refreshed = 0;
    await tester.pumpWidget(host(onRefresh: () async => refreshed++));

    await pullDown(tester);
    await tester.pumpAndSettle();

    expect(refreshed, 1);
    expect(played, [AppHapticKind.impact]);
  });

  testWidgets('조금만 당기다 놓으면 새로고침도 진동도 없다', (tester) async {
    var refreshed = 0;
    await tester.pumpWidget(host(onRefresh: () async => refreshed++));

    await tester.drag(find.text('첫 줄'), const Offset(0, 20));
    await tester.pumpAndSettle();

    expect(refreshed, 0);
    expect(played, isEmpty);
  });

  testWidgets('haptic: false면 새로고침은 되고 울리지 않는다', (tester) async {
    var refreshed = 0;
    await tester.pumpWidget(
      host(onRefresh: () async => refreshed++, haptic: false),
    );

    await pullDown(tester);
    await tester.pumpAndSettle();

    expect(refreshed, 1);
    expect(played, isEmpty);
  });

  testWidgets('새로고침이 끝날 때까지 동그라미가 남고, 끝나면 사라진다', (tester) async {
    final done = Completer<void>();
    await tester.pumpWidget(host(onRefresh: () => done.future));

    await pullDown(tester);
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);

    done.complete();
    await tester.pumpAndSettle();
    expect(find.byType(RefreshProgressIndicator), findsNothing);
  });

  testWidgets('색은 흰 바탕에 틸 — 화면이 따로 주지 않는다', (tester) async {
    await tester.pumpWidget(host(onRefresh: () async {}));

    final indicator =
        tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    expect(indicator.color, AppSemanticColors.interactivePrimaryDefault);
    expect(indicator.backgroundColor, AppSemanticColors.surfaceCard);
  });
}
