import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_app/main.dart' as app;

/// 추가 검토 캡처 — 배차관리와 결재 상세(공문).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const email = String.fromEnvironment('SHOT_EMAIL');
  const password = String.fromEnvironment('SHOT_PASSWORD');

  Future<void> settle(WidgetTester tester, {double seconds = 4}) async {
    final end = DateTime.now().add(
      Duration(milliseconds: (seconds * 1000).round()),
    );
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<bool> waitForText(WidgetTester tester, String text,
      {int maxSeconds = 30}) async {
    final end = DateTime.now().add(Duration(seconds: maxSeconds));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (find.text(text).evaluate().isNotEmpty) return true;
    }
    return false;
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 300));
    debugPrint('[SHOT] $name');
    await settle(tester, seconds: 6);
  }

  testWidgets('배차·결재상세 캡처', (tester) async {
    app.main();
    final loginShown = await waitForText(tester, '로그인', maxSeconds: 40);
    expect(loginShown, isTrue);
    await settle(tester, seconds: 1);

    final adminToggle = find.text('관리자');
    if (adminToggle.evaluate().isNotEmpty) {
      await tester.tap(adminToggle.first);
      await settle(tester, seconds: 1);
    }
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), email);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(fields.at(1), password);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('로그인').last);
    await waitForText(tester, '전자결재', maxSeconds: 25);
    await settle(tester, seconds: 3);

    // 오늘 일정 팝업이 뜨면 닫는다
    final closeBtn = find.text('닫기');
    if (closeBtn.evaluate().isNotEmpty) {
      await tester.tap(closeBtn.first, warnIfMissed: false);
      await settle(tester, seconds: 1);
    }

    // 전체 탭 → 배차관리
    await tester.tap(find.text('전체').last, warnIfMissed: false);
    await settle(tester, seconds: 2);
    final dispatch = find.text('배차관리');
    if (dispatch.evaluate().isNotEmpty) {
      await tester.tap(dispatch.first, warnIfMissed: false);
      await settle(tester, seconds: 5);
      await shot(tester, '11_dispatch');

      // 배차 설정 진입점이 보이면 이어서
      final settings = find.text('배차 설정');
      if (settings.evaluate().isNotEmpty) {
        await tester.tap(settings.first, warnIfMissed: false);
        await settle(tester, seconds: 4);
        await shot(tester, '12_dispatch_settings');
        await tester.pageBack();
        await settle(tester, seconds: 2);
      }
      await tester.pageBack();
      await settle(tester, seconds: 2);
    }

    // 전자결재 탭(관리자는 결재 관리 기본) → 첫 문서 상세
    await tester.tap(find.text('전자결재').last, warnIfMissed: false);
    await settle(tester, seconds: 4);
    final firstDoc = find.text('어르신 위생용품 구매 신청');
    if (firstDoc.evaluate().isNotEmpty) {
      await tester.tap(firstDoc.first, warnIfMissed: false);
      await settle(tester, seconds: 5);
      await shot(tester, '13_approval_detail');
    }
  }, timeout: const Timeout(Duration(minutes: 6)));
}
