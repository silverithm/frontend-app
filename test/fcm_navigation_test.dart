import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/screens/admin_user_management_screen.dart';
import 'package:frontend_app/screens/admin_vacation_management_screen.dart';
import 'package:frontend_app/screens/approval_detail_loader_screen.dart';
import 'package:frontend_app/screens/approval_hub_screen.dart';
import 'package:frontend_app/screens/calendar_screen.dart';
import 'package:frontend_app/screens/chat_room_list_screen.dart';
import 'package:frontend_app/screens/meeting_minutes_detail_screen.dart';
import 'package:frontend_app/screens/meeting_minutes_list_screen.dart';
import 'package:frontend_app/screens/my_vacation_screen.dart';
import 'package:frontend_app/screens/notice_detail_screen.dart';
import 'package:frontend_app/screens/notice_list_screen.dart';
import 'package:frontend_app/screens/profile_screen.dart';
import 'package:frontend_app/screens/work_task_list_screen.dart';
import 'package:frontend_app/services/fcm_service.dart';

/// FCM 알림 type → 이동할 화면 매핑이 깨지면 "알람은 뜨는데 눌러도 안 열리는" 사고가
/// 조용히 재발한다 (회의록 서명 알림 사고가 그 예). Navigator/BuildContext 없이도
/// 매핑 자체를 검증할 수 있도록 순수 함수 단위로 테스트한다.
void main() {
  group('resolveFCMDestination', () {
    test('vacation로 시작하는 모든 type은 휴무 화면으로 간다', () {
      expect(resolveFCMDestination('vacation'), FCMDestination.vacation);
      expect(resolveFCMDestination('vacation_approved'), FCMDestination.vacation);
      expect(resolveFCMDestination('vacation_rejected'), FCMDestination.vacation);
    });

    test('approval은 전자결재함으로 간다', () {
      expect(resolveFCMDestination('approval'), FCMDestination.approval);
    });

    test('notice는 공지 상세로 간다', () {
      expect(resolveFCMDestination('notice'), FCMDestination.notice);
    });

    test('chat은 채팅방 목록/대화로 간다', () {
      expect(resolveFCMDestination('chat'), FCMDestination.chat);
    });

    test('schedule은 일정 달력으로 간다', () {
      expect(resolveFCMDestination('schedule'), FCMDestination.schedule);
    });

    test('meeting_minutes는 회의록 상세(서명 화면)로 간다', () {
      expect(
        resolveFCMDestination('meeting_minutes'),
        FCMDestination.meetingMinutes,
      );
    });

    test('가입 요청·탈퇴 알림은 관리자 회원관리 화면으로 간다', () {
      expect(
        resolveFCMDestination('member_join_requested'),
        FCMDestination.memberManagement,
      );
      expect(
        resolveFCMDestination('member_withdrawal'),
        FCMDestination.memberManagement,
      );
    });

    test('가입 승인·거절 알림(신청자 본인용)은 내 정보 화면으로 간다', () {
      expect(
        resolveFCMDestination('member_join_approved'),
        FCMDestination.myProfile,
      );
      expect(
        resolveFCMDestination('member_join_rejected'),
        FCMDestination.myProfile,
      );
    });

    test('휴가 신청 알림은 관리자에게만 가므로 승인 화면으로 간다', () {
      // '내 휴무'로 보내면 정작 승인해야 할 신청을 볼 수 없다
      expect(
        resolveFCMDestination('vacation_submitted'),
        FCMDestination.vacationApproval,
      );
    });

    test('업무진행도(배정·매일 아침 알림)는 업무진행도 화면으로 간다', () {
      expect(resolveFCMDestination('work_task'), FCMDestination.workTask);
    });

    test('휴무 리마인더(마감 임박·조정 필요·알림함의 vacation_reminder)는 내 휴무로 간다', () {
      expect(
        resolveFCMDestination('vacation_deadline_reminder'),
        FCMDestination.vacation,
      );
      expect(
        resolveFCMDestination('vacation_adjustment'),
        FCMDestination.vacation,
      );
      expect(
        resolveFCMDestination('vacation_reminder'),
        FCMDestination.vacation,
      );
    });

    test('알림함의 일정 알림은 general + relatedEntityType(schedule…)으로 일정에 간다', () {
      // 일정 알림은 알림함 종류 칸에 자리가 없어 general로 저장된다
      for (final kind in const [
        'schedule',
        'schedule_start_reminder',
        'schedule_task_reminder',
      ]) {
        expect(
          resolveFCMDestination('general', relatedEntityType: kind),
          FCMDestination.schedule,
          reason: kind,
        );
      }
      expect(resolveFCMDestination('general'), FCMDestination.unknown);
      expect(
        resolveFCMDestination('general', relatedEntityType: 'notice'),
        FCMDestination.unknown,
      );
    });

    test('type이 알려진 종류면 relatedEntityType보다 type이 우선한다', () {
      expect(
        resolveFCMDestination('chat', relatedEntityType: 'schedule'),
        FCMDestination.chat,
      );
      expect(
        resolveFCMDestination('work_task', relatedEntityType: 'work_task_daily'),
        FCMDestination.workTask,
      );
    });

    test('매핑되지 않은 type은 unknown으로 분류돼 로그로 드러난다', () {
      expect(resolveFCMDestination('never_seen_before'), FCMDestination.unknown);
      expect(resolveFCMDestination(''), FCMDestination.unknown);
    });
  });

  /// 푸시와 앱 안 알림함이 **같은 함수**로 화면을 고르는지 못박는다.
  /// 예전에는 알림함이 자기 표를 따로 갖고 있다가 뒤처져, 채팅 알림을 눌러도 방이 아니라
  /// 목록에서 멈추고 회의록·가입요청은 아무 일도 일어나지 않았다.
  group('screenForNotification', () {
    test('채팅은 방 id가 있으면 그 대화까지 연다', () {
      final screen = screenForNotification(FCMDestination.chat, entityId: 12);
      expect(screen, isA<ChatRoomListScreen>());
      expect((screen as ChatRoomListScreen).initialRoomId, 12);
    });

    test('채팅에 방 id가 없으면 목록으로 — 빈 화면으로 보내지 않는다', () {
      final screen = screenForNotification(FCMDestination.chat);
      expect(screen, isA<ChatRoomListScreen>());
      expect((screen as ChatRoomListScreen).initialRoomId, isNull);
    });

    test('공지는 id가 있으면 상세, 없으면 목록', () {
      expect(
        screenForNotification(FCMDestination.notice, entityId: 7),
        isA<NoticeDetailScreen>(),
      );
      expect(
        screenForNotification(FCMDestination.notice),
        isA<NoticeListScreen>(),
      );
    });

    test('회의록은 id가 있으면 서명 화면, 없으면 목록', () {
      expect(
        screenForNotification(FCMDestination.meetingMinutes, entityId: 3),
        isA<MeetingMinutesDetailScreen>(),
      );
      expect(
        screenForNotification(FCMDestination.meetingMinutes),
        isA<MeetingMinutesListScreen>(),
      );
    });

    test('휴가 신청은 관리자 휴무 관리로, 승인·반려는 내 휴무로', () {
      expect(
        screenForNotification(FCMDestination.vacationApproval),
        isA<AdminVacationManagementScreen>(),
      );
      expect(
        screenForNotification(FCMDestination.vacation),
        isA<MyVacationScreen>(),
      );
    });

    test('가입 요청·탈퇴는 회원관리, 승인·거절은 내 정보', () {
      expect(
        screenForNotification(FCMDestination.memberManagement),
        isA<AdminUserManagementScreen>(),
      );
      expect(
        screenForNotification(FCMDestination.myProfile),
        isA<ProfileScreen>(),
      );
    });

    test('일정은 날짜·강조할 일정까지 달력에 넘긴다', () {
      final date = DateTime(2026, 9, 5);
      final screen = screenForNotification(
        FCMDestination.schedule,
        entityId: 99,
        scheduleDate: date,
      );
      expect(screen, isA<CalendarScreen>());
      expect((screen as CalendarScreen).initialScheduleDate, date);
      expect(screen.highlightedScheduleId, 99);
    });

    test('결재는 문서 번호가 있으면 그 문서를, 없으면 결재함을 연다', () {
      final screen = screenForNotification(
        FCMDestination.approval,
        entityId: 990,
      );
      expect(screen, isA<ApprovalDetailLoaderScreen>());
      expect((screen as ApprovalDetailLoaderScreen).approvalId, 990);
      expect(
        screenForNotification(FCMDestination.approval),
        isA<ApprovalHubScreen>(),
      );
    });

    test('업무진행도는 그 업무 창까지 연다 — 번호가 없으면 목록만', () {
      final screen = screenForNotification(
        FCMDestination.workTask,
        entityId: 41,
      );
      expect(screen, isA<WorkTaskListScreen>());
      expect((screen as WorkTaskListScreen).openTaskId, 41);
      final list = screenForNotification(FCMDestination.workTask);
      expect((list as WorkTaskListScreen).openTaskId, isNull);
    });

    test('일정에 날짜가 없으면(알림함) 번호만 넘긴다 — 달력이 일정을 받아 날짜를 찾는다', () {
      final screen = screenForNotification(
        FCMDestination.schedule,
        entityId: 5,
      );
      expect((screen as CalendarScreen).initialScheduleDate, isNull);
      expect(screen.highlightedScheduleId, 5);
    });

    test('알 수 없는 알림은 아무 화면도 열지 않는다', () {
      expect(screenForNotification(FCMDestination.unknown), isNull);
    });

    test('모든 종류가 화면을 하나씩 갖는다 — 새 종류를 넣고 화면을 빠뜨리지 않게', () {
      for (final destination in FCMDestination.values) {
        final screen = screenForNotification(destination, entityId: 1);
        if (destination == FCMDestination.unknown) {
          expect(screen, isNull);
        } else {
          expect(screen, isNotNull, reason: destination.name);
        }
      }
    });
  });

  /// 푸시 data의 id 키 이름은 종류마다 다르다 — 하나라도 틀리면 그 종류만 조용히 목록으로 샌다.
  group('entityIdFromFCMData', () {
    test('종류별로 알맞은 키에서 id를 꺼낸다', () {
      expect(
        entityIdFromFCMData(FCMDestination.chat, {'roomId': '12'}),
        12,
      );
      expect(
        entityIdFromFCMData(FCMDestination.notice, {'noticeId': '7'}),
        7,
      );
      expect(
        entityIdFromFCMData(FCMDestination.meetingMinutes, {'minutesId': '3'}),
        3,
      );
      expect(
        entityIdFromFCMData(FCMDestination.schedule, {'scheduleId': '99'}),
        99,
      );
      expect(
        entityIdFromFCMData(FCMDestination.approval, {'requestId': '990'}),
        990,
      );
      expect(
        entityIdFromFCMData(FCMDestination.workTask, {'taskId': '41'}),
        41,
      );
    });

    test('숫자로 와도 읽는다', () {
      expect(entityIdFromFCMData(FCMDestination.approval, {'requestId': 5}), 5);
    });

    test('키가 없거나 숫자가 아니면 null — 목록으로 떨어진다', () {
      expect(entityIdFromFCMData(FCMDestination.chat, {}), isNull);
      expect(
        entityIdFromFCMData(FCMDestination.chat, {'roomId': 'abc'}),
        isNull,
      );
    });
  });

  /// 서버가 실제로 보내는 푸시 data(서비스별 발송 코드 그대로)를 넣어 끝까지 따라간다.
  /// 서버 키 이름과 앱 매핑이 한 군데라도 어긋나면 "알림을 누르면 목록에서 멈춘다"가 재발한다.
  group('서버 푸시 data → 열리는 화면', () {
    Widget? open(Map<String, dynamic> data) {
      final destination = resolveFCMDestination(data['type'].toString());
      return screenForNotification(
        destination,
        entityId: entityIdFromFCMData(destination, data),
        scheduleDate: DateTime.tryParse(data['scheduleDate']?.toString() ?? ''),
      );
    }

    test('채팅(ChatService) — 그 방', () {
      final screen = open({
        'type': 'chat',
        'roomId': '191',
        'messageId': '5001',
        'mention': 'false',
      });
      expect((screen as ChatRoomListScreen).initialRoomId, 191);
    });

    test('결재(ApprovalRequestService) — 결재할 차례·결과 모두 그 문서', () {
      for (final data in [
        {'type': 'approval', 'requestId': '990'},
        {'type': 'approval', 'requestId': '990', 'result': 'APPROVED'},
      ]) {
        final screen = open(data);
        expect((screen as ApprovalDetailLoaderScreen).approvalId, 990);
      }
    });

    test('공지(NoticeService) — 그 공지', () {
      final screen = open({'type': 'notice', 'noticeId': '7', 'priority': 'HIGH'});
      expect(screen, isA<NoticeDetailScreen>());
    });

    test('일정 등록·당일·미완료(ScheduleService.scheduleNotificationData) — 그날 그 일정', () {
      final screen = open({
        'type': 'schedule',
        'scheduleId': '99',
        'scheduleDate': '2026-10-23',
      });
      expect((screen as CalendarScreen).initialScheduleDate, DateTime(2026, 10, 23));
      expect(screen.highlightedScheduleId, 99);
    });

    test('회의록 서명 요청(MeetingMinutesService) — 그 회의록', () {
      expect(
        open({'type': 'meeting_minutes', 'minutesId': '3'}),
        isA<MeetingMinutesDetailScreen>(),
      );
    });

    test('업무진행도(WorkTaskNotifier) — 그 업무', () {
      final screen = open({'type': 'work_task', 'taskId': '41'});
      expect((screen as WorkTaskListScreen).openTaskId, 41);
    });

    test('휴무 — 신청은 관리자 승인 화면, 나머지는 내 휴무', () {
      expect(
        open({'type': 'vacation_submitted', 'vacationId': '1'}),
        isA<AdminVacationManagementScreen>(),
      );
      for (final type in const [
        'vacation_approved',
        'vacation_rejected',
        'vacation_adjustment',
        'vacation_deadline_reminder',
      ]) {
        expect(open({'type': type}), isA<MyVacationScreen>(), reason: type);
      }
    });

    test('가입·탈퇴(MemberService)', () {
      expect(
        open({'type': 'member_join_requested'}),
        isA<AdminUserManagementScreen>(),
      );
      expect(open({'type': 'member_withdrawal'}), isA<AdminUserManagementScreen>());
      expect(open({'type': 'member_join_approved'}), isA<ProfileScreen>());
      expect(open({'type': 'member_join_rejected'}), isA<ProfileScreen>());
    });
  });

  /// 알림함 항목(서버 NotificationDTO: type 소문자 + relatedEntityId/Type)도 같은 화면으로 간다.
  group('알림함 항목 → 열리는 화면', () {
    Widget? open(String type, int? id, String? kind) => screenForNotification(
      resolveFCMDestination(type, relatedEntityType: kind),
      entityId: id,
    );

    test('채팅·결재·업무·일정·공지·회의록', () {
      expect((open('chat', 191, 'chatRoom') as ChatRoomListScreen).initialRoomId, 191);
      expect(
        (open('approval', 990, 'approval_request') as ApprovalDetailLoaderScreen)
            .approvalId,
        990,
      );
      expect(
        (open('work_task', 41, 'work_task_daily') as WorkTaskListScreen).openTaskId,
        41,
      );
      expect(
        (open('general', 99, 'schedule_start_reminder') as CalendarScreen)
            .highlightedScheduleId,
        99,
      );
      expect(open('notice', 7, 'notice'), isA<NoticeDetailScreen>());
      expect(open('meeting_minutes', 3, 'meeting_minutes'), isA<MeetingMinutesDetailScreen>());
      expect(open('vacation_reminder', null, 'vacation_adjustment'), isA<MyVacationScreen>());
    });
  });
}
