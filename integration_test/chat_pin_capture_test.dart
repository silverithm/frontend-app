import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_app/main.dart' as app;

/// 채팅방 상단 고정 캡처 — 체험 기관(체험 관리자)에서만 돈다.
/// '요양보호사 소통방'을 길게 눌러 상단 고정 → 목록 맨 위로 오는지 →
/// 다시 길게 눌러 고정 해제까지 확인한다.
///
/// 실행: flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/chat_pin_capture_test.dart \
///   --dart-define=SHOT_EMAIL=... --dart-define=SHOT_PASSWORD=... -d <device>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const email = String.fromEnvironment('SHOT_EMAIL');
  const password = String.fromEnvironment('SHOT_PASSWORD');
  const targetRoom = '전체 공지방';

  Future<void> settle(WidgetTester tester, {double seconds = 3}) async {
    final end = DateTime.now().add(
      Duration(milliseconds: (seconds * 1000).round()),
    );
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<bool> waitFor(
    WidgetTester tester,
    Finder finder, {
    int maxSeconds = 30,
  }) async {
    final end = DateTime.now().add(Duration(seconds: maxSeconds));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (finder.evaluate().isNotEmpty) return true;
    }
    return false;
  }

  Future<void> shot(
    WidgetTester tester,
    String name, {
    double before = 1.5,
  }) async {
    debugPrint('[STEP] $name');
    await settle(tester, seconds: before);
    debugPrint('[SHOT] $name');
    await settle(tester, seconds: 3);
  }

  Finder navItem(String label) => find.descendant(
    of: find.byType(BottomNavigationBar),
    matching: find.text(label),
  );

  /// 지금 채팅 목록에 보이는 방 이름을 위에서 아래 순서대로 뽑는다.
  List<String> currentRoomOrder(WidgetTester tester) {
    return find
        .byType(ListView)
        .evaluate()
        .expand((_) => find.byType(Text).evaluate())
        .map((e) => (e.widget as Text).data)
        .whereType<String>()
        .toList();
  }

  testWidgets('채팅방 상단 고정 캡처', (tester) async {
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
      (w) => w is Text && (w.data == '로그인' || w.data == '전자결재'),
    );
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
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester, seconds: 1.5);
      await tester.ensureVisible(find.text('로그인').last);
      await settle(tester, seconds: 0.5);
      await tester.tap(find.text('로그인').last);
      await waitFor(tester, find.text('전자결재'), maxSeconds: 25);
    }
    await settle(tester, seconds: 4);
    final isDemo = await waitFor(
      tester,
      find.textContaining('체험 관리자'),
      maxSeconds: 20,
    );
    expect(isDemo, isTrue, reason: '체험 계정(체험 관리자)으로만 캡처한다');
    for (var i = 0; i < 2; i++) {
      final close = find.text('닫기');
      if (close.evaluate().isNotEmpty) {
        await tester.tap(close.first, warnIfMissed: false);
        await settle(tester, seconds: 2);
      }
    }

    // ===================== 채팅 목록 =====================
    step = 'chat_list';
    await tester.tap(navItem('채팅').last, warnIfMissed: false);
    await settle(tester, seconds: 3);
    final room = find.text(targetRoom);
    expect(
      await waitFor(tester, room, maxSeconds: 20),
      isTrue,
      reason: '체험 기관에 $targetRoom이 있어야 한다',
    );
    await shot(tester, '80_chat_list_before');

    // ===================== 상단 고정 =====================
    step = 'pin';
    await tester.longPress(room.first, warnIfMissed: false);
    await settle(tester, seconds: 2);
    final pinAction = find.text('상단 고정');
    final pinShown = pinAction.evaluate().isNotEmpty;
    debugPrint('[INFO] 상단 고정 메뉴 노출: $pinShown');
    await shot(tester, '81_pin_sheet');
    expect(pinShown, isTrue, reason: '길게 누른 메뉴에 상단 고정 항목이 있어야 한다');
    await tester.tap(pinAction.first, warnIfMissed: false);
    final pinnedToast = await waitFor(
      tester,
      find.textContaining('상단에 고정했어요'),
      maxSeconds: 15,
    );
    debugPrint('[INFO] 고정 완료 안내: $pinnedToast');
    await settle(tester, seconds: 2);

    final orderAfterPin = currentRoomOrder(tester);
    debugPrint('[RESULT] order_after_pin=$orderAfterPin');
    await shot(tester, '82_pinned_top');

    // ===================== 고정 해제 =====================
    step = 'unpin';
    final pinnedRoom = find.text(targetRoom);
    expect(await waitFor(tester, pinnedRoom, maxSeconds: 15), isTrue);
    await tester.longPress(pinnedRoom.first, warnIfMissed: false);
    await settle(tester, seconds: 2);
    final unpinAction = find.text('고정 해제');
    final unpinShown = unpinAction.evaluate().isNotEmpty;
    debugPrint('[INFO] 고정 해제 메뉴 노출: $unpinShown');
    expect(unpinShown, isTrue, reason: '고정된 방은 메뉴가 고정 해제로 바뀌어야 한다');
    await tester.tap(unpinAction.first, warnIfMissed: false);
    final unpinnedToast = await waitFor(
      tester,
      find.textContaining('고정을 풀었어요'),
      maxSeconds: 15,
    );
    debugPrint('[INFO] 고정 해제 완료 안내: $unpinnedToast');
    await shot(tester, '83_unpinned');

    debugPrint(
      '[RESULT] pinToast=$pinnedToast unpinToast=$unpinnedToast',
    );

    FlutterError.onError = original;
    debugPrint('[DONE]');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
