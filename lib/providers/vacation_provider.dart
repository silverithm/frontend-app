import 'package:flutter/material.dart';
import '../models/vacation_request.dart';
import '../services/api_service.dart';

class VacationProvider with ChangeNotifier {
  List<VacationRequest> _vacationRequests = [];
  Map<DateTime, List<VacationRequest>> _calendarData = {};
  bool _isLoading = false;
  String _errorMessage = '';
  DateTime _selectedDate = DateTime.now();
  String _roleFilter = 'all';

  List<VacationRequest> get vacationRequests => _vacationRequests;
  Map<DateTime, List<VacationRequest>> get calendarData => _calendarData;
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
    _roleFilter = role;
    notifyListeners();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> loadCalendarData(DateTime month) async {
    try {
      setLoading(true);
      clearError();

      // 월의 시작일과 마지막일 계산
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0);

      // Spring Boot API 호출
      final response = await ApiService().getVacationCalendar(
        startDate: _formatDate(startDate),
        endDate: _formatDate(endDate),
        roleFilter: _roleFilter,
      );

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
      }

      notifyListeners();
    } catch (e) {
      setError('캘린더 데이터 로딩에 실패했습니다: ${e.toString()}');
      // 에러 시 임시 데이터 생성 (개발 중)
      _generateMockCalendarData(month);
      notifyListeners();
    } finally {
      setLoading(false);
    }
  }

  Future<void> loadMyVacationRequests(String userId) async {
    try {
      setLoading(true);
      clearError();

      // TODO: 사용자별 휴가 신청 목록 API 추가 필요
      // 현재는 임시 데이터 사용
      _generateMockVacationRequests(userId);

      notifyListeners();
    } catch (e) {
      setError('휴가 신청 목록 로딩에 실패했습니다: ${e.toString()}');
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
  }) async {
    try {
      setLoading(true);
      clearError();

      // Spring Boot API 호출
      final response = await ApiService().createVacationRequest(
        userName: userName,
        date: _formatDate(date),
        type: type.toString().split('.').last, // 'personal' 또는 'mandatory'
        reason: reason ?? '',
        role: userRole,
        password: password ?? '',
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

  Future<void> loadVacationForDate(DateTime date) async {
    try {
      final response = await ApiService().getVacationForDate(
        date: _formatDate(date),
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

    if (_roleFilter == 'all') {
      return vacations;
    }

    return vacations.where((vacation) => vacation.role == _roleFilter).toList();
  }

  int getVacationCountForDate(DateTime date) {
    return getVacationsForDate(date).length;
  }

  bool isDateFull(DateTime date, {int maxPeople = 3}) {
    return getVacationCountForDate(date) >= maxPeople;
  }

  // 개발 중 임시 데이터 생성 (API 연결 후 제거 예정)
  void _generateMockCalendarData(DateTime month) {
    _calendarData.clear();

    final random = DateTime.now().millisecondsSinceEpoch;

    // 이번 달의 몇 개 날짜에 임시 휴가 데이터 추가
    for (int i = 1; i <= 31; i++) {
      try {
        final date = DateTime(month.year, month.month, i);
        if (date.month != month.month) break;

        // 랜덤으로 휴가 신청자 생성
        if ((random + i) % 5 == 0) {
          final vacations = <VacationRequest>[];

          for (int j = 0; j < ((random + i) % 3) + 1; j++) {
            vacations.add(
              VacationRequest(
                id: '${date.millisecondsSinceEpoch}_$j',
                userId: 'user_$j',
                userName: '직원${j + 1}',
                role: j % 2 == 0 ? 'CAREGIVER' : 'OFFICE',
                date: date,
                status: VacationStatus.values[(random + i + j) % 3],
                type: j == 0 ? VacationType.mandatory : VacationType.personal,
                duration: j % 2 == 0
                    ? VacationDuration.fullDay
                    : VacationDuration.halfDay,
                createdAt: DateTime.now().subtract(Duration(days: j)),
              ),
            );
          }

          _calendarData[date] = vacations;
        }
      } catch (e) {
        // 날짜 생성 오류 무시
      }
    }
  }

  void _generateMockVacationRequests(String userId) {
    _vacationRequests.clear();

    final now = DateTime.now();

    // 지난 달, 이번 달, 다음 달의 휴가 신청 데이터 생성
    for (int i = 0; i < 10; i++) {
      final date = now.add(Duration(days: (i * 7) - 30));

      _vacationRequests.add(
        VacationRequest(
          id: 'request_$i',
          userId: userId,
          userName: '김직원',
          role: 'CAREGIVER',
          date: date,
          status: VacationStatus.values[i % 3],
          type: i % 3 == 0 ? VacationType.mandatory : VacationType.personal,
          duration: i % 2 == 0
              ? VacationDuration.fullDay
              : VacationDuration.halfDay,
          reason: i % 2 == 0 ? '개인 사정' : null,
          createdAt: now.subtract(Duration(days: i)),
          approvedAt: i % 3 == 1 ? now.subtract(Duration(days: i - 1)) : null,
          approvedBy: i % 3 == 1 ? 'admin' : null,
          rejectionReason: i % 3 == 2 ? '인원 초과' : null,
        ),
      );
    }
  }
}
