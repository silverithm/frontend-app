import 'package:flutter/foundation.dart';
import '../models/schedule.dart';
import '../services/api_service.dart';

class ScheduleProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Schedule> _schedules = [];
  Map<String, List<Schedule>> _schedulesByDate = {};
  bool _isLoading = false;
  String? _error;
  DateTime? _currentMonth;

  // Getters
  List<Schedule> get schedules => _schedules;
  Map<String, List<Schedule>> get schedulesByDate => _schedulesByDate;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 월별 일정 데이터 로드
  Future<void> loadCalendarData(DateTime month, {required String companyId}) async {
    _currentMonth = month;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 해당 월의 첫날과 마지막날 계산
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0);

      final startDateStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      final endDateStr = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

      print('[ScheduleProvider] 일정 로드: $startDateStr ~ $endDateStr');

      final response = await _apiService.getSchedules(
        companyId: companyId,
        startDate: startDateStr,
        endDate: endDateStr,
      );

      print('[ScheduleProvider] 응답: $response');

      if (response['schedules'] != null) {
        final scheduleList = response['schedules'] as List;
        print('[ScheduleProvider] 일정 개수: ${scheduleList.length}');

        _schedules = scheduleList
            .map((json) {
              final jsonMap = json as Map<String, dynamic>;
              print('[ScheduleProvider] 원본 startDate: ${jsonMap['startDate']} (타입: ${jsonMap['startDate'].runtimeType})');
              final schedule = Schedule.fromJson(jsonMap);
              print('[ScheduleProvider] 파싱된 startDate: ${schedule.startDate} (dateKey: ${_formatDateKey(schedule.startDate)})');
              return schedule;
            })
            .toList();

        print('[ScheduleProvider] 파싱된 일정 수: ${_schedules.length}');

        // 날짜별로 그룹화
        _groupSchedulesByDate();

        print('[ScheduleProvider] 날짜별 그룹화 결과:');
        _schedulesByDate.forEach((key, value) {
          print('[ScheduleProvider]   $key: ${value.length}건');
        });
      } else {
        print('[ScheduleProvider] schedules가 null');
        _schedules = [];
        _schedulesByDate = {};
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('[ScheduleProvider] 일정 로드 에러: $e');
      _error = '일정을 불러오는데 실패했습니다';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 날짜별로 일정 그룹화
  void _groupSchedulesByDate() {
    _schedulesByDate = {};

    for (var schedule in _schedules) {
      final dateKey = _formatDateKey(schedule.startDate);

      if (_schedulesByDate[dateKey] == null) {
        _schedulesByDate[dateKey] = [];
      }
      _schedulesByDate[dateKey]!.add(schedule);

      // 다중 일정인 경우 (시작일 ~ 종료일) 각 날짜에 추가
      if (schedule.endDate != null && schedule.endDate!.isAfter(schedule.startDate)) {
        var currentDate = schedule.startDate.add(const Duration(days: 1));
        while (!currentDate.isAfter(schedule.endDate!)) {
          final key = _formatDateKey(currentDate);
          if (_schedulesByDate[key] == null) {
            _schedulesByDate[key] = [];
          }
          _schedulesByDate[key]!.add(schedule);
          currentDate = currentDate.add(const Duration(days: 1));
        }
      }
    }
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 특정 날짜의 일정 목록
  List<Schedule> getSchedulesForDate(DateTime date) {
    final dateKey = _formatDateKey(date);
    return _schedulesByDate[dateKey] ?? [];
  }

  /// 특정 날짜에 일정이 있는지 확인
  bool hasSchedulesOnDate(DateTime date) {
    final dateKey = _formatDateKey(date);
    return _schedulesByDate[dateKey]?.isNotEmpty ?? false;
  }

  /// 특정 날짜의 일정 수
  int getScheduleCountForDate(DateTime date) {
    return getSchedulesForDate(date).length;
  }

  /// 일정 등록
  Future<bool> createSchedule({
    required String companyId,
    required Map<String, dynamic> scheduleData,
  }) async {
    try {
      _error = null;
      await _apiService.createSchedule(
        companyId: companyId,
        scheduleData: scheduleData,
      );
      // 등록 후 현재 월 데이터 새로고침
      await loadCalendarData(_currentMonth ?? DateTime.now(), companyId: companyId);
      return true;
    } catch (e) {
      print('[ScheduleProvider] 일정 등록 에러: $e');
      _error = '일정 등록에 실패했습니다';
      notifyListeners();
      return false;
    }
  }

  /// 일정 삭제
  Future<bool> deleteSchedule({
    required int scheduleId,
    required String companyId,
  }) async {
    try {
      _error = null;
      await _apiService.deleteSchedule(scheduleId: scheduleId);
      // 삭제 후 현재 월 데이터 새로고침
      await loadCalendarData(_currentMonth ?? DateTime.now(), companyId: companyId);
      return true;
    } catch (e) {
      print('[ScheduleProvider] 일정 삭제 에러: $e');
      _error = '일정 삭제에 실패했습니다';
      notifyListeners();
      return false;
    }
  }

  /// 에러 초기화
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
