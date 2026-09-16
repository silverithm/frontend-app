/// 노선 설정을 다루는 순수 함수들 — 주운전자 중복 검사, 하원↔등원 노선 복사.
///
/// UI(다이얼로그/스낵바)와 분리해서 단위 테스트로 규칙을 고정한다.
library;

import '../models/dispatch.dart';

/// 이 사람이 같은 방향(routeType)의 다른 노선에서 주운전자인지 찾는다.
///
/// 등원과 하원은 서로 다른 시간대라 한 사람이 등원 주운전자이면서 동시에
/// 하원 주운전자인 것은 정상이다. [routeType]을 넘기면 그 방향의 노선만 검사하고,
/// 넘기지 않으면 모든 방향을 검사한다(하위호환).
DispatchRoute? findPrimaryDriverConflict({
  required List<DispatchRoute> routes,
  required String driverName,
  String? exceptRouteId,
  String? routeType,
}) {
  final name = driverName.trim();
  if (name.isEmpty) return null;

  for (final route in routes) {
    if (exceptRouteId != null && route.id == exceptRouteId) continue;
    if (routeType != null && route.type != routeType) continue;
    if (route.routeDrivers.isEmpty) continue;
    if (route.routeDrivers.first.driverName.trim() == name) return route;
  }
  return null;
}

String _otherType(String type) =>
    type == RouteType.toWork ? RouteType.toHome : RouteType.toWork;

/// 한 방향(sourceType)의 노선들을 반대 방향(등원↔하원)으로 복사한 결과.
class RouteCopyResult {
  /// 새로 만들어진 노선들 (원본 순서 유지)
  final List<DispatchRoute> newRoutes;

  /// 새로 만들어진 어르신들 (새 노선에 새 id로 배정됨)
  final List<Senior> newSeniors;

  const RouteCopyResult({this.newRoutes = const [], this.newSeniors = const []});

  int get routeCount => newRoutes.length;
  int get seniorCount => newSeniors.length;
}

/// [sourceType] 방향의 노선 중, 같은 이름의 반대 방향 노선이 아직 없는 것만
/// 골라 반대 방향으로 복사한다. 운전자 배정은 그대로 옮기고, 어르신도 같은
/// 탑승 순서로 복사하되 새 id를 부여한다.
///
/// [newId]는 새 노선/어르신 id를 만드는 함수(호출마다 다른 값을 내야 한다).
RouteCopyResult copyRoutesToOtherTypePure({
  required List<DispatchRoute> routes,
  required List<Senior> seniors,
  required String sourceType,
  required String Function() newId,
}) {
  final targetType = _otherType(sourceType);
  final existingTargetNames = routes
      .where((r) => r.type == targetType)
      .map((r) => r.name.trim())
      .toSet();

  final sourceRoutes = routes
      .where((r) => r.type == sourceType)
      .where((r) => !existingTargetNames.contains(r.name.trim()))
      .toList();

  final newRoutes = <DispatchRoute>[];
  final newSeniors = <Senior>[];

  for (final source in sourceRoutes) {
    final newRouteId = newId();
    newRoutes.add(
      DispatchRoute(
        id: newRouteId,
        name: source.name,
        type: targetType,
        routeDrivers: source.routeDrivers
            .map((d) => d.copyWith())
            .toList(),
      ),
    );

    final sourceSeniors = seniors.where((s) => s.routeId == source.id).toList()
      ..sort((a, b) => a.boardingOrder.compareTo(b.boardingOrder));

    for (final s in sourceSeniors) {
      newSeniors.add(
        Senior(
          id: newId(),
          name: s.name,
          routeId: newRouteId,
          boardingOrder: s.boardingOrder,
          elderlyId: s.elderlyId,
          tripOrder: s.tripOrder,
          personalPickup: s.personalPickup,
          personalDropoff: s.personalDropoff,
        ),
      );
    }
  }

  return RouteCopyResult(newRoutes: newRoutes, newSeniors: newSeniors);
}
