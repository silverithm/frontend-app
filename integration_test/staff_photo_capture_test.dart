
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_app/main.dart' as app;

/// 채팅 사진을 사진첩(케어브이 앨범)에 저장하는 흐름만 찍는다.
/// 체험 계정(company 153)으로만 실행한다 — 아니면 즉시 멈춘다.
///
/// 실행: flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/dispatch_move_capture_test.dart \
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
    debugPrint('[STEP] $name');
    await settle(tester, seconds: 1.5);
    debugPrint('[SHOT] $name');
    await settle(tester, seconds: 4);
  }

  testWidgets('직원 탭 내 사진 캡처', (tester) async {
    app.main();
    var step = 'start';
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString().split('\n').first;
      debugPrint('[ERROR@$step] $text');
      if (!text.contains('overflowed')) original?.call(details);
    };

    // ===================== 로그인 (이미 자동 로그인됐으면 건너뛴다) =====================
    step = 'login';
    final either = find.byWidgetPredicate(
        (w) => w is Text && (w.data == '로그인' || w.data == '전자결재'));
    expect(await waitFor(tester, either, maxSeconds: 180), isTrue);
    await settle(tester, seconds: 1);
    final autoLoggedIn = find.text('전자결재').evaluate().isNotEmpty;
    debugPrint('[INFO] 자동 로그인: $autoLoggedIn');
    if (!autoLoggedIn) {
      final adminToggle = find.text('관리자');
      if (adminToggle.evaluate().isNotEmpty) {
        await tester.tap(adminToggle.first);
        await settle(tester, seconds: 1);
      }
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), email);
      await tester.enterText(fields.at(1), password);
      await tester.pump(const Duration(milliseconds: 300));
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester, seconds: 1.5);
      await tester.ensureVisible(find.text('로그인').last);
      await settle(tester, seconds: 0.5);
      await tester.tap(find.text('로그인').last);
      await waitFor(tester, find.text('전자결재'), maxSeconds: 25);
    }
    await settle(tester, seconds: 5);
    expect(find.textContaining('체험 관리자').evaluate().isNotEmpty, isTrue, reason: '체험 계정만');
    final close = find.text('닫기');
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close.first, warnIfMissed: false);
      await settle(tester, seconds: 2);
    }

    // ===================== 채팅 → 직원 탭 =====================
    step = 'staff_tab';
    await tester.tap(find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('채팅')).last,
        warnIfMissed: false);
    await settle(tester, seconds: 3);
    await tester.tap(find.text('직원').last, warnIfMissed: false);
    await settle(tester, seconds: 6);
    await shot(tester, '40_before_upload');

    // 다른 곳(웹)에서 관리자 사진을 올린 상황을 만든다 — 호스트가 이 표시를 보고 올린다
    step = 'upload';
    debugPrint('[STEP] upload_photo');
    await settle(tester, seconds: 15);

    // 앱은 아직 옛 정보를 들고 있다. 당겨서 새로고침하면 자동 로그인 때와 같은 갱신 함수가 돈다
    step = 'refresh';
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 400), warnIfMissed: false);
    await settle(tester, seconds: 6);
    await shot(tester, '41_after_refresh');

    FlutterError.onError = original;
    debugPrint('[DONE]');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
