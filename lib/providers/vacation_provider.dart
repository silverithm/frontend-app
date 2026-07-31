import 'package:flutter/material.dart';
import '../models/vacation_request.dart';
import '../services/api_service.dart';
import '../utils/role_utils.dart';

class VacationProvider with ChangeNotifier {
  List<VacationRequest> _vacationRequests = [];
  Map<DateTime, List<VacationRequest>> _calendarData = {};
  Map<DateTime, int> _vacationLimits = {}; // 날짜별 제한 인원 수
  bool _isLoading = false;
  String _errorMessage = '';
  DateTime _selectedDate = DateTime.now();
  String _roleFilter = RoleUtils.allRole;
  List<String> _availableRoles = [];

  List<VacationRequest> get vacationRequests => _vacationRequests;
  Map<DateTime, List<VacationRequest>> get calendarData => _calendarData;
  Map<DateTime, int> get vacationLimits => _vacationLimits;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  DateTime get selectedDate => _selectedDate;
  String get roleFilter => _roleFilter;

  /// 관리자 화면에서 만든 역할까지 포함한 필터 목록
  List<String> get availableRoles => _availableRoles;

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

  void setRoleFilter(String role) {
    print('[VacationProvider] 역할 필터 변경: $_roleFilter -> $role');
    final oldRole = _roleFilter;
    final normalizedRole = RoleUtils.normalize(role);
    _roleFilter = normalizedRole.isEmpty ? RoleUtils.allRole : normalizedRole;
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
    String? vacationDetailType, // 연차 미사용 세부 유형 (personal/sick/emergency/family/other)
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
        type: type.toString().split('.').last, // 'personal' / 'mandatory' / 'substitute'
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
  Future<bool> deleteVacationByAdmin({
    required String vacationId,
  }) async {
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

    if (_roleFilter == RoleUtils.allRole) {
      print('[VacationProvider] 전체 모드 - 모든 휴무 반환: ${vacations.length}개');
      return vacations;
    }

    // 역할 필터링 시 디버깅 로그 추가
    final filteredVacations = vacations.where((vacation) {
      final match = RoleUtils.matches(vacation.role, _roleFilter);
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
            final currentLimit = _vacationLimits[dateKey];
            _vacationLimits[dateKey] =
                currentLimit == null || maxPeople > currentLimit
                ? maxPeople
                : currentLimit;

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
