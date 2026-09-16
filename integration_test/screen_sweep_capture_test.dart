import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_app/main.dart' as app;

/// 디자인 검토용 화면 일주 캡처 — 하단 탭 4개, 홈 진입점, 메뉴의 모든 항목을 차례로 열어 찍는다.
/// 체험 계정(company 153)으로만 실행한다.
///
/// 실행: flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/screen_sweep_capture_test.dart \
///   --dart-define=SHOT_EMAIL=... --dart-define=SHOT_PASSWORD=... --dart-define=SHOT_MODE=true -d [device]
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
    await settle(tester, seconds: 2);
    debugPrint('[SHOT] $name');
    await settle(tester, seconds: 3.5);
  }

  testWidgets('화면 일주 캡처', (tester) async {
    app.main();
    var step = 'start';
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString().split('\n').first;
      debugPrint('[ERROR@$step] $text');
      if (!text.contains('overflowed')) original?.call(details);
    };

    // ===================== 로그인 =====================
    step = 'login';
    final either = find.byWidgetPredicate(
        (w) => w is Text && (w.data == '로그인' || w.data == '전자결재'));
    expect(await waitFor(tester, either, maxSeconds: 180), isTrue);
    await settle(tester, seconds: 1);
    if (find.text('전자결재').evaluate().isEmpty) {
      await shot(tester, '00_login');
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
    await settle(tester, seconds: 4);
    final isDemo = await waitFor(tester, find.textContaining('체험 관리자'), maxSeconds: 20);
    expect(isDemo, isTrue, reason: '체험 계정(체험 관리자)으로만 캡처한다 — company 153이 아니면 중단');
    final close = find.text('닫기');
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close.first, warnIfMissed: false);
      await settle(tester, seconds: 2);
    }

    Finder navTab(String label) => find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.text(label),
        );

    Future<void> tapNav(String label) async {
      await tester.tap(navTab(label).last, warnIfMissed: false);
      await settle(tester, seconds: 3);
    }

    /// 푸시된 화면을 메인(하단 탭이 보이는 상태)까지 모두 닫는다
    Future<void> popToMain() async {
      for (var i = 0; i < 6; i++) {
        if (find.byType(BottomNavigationBar).evaluate().isNotEmpty &&
            find.byType(BottomSheet).evaluate().isEmpty &&
            find.byType(Dialog).evaluate().isEmpty &&
            find.byType(AlertDialog).evaluate().isEmpty) {
          return;
        }
        await tester.binding.handlePopRoute();
        await settle(tester, seconds: 1.2);
      }
    }

    /// 메뉴 탭의 항목을 스크롤해 찾아 연다. 없으면 false.
    Future<bool> openMenuItem(String label) async {
      await tapNav('전체');
      final item = find.text(label);
      // 맨 위로
      await tester.drag(find.byType(Scrollable).last, const Offset(0, 2000), warnIfMissed: false);
      await settle(tester, seconds: 0.6);
      for (var i = 0; i < 14 && item.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -320), warnIfMissed: false);
        await settle(tester, seconds: 0.6);
      }
      if (item.evaluate().isEmpty) {
        debugPrint('[WARN] 메뉴 항목 없음: $label');
        return false;
      }
      await tester.ensureVisible(item.first);
      await settle(tester, seconds: 0.4);
      await tester.tap(item.first, warnIfMissed: false);
      await settle(tester, seconds: 3.5);
      return true;
    }

    // ===================== 하단 탭 =====================
    step = 'tabs';
    await tapNav('홈');
    await shot(tester, '01_home');
    // 홈 아래쪽도 찍는다
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900), warnIfMissed: false);
    await shot(tester, '01b_home_scrolled');

    await tapNav('채팅');
    await shot(tester, '02_chat_list');
    if (await waitFor(tester, find.text('전체 공지방'), maxSeconds: 15)) {
      await tester.tap(find.text('전체 공지방').first, warnIfMissed: false);
      await settle(tester, seconds: 4);
      await shot(tester, '03_chat_room');
      final more = find.byTooltip('더보기');
      if (more.evaluate().isNotEmpty) {
        await tester.tap(more.last, warnIfMissed: false);
        await shot(tester, '03b_chat_room_menu');
        await popToMain();
      }
      await popToMain();
    }

    await tapNav('일정');
    await shot(tester, '04_schedule');

    await tapNav('전자결재');
    await shot(tester, '05_approval');
    // 첫 결재 문서 열기 (있으면)
    final firstDoc = find.byType(ListTile);
    if (firstDoc.evaluate().isNotEmpty) {
      await tester.tap(firstDoc.first, warnIfMissed: false);
      await settle(tester, seconds: 3);
      await shot(tester, '05b_approval_detail');
      await popToMain();
    }

    await tapNav('전체');
    await shot(tester, '06_menu');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -900), warnIfMissed: false);
    await shot(tester, '06b_menu_scrolled');

    // ===================== 메뉴 항목 일주 =====================
    final items = <String, String>{
      '계정 설정': '10_profile',
      '알림 설정': '11_notification_settings',
      '글자 크기': '12_text_size',
      '공지사항': '13_notice_list',
      '케어브이 커뮤니티': '14_plaza',
      '기관 자료실': '15_company_library',
      '어르신 정보': '16_elder_list',
      '회의록': '17_meeting_minutes',
      '내 휴무': '18_my_vacation',
      '결재 서명 관리': '19_signature',
      '회원관리': '20_user_management',
      '휴무 승인': '21_vacation_management',
      '결재 양식 관리': '22_approval_templates',
      '휴무 한도 설정': '23_vacation_limits',
      '고충·건의함 관리': '24_voice_box_admin',
      '고충·신고 · 건의함': '25_voice_box',
      '회사 정보 · 구독': '26_company_settings',
      'AI 글쓰기': '27_ai_writer',
    };
    for (final entry in items.entries) {
      step = entry.value;
      await popToMain();
      if (await openMenuItem(entry.key)) {
        await shot(tester, entry.value);
        // 목록형 화면은 첫 항목도 열어 상세를 한 장 더 찍는다
        if (entry.value == '13_notice_list' || entry.value == '16_elder_list' || entry.value == '17_meeting_minutes') {
          final tile = find.byType(InkWell);
          if (tile.evaluate().length > 2) {
            await tester.tap(tile.at(2), warnIfMissed: false);
            await settle(tester, seconds: 3);
            await shot(tester, '${entry.value}_detail');
          }
        }
      }
      await popToMain();
    }

    FlutterError.onError = original;
    debugPrint('[DONE]');
  }, timeout: const Timeout(Duration(minutes: 20)));
}
