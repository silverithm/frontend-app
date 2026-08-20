import 'package:flutter/material.dart';
import '../models/vacation_planning.dart';
import '../models/vacation_request.dart';
import '../services/api_service.dart';
import '../utils/korean_holidays.dart';
import '../utils/role_utils.dart';

class VacationProvider with ChangeNotifier {
  List<VacationRequest> _vacationRequests = [];
  Map<DateTime, List<VacationRequest>> _calendarData = {};
  Map<DateTime, int> _vacationLimits = {}; // 날짜별 제한 인원 수
  // '전체(all)' 한도가 직접 설정된 날짜 — 직종 최댓값으로 덮이면 안 된다
  final Set<DateTime> _allLimitDates = {};
  bool _isLoading = false;
  String _errorMessage = '';
  DateTime _selectedDate = DateTime.now();
  String _roleFilter = RoleUtils.allRole;
  List<String> _roleFilters = [];
  List<String> _availableRoles = [];

  // 휴무 입력 마감일 설정 (다음 달만 받기 포함) — 기관당 한 벌, 자주 바뀌지 않아 세션 중 1회만 로드
  VacationDeadlineSetting _deadlineSetting = VacationDeadlineSetting.disabled;
  bool _planningSettingsLoaded = false;

  // 월별 마감일 직접 지정 — {"2026-08": "2026-08-16", ...} (키: 마감일이 속한 달)
  Map<String, DateTime> _deadlineDates = {};

  // 근무조정 중요 행사 — 현재 보고 있는 달 기준으로 로드
  List<VacationEvent> _events = [];

  List<VacationRequest> get vacationRequests => _vacationRequests;
  Map<DateTime, List<VacationRequest>> get calendarData => _calendarData;
  Map<DateTime, int> get vacationLimits => _vacationLimits;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  DateTime get selectedDate => _selectedDate;
  String get roleFilter => _roleFilter;
  List<String> get roleFilters => List.unmodifiable(_roleFilters);

  /// 관리자 화면에서 만든 역할까지 포함한 필터 목록
  List<String> get availableRoles => _availableRoles;

  VacationDeadlineSetting get deadlineSetting => _deadlineSetting;
  List<VacationEvent> get events => List.unmodifiable(_events);

  /// 기관이 "다음 달만 받기"를 켰는지
  bool get isNextMonthOnly => _deadlineSetting.nextMonthOnly;

