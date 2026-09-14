import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/widgets/common/app_action_sheet.dart';

/// 채팅방 ⋮ 메뉴 같은 액션 시트가 작은 폰(360×640)에서 넘치지 않는다.
///
/// 기본 바텀시트는 화면의 9/16까지만 커지는데, 제목 + 항목 다섯 개면 그보다 길어 마지막
/// 항목이 잘렸다(360dp 기기 캡처에서 8px 넘침). 글자를 크게 해 둔 분은 더 많이 잘린다.
void main() {
  Future<void> openSheet(WidgetTester tester, {double textScale = 1.0}) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(bottom: 72); // 제스처 바 24dp
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showAppActionSheet(
                  context,
                  title: '전체 공지방',
                  actions: [
                    for (final label in ['채팅방 정보', '대화 내용 검색', '주고받은 파일', '알림 끄기', '채팅방 나가기'])
                      AppSheetAction(icon: Icons.info_outline, label: label, onSelected: () {}),
                  ],
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
  }

  testWidgets('360×640에서 제목과 항목 다섯 개가 넘치지 않고 마지막 항목에 닿는다', (tester) async {
    await openSheet(tester);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('채팅방 나가기'), 50,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('채팅방 나가기').hitTestable(), findsOneWidget);
  });

  testWidgets('글자를 가장 크게 해도 넘치지 않고 마지막 항목에 닿는다', (tester) async {
    await openSheet(tester, textScale: 1.6);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('채팅방 나가기'), 50,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('채팅방 나가기').hitTestable(), findsOneWidget);
  });
}
