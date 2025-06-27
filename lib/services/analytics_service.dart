import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  late final FirebaseAnalytics _analytics;
  late final FirebaseAnalyticsObserver _observer;

  FirebaseAnalytics get analytics => _analytics;
  FirebaseAnalyticsObserver get observer => _observer;

  void initialize() {
    _analytics = FirebaseAnalytics.instance;
    _observer = FirebaseAnalyticsObserver(analytics: _analytics);
  }

  // 화면 조회 이벤트
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );
  }

  // 로그인 이벤트
  Future<void> logLogin({String? method}) async {
    await _analytics.logLogin(loginMethod: method);
  }

  // 로그아웃 이벤트
  Future<void> logLogout() async {
    await _analytics.logEvent(name: 'logout');
  }

  // 휴무 신청 이벤트
  Future<void> logVacationRequest({
    required String vacationType,
    required String startDate,
    required String endDate,
  }) async {
    await _analytics.logEvent(
      name: 'vacation_request',
      parameters: {
        'vacation_type': vacationType,
        'start_date': startDate,
        'end_date': endDate,
      },
    );
  }

  // 휴무 취소 이벤트
  Future<void> logVacationCancel({
    required String vacationType,
    required String date,
  }) async {
    await _analytics.logEvent(
      name: 'vacation_cancel',
      parameters: {'vacation_type': vacationType, 'date': date},
    );
  }

  // 캘린더 조회 이벤트
  Future<void> logCalendarView({
    required String viewType, // month, week, day
    required String date,
  }) async {
    await _analytics.logEvent(
      name: 'calendar_view',
      parameters: {'view_type': viewType, 'date': date},
    );
  }

  // 프로필 조회 이벤트
  Future<void> logProfileView() async {
    await _analytics.logEvent(name: 'profile_view');
  }

  // 사용자 속성 설정
  Future<void> setUserProperties({
    String? userId,
    String? userRole,
    String? companyId,
  }) async {
    if (userId != null) {
      await _analytics.setUserId(id: userId);
    }

    if (userRole != null) {
      await _analytics.setUserProperty(name: 'user_role', value: userRole);
    }

    if (companyId != null) {
      await _analytics.setUserProperty(name: 'company_id', value: companyId);
    }
  }

  // 커스텀 이벤트
  Future<void> logCustomEvent({
    required String eventName,
    Map<String, Object>? parameters,
  }) async {
    await _analytics.logEvent(name: eventName, parameters: parameters);
  }
}
