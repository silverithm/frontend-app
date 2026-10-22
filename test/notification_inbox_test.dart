import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/theme/app_colors.dart';
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

    test('relatedEntityType도 읽는다 — 일정 알림은 type이 general이라 이 값으로 갈 곳을 안다', () {
      final item = NotificationItem.fromJson({
        'id': '4',
        'type': 'general',
        'relatedEntityId': 99,
        'relatedEntityType': 'schedule_start_reminder',
        'createdAt': '2026-10-22T08:30:00',
      });

      expect(item.relatedEntityType, 'schedule_start_reminder');
      expect(item.relatedEntityId, 99);
    });
  });

  group('NotificationItem 아이콘 — 종류마다 다르게(예전엔 모두 회색 종)', () {
    NotificationItem item(String type, [String? kind]) => NotificationItem(
      id: '1',
      title: 't',
      message: 'm',
      type: type,
      relatedEntityType: kind,
      createdAt: DateTime(2026, 10, 22),
    );

    test('채팅·결재·업무·공지·회의록·휴무·가입·일정은 저마다 아이콘이 있다', () {
      final icons = {
        for (final entry in {
          'chat': item('chat'),
          'approval': item('approval'),
          'work_task': item('work_task'),
          'notice': item('notice'),
          'meeting_minutes': item('meeting_minutes'),
          'vacation_reminder': item('vacation_reminder'),
          'member_join_requested': item('member_join_requested'),
          'schedule': item('general', 'schedule'),
        }.entries)
          entry.key: entry.value.icon,
      };
      expect(icons.values.toSet(), hasLength(icons.length));
      expect(icons.values, isNot(contains(Icons.notifications)));
    });

    test('모르는 종류만 기본 종', () {
      expect(item('general').icon, Icons.notifications);
      expect(item('general').color, AppSemanticColors.textDisabled);
    });

    test('휴무 승인·반려는 예전 색 그대로', () {
      expect(item('vacation_approved').color, AppSemanticColors.statusSuccessIcon);
      expect(item('vacation_rejected').color, AppSemanticColors.statusErrorIcon);
    });
  });
}
