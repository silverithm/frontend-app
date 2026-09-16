import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_app/models/dispatch.dart';
import 'package:frontend_app/utils/dispatch_route_ops.dart';

DispatchRoute _route(String id, String name, String type, {String? driver}) {
  return DispatchRoute(
    id: id,
    name: name,
    type: type,
    routeDrivers: driver == null
        ? const []
        : [RouteDriver(driverId: '$id-d', driverName: driver)],
  );
}

void main() {
  group('findPrimaryDriverConflict', () {
    test('같은 방향(등원)의 다른 노선 주운전자와는 충돌한다', () {
      final routes = [
        _route('a', '1호차', RouteType.toWork, driver: '김선생'),
        _route('b', '2호차', RouteType.toWork),
      ];

      final conflict = findPrimaryDriverConflict(
        routes: routes,
        driverName: '김선생',
        exceptRouteId: 'b',
        routeType: RouteType.toWork,
      );

      expect(conflict?.id, 'a');
    });

    test('등원 주운전자가 하원 주운전자를 겸하는 것은 충돌이 아니다', () {
      final routes = [
        _route('a', '1호차', RouteType.toWork, driver: '김선생'),
        _route('b', '1호차', RouteType.toHome),
      ];

      final conflict = findPrimaryDriverConflict(
        routes: routes,
        driverName: '김선생',
        exceptRouteId: 'b',
        routeType: RouteType.toHome,
      );

      expect(conflict, isNull);
    });

    test('routeType을 생략하면 모든 방향을 검사한다(하위호환)', () {
      final routes = [
        _route('a', '1호차', RouteType.toWork, driver: '김선생'),
        _route('b', '1호차', RouteType.toHome),
      ];

      final conflict = findPrimaryDriverConflict(
        routes: routes,
        driverName: '김선생',
        exceptRouteId: 'b',
      );

      expect(conflict?.id, 'a');
    });

    test('자기 자신 노선은 제외한다', () {
      final routes = [_route('a', '1호차', RouteType.toWork, driver: '김선생')];

      final conflict = findPrimaryDriverConflict(
        routes: routes,
        driverName: '김선생',
        exceptRouteId: 'a',
        routeType: RouteType.toWork,
      );

      expect(conflict, isNull);
    });

    test('빈 이름은 충돌하지 않는다', () {
      final routes = [_route('a', '1호차', RouteType.toWork, driver: '김선생')];
      final conflict = findPrimaryDriverConflict(
        routes: routes,
        driverName: '   ',
        routeType: RouteType.toWork,
      );
      expect(conflict, isNull);
    });
  });

  group('copyRoutesToOtherTypePure', () {
    test('등원 노선과 어르신을 하원으로 복사한다', () {
      final routes = [_route('a', '1호차', RouteType.toWork, driver: '김선생')];
      final seniors = [
        const Senior(id: 's1', name: '박어르신', routeId: 'a', boardingOrder: 1),
        const Senior(id: 's2', name: '최어르신', routeId: 'a', boardingOrder: 2),
      ];

      var counter = 0;
      final result = copyRoutesToOtherTypePure(
        routes: routes,
        seniors: seniors,
        sourceType: RouteType.toWork,
        newId: () => 'new${counter++}',
      );

      expect(result.routeCount, 1);
      expect(result.seniorCount, 2);
      expect(result.newRoutes.first.type, RouteType.toHome);
      expect(result.newRoutes.first.name, '1호차');
      expect(result.newRoutes.first.routeDrivers.first.driverName, '김선생');
      expect(result.newSeniors.every((s) => s.routeId == result.newRoutes.first.id), isTrue);
      expect(result.newSeniors.map((s) => s.name), containsAll(['박어르신', '최어르신']));
    });

    test('이미 같은 이름의 반대 방향 노선이 있으면 건너뛴다', () {
      final routes = [
        _route('a', '1호차', RouteType.toWork, driver: '김선생'),
        _route('b', '1호차', RouteType.toHome, driver: '이선생'),
      ];

      final result = copyRoutesToOtherTypePure(
        routes: routes,
        seniors: const [],
        sourceType: RouteType.toWork,
        newId: () => 'x',
      );

      expect(result.routeCount, 0);
    });
  });
}
