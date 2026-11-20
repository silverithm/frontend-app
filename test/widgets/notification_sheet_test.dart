import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/providers/notification_provider.dart';
import 'package:frontend_app/widgets/common/notification_bell.dart';
import 'package:provider/provider.dart';

NotificationItem _n(
  String id,
  DateTime at, {
  String title = '알림',
  String message = '',
  String type = 'system',
  String? actorId,
  bool unread = false,
}) => NotificationItem(
  id: id,
  title: title,
  message: message,
  type: type,
  createdAt: at,
  actorId: actorId,
  isUnread: unread,
);

void main() {
  group('알림을 일으킨 사람 이름(actorName)', () {
    final at = DateTime(2026, 11, 20, 9);
    test('휴무 신청·결재·업무·회의록은 글 맨 앞 "이름(직책)님이"', () {
      expect(
        _n('1', at, type: 'vacation_submitted', message: '한희정(조리원)님이 2026-11-24 휴가를 신청했습니다.').actorName,
        '한희정',
      );
      expect(
        _n('2', at, type: 'APPROVAL', message: '한소연님의 「지출결의서」 결재 차례입니다.').actorName,
        '한소연',
      );
    });
    test('채팅은 제목이 보낸 사람', () {
      expect(_n('3', at, type: 'chat', title: '조은비').actorName, '조은비');
    });
    test('가입 요청·공지·이름 없는 글은 찾지 않는다', () {
      expect(_n('4', at, type: 'member_join_requested', message: '홍길동님이 가입을 요청했습니다.').actorName, isNull);
      expect(_n('5', at, type: 'approval', message: '「지출결의서」가 승인되었습니다.').actorName, isNull);
    });
    test('서버 actorId를 읽는다(빈 값은 없음으로)', () {
      final item = NotificationItem.fromJson({'id': 1, 'title': 't', 'message': 'm', 'type': 'chat', 'actorId': 'admin_3', 'createdAt': '2026-11-20T09:00:00'});
      expect(item.actorId, 'admin_3');
      final empty = NotificationItem.fromJson({'id': 2, 'title': 't', 'message': 'm', 'type': 'chat', 'actorId': '', 'createdAt': '2026-11-20T09:00:00'});
      expect(empty.actorId, isNull);
    });
  });

  test('날짜 묶음 — 오늘·어제·이번 주·이전, 빈 묶음은 뺀다', () {
    final now = DateTime(2026, 11, 20, 9);
    final sections = groupNotificationsByDay([
      _n('a', DateTime(2026, 11, 20, 8, 50)),
      _n('b', DateTime(2026, 11, 19, 23)),
      _n('c', DateTime(2026, 11, 14, 10)),
      _n('d', DateTime(2026, 11, 13, 10)),
    ], now);
    expect([for (final s in sections) s.label], ['오늘', '어제', '이번 주', '이전']);
    expect([for (final s in sections) s.items.single.id], ['a', 'b', 'c', 'd']);
    expect(
      [for (final s in groupNotificationsByDay([_n('x', DateTime(2026, 11, 1))], now)) s.label],
      ['이전'],
    );
  });

  testWidgets('알림함 — 묶음 머리, 새 알림 수, 닫기', (tester) async {
    final provider = NotificationProvider();
    final now = DateTime.now();
    provider.notifications.addAll([
      _n('1', now.subtract(const Duration(minutes: 5)), title: '휴가 신청', message: '오하늘(조리원)님이 휴가를 신청했습니다.', type: 'vacation_submitted'),
      _n('2', now.subtract(const Duration(days: 1)), title: '휴무 승인', message: '휴무 신청이 승인되었습니다.', type: 'vacation_approved'),
    ]);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => ChangeNotifierProvider.value(
                  value: provider,
                  child: NotificationSheet(newIds: const {'1'}, now: now),
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('새 알림 1'), findsOneWidget);
    expect(find.text('오늘'), findsOneWidget);
    expect(find.text('어제'), findsOneWidget);
    expect(find.text('휴가 신청'), findsOneWidget);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('휴가 신청'), findsNothing);
  });
}