  /// "다음 달만 받기"가 켜져 있을 때 신청 가능한 유일한 달 (매번 현재 시각 기준으로 계산)
  DateTime get nextMonthOnlyMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 1);
  }

  /// 이 날짜로 휴무를 신청할 수 있는지 — "다음 달만 받기"가 꺼져 있으면 항상 true.
  /// 서버(VacationController.validateNextMonthOnly)가 신청 시 같은 규칙으로 다시 검증한다.
  bool isDateAllowedForRequest(DateTime date) {
    if (!isNextMonthOnly) return true;
    final target = nextMonthOnlyMonth;
    return date.year == target.year && date.month == target.month;
  }

  /// 특정 달에 적용되는 마감일 — 월별 지정이 있으면 그 날짜, 없으면 매월 고정일(말일 클램프).
  /// 마감일 표시 자체가 꺼져 있으면 null.
  DateTime? deadlineForMonth(DateTime month) {
    final key =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    final override = _deadlineDates[key];
    if (override != null) return override;
    if (!_deadlineSetting.enabled) return null;
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final day = _deadlineSetting.deadlineDay.clamp(1, lastDay);
    return DateTime(month.year, month.month, day);
  }

  /// 그 달의 마감일이 이미 지났는지 (마감일 당일까지는 아직 유효한 것으로 본다)
  bool isDeadlinePassedForMonth(DateTime month) {
    final deadline = deadlineForMonth(month);
    if (deadline == null) return false;
    return _isPastEndOfDay(deadline);
  }

  /// [targetMonth]월 휴무의 '신청 마감일' — 마감일은 항상 그 전 달에 위치한다.
  /// (예: 9월 휴무는 8월 16일까지 신청 — 8월에 있는 마감일이 9월분을 관장한다.
  /// 서버 스케줄러(VacationDeadlinePreReminderScheduler)와 같은 의미론.)
  /// [deadlineForMonth]는 "그 달 안에 있는 마감일"이라 화면의 '이 달 휴무 마감'
  /// 표시에 그대로 쓰면 한 달 밀려 보인다 — 신청 안내에는 반드시 이 메서드를 쓴다.
  DateTime? deadlineForTargetMonth(DateTime targetMonth) {
    return deadlineForMonth(
      DateTime(targetMonth.year, targetMonth.month - 1, 1),
    );
  }

  /// [targetMonth]월 휴무의 신청 마감이 이미 지났는지
  bool isDeadlinePassedForTargetMonth(DateTime targetMonth) {
    final deadline = deadlineForTargetMonth(targetMonth);
    if (deadline == null) return false;
    return _isPastEndOfDay(deadline);
  }

  bool _isPastEndOfDay(DateTime deadline) {
    final endOfDeadlineDay = DateTime(
      deadline.year,
      deadline.month,
      deadline.day,
      23,
      59,
      59,
    );
    return DateTime.now().isAfter(endOfDeadlineDay);
  }

  /// 그 날짜에 걸친 중요 행사들 (기간 행사는 매일 표시 — 웹과 동일 규칙)
  List<VacationEvent> eventsForDate(DateTime date) {
    return _events.where((e) => e.covers(date)).toList();
  }

  /// 공휴일이면 이름을, 아니면 null
  String? holidayNameForDate(DateTime date) =>
      KoreanHolidays.getHolidayName(date);

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  /// 직종 다중 선택 (빈 목록 = 전체). 단일 한도 조회 등 기존 로직과의
  /// 동기화를 위해 setRoleFilter를 경유한다 — 1개 선택일 때만 그 직종,
  /// 그 외에는 전체로 동작하고 목록 필터링은 _roleFilters로 정밀 처리.
  void setRoleFilters(List<String> roles) {
    final normalized = roles
        .map(RoleUtils.normalize)
        .where((r) => r.isNotEmpty && r != RoleUtils.allRole)
        .toSet()
        .toList();
    setRoleFilter(
      normalized.length == 1 ? normalized.first : RoleUtils.allRole,
    );
    _roleFilters = normalized; // setRoleFilter의 단일 동기화를 다중 값으로 덮어쓴다
    notifyListeners();
  }

  void setRoleFilter(String role) {
    print('[VacationProvider] 역할 필터 변경: $_roleFilter -> $role');
    final oldRole = _roleFilter;
    final normalizedRole = RoleUtils.normalize(role);
    _roleFilter = normalizedRole.isEmpty ? RoleUtils.allRole : normalizedRole;
    _roleFilters = _roleFilter == RoleUtils.allRole ? [] : [_roleFilter];
    final newRole = _roleFilter;

    // 캘린더 데이터는 이미 모든 역할을 포함하므로 재로드 불필요
    // vacation limits만 필요시 재로드
    if (newRole != RoleUtils.allRole && oldRole == RoleUtils.allRole) {
      // 전체 -> 특정 역할: vacation limits 로드 필요
      final startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

      loadVacationLimits(startDate, endDate).then((_) {
        print(
          '[VacationProvider] 역할 필터 변경 완료 - limits: ${_vacationLimits.length}개',
        );
        notifyListeners();
      });
    } else if (newRole == RoleUtils.allRole && oldRole != RoleUtils.allRole) {
      // 특정 역할 -> 전체: vacation limits 기본값 설정
      final startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

      _vacationLimits.clear();
      for (
        var date = startDate;
        date.isBefore(endDate.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))
      ) {
        _vacationLimits[DateTime(date.year, date.month, date.day)] = 3;
      }
      print('[VacationProvider] 전체 모드로 변경 - 기본값 설정 완료');
      notifyListeners();
    } else if (newRole != RoleUtils.allRole &&
        oldRole != RoleUtils.allRole &&
        newRole != oldRole) {
      // 특정 역할 간 변경: vacation limits 재로드 필요
      final startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

      loadVacationLimits(startDate, endDate).then((_) {
        print(
          '[VacationProvider] 역할 필터 변경 완료 - limits: ${_vacationLimits.length}개',
        );
        notifyListeners();
      });
    } else {
      // 변경 없음 또는 기타 경우: 바로 업데이트
      notifyListeners();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> loadCalendarData(DateTime month, {String? companyId}) async {
    try {
      setLoading(true);
      clearError();

      // 월의 시작일과 마지막일 계산
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0);

      // Spring Boot API 호출 - companyId 필요, roleFilter는 'all'로 고정하여 모든 데이터 로드
      final response = await ApiService().getVacationCalendar(
        startDate: _formatDate(startDate),
        endDate: _formatDate(endDate),
        companyId: companyId ?? '1', // 기본값 1 사용
        roleFilter: 'all', // 모든 역할의 데이터를 가져옴
      );

      print('[VacationProvider] 캘린더 API 호출 - 모든 역할 데이터 요청');

      // API 응답을 캘린더 데이터로 변환
      _calendarData.clear();

      if (response['dates'] != null) {
        final datesMap = response['dates'] as Map<String, dynamic>;

        for (final entry in datesMap.entries) {
          final dateStr = entry.key;
          final dateInfo = entry.value as Map<String, dynamic>;
          final vacations = dateInfo['vacations'] as List? ?? [];

          final date = DateTime.parse(dateStr);
          final dateKey = DateTime(date.year, date.month, date.day);

          _calendarData[dateKey] = vacations
              .map((v) => VacationRequest.fromJson(v))
              .toList();
        }

        print(
          '[VacationProvider] 실제 캘린더 데이터 로드 완료: ${_calendarData.length}개 날짜',
        );
      } else {
        print('[VacationProvider] API 응답에 dates 없음 - 빈 캘린더로 설정');
        // 빈 캘린더 데이터로 설정 (임시 데이터 생성하지 않음)
      }

      // vacation limits도 함께 로드
      await loadVacationLimits(startDate, endDate, companyId: companyId);

      // 역할 필터 목록도 갱신 (관리자가 만든 역할 반영)
      await loadAvailableRoles(companyId: companyId);

      // 마감일 설정(다음 달만 받기 포함)은 세션 중 1회만, 중요 행사는 달이 바뀔 때마다 로드
      await loadPlanningSettings(companyId: companyId);
      await loadEvents(month, companyId: companyId);

      notifyListeners();
    } catch (e) {
      print('[VacationProvider] 캘린더 데이터 로드 에러: $e');
      setError('캘린더 데이터 로딩에 실패했습니다: ${e.toString()}');

      // 모든 에러 상황에서 빈 캘린더로 처리 (임시 데이터 생성하지 않음)
      _calendarData.clear();

      notifyListeners();
    } finally {
      setLoading(false);
    }
  }

  /// 휴무 입력 마감일 설정(다음 달만 받기 포함) + 월별 마감일 지정 로드.
  /// 조회 실패는 제한 없음으로 본다 — 마감일 안내는 편의 기능이라 실패로 휴무 조회 자체를 막지 않는다.
  Future<void> loadPlanningSettings({
    String? companyId,
    bool forceReload = false,
  }) async {
    if (_planningSettingsLoaded && !forceReload) return;
    final id = companyId ?? '1';

    try {
      final response = await ApiService().getVacationDeadlineSetting(
        companyId: id,
      );
      _deadlineSetting = VacationDeadlineSetting.fromJson(response);
    } catch (e) {
      print('[VacationProvider] 휴무 마감일 설정 로드 실패: $e');
      _deadlineSetting = VacationDeadlineSetting.disabled;
    }

    try {
      final response = await ApiService().getVacationDeadlineDates(
        companyId: id,
      );
      final dates = response['dates'];
      final parsed = <String, DateTime>{};
      if (dates is Map) {
        for (final entry in dates.entries) {
          final parsedDate = DateTime.tryParse(entry.value.toString());
          if (parsedDate != null) {
            parsed[entry.key.toString()] = parsedDate;
          }
        }
      }
      _deadlineDates = parsed;
    } catch (e) {
      print('[VacationProvider] 월별 마감일 지정 로드 실패: $e');
      _deadlineDates = {};
    }

    _planningSettingsLoaded = true;
    notifyListeners();
  }

  /// 근무조정 중요 행사 로드. 다음 달 휴무를 신청하는 흐름이 많아 보고 있는 달의 다음 달까지 함께 받는다.
  Future<void> loadEvents(DateTime month, {String? companyId}) async {
    try {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 2, 0);
      final response = await ApiService().getVacationEvents(
        companyId: companyId ?? '1',
        startDate: _formatDate(start),
        endDate: _formatDate(end),
      );
      final list = response['events'];
      _events = list is List
          ? list
                .whereType<Map>()
                .map(
                  (e) => VacationEvent.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : [];
      notifyListeners();
    } catch (e) {
      print('[VacationProvider] 중요 행사 로드 실패: $e');
      _events = [];
    }
  }

  Future<void> loadMyVacationRequests(
    String userId, {
    String? companyId,
    String? userName,
  }) async {
    try {
      setLoading(true);
      clearError();

      // companyId와 userName이 필요하므로 옵셔널 파라미터로 받음
      if (companyId == null || userName == null) {
        setError('회사 정보와 사용자 이름이 필요합니다.');
        return;
      }

      // Spring Boot API 호출
      final response = await ApiService().getMyVacationRequests(
        companyId: companyId,
        userName: userName,
        userId: userId,
      );

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> vacationsList = response['data'];
        _vacationRequests = vacationsList
            .map((v) => VacationRequest.fromJson(v))
            .toList();
      } else {
        setError(response['error'] ?? '휴무 신청 목록을 불러올 수 없습니다.');
        // 에러 시 빈 목록으로 초기화
        _vacationRequests = [];
      }

      notifyListeners();
    } catch (e) {
      if (e.toString().contains('ApiException')) {
        final errorMsg = e.toString().replaceAll('ApiException: ', '');
        setError(errorMsg.split(' (Status:')[0]);
      } else {
        setError('휴무 신청 목록 로딩에 실패했습니다: ${e.toString()}');
      }
      // 에러 시 빈 목록으로 초기화
      _vacationRequests = [];
      notifyListeners();
    } finally {
      setLoading(false);
    }
  }

  Future<bool> createVacationRequest({
    required String userId,
    required String userName,
    required String userRole,
    required DateTime date,
    required VacationType type,
    required VacationDuration duration,
    required bool isVacationUsed, // 연차 사용 여부 추가
    String?
    vacationDetailType, // 연차 미사용 세부 유형 (personal/sick/emergency/family/other)
    String? reason,
    String? password,
    String? companyId,
  }) async {
    try {
      setLoading(true);
      clearError();

      // 연차 사용 여부에 따라 API 형식 결정
      String durationString;
      if (!isVacationUsed) {
        // 미사용인 경우
        durationString = 'UNUSED';
      } else {
        // 사용인 경우 선택된 duration에 따라 변환
        switch (duration) {
          case VacationDuration.unused:
            durationString = 'UNUSED'; // 이 경우는 발생하지 않아야 함
            break;
          case VacationDuration.fullDay:
            durationString = 'FULL_DAY';
            break;
          case VacationDuration.halfDayAm:
            durationString = 'HALF_DAY_AM';
            break;
          case VacationDuration.halfDayPm:
            durationString = 'HALF_DAY_PM';
            break;
        }
      }

      // 대체휴무는 세부유형도 substitute로 통일 (백엔드 isSubstitute 판정 규칙)
      final String? effectiveDetailType = type == VacationType.substitute
          ? 'substitute'
          : (!isVacationUsed ? vacationDetailType : null);

      // Spring Boot API 호출 - companyId 필요
      final response = await ApiService().createVacationRequest(
        userName: userName,
        date: _formatDate(date),
        type: type
            .toString()
            .split('.')
            .last, // 'personal' / 'mandatory' / 'substitute'
        vacationType: effectiveDetailType,
        reason: reason ?? '',
        role: userRole,
        password: password ?? '',
        companyId: companyId ?? '1', // 기본값 1 사용
        userId: userId,
        duration: durationString, // 변환된 duration 전송
      );

      if (response['success'] == true && response['data'] != null) {
        // 성공 시 로컬 데이터 업데이트
        final newRequest = VacationRequest.fromJson(response['data']);
        _vacationRequests.add(newRequest);

        // 캘린더 데이터에도 추가
        final dateKey = DateTime(date.year, date.month, date.day);
        if (_calendarData.containsKey(dateKey)) {
          _calendarData[dateKey]!.add(newRequest);
        } else {
          _calendarData[dateKey] = [newRequest];
        }

        notifyListeners();
        return true;
      } else {
        setError(response['error'] ?? '휴무 신청에 실패했습니다.');
        return false;
      }
    } catch (e) {
      if (e.toString().contains('ApiException')) {
        final errorMsg = e.toString().replaceAll('ApiException: ', '');
        setError(errorMsg.split(' (Status:')[0]);
      } else {
        setError('휴무 신청에 실패했습니다: ${e.toString()}');
      }
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<bool> cancelVacationRequest(String requestId) async {
    try {
      setLoading(true);
      clearError();

      // TODO: 휴무 신청 취소 API 호출 구현 필요
      // 현재는 로컬에서만 제거
      _vacationRequests.removeWhere((request) => request.id == requestId);

      // 캘린더 데이터에서도 제거
      _calendarData.forEach((date, requests) {
        requests.removeWhere((request) => request.id == requestId);
      });

      notifyListeners();
      return true;
    } catch (e) {
      setError('휴무 신청 취소에 실패했습니다: ${e.toString()}');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // 내 휴무 신청 삭제 (Spring Boot API 연동)
  Future<bool> deleteMyVacationRequest({
    required String vacationId,
    required String userName,
    required String userId,
    required String password,
  }) async {
    try {
      setLoading(true);
      clearError();

      // Spring Boot API 호출
      final response = await ApiService().deleteMyVacationRequest(
        vacationId: vacationId,
        userName: userName,
        userId: userId,
        password: password,
      );

      if (response['message'] != null) {
        // 성공 시 로컬 데이터에서 제거
        _vacationRequests.removeWhere((request) => request.id == vacationId);

        // 캘린더 데이터에서도 제거
        _calendarData.forEach((date, requests) {
          requests.removeWhere((request) => request.id == vacationId);
        });

        notifyListeners();
        return true;
      } else {
        setError(response['error'] ?? '휴무 신청 삭제에 실패했습니다.');
        return false;
      }
    } catch (e) {
      if (e.toString().contains('ApiException')) {
        final errorMsg = e.toString().replaceAll('ApiException: ', '');
        setError(errorMsg.split(' (Status:')[0]);
      } else {
        setError('휴무 신청 삭제에 실패했습니다: ${e.toString()}');
      }
      return false;
    } finally {
      setLoading(false);
    }
  }

  // 관리자용 휴무 삭제 (Spring Boot API 연동)
  Future<bool> deleteVacationByAdmin({required String vacationId}) async {
    try {
      setLoading(true);
      clearError();

      print('[VacationProvider] 관리자 휴무 삭제 요청 시작 - ID: $vacationId');

      // 관리자용 휴무 삭제 API 호출
      final response = await ApiService().deleteVacationByAdmin(
        vacationId: vacationId,
      );

      print('[VacationProvider] 관리자 휴무 삭제 API 응답: $response');

      // 성공 시 로컬 데이터에서 제거
      _vacationRequests.removeWhere((request) => request.id == vacationId);

      // 캘린더 데이터에서도 제거
      _calendarData.forEach((date, requests) {
        requests.removeWhere((request) => request.id == vacationId);
      });

      print('[VacationProvider] 관리자 휴무 삭제 성공 - 로컬 데이터 업데이트 완료');
      notifyListeners();
      return true;
    } catch (e) {
      print('[VacationProvider] 관리자 휴무 삭제 실패: $e');
      if (e.toString().contains('ApiException')) {
        final errorMsg = e.toString().replaceAll('ApiException: ', '');
        setError(errorMsg.split(' (Status:')[0]);
      } else {
        setError('관리자 휴무 삭제에 실패했습니다: ${e.toString()}');
      }
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<void> loadVacationForDate(DateTime date, {String? companyId}) async {
    try {
      final response = await ApiService().getVacationForDate(
        date: _formatDate(date),
        companyId: companyId ?? '1', // 기본값 1 사용
        role: _roleFilter,
      );

      if (response['vacations'] != null) {
        final vacations = (response['vacations'] as List)
            .map((v) => VacationRequest.fromJson(v))
            .toList();

        final dateKey = DateTime(date.year, date.month, date.day);
        _calendarData[dateKey] = vacations;
        notifyListeners();
      }
    } catch (e) {
      // 에러 시 기존 데이터 유지
      print('날짜별 휴무 데이터 로딩 실패: $e');
    }
  }

  List<VacationRequest> getVacationsForDate(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    final vacations = _calendarData[dateKey] ?? [];

    print(
      '[VacationProvider] getVacationsForDate - 날짜: ${_formatDate(date)}, 전체 휴무: ${vacations.length}개, 현재 필터: $_roleFilter',
    );

    if (_roleFilters.isEmpty) {
      print('[VacationProvider] 전체 모드 - 모든 휴무 반환: ${vacations.length}개');
      return vacations;
    }

    // 직종 다중 선택: 선택된 직종 중 하나라도 일치하면 통과
    final filteredVacations = vacations.where((vacation) {
      final match = _roleFilters.any(
        (f) => RoleUtils.matches(vacation.role, f),
      );
      print(
        '[VacationProvider] 휴무 필터링 - 사용자: ${vacation.userName}, 역할: ${vacation.role}, 필터: $_roleFilter, 일치: $match',
      );
      return match;
    }).toList();

    print(
      '[VacationProvider] 필터링 결과: ${filteredVacations.length}개 (전체 ${vacations.length}개 중)',
    );
    return filteredVacations;
  }

  int getVacationCountForDate(DateTime date) {
    return getVacationsForDate(date).length;
  }

  bool isDateFull(DateTime date, {int maxPeople = 3}) {
    return getVacationCountForDate(date) >= maxPeople;
  }

  /// 역할 필터 목록 갱신.
  /// 관리자 화면에서 만든 역할(Position)을 우선 쓰고, 캘린더에 실제로 나타난 역할을 덧붙인다.
  Future<void> loadAvailableRoles({String? companyId}) async {
    final roles = <String>[];
    final seen = <String>{};

    void addRole(String? value) {
      final normalizedRole = RoleUtils.normalize(value);
      if (normalizedRole.isEmpty ||
          normalizedRole == RoleUtils.allRole ||
          normalizedRole == 'admin' ||
          normalizedRole == 'employee' ||
          !seen.add(normalizedRole)) {
        return;
      }

      roles.add(normalizedRole);
    }

    try {
      final response = await ApiService().getPositions(
        companyId: companyId ?? '1',
      );
      final positions = (response['positions'] as List?) ?? [];
      for (final position in positions) {
        if (position is Map) {
          addRole(position['name']?.toString());
        }
      }
    } catch (e) {
      // 역할 목록 조회 실패는 캘린더 사용을 막지 않는다
      print('[VacationProvider] 역할 목록 로드 실패: $e');
    }

    for (final vacations in _calendarData.values) {
      for (final vacation in vacations) {
        addRole(vacation.role);
      }
    }

    if (roles.isEmpty) {
      addRole('caregiver');
      addRole('office');
    }

    _availableRoles = roles;
    print('[VacationProvider] 역할 필터 목록: $_availableRoles');
    notifyListeners();
  }

  // vacation limits 로드
  Future<void> loadVacationLimits(
    DateTime start,
    DateTime end, {
    String? companyId,
  }) async {
    try {
      // 서버는 기간 내 모든 역할의 상한을 내려주므로 현재 필터에 맞는 값만 골라 쓴다
      print('[VacationProvider] API 호출 - 현재 필터: $_roleFilter');

      final response = await ApiService().getVacationLimits(
        start: _formatDate(start),
        end: _formatDate(end),
        companyId: companyId ?? '1',
        role: _roleFilter,
      );

      print('[VacationProvider] vacation limits 응답: $response');

      // 응답을 vacationLimits Map으로 변환
      _vacationLimits.clear();
      _allLimitDates.clear();

      if (response['limits'] != null) {
        final limitsList = response['limits'] as List;

        print('[VacationProvider] API 응답 limits 개수: ${limitsList.length}');

        for (final limitItem in limitsList) {
          try {
            final dateStr = limitItem['date'] as String;
            final maxPeople = limitItem['maxPeople'] as int? ?? 3;
            final itemRole = limitItem['role']?.toString();

            // 특정 역할을 보고 있으면 그 역할의 상한만, 전체 모드면 역할별 상한 중 최댓값
            if (!RoleUtils.matches(itemRole, _roleFilter)) {
              print(
                '[VacationProvider] 역할 불일치 - 필터: $_roleFilter, 실제: $itemRole',
              );
              continue;
            }

            final date = DateTime.parse(dateStr);
            final dateKey = DateTime(date.year, date.month, date.day);
            // 관리자가 '전체(all)' 한도를 직접 건 날짜는 그 값이 정답 —
            // 직종별 최댓값 누적으로 덮이지 않게 확정 기록한다
            final isAllRow = (itemRole ?? '').toLowerCase() == 'all';
            if (isAllRow) {
              _vacationLimits[dateKey] = maxPeople;
              _allLimitDates.add(dateKey);
            } else if (!_allLimitDates.contains(dateKey)) {
              final currentLimit = _vacationLimits[dateKey];
              _vacationLimits[dateKey] =
                  currentLimit == null || maxPeople > currentLimit
                  ? maxPeople
                  : currentLimit;
            }

            print(
              '[VacationProvider] 역할 일치 - 날짜: $dateStr, 역할: $itemRole, 제한: $maxPeople',
            );
          } catch (e) {
            print('[VacationProvider] limit 파싱 오류: $limitItem - $e');
          }
        }

        print(
          '[VacationProvider] vacation limits 파싱 완료: ${_vacationLimits.length}개',
        );
      }

      // API 응답이 없거나 빈 배열인 경우 기본값 설정
      if (_vacationLimits.isEmpty) {
        print('[VacationProvider] limits가 비어있음 - 기본값 3으로 설정');
        for (
          var date = start;
          date.isBefore(end.add(const Duration(days: 1)));
          date = date.add(const Duration(days: 1))
        ) {
          _vacationLimits[DateTime(date.year, date.month, date.day)] = 3;
        }
        print('[VacationProvider] 기본값 설정 완료: ${_vacationLimits.length}개 날짜');
      }

      print(
        '[VacationProvider] vacation limits 로드 완료: ${_vacationLimits.length}개 날짜',
      );
    } catch (e) {
      print('[VacationProvider] vacation limits 로드 실패: $e');
      setError('휴무 제한 정보를 불러오는데 실패했습니다: $e');
    }
  }

  // 날짜별 여유 인원 체크
  bool isDateAvailable(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    final currentCount = getVacationCountForDate(date);
    final limit = _vacationLimits[dateKey] ?? 3;
    return currentCount < limit;
  }

  // 날짜별 제한 인원 가져오기
  int getVacationLimitForDate(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    return _vacationLimits[dateKey] ?? 3;
  }
}
