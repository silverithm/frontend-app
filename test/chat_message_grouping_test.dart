import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/chat_message.dart';
import 'package:frontend_app/utils/chat_message_grouping.dart';

/// 채팅방 날짜 구분선·발신자 그룹 경계 판정 로직(순수 함수) 단위 테스트.
/// 실제 위젯(chat_room_screen.dart)의 ListView.builder(reverse: true)가
/// 이 함수들을 그대로 사용하므로, 여기서 인덱스 판정이 맞으면 화면에서도 맞는다.
void main() {
  ChatMessage msg({
    required int id,
    required String senderId,
    required DateTime createdAt,
    MessageType type = MessageType.text,
    bool isDeleted = false,
  }) {
    return ChatMessage(
      id: id,
      chatRoomId: 1,
      senderId: senderId,
      senderName: senderId,
      type: type,
      content: '내용',
      createdAt: createdAt,
      isDeleted: isDeleted,
    );
  }

  group('shouldShowDateSeparatorAbove', () {
    test('가장 오래된(마지막 인덱스) 메시지 위에는 항상 구분선', () {
      final messages = [
        msg(id: 2, senderId: 'a', createdAt: DateTime(2026, 8, 29, 10)),
        msg(id: 1, senderId: 'a', createdAt: DateTime(2026, 8, 29, 9)),
      ];
      expect(shouldShowDateSeparatorAbove(messages, 1), isTrue);
    });

    test('같은 날짜의 연속 메시지 사이에는 구분선 없음', () {
      final messages = [
        msg(id: 3, senderId: 'a', createdAt: DateTime(2026, 8, 29, 11)),
        msg(id: 2, senderId: 'a', createdAt: DateTime(2026, 8, 29, 10)),
        msg(id: 1, senderId: 'a', createdAt: DateTime(2026, 8, 29, 9)),
      ];
      expect(shouldShowDateSeparatorAbove(messages, 0), isFalse);
      expect(shouldShowDateSeparatorAbove(messages, 1), isFalse);
    });

    test('날짜가 바뀌는 지점에 구분선', () {
      // index 0: 8/30, index 1: 8/29 → index 0 위(=index 0과 1 사이)에 구분선
      final messages = [
        msg(id: 2, senderId: 'a', createdAt: DateTime(2026, 8, 30, 9)),
        msg(id: 1, senderId: 'a', createdAt: DateTime(2026, 8, 29, 22)),
      ];
      expect(shouldShowDateSeparatorAbove(messages, 0), isTrue);
    });
  });

  group('formatDateSeparatorLabel', () {
    final now = DateTime(2026, 8, 30, 15, 0);

    test('오늘', () {
      expect(
        formatDateSeparatorLabel(DateTime(2026, 8, 30, 1), now: now),
        '오늘',
      );
    });

    test('어제', () {
      expect(
        formatDateSeparatorLabel(DateTime(2026, 8, 29, 23), now: now),
        '어제',
      );
    });

    test('그 외 날짜는 연월일과 요일', () {
      // 2026-08-29 는 토요일
      expect(
        formatDateSeparatorLabel(DateTime(2026, 8, 29), now: DateTime(2026, 9, 2)),
        '2026년 8월 29일 (토)',
      );
    });
  });

  group('isSenderGroupStart', () {
    test('가장 오래된 메시지는 항상 그룹 시작', () {
      final messages = [
        msg(id: 1, senderId: 'a', createdAt: DateTime(2026, 8, 29, 9)),
      ];
      expect(isSenderGroupStart(messages, 0), isTrue);
    });

    test('발신자가 바뀌면 그룹 시작', () {
      final messages = [
        msg(id: 2, senderId: 'b', createdAt: DateTime(2026, 8, 29, 10)),
        msg(id: 1, senderId: 'a', createdAt: DateTime(2026, 8, 29, 9)),
      ];
      expect(isSenderGroupStart(messages, 0), isTrue);
    });

    test('같은 발신자·같은 날짜 연속 메시지는 그룹 시작 아님', () {
      final messages = [
        msg(id: 3, senderId: 'a', createdAt: DateTime(2026, 8, 29, 11)),
        msg(id: 2, senderId: 'a', createdAt: DateTime(2026, 8, 29, 10)),
        msg(id: 1, senderId: 'a', createdAt: DateTime(2026, 8, 29, 9)),
      ];
      expect(isSenderGroupStart(messages, 0), isFalse);
      expect(isSenderGroupStart(messages, 1), isFalse);
    });

    test('지운 메시지 다음은 그룹 시작 — 얼굴도 이름도 없는 말풍선이 뜨지 않게', () {
      // 지운 자리에는 "삭제된 메시지입니다"만 남고 얼굴·이름을 그리지 않는다.
      // 그런데 보낸 사람은 그대로 남아 있어서, 지웠다가 다시 쓰면 다음 메시지가
      // "앞에 같은 사람이 있다"는 이유로 머리를 잃었다. (제보 2026-09-08)
      final messages = [
        msg(id: 3, senderId: 'a', createdAt: DateTime(2026, 8, 29, 11)),
        msg(id: 2, senderId: 'a', createdAt: DateTime(2026, 8, 29, 10), isDeleted: true),
        msg(id: 1, senderId: 'a', createdAt: DateTime(2026, 8, 29, 9)),
      ];
      expect(isSenderGroupStart(messages, 0), isTrue);
    });

    test('지운 메시지 자신은 앞과 같은 사람이면 그룹 시작이 아니다 — 빈 머리를 새로 그리지 않는다', () {
      final messages = [
        msg(id: 2, senderId: 'a', createdAt: DateTime(2026, 8, 29, 10), isDeleted: true),
        msg(id: 1, senderId: 'a', createdAt: DateTime(2026, 8, 29, 9)),
      ];
      expect(isSenderGroupStart(messages, 0), isFalse);
    });

    test('같은 발신자라도 날짜가 바뀌면 그룹을 끊는다', () {
      final messages = [
        msg(id: 2, senderId: 'a', createdAt: DateTime(2026, 8, 30, 9)),
        msg(id: 1, senderId: 'a', createdAt: DateTime(2026, 8, 29, 22)),
      ];
      expect(isSenderGroupStart(messages, 0), isTrue);
    });

    test('사이에 시스템 메시지가 끼면 그룹을 끊는다', () {
      final messages = [
        msg(id: 3, senderId: 'a', createdAt: DateTime(2026, 8, 29, 11)),
        msg(
          id: 2,
          senderId: 'system',
          createdAt: DateTime(2026, 8, 29, 10, 30),
          type: MessageType.system,
        ),
        msg(id: 1, senderId: 'a', createdAt: DateTime(2026, 8, 29, 10)),
      ];
      expect(isSenderGroupStart(messages, 0), isTrue);
    });
  });
}
