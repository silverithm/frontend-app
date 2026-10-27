// R1(앱 채팅) 2차 점검용 추가 캡처 — 기존 하니스를 그대로 쓰고 채팅 메시지 응답만 덮어쓴다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/chat_room.dart';
import 'package:frontend_app/screens/chat_room_screen.dart';

import 'fake_http.dart';
import 'fixtures.dart';
import 'fx_core.dart';
import 'harness.dart';

Map<String, dynamic> m(int id, String sid, String name, String content,
    {int mins = 10,
    String type = 'TEXT',
    Map<String, dynamic>? extra,
    int read = 0,
    String? pos}) =>
    {
      'id': id,
      'chatRoomId': 7,
      'senderId': sid,
      'senderName': name,
      'senderPosition': pos ?? (sid == adminId ? '센터장' : '요양보호사'),
      'type': type,
      'content': content,
      'readCount': read,
      'createdAt': iso(DateTime.now().subtract(Duration(minutes: mins))),
      'isDeleted': false,
      'reactions': <dynamic>[],
      ...?extra,
    };

List<Map<String, dynamic>> msgs(String me, String myName) => [
      m(20, '2', '이서연', '네 알겠습니다 👍', mins: 3),
      m(19, me, myName, '@이서연 오늘 3시에 회의실 확인해 주세요 https://carev.kr/notice/123', mins: 5, read: 3,
          extra: {'editedAt': iso(DateTime.now())}),
      m(18, me, myName, '네!', mins: 6, read: 3),
      m(17, me, myName, '확인했습니다.', mins: 6, read: 3),
      m(16, '9', '한소연', '급여대장.xlsx', mins: 9, type: 'FILE', pos: '사무원',
          extra: {'fileUrl': 'https://img.example/f.xlsx', 'fileName': '10월_급여대장_최종_수정본.xlsx', 'fileSize': 34000}),
      m(15, '3', '박지훈', '오늘 행사 영상', mins: 11, type: 'FILE',
          extra: {'fileUrl': 'https://img.example/v.mp4', 'fileName': 'event.mp4', 'mediaType': 'video', 'mimeType': 'video/mp4', 'thumbnailUrl': 'https://img.example/vt.jpg'}),
      m(14, me, myName, '삭제할 말', mins: 12, extra: {'isDeleted': true}),
      m(13, '3', '박지훈', '1호차 하원 경로 변경 건, 내일부터 적용되나요? 아니면 이번 주 금요일부터인가요? 보호자분들께 미리 안내가 필요해서요.',
          mins: 14, read: 0, extra: {
        'reactions': [
          {'emoji': '👍', 'count': 3, 'userNames': ['이서연', '최유진', myName], 'myReaction': true},
          {'emoji': '❤️', 'count': 1, 'userNames': ['한소연'], 'myReaction': false},
        ]
      }),
      m(12, '3', '박지훈', '박지훈님이 입장했습니다', mins: 15, type: 'SYSTEM'),
      m(11, '2', '이서연', '네, 내일부터 적용됩니다.', mins: 20, extra: {
        'replyToId': 10,
        'replyToSenderName': '박지훈',
        'replyToContent': '내일 1호차 경로 바뀌는 거 맞죠?',
        'replyToType': 'TEXT'
      }),
      m(10, '3', '박지훈', '내일 1호차 경로 바뀌는 거 맞죠?', mins: 22),
      m(9, '2', '이서연', '아침 프로그램 준비물 목록입니다.', mins: 60 * 24 + 30),
      m(8, '2', '이서연', '색종이, 풀, 가위, 도화지 20장', mins: 60 * 24 + 31),
      m(7, adminId, '김관리', '모두 수고 많으셨습니다.', mins: 60 * 24 + 35, pos: '센터장'),
    ];

