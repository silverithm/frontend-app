import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/chat_room.dart';
import 'package:frontend_app/utils/chat_room_sort.dart';

/// 상단 고정 정렬/병합 규칙 단위 테스트.
void main() {
  ChatRoom room({
    required int id,
    bool pinned = false,
    DateTime? lastMessageAt,
    DateTime? createdAt,
  }) {
    return ChatRoom(
      id: id,
      name: 'room$id',
      companyId: 1,
      createdBy: 'u1',
      createdByName: '사용자',
      createdAt: createdAt ?? DateTime(2026, 1, 1),
      lastMessageAt: lastMessageAt,
      pinned: pinned,
    );
  }

  group('sortChatRooms', () {
    test('고정 방이 항상 먼저 온다', () {
      final rooms = [
        room(id: 1, lastMessageAt: DateTime(2026, 9, 24, 12)),
        room(id: 2, pinned: true, lastMessageAt: DateTime(2026, 9, 20)),
        room(id: 3, lastMessageAt: DateTime(2026, 9, 24, 13)),
      ];

      sortChatRooms(rooms);

      expect(rooms.map((r) => r.id).toList(), [2, 3, 1]);
    });

    test('같은 그룹 안에서는 최근 활동순이다', () {
      final rooms = [
        room(id: 1, pinned: true, lastMessageAt: DateTime(2026, 9, 20)),
        room(id: 2, pinned: true, lastMessageAt: DateTime(2026, 9, 24)),
        room(id: 3, lastMessageAt: DateTime(2026, 9, 22)),
        room(id: 4, lastMessageAt: DateTime(2026, 9, 23)),
      ];

      sortChatRooms(rooms);

      expect(rooms.map((r) => r.id).toList(), [2, 1, 4, 3]);
    });

    test('새 메시지가 오면 자기 그룹 안에서만 맨 위로 온다 — 고정 안 된 방이 고정 방을 앞지르지 않는다', () {
      final rooms = [
        room(id: 1, pinned: true, lastMessageAt: DateTime(2026, 9, 20)),
        room(id: 2, lastMessageAt: DateTime(2026, 9, 22)),
      ];

      // id=2(고정 안 됨)에 방금 새 메시지가 온 상황
      final updated = [
        rooms[0],
        rooms[1].copyWith(lastMessageAt: DateTime(2026, 9, 25)),
      ];
      sortChatRooms(updated);

      // 고정 안 된 2가 아무리 최신이어도 고정된 1보다 위로 못 온다
      expect(updated.map((r) => r.id).toList(), [1, 2]);
    });

    test('메시지가 없는 방은 생성 시각으로 비교한다', () {
      final rooms = [
        room(id: 1, createdAt: DateTime(2026, 9, 20)),
        room(id: 2, createdAt: DateTime(2026, 9, 24)),
      ];

      sortChatRooms(rooms);

      expect(rooms.map((r) => r.id).toList(), [2, 1]);
    });
  });

  group('mergeRoomPreservingPin', () {
    test('단일 방 조회 응답처럼 pinned가 없는 새 값을 덮어써도 기존 고정 상태가 이어진다', () {
      final current = room(
        id: 1,
        pinned: true,
      ).copyWith(pinnedAt: DateTime(2026, 9, 1));
      // 서버 단일 조회/소켓 응답은 pinned/pinnedAt을 안 실어 보낸다 → fromJson 기본값(false/null)
      final incoming = room(id: 1, pinned: false).copyWith(
        name: '이름 바뀜',
      );

      final merged = mergeRoomPreservingPin(current, incoming);

      expect(merged.pinned, isTrue);
      expect(merged.pinnedAt, DateTime(2026, 9, 1));
      expect(merged.name, '이름 바뀜');
    });

    test('원래 고정이 아니었으면 그대로 고정 아님으로 남는다', () {
      final current = room(id: 1, pinned: false);
      final incoming = room(id: 1, pinned: false).copyWith(name: '새 이름');

      final merged = mergeRoomPreservingPin(current, incoming);

      expect(merged.pinned, isFalse);
      expect(merged.pinnedAt, isNull);
    });
  });

  group('ChatRoom.fromJson', () {
    test('pinned/pinnedAt 필드가 없는 구버전 서버 응답도 안전하게 파싱된다', () {
      final json = {
        'id': 1,
        'name': '방',
        'companyId': 1,
        'createdBy': 'u1',
        'createdByName': '사용자',
        'createdAt': '2026-09-24T00:00:00.000',
      };

      final parsed = ChatRoom.fromJson(json);

      expect(parsed.pinned, isFalse);
      expect(parsed.pinnedAt, isNull);
    });

    test('pinned/pinnedAt이 실려 오면 그대로 반영한다', () {
      final json = {
        'id': 1,
        'name': '방',
        'companyId': 1,
        'createdBy': 'u1',
        'createdByName': '사용자',
        'createdAt': '2026-09-24T00:00:00.000',
        'pinned': true,
        'pinnedAt': '2026-09-24T01:00:00.000',
      };

      final parsed = ChatRoom.fromJson(json);

      expect(parsed.pinned, isTrue);
      expect(parsed.pinnedAt, DateTime(2026, 9, 24, 1));
    });
  });
}
