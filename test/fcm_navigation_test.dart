import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/screens/admin_user_management_screen.dart';
import 'package:frontend_app/screens/admin_vacation_management_screen.dart';
import 'package:frontend_app/screens/calendar_screen.dart';
import 'package:frontend_app/screens/chat_room_list_screen.dart';
import 'package:frontend_app/screens/meeting_minutes_detail_screen.dart';
import 'package:frontend_app/screens/meeting_minutes_list_screen.dart';
import 'package:frontend_app/screens/my_vacation_screen.dart';
import 'package:frontend_app/screens/notice_detail_screen.dart';
import 'package:frontend_app/screens/notice_list_screen.dart';
import 'package:frontend_app/screens/profile_screen.dart';
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

    test('알 수 없는 알림은 아무 화면도 열지 않는다', () {
      expect(screenForNotification(FCMDestination.unknown), isNull);
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
    });

    test('키가 없거나 숫자가 아니면 null — 목록으로 떨어진다', () {
      expect(entityIdFromFCMData(FCMDestination.chat, {}), isNull);
      expect(
        entityIdFromFCMData(FCMDestination.chat, {'roomId': 'abc'}),
        isNull,
      );
    });
  });
}
