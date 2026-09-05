import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/providers/notification_provider.dart';

/// 알림함이 "그 대상까지" 열려면 서버가 준 relatedEntityId를 들고 있어야 한다.
/// 이 필드를 읽지 않아 채팅 알림이 방이 아니라 목록에서 멈췄다.
void main() {
  group('NotificationItem.fromJson', () {
    test('relatedEntityId를 읽어둔다 — 채팅방·공지·회의록으로 가는 열쇠', () {
      final item = NotificationItem.fromJson({
        'id': 1,
        'title': '김간호',
        'message': '사진 3장',
        'type': 'chat',
        'relatedEntityId': 42,
        'createdAt': '2026-09-05T10:00:00',
        'isRead': false,
      });

      expect(item.type, 'chat');
      expect(item.relatedEntityId, 42);
      expect(item.isUnread, isTrue);
    });

    test('문자열로 와도 숫자로 읽는다', () {
      final item = NotificationItem.fromJson({
        'id': '2',
        'type': 'notice',
        'relatedEntityId': '7',
        'createdAt': '2026-09-05T10:00:00',
      });

      expect(item.relatedEntityId, 7);
    });

    test('대상이 없는 알림은 null — 목록 화면으로 떨어진다', () {
      final item = NotificationItem.fromJson({
        'id': '3',
        'type': 'system',
        'createdAt': '2026-09-05T10:00:00',
      });

      expect(item.relatedEntityId, isNull);
    });
  });
}
