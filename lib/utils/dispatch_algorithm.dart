/// 날짜별 배차 결정.
///
/// 규칙은 관리자 웹(src/lib/dispatchAlgorithm.ts)과 같아야 한다. 같은 설정을 보고
/// 앱과 웹이 다른 답을 내면 현장에서 신뢰를 잃는다.
///
/// - 주운전자가 그날 쉬면 부1 → 부2 … 순서로 대체
/// - 모두 쉬면 운행 없음
/// - 일요일은 운행 없음(휴일)
/// - 결석/개인등하원인 어르신은 해당 방향 탑승 명단에서 빠진다
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

/// 그날 그 어르신의 출결 기록. elderlyId로만 맞춘다 — 이름은 동명이인이 있다.
ElderDayAttendance? findAttendance(
  Senior senior,
  String dateStr,
  List<ElderDayAttendance> attendances,
) {
  if (senior.elderlyId == null) return null;
  for (final a in attendances) {
    if (a.elderlyId == senior.elderlyId && a.date == dateStr) return a;
  }
  return null;
}

/// 그날 그 어르신이 그 방향(등원/하원) 차량을 타는가?
///
/// 1) 그날 출결 기록이 있으면 그것이 우선 (결석이면 양방향 제외)
/// 2) 없으면 Senior의 고정 설정으로 판정
///
/// 웹의 isSeniorRiding(src/lib/dispatchAlgorithm.ts)과 같은 규칙이다.
bool isSeniorRiding(
  Senior senior,
  String dateStr,
  String routeType,
  List<ElderDayAttendance> attendances,
) {
  final record = findAttendance(senior, dateStr, attendances);

  if (record != null) {
    if (record.isAbsent) return false;
    return routeType == RouteType.toWork
        ? !record.personalPickup
        : !record.personalDropoff;
  }

  return routeType == RouteType.toWork
      ? !senior.personalPickup
      : !senior.personalDropoff;
}

/// 그날 개인등하원인 어르신 (배차표 헤더용).
/// 어르신 한 명이 등원용·하원용 Senior 두 레코드로 존재하므로 사람 단위로 합친다.
List<Senior> personalTransportSeniors(
  String dateStr,
  String routeType,
  List<Senior> seniors,
  List<ElderDayAttendance> attendances,
) {
  final unique = <String, Senior>{};

  for (final s in seniors) {
    final record = findAttendance(s, dateStr, attendances);
    final bool isPersonal;
    if (record != null) {
      if (record.isAbsent) continue;
      isPersonal = routeType == RouteType.toWork
          ? record.personalPickup
          : record.personalDropoff;
    } else {
      isPersonal = routeType == RouteType.toWork
          ? s.personalPickup
          : s.personalDropoff;
    }
    if (!isPersonal) continue;

    final key = s.elderlyId != null ? 'id:${s.elderlyId}' : 'name:${s.name}';
    unique.putIfAbsent(key, () => s);
  }

  final list = unique.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  return list;
}

/// 회차 우선, 그 다음 탑승순서
int _compareByTripThenBoarding(Senior a, Senior b) {
  final at = a.tripOrder ?? 0;
  final bt = b.tripOrder ?? 0;
  if (at != bt) return at.compareTo(bt);
  return a.boardingOrder.compareTo(b.boardingOrder);
}

/// 그날 그 노선에 타는 어르신 (결석·개인등하원 제외, 회차-탑승순서대로)
List<Senior> seniorsForRoute(
  String routeId,
  String routeType,
  String dateStr,
  List<Senior> seniors,
  List<ElderDayAttendance> attendances,
) {
  final list =
      seniors
          .where((s) => s.routeId == routeId)
          .where((s) => isSeniorRiding(s, dateStr, routeType, attendances))
          .toList()
        ..sort(_compareByTripThenBoarding);
  return list;
}

/// 탑승 명단을 회차별로 묶는다.
/// 아무도 회차를 지정하지 않은 노선은 그룹 하나(tripOrder null)로 돌려준다.
List<TripGroup> groupPassengersByTrip(List<Senior> passengers) {
  final hasTrip = passengers.any((s) => s.tripOrder != null);
  if (!hasTrip) {
    if (passengers.isEmpty) return const [];
    final sorted = [...passengers]..sort(_compareByTripThenBoarding);
    return [TripGroup(seniors: sorted)];
  }

  final groups = <int, List<Senior>>{};
  for (final s in passengers) {
    // 회차를 쓰는 노선에서 미지정 어르신은 1차로 본다
    final trip = s.tripOrder ?? 1;
    groups.putIfAbsent(trip, () => []).add(s);
  }

  final keys = groups.keys.toList()..sort();
  return keys.map((trip) {
    final list = groups[trip]!
      ..sort((a, b) => a.boardingOrder.compareTo(b.boardingOrder));
    return TripGroup(tripOrder: trip, seniors: list);
  }).toList();
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
  List<VacationRequest> vacations, {
  List<ElderDayAttendance> attendances = const [],
}) {
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
    route.type,
    dateStr,
    settings.seniors,
    attendances,
  );
  final tripGroups = groupPassengersByTrip(passengers);
  // 그날 그 차에 실제로 타는 인력 (주운전자든 동승 팀장이든 휴무가 아닌 사람 전원)
  final crew = route.routeDrivers
      .where((d) => !isDriverOnVacation(d, dateStr, vacations))
      .toList();

  if (!isDriverOnVacation(mainDriver, dateStr, vacations)) {
    return RouteDispatch(
      routeId: route.id,
      routeName: route.name,
      routeType: route.type,
      driver: mainDriver,
      driverRole: '주운전자',
      status: DispatchStatus.normal,
      passengers: passengers,
      crew: crew,
      tripGroups: tripGroups,
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
        crew: crew,
        tripGroups: tripGroups,
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
  List<VacationRequest> vacations, {
  List<ElderDayAttendance> attendances = const [],
}) {
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
        .map(
          (route) => routeDispatchForDate(
            route,
            dateStr,
            settings,
            vacations,
            attendances: attendances,
          ),
        )
        .toList(),
    personalPickupSeniors: personalTransportSeniors(
      dateStr,
      RouteType.toWork,
      settings.seniors,
      attendances,
    ),
    personalDropoffSeniors: personalTransportSeniors(
      dateStr,
      RouteType.toHome,
      settings.seniors,
      attendances,
    ),
  );
}

DispatchDaySummary dispatchDaySummary(
  DateTime date,
  DispatchSettings settings,
  List<VacationRequest> vacations, {
  List<ElderDayAttendance> attendances = const [],
}) {
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

  final dispatch = dailyDispatch(date, settings, vacations, attendances: attendances);

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
  List<VacationRequest> vacations, {
  List<ElderDayAttendance> attendances = const [],
}) {
  final result = <String, DispatchDaySummary>{};
  final lastDay = DateTime(year, month + 1, 0).day;

  for (var day = 1; day <= lastDay; day++) {
    final date = DateTime(year, month, day);
    final summary = dispatchDaySummary(date, settings, vacations, attendances: attendances);
    result[summary.date] = summary;
  }

  return result;
}
