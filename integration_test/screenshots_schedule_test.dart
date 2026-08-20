import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_app/main.dart' as app;

/// 일정 등록 구분 체계 검증 캡처 — 커스텀 구분 합류, 고르면 색 자동
/// (색상 줄 숨김), 구분 관리 시트.
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

  testWidgets('일정 구분 캡처', (tester) async {
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

    final closeBtn = find.text('닫기');
    if (closeBtn.evaluate().isNotEmpty) {
      await tester.tap(closeBtn.first, warnIfMissed: false);
      await settle(tester, seconds: 1);
    }

    // 일정 탭 → 월간일정 → 일정 추가
    await tester.tap(find.text('일정').last, warnIfMissed: false);
    await settle(tester, seconds: 3);
    await tester.tap(find.text('월간일정').first, warnIfMissed: false);
    await settle(tester, seconds: 4);
    final fab = find.byType(FloatingActionButton);
    expect(fab.evaluate().isNotEmpty, isTrue);
    await tester.tap(fab.first, warnIfMissed: false);
    await settle(tester, seconds: 4);
    await shot(tester, '16_schedule_form');

    // 일정 구분 드롭다운 열기 → 커스텀 구분(사업) 선택 → 색상 줄 사라짐
    final dropdown = find.byType(DropdownButtonFormField<String>);
    if (dropdown.evaluate().isNotEmpty) {
      await tester.tap(dropdown.first, warnIfMissed: false);
      await settle(tester, seconds: 2);
      await shot(tester, '17_schedule_kind_options');
      final biz = find.text('사업');
      if (biz.evaluate().isNotEmpty) {
        await tester.tap(biz.last, warnIfMissed: false);
        await settle(tester, seconds: 2);
        await shot(tester, '18_schedule_custom_selected');
      } else {
        // 옵션이 안 보이면 닫기
        await tester.tapAt(const Offset(50, 100));
        await settle(tester, seconds: 1);
      }
    }

    // 구분 관리 시트
    final manage = find.text('구분 관리');
    if (manage.evaluate().isNotEmpty) {
      await tester.tap(manage.first, warnIfMissed: false);
      await settle(tester, seconds: 4);
      await shot(tester, '19_kind_manage_sheet');
    }
  }, timeout: const Timeout(Duration(minutes: 6)));
}
