import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/dispatch.dart';
import 'package:frontend_app/utils/dispatch_algorithm.dart';

/// 그날 하루치 배차 수정본 — 관리자 웹에서 손으로 옮긴 배치를 앱도 똑같이 그려야 한다.
/// 같은 날 배차표가 웹과 앱에서 다르면 현장에서 둘 다 믿을 수 없게 된다.
void main() {
  const monday = '2026-08-31';

  List<Senior> baseSeniors() => const [
        Senior(id: 's1', name: '강문자', routeId: 'r1', boardingOrder: 1),
        Senior(id: 's2', name: '조복수', routeId: 'r1', boardingOrder: 2),
        Senior(id: 's3', name: '김안자', routeId: 'r2', boardingOrder: 1),
      ];

  test('수정본이 없으면 명단이 그대로다', () {
    final seniors = baseSeniors();
    expect(applyDispatchOverrides(seniors, const []), same(seniors));
  });

  test('옮긴 어르신만 노선이 바뀐다', () {
    final result = applyDispatchOverrides(baseSeniors(), const [
      DispatchAssignmentOverride(seniorId: 's1', routeId: 'r2', boardingOrder: 9),
    ]);

    expect(result.firstWhere((s) => s.id == 's1').routeId, 'r2');
    expect(result.firstWhere((s) => s.id == 's2').routeId, 'r1');
  });

  test('사이값으로 온 자리도 순서가 살아 있다 — 정수로 자르면 두 사람이 같은 자리가 된다', () {
    // 웹이 "조복수 앞"으로 옮기면 1과 2 사이인 1.5로 온다
    final result = applyDispatchOverrides(baseSeniors(), const [
      DispatchAssignmentOverride(seniorId: 's3', routeId: 'r1', boardingOrder: 1.5),
    ]);

    final r1 = result.where((s) => s.routeId == 'r1').toList()
      ..sort((a, b) => a.boardingOrder.compareTo(b.boardingOrder));

    expect(r1.map((s) => s.name).toList(), ['강문자', '김안자', '조복수']);
    // 순서 번호는 1,2,3으로 다시 매겨진다 (앱의 자리 번호는 정수다)
    expect(r1.map((s) => s.boardingOrder).toList(), [1, 2, 3]);
  });

  test('원본 명단은 바뀌지 않는다 — 내일 배차가 오늘 조작을 물려받으면 안 된다', () {
    final seniors = baseSeniors();
    applyDispatchOverrides(seniors, const [
      DispatchAssignmentOverride(seniorId: 's1', routeId: 'r2', boardingOrder: 9),
    ]);

    expect(seniors.first.routeId, 'r1');
  });

  test('배차표 명단이 실제로 바뀐다', () {
    final settings = DispatchSettings(
      routes: const [
        DispatchRoute(
          id: 'r1',
          name: '레이',
          type: RouteType.toWork,
          routeDrivers: [
            RouteDriver(
              driverId: 'd1',
              driverName: '이광성',
              vehicleName: '레이',
              vehicleCapacity: 12,
            ),
          ],
        ),
        DispatchRoute(
          id: 'r2',
          name: '스타리아',
          type: RouteType.toWork,
          routeDrivers: [
            RouteDriver(
              driverId: 'd2',
              driverName: '황인후',
              vehicleName: '스타리아',
              vehicleCapacity: 12,
            ),
          ],
        ),
      ],
      seniors: baseSeniors(),
    );

    final moved = settings.copyWith(
      seniors: applyDispatchOverrides(settings.seniors, const [
        DispatchAssignmentOverride(seniorId: 's1', routeId: 'r2', boardingOrder: 9),
      ]),
    );

    final daily = dailyDispatch(DateTime.parse(monday), moved, const []);
    final rayRoute = daily.routeDispatches.firstWhere((rd) => rd.routeId == 'r1');
    final starexRoute = daily.routeDispatches.firstWhere((rd) => rd.routeId == 'r2');

    expect(rayRoute.passengers.map((s) => s.name).toList(), ['조복수']);
    expect(starexRoute.passengers.map((s) => s.name).toList(), ['김안자', '강문자']);
  });

  test('사이값을 보내는 서버 응답을 그대로 읽는다', () {
    final parsed = DispatchAssignmentOverride.fromJson(const {
      'seniorId': 's3',
      'routeId': 'r1',
      'tripOrder': 2,
      'boardingOrder': 1.5,
    });

    expect(parsed.boardingOrder, 1.5);
    expect(parsed.tripOrder, 2);
  });
}
