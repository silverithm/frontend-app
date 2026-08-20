import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_app/main.dart' as app;

/// 휴무 제한 초과 경고 검증 캡처 — 직원 계정으로 한도가 가득 찬 날짜(8/22)에
/// 신청을 시도해 제한 표시와 사전 차단 경고를 찍는다.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const username = String.fromEnvironment('SHOT_EMAIL');
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

  testWidgets('휴무 제한 경고 캡처', (tester) async {
    app.main();
    final loginShown = await waitForText(tester, '로그인', maxSeconds: 40);
    expect(loginShown, isTrue);
    await settle(tester, seconds: 1);

    // 직원 로그인
    final staffToggle = find.text('직원');
    if (staffToggle.evaluate().isNotEmpty) {
      await tester.tap(staffToggle.first);
      await settle(tester, seconds: 1);
    }
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), username);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(fields.at(1), password);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('로그인').last);
    await waitForText(tester, '전자결재', maxSeconds: 25);
    await settle(tester, seconds: 3);

    // 오늘 일정 팝업 닫기
    final closeBtn = find.text('닫기');
    if (closeBtn.evaluate().isNotEmpty) {
      await tester.tap(closeBtn.first, warnIfMissed: false);
      await settle(tester, seconds: 1);
    }

    // 일정 탭 → 근무조정 → 22일 선택
    await tester.tap(find.text('일정').last, warnIfMissed: false);
    await settle(tester, seconds: 4);
    final day22 = find.text('22');
    if (day22.evaluate().isNotEmpty) {
      await tester.tap(day22.first, warnIfMissed: false);
      await settle(tester, seconds: 3);
    }

    // 휴무 추가 → 신청 폼 (제한 1/1 표시)
    final fab = find.byType(FloatingActionButton);
    expect(fab.evaluate().isNotEmpty, isTrue);
    await tester.tap(fab.first, warnIfMissed: false);
    await settle(tester, seconds: 4);
    await shot(tester, '14_vacation_form_full');

    // 신청 시도 → 사전 차단 경고
    final submit = find.text('신청하기');
    final submitAlt = find.text('신청');
    final target = submit.evaluate().isNotEmpty
        ? submit
        : (submitAlt.evaluate().isNotEmpty ? submitAlt : null);
    if (target != null) {
      // 스크롤해서 버튼을 보이게
      await tester.ensureVisible(target.last);
      await settle(tester, seconds: 1);
      await tester.tap(target.last, warnIfMissed: false);
      await settle(tester, seconds: 3);
      await shot(tester, '15_vacation_limit_alert');
    }
  }, timeout: const Timeout(Duration(minutes: 6)));
}
