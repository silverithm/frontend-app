class Constants {
  // API 관련 상수 - TODO: 실제 Spring Boot 서버 URL로 변경 필요
  static const String baseUrl = 'https://silverithm.site/api';

  // API 엔드포인트
  static const String loginEndpoint = '/auth/login';
  static const String signinEndpoint = '/v1/members/signin';
  static const String adminSigninEndpoint = '/v1/signin';
  static const String refreshTokenEndpoint = '/v1/refresh-token';
  static const String validateTokenEndpoint = '/v1/validate-token';
  static const String joinRequestEndpoint = '/v1/members/join-request';
  static const String withdrawalEndpoint = '/v1/members/withdrawal';
  static const String companiesEndpoint = '/v1/members/companies';
  static const String fcmTokenEndpoint = '/v1/members';
  static const String vacationCalendarEndpoint = '/vacation/calendar';
  static const String vacationDateEndpoint = '/vacation/date';
  static const String vacationSubmitEndpoint = '/vacation/submit';
  static const String vacationLimitsEndpoint = '/vacation/limits';
  // 개인 휴무 관련 엔드포인트
  static const String myVacationRequestsEndpoint = '/vacation/my/requests';
  // 알림 관련 엔드포인트
  static const String notificationsEndpoint = '/notifications/user';
  // 비밀번호 찾기 및 역할 변경 엔드포인트
  static const String findPasswordEndpoint = '/v1/members/find/password';
  static const String changePasswordEndpoint = '/v1/members/change/password';
  static const String updateRoleEndpoint = '/v1/members/role';

  // 저장소 키
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';

  // UI 관련 상수
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;

  // 애니메이션 지속 시간
  static const Duration animationDuration = Duration(milliseconds: 300);
}
