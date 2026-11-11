import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/utils/app_haptics.dart';
import 'package:frontend_app/widgets/common/app_segmented_tabs.dart';

/// B안 나눔 조절(구간 탭) — TabBar 자리에 그대로 들어가고, 다른 칸을 누를 때만 selection 햅틱,
/// TabBarView를 쓸면 흰 칸이 따라가고, 글자를 키워도 넘치지 않는다.
void main() {
  Widget host({
    int badge = 0,
    bool reduceMotion = false,
    double textScale = 1,
    ValueChanged<TabController>? onController,
  }) =>
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: DefaultTabController(
            length: 2,
            child: Builder(
              builder: (context) {
                final controller = DefaultTabController.of(context);
                onController?.call(controller);
                return Scaffold(
                  body: Column(
                    children: [
                      AppSegmentedTabs(
                        controller: controller,
                        tabs: [
                          const AppSegmentedTab('결재 신청'),
                          AppSegmentedTab('결재 관리', badgeCount: badge),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: controller,
                          children: const [
                            Center(child: Text('첫째 내용')),
                            Center(child: Text('둘째 내용')),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

  List<AppHapticKind> listenHaptics() {
    final heard = <AppHapticKind>[];
    AppHaptics.debugPerformOverride = (k) async => heard.add(k);
    addTearDown(() => AppHaptics.debugPerformOverride = null);
    return heard;
  }

  testWidgets('다른 칸을 누르면 바뀌고 selection 햅틱이 한 번 울린다', (tester) async {
    final heard = listenHaptics();
    late TabController controller;
    await tester.pumpWidget(host(onController: (c) => controller = c));
    expect(controller.index, 0);

    await tester.tap(find.text('결재 관리'));
    await tester.pumpAndSettle();
    expect(controller.index, 1);
    expect(find.text('둘째 내용'), findsOneWidget);
    expect(heard, [AppHapticKind.selection]);

    // 같은 칸을 다시 눌러도 울리지 않는다
    await tester.tap(find.text('결재 관리'));
    await tester.pumpAndSettle();
    expect(heard, [AppHapticKind.selection]);
  });

  testWidgets('고른 칸은 selected로 읽히고, 배지 건수도 같이 읽힌다', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(badge: 3));
    expect(
      tester.getSemantics(find.bySemanticsLabel('결재 신청')),
      matchesSemantics(
        label: '결재 신청',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    expect(find.bySemanticsLabel('결재 관리, 3건'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('배지는 0이면 없고 99를 넘으면 99+', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('0'), findsNothing);
    await tester.pumpWidget(host(badge: 120));
    await tester.pump();
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('내용을 옆으로 쓸면 조절도 따라 바뀐다', (tester) async {
    late TabController controller;
    await tester.pumpWidget(host(onController: (c) => controller = c));
    await tester.fling(find.text('첫째 내용'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(controller.index, 1);
    final semantics = tester.ensureSemantics();
    await tester.pump();
    expect(
      tester.getSemantics(find.bySemanticsLabel('결재 관리')),
      matchesSemantics(
        label: '결재 관리',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets("'동작 줄이기'면 미끄러지지 않고 바로 바뀐다", (tester) async {
    late TabController controller;
    await tester.pumpWidget(
      host(reduceMotion: true, onController: (c) => controller = c),
    );
    await tester.tap(find.text('결재 관리'));
    await tester.pump();
    expect(controller.index, 1);
    expect(controller.indexIsChanging, isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('글자를 1.3배로 키워도 넘치지 않고, 기본 높이는 defaultHeight', (tester) async {
    await tester.pumpWidget(host());
    expect(
      tester.getSize(find.byType(AppSegmentedTabs)).height,
      AppSegmentedTabs.defaultHeight,
    );
    await tester.pumpWidget(host(textScale: 1.3, badge: 12));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(AppSegmentedTabs)).height,
      greaterThanOrEqualTo(AppSegmentedTabs.defaultHeight),
    );
  });
}
