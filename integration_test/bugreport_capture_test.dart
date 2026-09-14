import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_app/main.dart' as app;
import 'package:frontend_app/widgets/chat/chat_image_viewer.dart';

/// 버그제보방 요청 검증 캡처 — 줄바꿈, 날짜로 이동, 긴 공문 한 장 이미지.
/// 체험 계정으로만 실행한다(체험 관리자가 아니면 멈춘다).
///
/// 실행: flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/bugreport_capture_test.dart \
///   --dart-define=SHOT_EMAIL=... --dart-define=SHOT_PASSWORD=... -d <device>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const email = String.fromEnvironment('SHOT_EMAIL');
  const password = String.fromEnvironment('SHOT_PASSWORD');

  Future<void> settle(WidgetTester tester, {double seconds = 3}) async {
    final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<bool> waitFor(WidgetTester tester, Finder finder, {int maxSeconds = 30}) async {
    final end = DateTime.now().add(Duration(seconds: maxSeconds));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (finder.evaluate().isNotEmpty) return true;
    }
    return false;
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester, seconds: 1.5);
    debugPrint('[SHOT] $name');
    await settle(tester, seconds: 4);
  }

  testWidgets('버그제보 요청 캡처', (tester) async {
    app.main();
    final either = find.byWidgetPredicate(
        (w) => w is Text && (w.data == '로그인' || w.data == '전자결재'));
    expect(await waitFor(tester, either, maxSeconds: 180), isTrue);
    await settle(tester, seconds: 1);
    if (find.text('전자결재').evaluate().isEmpty) {
      final adminToggle = find.text('관리자');
      if (adminToggle.evaluate().isNotEmpty) {
        await tester.tap(adminToggle.first);
        await settle(tester, seconds: 1);
      }
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), email);
      await tester.enterText(fields.at(1), password);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('로그인').last);
      await waitFor(tester, find.text('전자결재'), maxSeconds: 25);
    }
    await settle(tester, seconds: 4);
    final isDemo = find.textContaining('체험 관리자').evaluate().isNotEmpty;
    expect(isDemo, isTrue, reason: '체험 계정(체험 관리자)으로만 캡처한다');
    final close = find.text('닫기');
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close.first, warnIfMissed: false);
      await settle(tester, seconds: 2);
    }

    // 채팅방 입장 — 맨 아래에 방금 공유한 긴 공문 이미지·PDF·요약이 있다
    await tester.tap(find.text('채팅').last, warnIfMissed: false);
    await settle(tester, seconds: 3);
    expect(await waitFor(tester, find.text('전체 공지방'), maxSeconds: 20), isTrue);
    await tester.tap(find.text('전체 공지방').first, warnIfMissed: false);
    await settle(tester, seconds: 6);
    await shot(tester, '50_room_bottom');

    // 1) 긴 공문 이미지 — 말풍선을 눌러 크게 보기
    final pdfName = find.textContaining('공문_오전 반차 신청');
    debugPrint('[INFO] 공문 파일 줄 ${pdfName.evaluate().length}개');
    final images = find.byWidgetPredicate((w) => w is Image);
    debugPrint('[INFO] 화면의 Image ${images.evaluate().length}개');
    // 긴 이미지 말풍선: 화면 아래쪽 Image 중 세로로 가장 긴 것
    Element? tallest;
    double best = 0;
    for (final e in images.evaluate()) {
      final box = e.renderObject as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final ratio = box.size.height / (box.size.width == 0 ? 1 : box.size.width);
      if (ratio > best && box.size.height > 60) {
        best = ratio;
        tallest = e;
      }
    }
    if (tallest != null) {
      final box = tallest.renderObject as RenderBox;
      debugPrint('[INFO] 긴 이미지 말풍선 크기 ${box.size}');
      // 말풍선 윗부분이 화면에 들어오게 올린 뒤, 보이는 곳을 누른다
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 300), warnIfMissed: false);
      await settle(tester, seconds: 2);
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      final topLeft = box.localToGlobal(Offset.zero);
      final visibleTop = topLeft.dy.clamp(120.0, screen.height - 200);
      final visibleBottom = (topLeft.dy + box.size.height).clamp(120.0, screen.height - 200);
      final tapPoint = Offset(topLeft.dx + box.size.width / 2, (visibleTop + visibleBottom) / 2);
      debugPrint('[INFO] 누르는 위치 $tapPoint (말풍선 위 ${topLeft.dy}, 아래 ${topLeft.dy + box.size.height})');
      await tester.tapAt(tapPoint);
      await settle(tester, seconds: 2);
      final viewerOpen = find.byType(ChatImageViewer).evaluate().isNotEmpty;
      debugPrint('[INFO] 크게 보기 열림: $viewerOpen');
      await settle(tester, seconds: 6);
      final broken = find.text('사진을 불러오지 못했습니다').evaluate().isNotEmpty;
      debugPrint('[INFO] 크게 보기 깨짐 표시: $broken');
      for (final e in find.descendant(of: find.byType(ChatImageViewer), matching: find.byType(RawImage)).evaluate()) {
        final raw = e.widget as RawImage;
        final box2 = e.renderObject as RenderBox?;
        debugPrint('[INFO] 크게 보기 이미지 디코딩 ${raw.image?.width}x${raw.image?.height}, 화면 표시 ${box2?.size}');
      }
      await shot(tester, '51_viewer');
      if (viewerOpen) {
        // 긴 문서는 끌어서 아래로 내려 읽는다
        await tester.dragFrom(const Offset(180, 500), const Offset(0, -900));
        await settle(tester, seconds: 2);
        await shot(tester, '51b_viewer_scrolled');
        await tester.binding.handlePopRoute();
        await settle(tester, seconds: 2);
      }
    }

    // 2) 줄바꿈 — 엔터가 줄바꿈이고 보내지지 않는다
    final input = find.byType(TextField).last;
    final field = tester.widget<TextField>(input);
    debugPrint('[INFO] 입력창 textInputAction=${field.textInputAction} keyboardType=${field.keyboardType.index} onSubmitted=${field.onSubmitted != null}');
    await tester.tap(input);
    await settle(tester, seconds: 1);
    await tester.enterText(input, '첫 줄입니다');
    await tester.testTextInput.receiveAction(TextInputAction.newline);
    await settle(tester, seconds: 2);
    final afterEnter = tester.widget<TextField>(input).controller?.text;
    debugPrint('[INFO] 엔터 뒤 입력창 내용="$afterEnter" (비었으면 보내진 것)');
    await tester.enterText(input, '첫 줄입니다\n둘째 줄입니다\n셋째 줄');
    await settle(tester, seconds: 1);
    await shot(tester, '52_multiline_input');
    await tester.enterText(input, '');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, seconds: 1);

    // 3) 날짜로 이동 — ⋮ → 대화 내용 검색 → 날짜로 이동
    await tester.tap(find.byTooltip('더보기').last, warnIfMissed: false);
    await settle(tester, seconds: 2);
    await tester.tap(find.text('대화 내용 검색').last, warnIfMissed: false);
    await settle(tester, seconds: 2);
    await shot(tester, '53_search_sheet');
    final dateBtn = find.text('날짜');
    if (dateBtn.evaluate().isNotEmpty) {
      await tester.tap(dateBtn.last, warnIfMissed: false);
      await settle(tester, seconds: 2);
      await shot(tester, '54_date_picker');
      final day = find.text('10');
      if (day.evaluate().isNotEmpty) {
        await tester.tap(day.last, warnIfMissed: false);
        await settle(tester, seconds: 1);
      }
      for (final label in ['확인', 'OK']) {
        final ok = find.text(label);
        if (ok.evaluate().isNotEmpty) {
          await tester.tap(ok.last, warnIfMissed: false);
          break;
        }
      }
      await settle(tester, seconds: 1);
      await shot(tester, '55_date_jump_result');
    }
    debugPrint('[DONE]');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
