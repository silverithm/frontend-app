// 근무조정 계획 보조 정보 — 휴무 입력 마감일(월별 지정 + 매월 고정일), 다음 달만 받기 제한, 중요 행사.
//
// 웹(frontend-admin)의 VacationDeadlineSetting/VacationEvent와 같은 서버 응답을 그대로 받는다.
// 참고: src/lib/apiService.ts getVacationDeadlineSetting/getVacationDeadlineDates/getVacationEvents,
//       src/components/EmployeeCalendar.tsx (달력 표시 규칙의 원본).

/// 휴무 입력 마감일 설정 — 기관당 한 벌.
/// GET/POST /api/vacation/deadline-setting 응답: {deadlineDay, enabled, nextMonthOnly}
class VacationDeadlineSetting {
  /// 마감일이 매월 고정일로 적용될 때의 일자(1~31). 월별 지정(deadlineDates)이 있으면 그게 우선.
  final int deadlineDay;

  /// 마감일 표시 자체를 켰는지 (꺼져 있으면 매월 고정일도 적용하지 않는다)
  final bool enabled;

  /// 켜져 있으면 "바로 다음 달" 휴무만 신청받는다. 서버(VacationController)가 신청 시 다시 검증한다.
  final bool nextMonthOnly;

  const VacationDeadlineSetting({
    required this.deadlineDay,
    required this.enabled,
    required this.nextMonthOnly,
  });

  factory VacationDeadlineSetting.fromJson(Map<String, dynamic> json) {
    return VacationDeadlineSetting(
      deadlineDay: (json['deadlineDay'] as num?)?.toInt() ?? 20,
      enabled: json['enabled'] == true,
      nextMonthOnly: json['nextMonthOnly'] == true,
    );
  }

  static const VacationDeadlineSetting disabled = VacationDeadlineSetting(
    deadlineDay: 20,
    enabled: false,
    nextMonthOnly: false,
  );
}

/// 근무조정 중요 행사 — 관리자가 등록, 직원은 휴무 신청 시 참고만 한다(막지 않음).
/// GET /api/vacation/events 응답 항목: {id, title, description, startDate, endDate, warnOnRequest}
class VacationEvent {
  final int id;
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;

  /// 이 기간에 휴무를 신청하면 안내 배너를 띄울지 여부
  final bool warnOnRequest;

  const VacationEvent({
    required this.id,
    required this.title,
    this.description,
    required this.startDate,
    required this.endDate,
    required this.warnOnRequest,
  });

  factory VacationEvent.fromJson(Map<String, dynamic> json) {
    return VacationEvent(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      description: (json['description'] as String?)?.trim().isNotEmpty == true
          ? json['description'] as String
          : null,
      startDate:
          DateTime.tryParse(json['startDate']?.toString() ?? '') ??
          DateTime.now(),
      endDate:
          DateTime.tryParse(json['endDate']?.toString() ?? '') ??
          DateTime.now(),
      warnOnRequest: json['warnOnRequest'] == true,
    );
  }

  /// 기간(연속일) 행사이므로 그 안의 모든 날짜에 표시한다 (웹과 동일 규칙)
  bool covers(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }
}
