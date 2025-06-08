import 'package:flutter/material.dart';
import '../models/vacation_request.dart';
import '../services/api_service.dart';

class VacationProvider with ChangeNotifier {
  List<VacationRequest> _vacationRequests = [];
  Map<DateTime, List<VacationRequest>> _calendarData = {};
  Map<DateTime, int> _vacationLimits = {}; // 날짜별 제한 인원 수
  bool _isLoading = false;
  String _errorMessage = '';
  DateTime _selectedDate = DateTime.now();
  String _roleFilter = 'all';

  List<VacationRequest> get vacationRequests => _vacationRequests;
  Map<DateTime, List<VacationRequest>> get calendarData => _calendarData;
  Map<DateTime, int> get vacationLimits => _vacationLimits;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  DateTime get selectedDate => _selectedDate;
  String get roleFilter => _roleFilter;

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
    _roleFilter = role;

    // 캘린더 데이터는 이미 모든 역할을 포함하므로 재로드 불필요
    // vacation limits만 필요시 재로드
    if (role != 'all' && oldRole == 'all') {
      // 전체 -> 특정 역할: vacation limits 로드 필요
      final startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

      loadVacationLimits(startDate, endDate).then((_) {
        print(
          '[VacationProvider] 역할 필터 변경 완료 - limits: ${_vacationLimits.length}개',
        );
        notifyListeners();
      });
    } else if (role == 'all' && oldRole != 'all') {
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
    } else if (role != 'all' && oldRole != 'all' && role != oldRole) {
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
        setError(response['error'] ?? '휴가 신청 목록을 불러올 수 없습니다.');
        // 에러 시 빈 목록으로 초기화
        _vacationRequests = [];
      }

      notifyListeners();
    } catch (e) {
      if (e.toString().contains('ApiException')) {
        final errorMsg = e.toString().replaceAll('ApiException: ', '');
        setError(errorMsg.split(' (Status:')[0]);
      } else {
        setError('휴가 신청 목록 로딩에 실패했습니다: ${e.toString()}');
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
    String? reason,
    String? password,
    String? companyId,
  }) async {
    try {
      setLoading(true);
      clearError();

      // Spring Boot API 호출 - companyId 필요
      final response = await ApiService().createVacationRequest(
        userName: userName,
        date: _formatDate(date),
        type: type.toString().split('.').last, // 'personal' 또는 'mandatory'
        reason: reason ?? '',
        role: userRole,
        password: password ?? '',
        companyId: companyId ?? '1', // 기본값 1 사용
        userId: userId,
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
        setError(response['error'] ?? '휴가 신청에 실패했습니다.');
        return false;
      }
    } catch (e) {
      if (e.toString().contains('ApiException')) {
        final errorMsg = e.toString().replaceAll('ApiException: ', '');
        setError(errorMsg.split(' (Status:')[0]);
      } else {
        setError('휴가 신청에 실패했습니다: ${e.toString()}');
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

      // TODO: 휴가 신청 취소 API 호출 구현 필요
      // 현재는 로컬에서만 제거
      _vacationRequests.removeWhere((request) => request.id == requestId);

      // 캘린더 데이터에서도 제거
      _calendarData.forEach((date, requests) {
        requests.removeWhere((request) => request.id == requestId);
      });

      notifyListeners();
      return true;
    } catch (e) {
      setError('휴가 신청 취소에 실패했습니다: ${e.toString()}');
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
        setError(response['error'] ?? '휴가 신청 삭제에 실패했습니다.');
        return false;
      }
    } catch (e) {
      if (e.toString().contains('ApiException')) {
        final errorMsg = e.toString().replaceAll('ApiException: ', '');
        setError(errorMsg.split(' (Status:')[0]);
      } else {
        setError('휴가 신청 삭제에 실패했습니다: ${e.toString()}');
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
        role: _roleFilter == 'all' ? 'CAREGIVER' : _roleFilter,
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
      print('날짜별 휴가 데이터 로딩 실패: $e');
    }
  }

  List<VacationRequest> getVacationsForDate(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    final vacations = _calendarData[dateKey] ?? [];

    print(
      '[VacationProvider] getVacationsForDate - 날짜: ${_formatDate(date)}, 전체 휴무: ${vacations.length}개, 현재 필터: $_roleFilter',
    );

    if (_roleFilter == 'all') {
      print('[VacationProvider] 전체 모드 - 모든 휴무 반환: ${vacations.length}개');
      return vacations;
    }

    // 역할 필터링 시 디버깅 로그 추가
    final filteredVacations = vacations.where((vacation) {
      final match = vacation.role.toUpperCase() == _roleFilter.toUpperCase();
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

  // vacation limits 로드
  Future<void> loadVacationLimits(
    DateTime start,
    DateTime end, {
    String? companyId,
  }) async {
    try {
      // 전체 모드일 때는 vacation limits를 요청하지 않음
      if (_roleFilter == 'all') {
        print('[VacationProvider] 전체 모드 - vacation limits 요청 생략');
        // 기본값으로 설정
        _vacationLimits.clear();
        for (
          var date = start;
          date.isBefore(end.add(const Duration(days: 1)));
          date = date.add(const Duration(days: 1))
        ) {
          _vacationLimits[DateTime(date.year, date.month, date.day)] =
              3; // 전체 모드일 때도 기본값 3으로 설정
        }
        return;
      }

      // Spring Boot API 호출 - role 필터 포함
      final apiRole = _roleFilter == 'OFFICE' ? 'OFFICE' : 'CAREGIVER';
      print(
        '[VacationProvider] API 호출 - 현재 필터: $_roleFilter, API 역할: $apiRole',
      );

      final response = await ApiService().getVacationLimits(
        start: _formatDate(start),
        end: _formatDate(end),
        companyId: companyId ?? '1',
        role: apiRole, // 정확한 role 매핑 사용
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
            final itemRole = limitItem['role'] as String?;

            // 현재 선택된 역할과 일치하는 데이터만 사용
            String expectedRole;
            if (_roleFilter == 'CAREGIVER') {
              expectedRole = 'caregiver';
            } else if (_roleFilter == 'OFFICE') {
              expectedRole = 'office';
            } else {
              continue; // 예상치 못한 역할은 건너뛰기
            }

            if (itemRole != null && itemRole.toLowerCase() == expectedRole) {
              final date = DateTime.parse(dateStr);
              _vacationLimits[DateTime(date.year, date.month, date.day)] =
                  maxPeople;

              print(
                '[VacationProvider] 역할 일치 - 날짜: $dateStr, 역할: $itemRole->$expectedRole, 제한: $maxPeople',
              );
            } else {
              print(
                '[VacationProvider] 역할 불일치 - 기대: $expectedRole, 실제: $itemRole',
              );
            }
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
      setError('휴가 제한 정보를 불러오는데 실패했습니다: $e');
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
