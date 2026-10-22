import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/chat_room.dart';
import 'package:frontend_app/screens/calendar_screen.dart';
import 'package:frontend_app/screens/chat_room_list_screen.dart';

/// 알림을 눌러 들어온 화면이 "그 대상"을 찾는 작은 규칙들.
void main() {
  group('scheduleStartDateOf — 알림함 일정 알림은 번호만 있어 일정을 받아 날짜를 찾는다', () {
    test('서버 응답 {schedule: {...}}', () {
      expect(
        scheduleStartDateOf({
          'schedule': {'id': 99, 'startDate': '2026-10-23'},
        }),
        DateTime(2026, 10, 23),
      );
    });

    test('일정 그대로 와도, 시각이 붙어 와도 날짜만', () {
      expect(
        scheduleStartDateOf({'startDate': '2026-10-23T09:30:00'}),
        DateTime(2026, 10, 23),
      );
    });

    test('시작일이 없거나 이상하면 null — 이번 달 일정 달력을 그대로 보여 준다', () {
      expect(scheduleStartDateOf({'schedule': {'id': 1}}), isNull);
      expect(scheduleStartDateOf({'startDate': '10/23'}), isNull);
      expect(scheduleStartDateOf({}), isNull);
    });
  });

  group('findChatRoomById — 알림이 가리킨 방', () {
    ChatRoom room(int id) => ChatRoom(
      id: id,
      name: 'room$id',
      companyId: 1,
      createdBy: 'u1',
      createdByName: '사용자',
      createdAt: DateTime(2026, 1, 1),
    );

    test('목록에 있으면 그 방', () {
      expect(findChatRoomById([room(1), room(191)], 191)?.name, 'room191');
    });

    test('없으면 null — 그때는 방 하나만 따로 받는다', () {
      expect(findChatRoomById([room(1)], 191), isNull);
      expect(findChatRoomById(const [], 191), isNull);
    });
  });
}
