import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_app/main.dart' as app;

/// 12번(재설치 후 자동로그인) 확인 — 두 번에 나눠 돈다.
///  PHASE=login : 체험 관리자로 로그인하고 홈이 뜨는 것까지 본다.
///  (호스트가 여기서 앱을 지우고 다시 설치한다)
///  PHASE=check : 아무것도 입력하지 않고 기다린다 — 로그인 화면 없이 홈(체험 관리자)이
///               뜨면 [RESULT12] autologin=true.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('PHASE');
  const email = String.fromEnvironment('SHOT_EMAIL');
  const password = String.fromEnvironment('SHOT_PASSWORD');

  Future<bool> waitFor(WidgetTester tester, Finder finder, {int maxSeconds = 30}) async {
    final end = DateTime.now().add(Duration(seconds: maxSeconds));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (finder.evaluate().isNotEmpty) return true;
    }
    return false;
  }

  Future<void> settle(WidgetTester tester, double seconds) async {
    final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  testWidgets('재설치 후 자동로그인 ($phase)', (tester) async {
    app.main();
    final either = find.byWidgetPredicate(
        (w) => w is Text && (w.data == '로그인' || w.data == '전자결재'));
    expect(await waitFor(tester, either, maxSeconds: 180), isTrue);
    await settle(tester, 3);

    if (phase == 'login') {
      if (find.text('전자결재').evaluate().isEmpty) {
        final adminToggle = find.text('관리자');
        if (adminToggle.evaluate().isNotEmpty) {
          await tester.tap(adminToggle.first);
          await settle(tester, 1);
        }
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), email);
        await tester.enterText(fields.at(1), password);
        FocusManager.instance.primaryFocus?.unfocus();
        await settle(tester, 1.5);
        await tester.ensureVisible(find.text('로그인').last);
        await tester.tap(find.text('로그인').last);
      }
      final home = await waitFor(tester, find.textContaining('체험 관리자'), maxSeconds: 40);
      expect(home, isTrue, reason: '체험 관리자로만 돈다');
      await settle(tester, 5); // 저장(SharedPreferences·Keychain)이 끝날 시간
      debugPrint('[SHOT] 70_ios_logged_in');
      await settle(tester, 3);
      debugPrint('[RESULT12] login=ok');
    } else {
      final loginShown = find.text('로그인').evaluate().isNotEmpty &&
          find.text('전자결재').evaluate().isEmpty;
      final home = await waitFor(tester, find.textContaining('체험 관리자'), maxSeconds: 40);
      debugPrint('[SHOT] 71_ios_after_reinstall');
      await settle(tester, 3);
      debugPrint('[RESULT12] autologin=${home && !loginShown} loginShown=$loginShown');
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
