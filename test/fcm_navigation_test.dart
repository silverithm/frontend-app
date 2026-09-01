import 'package:flutter_test/flutter_test.dart';
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

    test('매핑되지 않은 type은 unknown으로 분류돼 로그로 드러난다', () {
      expect(resolveFCMDestination('never_seen_before'), FCMDestination.unknown);
      expect(resolveFCMDestination(''), FCMDestination.unknown);
    });
  });
}
