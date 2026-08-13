/// 날짜별 배차 결정.
///
/// 규칙은 관리자 웹(src/lib/dispatchAlgorithm.ts)과 같아야 한다. 같은 설정을 보고
/// 앱과 웹이 다른 답을 내면 현장에서 신뢰를 잃는다.
///
/// - 주운전자가 그날 쉬면 부1 → 부2 … 순서로 대체
/// - 모두 쉬면 운행 없음
/// - 일요일은 운행 없음(휴일)
/// - 결석한 어르신은 탑승 명단에서 빠진다
library;

import '../models/dispatch.dart';
import '../models/vacation_request.dart';

String formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// 일요일만 휴무로 본다 (공휴일은 웹도 아직 반영하지 않는다)
bool isNonWorkingDay(DateTime date) => date.weekday == DateTime.sunday;

/// 그날 이 운전자가 휴무인지.
/// driverId로 맞춰보고, 예전 데이터라 id가 없으면 이름으로 맞춘다.
///
/// 승인 대기 중인 휴무도 휴무로 센다 — 관리자 웹이 그렇게 세고 있어서
/// 여기서만 다르게 세면 두 화면의 배차가 어긋난다.
bool isDriverOnVacation(
  RouteDriver driver,
  String dateStr,
  List<VacationRequest> vacations,
) {
  if (driver.driverId.isNotEmpty) {
    return vacations.any(
      (v) => v.userId == driver.driverId && formatDate(v.date) == dateStr,
    );
  }
  if (driver.driverName.isEmpty) return false;
  return vacations.any(
    (v) => v.userName == driver.driverName && formatDate(v.date) == dateStr,
  );
}

bool isSeniorAbsent(
  Senior senior,
  String dateStr,
  List<SeniorAbsence> absences,
) {
  return absences.any((a) => a.seniorId == senior.id && a.date == dateStr);
}

/// 그날 그 노선에 타는 어르신 (결석자 제외, 탑승 순서대로)
List<Senior> seniorsForRoute(
  String routeId,
  String dateStr,
  List<Senior> seniors,
  List<SeniorAbsence> absences,
) {
  final list =
      seniors
          .where((s) => s.routeId == routeId)
          .where((s) => !isSeniorAbsent(s, dateStr, absences))
          .toList()
        ..sort((a, b) => a.boardingOrder.compareTo(b.boardingOrder));
  return list;
}

/// routeDrivers 내 위치를 사람이 읽는 역할명으로 (0 = 주운전자)
String? driverRoleName(int index) {
  if (index == 0) return '주운전자';
  if (index >= 1 && index <= 3) return '부$index운전자';
  return null;
}

RouteDispatch routeDispatchForDate(
  DispatchRoute route,
  String dateStr,
  DispatchSettings settings,
  List<VacationRequest> vacations,
) {
  if (route.routeDrivers.isEmpty) {
    return RouteDispatch(
      routeId: route.id,
      routeName: route.name,
      routeType: route.type,
      status: DispatchStatus.noService,
      reason: '운전자가 배정되지 않음',
    );
  }

  final mainDriver = route.routeDrivers.first;
  final passengers = seniorsForRoute(
    route.id,
    dateStr,
    settings.seniors,
    settings.seniorAbsences,
  );

  if (!isDriverOnVacation(mainDriver, dateStr, vacations)) {
    return RouteDispatch(
      routeId: route.id,
      routeName: route.name,
      routeType: route.type,
      driver: mainDriver,
      driverRole: '주운전자',
      status: DispatchStatus.normal,
      passengers: passengers,
      reason: '주운전자 ${mainDriver.driverName} 정상 운행',
    );
  }

  // 주운전자가 쉰다 — 부운전자를 순서대로 찾는다
  final restingNames = <String>[mainDriver.driverName];

  for (var i = 1; i < route.routeDrivers.length; i++) {
    final sub = route.routeDrivers[i];
    if (!isDriverOnVacation(sub, dateStr, vacations)) {
      final role = driverRoleName(i);
      return RouteDispatch(
        routeId: route.id,
        routeName: route.name,
        routeType: route.type,
        driver: sub,
        driverRole: role,
        status: DispatchStatus.substitute,
        passengers: passengers,
        originalMainDriver: mainDriver,
        reason:
            '주운전자 ${mainDriver.driverName} 휴무 → $role ${sub.driverName} 대체 운행',
      );
    }
    restingNames.add(sub.driverName);
  }

  return RouteDispatch(
    routeId: route.id,
    routeName: route.name,
    routeType: route.type,
    status: DispatchStatus.noService,
    originalMainDriver: mainDriver,
    reason: '모든 운전자 휴무 (${restingNames.join(', ')})',
  );
}

DailyDispatch dailyDispatch(
  DateTime date,
  DispatchSettings settings,
  List<VacationRequest> vacations,
) {
  final dateStr = formatDate(date);

  if (isNonWorkingDay(date)) {
    return DailyDispatch(
      date: dateStr,
      routeDispatches: settings.routes
          .map(
            (route) => RouteDispatch(
              routeId: route.id,
              routeName: route.name,
              routeType: route.type,
              status: DispatchStatus.holiday,
            ),
          )
          .toList(),
    );
  }

  return DailyDispatch(
    date: dateStr,
    routeDispatches: settings.routes
        .map((route) => routeDispatchForDate(route, dateStr, settings, vacations))
        .toList(),
  );
}

DispatchDaySummary dispatchDaySummary(
  DateTime date,
  DispatchSettings settings,
  List<VacationRequest> vacations,
) {
  final dateStr = formatDate(date);

  if (isNonWorkingDay(date)) {
    return DispatchDaySummary(
      date: dateStr,
      normalCount: 0,
      substituteCount: 0,
      noServiceCount: 0,
      totalRoutes: settings.routes.length,
      isHoliday: true,
      holidayName: '일요일',
    );
  }

  final dispatch = dailyDispatch(date, settings, vacations);

  var normal = 0;
  var substitute = 0;
  var noService = 0;
  for (final rd in dispatch.routeDispatches) {
    switch (rd.status) {
      case DispatchStatus.normal:
        normal++;
      case DispatchStatus.substitute:
        substitute++;
      case DispatchStatus.noService:
        noService++;
    }
  }

  return DispatchDaySummary(
    date: dateStr,
    normalCount: normal,
    substituteCount: substitute,
    noServiceCount: noService,
    totalRoutes: settings.routes.length,
    isHoliday: false,
  );
}

/// 한 달치 요약 — 키는 yyyy-MM-dd
Map<String, DispatchDaySummary> monthlyDispatchSummary(
  int year,
  int month,
  DispatchSettings settings,
  List<VacationRequest> vacations,
) {
  final result = <String, DispatchDaySummary>{};
  final lastDay = DateTime(year, month + 1, 0).day;

  for (var day = 1; day <= lastDay; day++) {
    final date = DateTime(year, month, day);
    final summary = dispatchDaySummary(date, settings, vacations);
    result[summary.date] = summary;
  }

  return result;
}