void main() {
  setUpAll(setUpAudit);
  for (final role in [Role.emp, Role.adm]) {
    final r = role == Role.emp ? 'emp' : 'adm';
    testWidgets('R1 채팅 추가 $r', (tester) async {
      final a = AuditApp(tester, role);
      await a.boot();
      final me = role == Role.adm ? adminId : '1';
      final myName = role == Role.adm ? '김관리' : '김민지';
      final prev = HttpOverrides.current as FakeHttpOverrides;
      HttpOverrides.global = FakeHttpOverrides((method, uri, body) {
        final p = uri.path.replaceFirst('/api', '');
        if (method == 'GET' && RegExp(r'^/v1/chat/rooms/7/messages$').hasMatch(p)) {
          return FakeReply(200, {'messages': msgs(me, myName), 'hasMore': false});
        }
        if (method == 'GET' && RegExp(r'^/v1/chat/rooms/7$').hasMatch(p)) {
          return null;
        }
        return prev.router(method, uri, body);
      });
      final room = ChatRoom.fromJson({
        'id': 7, 'name': '요양보호사 1팀', 'companyId': 1, 'createdBy': adminId, 'createdByName': '김관리',
        'participantCount': 6, 'unreadCount': 0, 'createdAt': iso(daysFromNow(-100)), 'status': 'ACTIVE',
        'noticeMessageId': 7, 'noticeContent': '내일 안전점검 교육 오전 10시, 전원 참석 부탁드립니다. 준비물은 필기구입니다.',
        'noticeByName': '김관리', 'noticeAt': iso(daysFromNow(-1)), 'pinned': false,
        'avatars': [],
      });
      currentShot = '$r-r2-chat-rich';
      a.nav.push(MaterialPageRoute<void>(builder: (_) => ChatRoomScreen(room: room)));
      await a.settle(seconds: 3.5);
      await a.shot('$r-r2-chat-rich-bottom');
      // 위로 스크롤
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 500), warnIfMissed: false);
      await a.settle(seconds: 1);
      await a.shot('$r-r2-chat-rich-mid');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 900), warnIfMissed: false);
      await a.settle(seconds: 1);
      await a.shot('$r-r2-chat-rich-top');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2500), warnIfMissed: false);
      await a.settle(seconds: 1);
      // 공지 펼침
      try {
        await tester.tap(find.byIcon(Icons.expand_more).first, warnIfMissed: false);
        await a.settle(seconds: 1);
        await a.shot('$r-r2-chat-notice-open');
        await tester.tap(find.byIcon(Icons.expand_less).first, warnIfMissed: false);
        await a.settle(seconds: 0.5);
      } catch (e) { renderFailed['notice'] = '$e'; }
      Future<void> closeSheet() async {
        await tester.tapAt(const Offset(195, 60));
        await a.settle(seconds: 0.8);
      }
      // 내 메시지 길게 누르기 → 답장 배너 → 첨부 시트 → 입력 → 더보기
      try {
        await tester.longPress(find.text('확인했습니다.').first, warnIfMissed: false);
        await a.settle(seconds: 1.5);
        await a.shot('$r-r2-chat-longpress-mine');
        await tester.tap(find.text('답장').first, warnIfMissed: false);
        await a.settle(seconds: 1);
        await a.shot('$r-r2-chat-reply-banner');
      } catch (e) { renderFailed['longpress-mine'] = '$e'; }
      try {
        await tester.tap(find.byTooltip('파일 첨부'), warnIfMissed: false);
        await a.settle(seconds: 1.5);
        await a.shot('$r-r2-chat-attach-sheet');
        await closeSheet();
      } catch (e) { renderFailed['attach'] = '$e'; }
      try {
        await tester.enterText(find.byType(TextField).first, '첫 줄입니다\n둘째 줄입니다\n셋째 줄입니다');
        await a.settle(seconds: 1);
        await a.shot('$r-r2-chat-typing');
        await tester.enterText(find.byType(TextField).first, '');
      } catch (e) { renderFailed['typing'] = '$e'; }
      try {
        await tester.tap(find.byTooltip('더보기'), warnIfMissed: false);
        await a.settle(seconds: 1.5);
        await a.shot('$r-r2-chat-more-sheet');
        await closeSheet();
      } catch (e) { renderFailed['more'] = '$e'; }
      try {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 500), warnIfMissed: false);
        await a.settle(seconds: 1);
        await tester.longPress(find.text('내일 1호차 경로 바뀌는 거 맞죠?').last, warnIfMissed: false);
        await a.settle(seconds: 1.5);
        await a.shot('$r-r2-chat-longpress-other');
        await closeSheet();
      } catch (e) { renderFailed['longpress-other'] = '$e'; }
      writeReport('r2_$r');
    }, timeout: const Timeout(Duration(minutes: 10)));
  }
}
