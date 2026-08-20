/// 차량 배차 모델.
///
/// 관리자 웹(frontend-admin)의 src/types/dispatch.ts와 같은 모양이다.
/// 서버는 `/api/v1/dispatch-settings`에 {routes, seniors, seniorAbsences}를
/// JSON 그대로 보관하므로, 필드 이름이 웹과 어긋나면 서로 못 읽는다.
library;

/// 노선 유형 — 서버에는 '등원'/'하원' 문자열 그대로 들어간다.
class RouteType {
  static const String toWork = '등원';
  static const String toHome = '하원';

  static const List<String> values = [toWork, toHome];
}

/// 배차 상태
class DispatchStatus {
  static const String normal = '정상';
  static const String substitute = '대체';
  static const String noService = '운행없음';
  static const String holiday = '휴일';
}

/// 노선에 배정된 운전자 + 차량
class RouteDriver {
  final String driverId;
  final String driverName;
  final String vehicleName;
  final int vehicleCapacity;

  const RouteDriver({
    this.driverId = '',
    this.driverName = '',
    this.vehicleName = '',
    this.vehicleCapacity = 0,
  });

  RouteDriver copyWith({
    String? driverId,
    String? driverName,
    String? vehicleName,
    int? vehicleCapacity,
  }) {
    return RouteDriver(
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      vehicleName: vehicleName ?? this.vehicleName,
      vehicleCapacity: vehicleCapacity ?? this.vehicleCapacity,
    );
  }

  factory RouteDriver.fromJson(Map<String, dynamic> json) {
    return RouteDriver(
      driverId: json['driverId']?.toString() ?? '',
      driverName: json['driverName']?.toString() ?? '',
      vehicleName: json['vehicleName']?.toString() ?? '',
      vehicleCapacity: _asInt(json['vehicleCapacity']),
    );
  }

  Map<String, dynamic> toJson() => {
    'driverId': driverId,
    'driverName': driverName,
    'vehicleName': vehicleName,
    'vehicleCapacity': vehicleCapacity,
  };
}

/// 노선. routeDrivers는 [주운전자, 부1, 부2, ...] 순서다.
class DispatchRoute {
  final String id;
  final String name;
  final String type;
  final List<RouteDriver> routeDrivers;

  const DispatchRoute({
    required this.id,
    required this.name,
    required this.type,
    this.routeDrivers = const [],
  });

  DispatchRoute copyWith({
    String? name,
    String? type,
    List<RouteDriver>? routeDrivers,
  }) {
    return DispatchRoute(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      routeDrivers: routeDrivers ?? this.routeDrivers,
    );
  }

