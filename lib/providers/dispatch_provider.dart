import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/dispatch.dart';
import '../models/vacation_request.dart';
import '../services/api_service.dart';
import '../utils/dispatch_algorithm.dart';

/// 배차 설정과 그날그날의 배차 결과를 들고 있는다.
///
/// 설정 원본은 서버(`/api/v1/dispatch-settings`)다. 관리자 웹과 같은 JSON을 보므로
/// 어느 쪽에서 고쳐도 반대쪽에 그대로 보인다. 화면에서 설정을 바꾸면 잠깐 모았다가
/// 한 번에 저장한다 — 노선 이름 한 글자마다 저장 요청을 보내지 않기 위해서다.
class DispatchProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  static const Duration _saveDebounce = Duration(milliseconds: 800);

  DispatchSettings _settings = const DispatchSettings();
  List<VacationRequest> _vacations = [];
  // 출결은 백엔드 elder_attendance가 원본이다 (배차설정 JSON의 결석은 레거시)
  List<ElderDayAttendance> _attendances = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  String? _companyId;
  Timer? _saveTimer;

  DispatchSettings get settings => _settings;
  List<DispatchRoute> get routes => _settings.routes;
  List<Senior> get seniors => _settings.seniors;
  List<SeniorAbsence> get absences => _settings.seniorAbsences;
  List<ElderDayAttendance> get attendances => _attendances;
  List<VacationRequest> get vacations => _vacations;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  bool get isEmpty => _settings.isEmpty;

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  /// 배차 설정과 휴무를 함께 불러온다.
  /// 휴무를 같이 받아야 "오늘 이 노선을 누가 모는지"를 계산할 수 있다.
  Future<void> load({required String companyId}) async {
    _companyId = companyId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.getDispatchSettings(companyId: companyId),
        _loadVacations(companyId),
        _loadAttendances(companyId, DateTime.now()),
      ]);

      final settingsJson = results[0] as Map<String, dynamic>;
      _settings = DispatchSettings.fromJson(settingsJson);
    } catch (e) {
      _error = '배차 설정을 불러오지 못했습니다';
      debugPrint('[DispatchProvider] 로드 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadVacations(String companyId) async {
    try {
      final response = await _apiService.getVacationRequests(
        companyId: companyId,
      );
      // 백엔드 응답은 배열이 아니라 래퍼다: { requests: [...] }
      final raw = response['requests'] ?? response['data'] ?? response['content'];
      if (raw is List) {
        _vacations = raw
            .whereType<Map>()
            .map((e) => VacationRequest.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } else {
        _vacations = [];
      }
    } catch (e) {
      // 휴무를 못 받아도 노선 자체는 보여준다. 대체 표시만 빠질 뿐이다.
      debugPrint('[DispatchProvider] 휴무 조회 실패: $e');
      _vacations = [];
    }
  }

  /// 그 달의 출결을 한 번에 받는다.
  /// 날짜별로 부르면 한 달에 30번 왕복하게 된다.
  Future<void> _loadAttendances(String companyId, DateTime month) async {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);

    try {
      final response = await _apiService.getElderAttendanceRange(
        companyId: companyId,
        startDate: formatDate(first),
        endDate: formatDate(last),
      );
      final raw = response['attendances'] ?? response['records'] ?? response['data'];
      if (raw is List) {
        _attendances = raw
            .whereType<Map>()
            .map((e) => ElderDayAttendance.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } else {
        _attendances = [];
      }
    } catch (e) {
      // 출결을 못 받아도 노선은 보여준다. 결석·개인등하원 반영만 빠진다.
      debugPrint('[DispatchProvider] 출결 조회 실패: $e');
      _attendances = [];
    }
  }

  /// 달을 넘길 때 그 달 출결을 받아온다
  Future<void> loadAttendancesForMonth(DateTime month) async {
    final companyId = _companyId;
    if (companyId == null) return;
    await _loadAttendances(companyId, month);
    notifyListeners();
  }

  /// 어르신 출결을 바꾼다 (낙관적 반영 후 저장, 실패하면 되돌린다)
  Future<bool> saveAttendances(List<ElderDayAttendance> changes) async {
    final companyId = _companyId;
    if (companyId == null || changes.isEmpty) return false;

    final before = [..._attendances];
    final merged = {
      for (final a in _attendances) '${a.elderlyId}@${a.date}': a,
      for (final c in changes) '${c.elderlyId}@${c.date}': c,
    };
    _attendances = merged.values.toList();
    notifyListeners();

    try {
      await _apiService.bulkCheckElderAttendance(
        companyId: companyId,
        requests: changes.map((c) => c.toJson()).toList(),
      );
      return true;
    } catch (e) {
      debugPrint('[DispatchProvider] 출결 저장 실패: $e');
      _attendances = before;
      notifyListeners();
      return false;
    }
  }

  /// 그날 그 어르신의 출결 기록 (없으면 null)
  ElderDayAttendance? attendanceOf(int elderlyId, String date) {
    for (final a in _attendances) {
      if (a.elderlyId == elderlyId && a.date == date) return a;
    }
    return null;
  }

  /// 서버에서 다시 읽어온다 (당겨서 새로고침)
  Future<void> refresh() async {
    final companyId = _companyId;
    if (companyId == null) return;
    await load(companyId: companyId);
  }

  // ================== 조회 ==================

  DailyDispatch dispatchForDate(DateTime date) =>
      dailyDispatch(date, _settings, _vacations, attendances: _attendances);

  Map<String, DispatchDaySummary> summaryForMonth(int year, int month) =>
      monthlyDispatchSummary(
        year,
        month,
        _settings,
        _vacations,
        attendances: _attendances,
      );

  List<Senior> seniorsOfRoute(String routeId) {
    final list = _settings.seniors.where((s) => s.routeId == routeId).toList()
      ..sort((a, b) => a.boardingOrder.compareTo(b.boardingOrder));
    return list;
  }

  List<SeniorAbsence> absencesOn(String date) =>
      _settings.seniorAbsences.where((a) => a.date == date).toList();

  bool isAbsent(String seniorId, String date) => _settings.seniorAbsences.any(
    (a) => a.seniorId == seniorId && a.date == date,
  );

  /// 이 사람이 다른 노선의 주운전자인지.
  ///
  /// 주운전자는 두 노선을 동시에 몰 수 없어 겹치면 막는다. 부운전자는 예비라서
  /// 한 사람이 여러 코스를 맡는 것이 정상이므로 겹쳐도 막지 않는다.
  DispatchRoute? primaryDriverConflict(String driverName, {String? exceptRouteId}) {
    final name = driverName.trim();
    if (name.isEmpty) return null;

    for (final route in _settings.routes) {
      if (exceptRouteId != null && route.id == exceptRouteId) continue;
      if (route.routeDrivers.isEmpty) continue;
      if (route.routeDrivers.first.driverName.trim() == name) return route;
    }
    return null;
  }

  // ================== 노선 ==================

  void addRoute(DispatchRoute route) {
    _settings = _settings.copyWith(routes: [..._settings.routes, route]);
    _commit();
  }

  void updateRoute(String routeId, DispatchRoute Function(DispatchRoute) build) {
    _settings = _settings.copyWith(
      routes: _settings.routes
          .map((r) => r.id == routeId ? build(r) : r)
          .toList(),
    );
    _commit();
  }

  void deleteRoute(String routeId) {
    _settings = _settings.copyWith(
      routes: _settings.routes.where((r) => r.id != routeId).toList(),
      // 노선이 사라지면 그 노선에만 붙어 있던 어르신도 함께 정리한다
      seniors: _settings.seniors.where((s) => s.routeId != routeId).toList(),
    );
    _commit();
  }

  // ================== 어르신 ==================

  void addSenior(Senior senior) {
    _settings = _settings.copyWith(seniors: [..._settings.seniors, senior]);
    _commit();
  }

  void updateSenior(String seniorId, Senior Function(Senior) build) {
    _settings = _settings.copyWith(
      seniors: _settings.seniors
          .map((s) => s.id == seniorId ? build(s) : s)
          .toList(),
    );
    _commit();
  }

  void deleteSenior(String seniorId) {
    _settings = _settings.copyWith(
      seniors: _settings.seniors.where((s) => s.id != seniorId).toList(),
      seniorAbsences: _settings.seniorAbsences
          .where((a) => a.seniorId != seniorId)
          .toList(),
    );
    _commit();
  }

  /// 같은 노선 안에서 탑승 순서를 한 칸 옮긴다
  void moveSenior(String routeId, int oldIndex, int newIndex) {
    final ordered = seniorsOfRoute(routeId);
    if (oldIndex < 0 || oldIndex >= ordered.length) return;
    if (newIndex < 0 || newIndex >= ordered.length) return;

    final moved = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, moved);

    // 옮긴 뒤 1번부터 다시 매긴다 — 중간에 빈 번호가 생기면 순서가 흔들린다
    final renumbered = <String, int>{};
    for (var i = 0; i < ordered.length; i++) {
      renumbered[ordered[i].id] = i + 1;
    }

    _settings = _settings.copyWith(
      seniors: _settings.seniors.map((s) {
        final order = renumbered[s.id];
        return order == null ? s : s.copyWith(boardingOrder: order);
      }).toList(),
    );
    _commit();
  }

  // ================== 결석 ==================

  void addAbsence(SeniorAbsence absence) {
    final exists = _settings.seniorAbsences.any(
      (a) => a.seniorId == absence.seniorId && a.date == absence.date,
    );
    if (exists) return;

    _settings = _settings.copyWith(
      seniorAbsences: [..._settings.seniorAbsences, absence],
    );
    _commit();
  }

  void removeAbsence(String seniorId, String date) {
    _settings = _settings.copyWith(
      seniorAbsences: _settings.seniorAbsences
          .where((a) => !(a.seniorId == seniorId && a.date == date))
          .toList(),
    );
    _commit();
  }

  // ================== 저장 ==================

  void _commit() {
    notifyListeners();
    _scheduleSave();
  }

  void _scheduleSave() {
    final companyId = _companyId;
    if (companyId == null) return;

    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounce, () => _save(companyId));
  }

  Future<void> _save(String companyId) async {
    _isSaving = true;
    notifyListeners();

    try {
      await _apiService.saveDispatchSettings(
        companyId: companyId,
        settings: _settings.toJson(),
      );
      _error = null;
    } catch (e) {
      _error = '배차 설정을 저장하지 못했습니다';
      debugPrint('[DispatchProvider] 저장 실패: $e');
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// 화면을 떠나기 전처럼 지금 당장 저장해야 할 때
  Future<void> flushSave() async {
    final companyId = _companyId;
    if (companyId == null) return;
    if (_saveTimer?.isActive != true) return;

    _saveTimer?.cancel();
    await _save(companyId);
  }
}
