import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/widgets/approval/signature_pad.dart';

/// 서명 칸 위에서 시작한 손가락은 무조건 서명이어야 한다.
///
/// 서명 칸이 무엇 안에 들어 있느냐에 따라 획이 통째로 사라졌다 —
/// 세로 스크롤 화면과 결재 시트에서는 세로 획을 스크롤·시트 내리기가 가져갔고,
/// iOS에서 화면 왼쪽 끝부터 그은 가로 획은 '밀어서 뒤로가기'가 가져갔다
/// ("앱에서 서명 작성 시 가로 획 작성이 안됨" 제보).
void main() {
  late SignaturePadController controller;

  setUp(() => controller = SignaturePadController());

  Widget pad() => SignaturePad(controller: controller, height: 180);

  /// 손가락으로 긋듯 여러 번 나눠 민다 (한 번에 밀면 실제 입력과 다르다)
  Future<void> stroke(WidgetTester tester, Offset from, Offset total) async {
    final gesture = await tester.startGesture(from);
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(total / 10);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  /// 서명 칸 안쪽 한 점 — 칸은 패드 위쪽에 있고 아래는 '지우기' 버튼이다
  Offset canvasPoint(WidgetTester tester, {double dx = 40}) =>
      tester.getRect(find.byType(SignaturePad)).topLeft + Offset(dx, 40);

  Future<void> expectStroke(
    WidgetTester tester,
    String what,
    Offset from,
    Offset total,
  ) async {
    controller.clear();
    await tester.pump();
    await stroke(tester, from, total);
    expect(controller.isEmpty, isFalse, reason: '$what 획이 기록되지 않았다');
  }

  testWidgets('아무것도 감싸지 않은 화면 — 가로·세로 모두 그려진다', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: pad())));

    await expectStroke(tester, '가로', canvasPoint(tester), const Offset(120, 0));
    await expectStroke(tester, '세로', canvasPoint(tester), const Offset(0, 60));
  });

  testWidgets('세로 스크롤 화면 안(내 서명 관리) — 세로 획을 스크롤에 뺏기지 않는다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(children: [
            const SizedBox(height: 400),
            pad(),
            const SizedBox(height: 900),
          ]),
        ),
      ),
    ));

    await expectStroke(tester, '가로', canvasPoint(tester), const Offset(120, 0));
    await expectStroke(tester, '세로', canvasPoint(tester), const Offset(0, 60));
  });

  testWidgets('모달 시트 안(결재·회의록 서명) — 세로 획을 시트 내리기에 뺏기지 않는다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: pad(),
                ),
              ),
              child: const Text('서명하기'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('서명하기'));
    await tester.pumpAndSettle();

    await expectStroke(tester, '가로', canvasPoint(tester), const Offset(120, 0));
    await expectStroke(tester, '세로', canvasPoint(tester), const Offset(0, 50));
  });

  testWidgets('iOS 밀어서 뒤로가기 화면 — 왼쪽 끝에서 시작한 가로 획도 그려진다', (tester) async {
    // 테스트 본문이 끝나기 전에 되돌려야 한다 — 프레임워크가 본문 종료 직후에 검사한다
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => Scaffold(body: pad())),
                ),
                child: const Text('서명 화면으로'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('서명 화면으로'));
      await tester.pumpAndSettle();

      // 뒤로가기 제스처가 잡는 자리(화면 왼쪽 20px 안쪽)에서 시작한다
      await expectStroke(
        tester,
        'iOS 왼쪽 끝 가로',
        canvasPoint(tester, dx: 4),
        const Offset(120, 0),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
