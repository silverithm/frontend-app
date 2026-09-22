import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_app/main.dart' as app;
import 'package:frontend_app/widgets/chat/chat_photo.dart';
import 'package:frontend_app/widgets/chat/chat_photo_group.dart';

/// 버그제보방 9/23 앱 수정 캡처 — 체험 기관(체험 관리자)에서만 돈다.
///  6번: 결재 목록을 띄운 채 호스트가 그 문서를 지운다([STEP] delete_approval) →
///       눌렀을 때 "이미 삭제되었거나 처리된 결재입니다" 안내 후 목록에서 빠지는지
///  11번: 사진 저장 시 앨범 선택 시트(새 앨범 포함), 동영상 길게 눌러 '동영상 저장'
///
/// 실행: flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/bugroom_0923_capture_test.dart \
///   --dart-define=SHOT_EMAIL=... --dart-define=SHOT_PASSWORD=... -d <device>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const email = String.fromEnvironment('SHOT_EMAIL');
  const password = String.fromEnvironment('SHOT_PASSWORD');
  const deletedTitle = '어르신 위생용품 구매 신청';
  const newAlbum = '어르신 사진';
  // 6번을 이미 확인한 뒤 11번만 다시 볼 때 (지운 결재는 다시 만들 수 없다)
  const skip6 = bool.fromEnvironment('SKIP6');

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

  testWidgets('버그제보방 9/23 캡처', (tester) async {
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

    // ===================== 6번: 지워진 결재 =====================
    step = 'approval';
    if (!skip6) {
      await shot(tester, '60_home');
      await tester.tap(navItem('전자결재').last, warnIfMissed: false);
      await settle(tester, seconds: 4);
      final doc = find.text(deletedTitle);
      final listed = await waitFor(tester, doc, maxSeconds: 20);
      debugPrint('[INFO] 삭제 전 목록에 문서 있음: $listed');
      expect(listed, isTrue, reason: '체험 기관의 대기 결재가 목록에 있어야 한다');
      await shot(tester, '61_approval_list_before');

      debugPrint('[STEP] delete_approval');
      await settle(tester, seconds: 15); // 호스트가 웹처럼 그 문서를 지운다
      // 탭을 바꾸지 않고(=새로고침 없이) 옛 목록에 남은 문서를 누른다 — 현장과 같은 상황
      expect(
        doc.evaluate().isNotEmpty,
        isTrue,
        reason: '새로고침 전이라 옛 목록에 아직 남아 있어야 한다',
      );
      await tester.tap(doc.first, warnIfMissed: false);
      final notice = find.textContaining('이미 삭제되었거나 처리된 결재');
      final noticed = await waitFor(tester, notice, maxSeconds: 15);
      debugPrint('[INFO] 안내 문구 뜸: $noticed');
      await shot(tester, '62_after_tap_deleted', before: 0.3);
      await settle(tester, seconds: 4);
      final stillListed = find.text(deletedTitle).evaluate().isNotEmpty;
      debugPrint('[INFO] 목록에 지운 문서 남음: $stillListed');
      await shot(tester, '63_approval_list_after');
      debugPrint('[RESULT6] noticed=$noticed stillListed=$stillListed');
    }

    // ===================== 11번: 사진 저장 앨범 =====================
    step = 'photo';
    await tester.tap(navItem('채팅').last, warnIfMissed: false);
    await settle(tester, seconds: 3);
    final room = find.text('전체 공지방');
    expect(await waitFor(tester, room, maxSeconds: 20), isTrue);
    await tester.tap(room.first, warnIfMissed: false);
    await settle(tester, seconds: 5);
    final photos = find.byType(ChatPhoto);
    expect(
      await waitFor(tester, photos, maxSeconds: 15),
      isTrue,
      reason: '사진 메시지가 있어야 한다',
    );
    await tester.ensureVisible(photos.last);
    await settle(tester, seconds: 1);
    await tester.tap(photos.last, warnIfMissed: false);
    await settle(tester, seconds: 3);
    final saveBtn = find.byTooltip('저장');
    expect(saveBtn.evaluate().isNotEmpty, isTrue, reason: '뷰어에 저장 버튼이 있어야 한다');
    await tester.tap(saveBtn.first, warnIfMissed: false);
    await settle(tester, seconds: 2.5);
    final newAlbumCell = find.text('새 앨범 이름 입력');
    final sheetShown = newAlbumCell.evaluate().isNotEmpty;
    debugPrint('[INFO] 앨범 선택 시트: $sheetShown');
    await shot(tester, '64_photo_album_sheet');
    await tester.tap(newAlbumCell.first, warnIfMissed: false);
    await settle(tester, seconds: 2);
    await tester.enterText(find.byType(TextField).last, newAlbum);
    await settle(tester, seconds: 1);
    await shot(tester, '65_new_album_input');
    await tester.tap(find.text('저장').last, warnIfMissed: false);
    final savedPhoto = await waitFor(
      tester,
      find.textContaining("'$newAlbum' 앨범에 저장"),
      maxSeconds: 20,
    );
    debugPrint('[INFO] 사진 새 앨범 저장 문구: $savedPhoto');
    await shot(tester, '66_photo_saved', before: 0.3);
    await tester.binding.handlePopRoute(); // 뷰어 닫기
    await settle(tester, seconds: 3);

    // ===================== 11번: 동영상 저장 =====================
    step = 'video';
    final video = find.byType(ChatVideoBubble);
    expect(
      await waitFor(tester, video, maxSeconds: 15),
      isTrue,
      reason: '동영상 메시지가 있어야 한다',
    );
    await tester.ensureVisible(video.last);
    await settle(tester, seconds: 1);
    await tester.longPress(video.last, warnIfMissed: false);
    await settle(tester, seconds: 2);
    final videoSave = find.text('동영상 저장');
    final menuHas = videoSave.evaluate().isNotEmpty;
    debugPrint('[INFO] 길게 누른 메뉴에 동영상 저장: $menuHas');
    await shot(tester, '67_video_menu');
    await tester.ensureVisible(videoSave.first);
    await settle(tester, seconds: 0.5);
    await tester.tap(videoSave.first, warnIfMissed: false);
    await settle(tester, seconds: 2.5);
    final recent = find.text("사진첩 '$newAlbum'에 저장");
    final recentShown = recent.evaluate().isNotEmpty;
    debugPrint('[INFO] 최근 앨범이 시트에 보임: $recentShown');
    await shot(tester, '68_video_album_sheet');
    await tester.tap(recent.first, warnIfMissed: false);
    final savedVideo = await waitFor(
      tester,
      find.textContaining("'$newAlbum' 앨범에 저장"),
      maxSeconds: 60,
    );
    debugPrint('[INFO] 동영상 저장 문구: $savedVideo');
    await shot(tester, '69_video_saved', before: 0.3);
    debugPrint(
      '[RESULT11] sheet=$sheetShown photo=$savedPhoto menu=$menuHas recent=$recentShown video=$savedVideo',
    );

    FlutterError.onError = original;
    debugPrint('[DONE]');
  }, timeout: const Timeout(Duration(minutes: 12)));
}
