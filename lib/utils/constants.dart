class Constants {
  // API 관련 상수 - TODO: 실제 Spring Boot 서버 URL로 변경 필요
  static const String baseUrl = 'https://69af-211-177-230-196.ngrok-free.app/api/v1';

  // API 엔드포인트
  static const String loginEndpoint = '/auth/login';
  static const String signinEndpoint = '/members/signin';
  static const String joinRequestEndpoint = '/members/join-request';
  static const String companiesEndpoint = '/members/companies';
  static const String fcmTokenEndpoint = '/members';
  static const String vacationCalendarEndpoint = '/vacations/calendar';
  static const String vacationDateEndpoint = '/vacations/date';
  static const String vacationSubmitEndpoint = '/vacations/submit';
  static const String vacationLimitsEndpoint = '/vacations/limits';

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
