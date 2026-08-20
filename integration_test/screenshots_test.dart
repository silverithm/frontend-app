import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_app/main.dart' as app;

/// 검토용 화면 스크린샷 캡처 — 실제 서버(체험 테넌트)에 로그인해
/// 개편된 각 탭 화면을 순서대로 찍는다.
///
/// 실행:
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/screenshots_test.dart \
///   --dart-define=SHOT_EMAIL=... --dart-define=SHOT_PASSWORD=... -d <sim>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const email = String.fromEnvironment('SHOT_EMAIL');
  const password = String.fromEnvironment('SHOT_PASSWORD');

  /// 네트워크·무한 애니메이션이 있어 pumpAndSettle 대신 시간 기반 펌프를 쓴다.
  /// Future.delayed로 실제 시간이 흘러야 main()의 비동기 초기화·네트워크가 진행된다.
  Future<void> settle(WidgetTester tester, {double seconds = 4}) async {
    final end = DateTime.now().add(
      Duration(milliseconds: (seconds * 1000).round()),
    );
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  /// [text]가 화면에 나타날 때까지 최대 [maxSeconds] 기다린다
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

  /// 호스트(simctl)가 캡처할 수 있게 마커를 찍고 화면에 머문다.
  /// iOS의 binding.takeScreenshot은 두 번째 호출부터 불안정해 쓰지 않는다.
  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 300));
    debugPrint('[SHOT] $name');
    await settle(tester, seconds: 6);
  }

  testWidgets('개편 화면 캡처', (tester) async {
    app.main();
    // main()의 비동기 초기화가 끝나고 로그인 화면이 뜰 때까지 기다린다
    final loginShown = await waitForText(tester, '로그인', maxSeconds: 40);
    expect(loginShown, isTrue, reason: '로그인 화면이 40초 안에 뜨지 않았다');
    await settle(tester, seconds: 1);

    await shot(tester, '01_login');

    // 관리자 로그인
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
    // 홈 진입(하단 탭 등장) 대기
    await waitForText(tester, '전자결재', maxSeconds: 25);
    await settle(tester, seconds: 4);
    // 오늘 일정 팝업이 홈을 가리면 닫는다
    final todayClose = find.text('닫기');
    if (todayClose.evaluate().isNotEmpty) {
      await tester.tap(todayClose.first, warnIfMissed: false);
      await settle(tester, seconds: 2);
    }
    await shot(tester, '02_home');

    Future<void> goTab(String label, String name,
        {double wait = 5}) async {
      await tester.tap(find.text(label).last, warnIfMissed: false);
      await settle(tester, seconds: wait);
      await shot(tester, name);
    }

    await goTab('채팅', '03_chat');
    await goTab('일정', '04_schedule_vacation'); // 기본 탭: 근무조정

    // 월간일정 전환
    final monthly = find.text('월간일정');
    if (monthly.evaluate().isNotEmpty) {
      await tester.tap(monthly.first, warnIfMissed: false);
      await settle(tester, seconds: 4);
      await shot(tester, '05_schedule_monthly');
    }

    await goTab('전자결재', '06_approval_submit'); // 기본 탭: 결재 신청

    // 결재 관리 전환
    final manage = find.text('결재 관리');
    if (manage.evaluate().isNotEmpty) {
      await tester.tap(manage.first, warnIfMissed: false);
      await settle(tester, seconds: 5);
      await shot(tester, '07_approval_manage');
    }

    await goTab('전체', '08_menu', wait: 3);

    // 근무조정으로 돌아가 휴무 신청 다이얼로그 (관리자는 액션 시트가 먼저 뜬다)
    await tester.tap(find.text('일정').last, warnIfMissed: false);
    await settle(tester, seconds: 3);
    final vacationTab = find.text('근무조정');
    if (vacationTab.evaluate().isNotEmpty) {
      await tester.tap(vacationTab.first, warnIfMissed: false);
      await settle(tester, seconds: 3);
    }
    final fab = find.byType(FloatingActionButton);
    if (fab.evaluate().isNotEmpty) {
      await tester.tap(fab.first, warnIfMissed: false);
      await settle(tester, seconds: 2);
      await shot(tester, '09_vacation_action');
      // 열린 시트에서 '휴무 추가'가 보이면 이어서 캡처
      final addVacation = find.text('휴무 추가');
      if (addVacation.evaluate().isNotEmpty) {
        await tester.tap(addVacation.first, warnIfMissed: false);
        await settle(tester, seconds: 3);
        await shot(tester, '10_vacation_form');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 6)));
}