  factory DispatchRoute.fromJson(Map<String, dynamic> json) {
    final drivers = json['routeDrivers'];
    return DispatchRoute(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? RouteType.toWork,
      routeDrivers: drivers is List
          ? drivers
                .whereType<Map>()
                .map((e) => RouteDriver.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'routeDrivers': routeDrivers.map((d) => d.toJson()).toList(),
  };
}

/// 탑승 어르신. routeId로 노선에 붙고, boardingOrder는 1부터다.
class Senior {
  final String id;
  final String name;
  final String routeId;
  final int boardingOrder;

  /// 회원관리의 Elderly 엔티티 id (연동된 경우)
  final int? elderlyId;

  const Senior({
    required this.id,
    required this.name,
    required this.routeId,
    required this.boardingOrder,
    this.elderlyId,
  });

  Senior copyWith({String? name, String? routeId, int? boardingOrder}) {
    return Senior(
      id: id,
      name: name ?? this.name,
      routeId: routeId ?? this.routeId,
      boardingOrder: boardingOrder ?? this.boardingOrder,
      elderlyId: elderlyId,
    );
  }

  factory Senior.fromJson(Map<String, dynamic> json) {
    return Senior(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      routeId: json['routeId']?.toString() ?? '',
      boardingOrder: _asInt(json['boardingOrder']),
      elderlyId: json['elderlyId'] == null ? null : _asInt(json['elderlyId']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'routeId': routeId,
    'boardingOrder': boardingOrder,
    if (elderlyId != null) 'elderlyId': elderlyId,
  };
}

/// 어르신 결석 (yyyy-MM-dd)
class SeniorAbsence {
  final String seniorId;
  final String date;
  final String? reason;

  const SeniorAbsence({
    required this.seniorId,
    required this.date,
    this.reason,
  });

  factory SeniorAbsence.fromJson(Map<String, dynamic> json) {
    return SeniorAbsence(
      seniorId: json['seniorId']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      reason: json['reason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'seniorId': seniorId,
    'date': date,
    if (reason != null && reason!.isNotEmpty) 'reason': reason,
  };
}

/// 배차 설정 한 벌 (회사당 하나)
class DispatchSettings {
  final List<DispatchRoute> routes;
  final List<Senior> seniors;

  /// 결석은 웹 타입에는 없지만 서버가 JSON을 통째로 보관하므로 같이 싣는다.
  /// 이렇게 해야 관리자 웹에서 넣은 결석을 앱에서도 본다.
  final List<SeniorAbsence> seniorAbsences;

  const DispatchSettings({
    this.routes = const [],
    this.seniors = const [],
    this.seniorAbsences = const [],
  });

  bool get isEmpty => routes.isEmpty && seniors.isEmpty;

  DispatchSettings copyWith({
    List<DispatchRoute>? routes,
    List<Senior>? seniors,
    List<SeniorAbsence>? seniorAbsences,
  }) {
    return DispatchSettings(
      routes: routes ?? this.routes,
      seniors: seniors ?? this.seniors,
      seniorAbsences: seniorAbsences ?? this.seniorAbsences,
    );
  }

  factory DispatchSettings.fromJson(Map<String, dynamic> json) {
    List<T> parse<T>(String key, T Function(Map<String, dynamic>) build) {
      final raw = json[key];
      if (raw is! List) return <T>[];
      return raw
          .whereType<Map>()
          .map((e) => build(Map<String, dynamic>.from(e)))
          .toList();
    }

    return DispatchSettings(
      routes: parse('routes', DispatchRoute.fromJson),
      seniors: parse('seniors', Senior.fromJson),
      seniorAbsences: parse('seniorAbsences', SeniorAbsence.fromJson),
    );
  }

  Map<String, dynamic> toJson() => {
    // routeDrivers의 자리(인덱스)는 곧 역할이다: 0=주운전자, 1=부1운전자 ...
    // 예전에는 여기서 이름 없는 자리를 걸러냈는데, 그러면 "주운전자 자리가
    // 비고 부운전자만 채워진" 노선을 저장할 때 부운전자가 앞으로 당겨지며
    // 주운전자로 승격돼 버렸다(관리자 웹은 노선을 편집할 때 이런 걸러내기를
    // 하지 않는다 — dispatchStore.ts의 updateRoute류 참고). 그래서 빈 자리도
    // 그대로 두어 인덱스 의미를 지킨다. 운전자를 하나도 못 고른 채로 노선이
    // 만들어지는 것 자체는 화면(노선 추가) 쪽 검증으로 막는다.
    'routes': routes.map((r) => r.toJson()).toList(),
    'seniors': seniors.map((s) => s.toJson()).toList(),
    'seniorAbsences': seniorAbsences.map((a) => a.toJson()).toList(),
  };
}

/// 특정 날짜, 특정 노선의 배차 결과
class RouteDispatch {
  final String routeId;
  final String routeName;
  final String routeType;
  final RouteDriver? driver;

  /// '주운전자' / '부1운전자' … (배차된 사람이 없으면 null)
  final String? driverRole;
  final String status;
  final List<Senior> passengers;

  /// 대체 운행일 때 원래 주운전자
  final RouteDriver? originalMainDriver;
  final String? reason;

  const RouteDispatch({
    required this.routeId,
    required this.routeName,
    required this.routeType,
    required this.status,
    this.driver,
    this.driverRole,
    this.passengers = const [],
    this.originalMainDriver,
    this.reason,
  });
}

/// 하루치 배차 결과
class DailyDispatch {
  final String date;
  final List<RouteDispatch> routeDispatches;

  const DailyDispatch({required this.date, required this.routeDispatches});
}

/// 달력 한 칸에 표시할 요약
class DispatchDaySummary {
  final String date;
  final int normalCount;
  final int substituteCount;
  final int noServiceCount;
  final int totalRoutes;
  final bool isHoliday;
  final String? holidayName;

  const DispatchDaySummary({
    required this.date,
    required this.normalCount,
    required this.substituteCount,
    required this.noServiceCount,
    required this.totalRoutes,
    required this.isHoliday,
    this.holidayName,
  });
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
