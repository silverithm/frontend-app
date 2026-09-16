
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_app/main.dart' as app;
import 'package:frontend_app/widgets/chat/chat_image_viewer.dart';
import 'package:frontend_app/widgets/chat/chat_photo.dart';

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

  testWidgets('채팅 사진 저장 캡처', (tester) async {
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

    // ===================== 채팅방 → 사진 → 저장 =====================
    step = 'chat';
    final navChatTab = find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('채팅'),
    );
    await tester.tap(navChatTab.last, warnIfMissed: false);
    await settle(tester, seconds: 3);
    final room = find.text('전체 공지방');
    expect(await waitFor(tester, room, maxSeconds: 20), isTrue);
    await tester.tap(room.first, warnIfMissed: false);
    await settle(tester, seconds: 5);

    step = 'find_photo';
    final photos = find.byType(ChatPhoto);
    await waitFor(tester, photos, maxSeconds: 15);
    debugPrint('[INFO] ChatPhoto 개수: ${photos.evaluate().length}');
    expect(photos.evaluate().isNotEmpty, isTrue, reason: '방에 사진 메시지가 있어야 한다');
    await tester.ensureVisible(photos.last);
    await settle(tester, seconds: 1);
    await tester.tap(photos.last, warnIfMissed: false);
    await settle(tester, seconds: 3);
    final viewerOpen = find.byType(ChatImageViewer).evaluate().isNotEmpty;
    debugPrint('[INFO] 이미지 뷰어 열림: $viewerOpen');
    await shot(tester, '13a_image_viewer');

    step = 'save';
    final saveBtn = find.byTooltip('저장');
    expect(saveBtn.evaluate().isNotEmpty, isTrue, reason: '뷰어에 저장 버튼이 있어야 한다');
    await tester.tap(saveBtn.first, warnIfMissed: false);
    await settle(tester, seconds: 2.5);
    final folderChoice = find.text('폴더 선택해 저장');
    if (folderChoice.evaluate().isNotEmpty) {
      await shot(tester, '14_folder_picker');
      final album = find.textContaining('사진첩');
      await tester.tap(album.first, warnIfMissed: false);
      await settle(tester, seconds: 3);
    }
    await shot(tester, '13_image_save_success');
    debugPrint('[INFO] 저장 문구: ${find.textContaining('저장').evaluate().map((e) => (e.widget as Text).data).toList()}');

    FlutterError.onError = original;
    debugPrint('[DONE]');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
