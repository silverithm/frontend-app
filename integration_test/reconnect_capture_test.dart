import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_app/main.dart' as app;

/// 끊김·재접속 검증 캡처. 호스트가 [STEP] 마커를 보고 기기 네트워크를 끄고 켠다.
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

  Future<bool> waitFor(WidgetTester tester, Finder f, {int maxSeconds = 30}) async {
    final end = DateTime.now().add(Duration(seconds: maxSeconds));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (f.evaluate().isNotEmpty) return true;
    }
    return false;
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester, seconds: 1);
    debugPrint('[SHOT] $name');
    await settle(tester, seconds: 4);
  }

  void banner() {
    for (final t in ['다시 연결하는 중', '네트워크 상태를 확인해주세요', '로그인이 만료']) {
      debugPrint('[INFO] 배너 "$t": ${find.textContaining(t).evaluate().isNotEmpty}');
    }
  }

  testWidgets('끊김 재접속 캡처', (tester) async {
    app.main();
    final either = find.byWidgetPredicate((w) => w is Text && (w.data == '로그인' || w.data == '전자결재'));
    expect(await waitFor(tester, either, maxSeconds: 180), isTrue);
    await settle(tester, seconds: 1);
    if (find.text('전자결재').evaluate().isEmpty) {
      final adminToggle = find.text('관리자');
      if (adminToggle.evaluate().isNotEmpty) { await tester.tap(adminToggle.first); await settle(tester, seconds: 1); }
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), email);
      await tester.enterText(fields.at(1), password);
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester, seconds: 1.5);
      await tester.ensureVisible(find.text('로그인').last);
      await tester.tap(find.text('로그인').last);
      await waitFor(tester, find.text('전자결재'), maxSeconds: 25);
    }
    await settle(tester, seconds: 4);
    expect(await waitFor(tester, find.textContaining('체험 관리자'), maxSeconds: 20), isTrue, reason: '체험 계정만');
    final close = find.text('닫기');
    if (close.evaluate().isNotEmpty) { await tester.tap(close.first, warnIfMissed: false); await settle(tester, seconds: 2); }

    await tester.tap(find.text('채팅').last, warnIfMissed: false);
    await settle(tester, seconds: 3);
    await tester.tap(find.text('전체 공지방').first, warnIfMissed: false);
    await settle(tester, seconds: 6);
    await shot(tester, '70_connected'); banner();

    debugPrint('[STEP] offline');
    await settle(tester, seconds: 15);
    await shot(tester, '71_offline_short'); banner();

    debugPrint('[STEP] online');
    await settle(tester, seconds: 20);
    await shot(tester, '72_back_online'); banner();
    debugPrint('[INFO] 놓친 메시지 보임: ${find.textContaining('[오프라인 중 보냄]').evaluate().isNotEmpty}');

    debugPrint('[STEP] offline');
    await settle(tester, seconds: 75);
    await shot(tester, '73_offline_long'); banner();

    debugPrint('[STEP] online');
    final onlineAt = DateTime.now();
    for (var i = 0; i < 12; i++) {
      await settle(tester, seconds: 5);
      final gone = find.textContaining('네트워크 상태를 확인해주세요').evaluate().isEmpty &&
          find.textContaining('다시 연결하는 중').evaluate().isEmpty;
      if (gone) {
        debugPrint('[INFO] 네트워크 복귀 후 배너 사라짐: ${DateTime.now().difference(onlineAt).inSeconds}초');
        break;
      }
    }
    await shot(tester, '74_recovered'); banner();
    debugPrint('[DONE]');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
