import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/dispatch.dart';
import 'package:frontend_app/models/vacation_request.dart';
import 'package:frontend_app/utils/dispatch_algorithm.dart';

/// 배차 규칙은 관리자 웹과 한 글자도 다르면 안 된다.
/// 같은 설정을 두고 앱과 웹이 다른 답을 내면 현장에서 못 믿는다.

VacationRequest vacation({
  required String userId,
  required String userName,
  required DateTime date,
}) {
  return VacationRequest(
    id: '$userId-${date.day}',
    userId: userId,
    userName: userName,
    role: '요양보호사',
    date: date,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  // 2026-08-13은 목요일 (평일), 2026-08-16은 일요일
  final thursday = DateTime(2026, 8, 13);
  final sunday = DateTime(2026, 8, 16);

  const main1 = RouteDriver(
    driverId: '1',
    driverName: '김영희',
    vehicleName: '스타리아',
  );
  const sub1 = RouteDriver(driverId: '2', driverName: '박순자');
  const sub2 = RouteDriver(driverId: '3', driverName: '이민수');

  final routeA = DispatchRoute(
    id: 'r1',
    name: 'A코스',
    type: RouteType.toWork,
    routeDrivers: const [main1, sub1, sub2],
  );

  final seniors = [
    const Senior(id: 's1', name: '어르신1', routeId: 'r1', boardingOrder: 1),
    const Senior(id: 's2', name: '어르신2', routeId: 'r1', boardingOrder: 2),
  ];

  DispatchSettings settingsWith({List<SeniorAbsence> absences = const []}) {
    return DispatchSettings(
      routes: [routeA],
      seniors: seniors,
      seniorAbsences: absences,
    );
  }

  group('배차 결정', () {
    test('주운전자가 근무하면 정상 운행', () {
      final result = dailyDispatch(thursday, settingsWith(), []);
      final rd = result.routeDispatches.single;

      expect(rd.status, DispatchStatus.normal);
      expect(rd.driver?.driverName, '김영희');
      expect(rd.driverRole, '주운전자');
      expect(rd.passengers.length, 2);
    });

    test('주운전자가 쉬면 부1운전자가 대체한다', () {
      final result = dailyDispatch(thursday, settingsWith(), [
        vacation(userId: '1', userName: '김영희', date: thursday),
      ]);
      final rd = result.routeDispatches.single;

      expect(rd.status, DispatchStatus.substitute);
      expect(rd.driver?.driverName, '박순자');
      expect(rd.driverRole, '부1운전자');
      expect(rd.originalMainDriver?.driverName, '김영희');
    });

    test('주운전자와 부1이 함께 쉬면 부2가 대체한다', () {
      final result = dailyDispatch(thursday, settingsWith(), [
        vacation(userId: '1', userName: '김영희', date: thursday),
        vacation(userId: '2', userName: '박순자', date: thursday),
      ]);
      final rd = result.routeDispatches.single;

      expect(rd.status, DispatchStatus.substitute);
      expect(rd.driver?.driverName, '이민수');
      expect(rd.driverRole, '부2운전자');
    });

    test('전원이 쉬면 운행 없음', () {
      final result = dailyDispatch(thursday, settingsWith(), [
        vacation(userId: '1', userName: '김영희', date: thursday),
        vacation(userId: '2', userName: '박순자', date: thursday),
        vacation(userId: '3', userName: '이민수', date: thursday),
      ]);
      final rd = result.routeDispatches.single;

      expect(rd.status, DispatchStatus.noService);
      expect(rd.driver, isNull);
      expect(rd.reason, contains('모든 운전자 휴무'));
    });

    test('다른 날 휴무는 오늘 배차에 영향을 주지 않는다', () {
      final result = dailyDispatch(thursday, settingsWith(), [
        vacation(userId: '1', userName: '김영희', date: DateTime(2026, 8, 14)),
      ]);

      expect(result.routeDispatches.single.status, DispatchStatus.normal);
    });

    test('일요일은 운행 없이 휴일로 표시된다', () {
      final result = dailyDispatch(sunday, settingsWith(), []);
      final rd = result.routeDispatches.single;

      expect(rd.status, DispatchStatus.holiday);
      expect(rd.driver, isNull);
    });

    test('운전자가 없는 노선은 운행 없음', () {
      final empty = DispatchRoute(
        id: 'r2',
        name: 'B코스',
        type: RouteType.toHome,
      );
      final result = dailyDispatch(
        thursday,
        DispatchSettings(routes: [empty]),
        [],
      );

      expect(result.routeDispatches.single.status, DispatchStatus.noService);
      expect(result.routeDispatches.single.reason, '운전자가 배정되지 않음');
    });

    test('driverId가 없는 예전 데이터는 이름으로 휴무를 맞춘다', () {
      final legacyRoute = DispatchRoute(
        id: 'r3',
        name: 'C코스',
        type: RouteType.toWork,
        routeDrivers: const [
          RouteDriver(driverName: '김영희'),
          RouteDriver(driverName: '박순자'),
        ],
      );
      final result = dailyDispatch(
        thursday,
        DispatchSettings(routes: [legacyRoute]),
        [vacation(userId: '999', userName: '김영희', date: thursday)],
      );

      expect(result.routeDispatches.single.status, DispatchStatus.substitute);
      expect(result.routeDispatches.single.driver?.driverName, '박순자');
    });
  });

  group('어르신 결석', () {
    test('결석한 어르신은 탑승 명단에서 빠진다', () {
      final result = dailyDispatch(
        thursday,
        settingsWith(
          absences: [SeniorAbsence(seniorId: 's1', date: formatDate(thursday))],
        ),
        [],
      );
      final rd = result.routeDispatches.single;

      expect(rd.passengers.length, 1);
      expect(rd.passengers.single.name, '어르신2');
    });

    test('결석은 그날 하루만 적용된다', () {
      final result = dailyDispatch(
        DateTime(2026, 8, 14),
        settingsWith(
          absences: [SeniorAbsence(seniorId: 's1', date: formatDate(thursday))],
        ),
        [],
      );

      expect(result.routeDispatches.single.passengers.length, 2);
    });
  });

  group('월간 요약', () {
    test('일요일은 휴일로, 평일 대체는 대체로 센다', () {
      final summary = monthlyDispatchSummary(2026, 8, settingsWith(), [
        vacation(userId: '1', userName: '김영희', date: thursday),
      ]);

      expect(summary[formatDate(sunday)]!.isHoliday, isTrue);
      expect(summary[formatDate(thursday)]!.substituteCount, 1);
      expect(summary[formatDate(thursday)]!.normalCount, 0);
      expect(summary[formatDate(DateTime(2026, 8, 14))]!.normalCount, 1);
      // 8월은 31일까지 있다
      expect(summary.length, 31);
    });
  });

  group('서버 JSON 왕복', () {
    test('저장했다 다시 읽어도 설정이 그대로다', () {
      final original = settingsWith(
        absences: [
          SeniorAbsence(seniorId: 's1', date: '2026-08-13', reason: '병원'),
        ],
      );

      final restored = DispatchSettings.fromJson(original.toJson());

      expect(restored.routes.length, 1);
      expect(restored.routes.single.routeDrivers.length, 3);
      expect(restored.routes.single.routeDrivers.first.vehicleName, '스타리아');
      expect(restored.seniors.length, 2);
      expect(restored.seniorAbsences.single.reason, '병원');
    });

    test('아직 사람을 고르지 않은 빈 운전자 자리는 저장하지 않는다', () {
      final withBlank = DispatchSettings(
        routes: [
          DispatchRoute(
            id: 'r1',
            name: 'A코스',
            type: RouteType.toWork,
            routeDrivers: const [main1, RouteDriver()],
          ),
        ],
      );

      final restored = DispatchSettings.fromJson(withBlank.toJson());

      expect(restored.routes.single.routeDrivers.length, 1);
      expect(restored.routes.single.routeDrivers.single.driverName, '김영희');
    });

    test('서버가 빈 설정을 주면 빈 상태로 읽는다', () {
      final restored = DispatchSettings.fromJson({
        'routes': <dynamic>[],
        'seniors': <dynamic>[],
      });

      expect(restored.isEmpty, isTrue);
      expect(restored.seniorAbsences, isEmpty);
    });
  });
}
