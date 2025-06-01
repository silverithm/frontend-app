import 'package:flutter/material.dart';
import '../models/vacation_request.dart';

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

  Future<void> loadCalendarData(DateTime month) async {
    try {
      setLoading(true);
      clearError();

      // TODO: 실제 API 호출로 교체
      await Future.delayed(const Duration(seconds: 1));

      // 임시 달력 데이터 생성
      _generateMockCalendarData(month);

      notifyListeners();
    } catch (e) {
      setError('캘린더 데이터 로딩에 실패했습니다: ${e.toString()}');
    } finally {
      setLoading(false);
    }
  }

  Future<void> loadMyVacationRequests(String userId) async {
    try {
      setLoading(true);
      clearError();

      // TODO: 실제 API 호출로 교체
      await Future.delayed(const Duration(seconds: 1));

      // 임시 휴가 신청 데이터 생성
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
    String? reason,
  }) async {
    try {
      setLoading(true);
      clearError();

      // TODO: 실제 API 호출로 교체
      await Future.delayed(const Duration(seconds: 2));

      final newRequest = VacationRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        userName: userName,
        userRole: userRole,
        date: date,
        type: type,
        reason: reason,
        createdAt: DateTime.now(),
      );

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
    } catch (e) {
      setError('휴가 신청에 실패했습니다: ${e.toString()}');
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<bool> cancelVacationRequest(String requestId) async {
    try {
      setLoading(true);
      clearError();

      // TODO: 실제 API 호출로 교체
      await Future.delayed(const Duration(seconds: 1));

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

  List<VacationRequest> getVacationsForDate(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    final vacations = _calendarData[dateKey] ?? [];

    if (_roleFilter == 'all') {
      return vacations;
    }

    return vacations
        .where((vacation) => vacation.userRole == _roleFilter)
        .toList();
  }

  int getVacationCountForDate(DateTime date) {
    return getVacationsForDate(date).length;
  }

  bool isDateFull(DateTime date, {int maxPeople = 3}) {
    return getVacationCountForDate(date) >= maxPeople;
  }

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
                userRole: j % 2 == 0 ? 'caregiver' : 'office',
                date: date,
                status: VacationStatus.values[(random + i + j) % 3],
                type: j == 0 ? VacationType.mandatory : VacationType.personal,
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
          userRole: 'caregiver',
          date: date,
          status: VacationStatus.values[i % 3],
          type: i % 3 == 0 ? VacationType.mandatory : VacationType.personal,
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
