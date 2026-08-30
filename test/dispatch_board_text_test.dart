import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/dispatch.dart';
import 'package:frontend_app/utils/dispatch_algorithm.dart';
import 'package:frontend_app/utils/dispatch_board_text.dart';

/// 노선배차표 문구는 관리자 웹(src/lib/dispatchBoardText.ts)과 글자 단위로 같아야 한다.
/// 같은 날 같은 배차인데 앱과 웹이 다른 문구를 내놓으면 현장에서 신뢰를 잃는다.
///
/// 기대값은 센터장이 실제로 카톡방에 올리는 공지에서 그대로 가져왔다.
void main() {
  const monday = '2026-08-31';

  /// 실제 공지 한 판: 차량 / 인력 / [1차 명단, 2차 명단]
  const raw = <List<dynamic>>[
    [
      '레이2',
      ['이광성팀장'],
      [
        ['강문자', '조복수', '이종술', '유임생'],
        ['김태선', '이옥자2', '박옥자'],
      ],
    ],
    [
      '스타리아',
      ['황인후', '박성은팀장'],
      [
        ['박윤철', '김필수', '정순효'],
        ['김성숙', '황쌍자'],
      ],
    ],
    [
      '스타렉스',
      ['김형인'],
      [
        ['김안자', '정경남', '김옥남'],
      ],
    ],
  ];

  late DispatchSettings settings;

  setUp(() {
    final routes = <DispatchRoute>[];
    final seniors = <Senior>[];
    var elderlyId = 1;

    for (var ri = 0; ri < raw.length; ri++) {
      final vehicle = raw[ri][0] as String;
      final drivers = (raw[ri][1] as List).cast<String>();
      final trips = (raw[ri][2] as List).cast<List<dynamic>>();

      routes.add(
        DispatchRoute(
          id: 'r$ri',
          name: vehicle,
          type: RouteType.toWork,
          routeDrivers: [
            for (var i = 0; i < drivers.length; i++)
              RouteDriver(
                driverId: 'd$ri-$i',
                driverName: drivers[i],
                vehicleName: vehicle,
                vehicleCapacity: 12,
              ),
          ],
        ),
      );

      final usesTrip = trips.length > 1;
      var order = 1;
      for (var ti = 0; ti < trips.length; ti++) {
        for (final name in trips[ti].cast<String>()) {
          seniors.add(
            Senior(
              id: 's$elderlyId',
              name: name,
              routeId: 'r$ri',
              boardingOrder: order++,
              elderlyId: elderlyId,
              tripOrder: usesTrip ? ti + 1 : null,
            ),
          );
          elderlyId++;
        }
      }
    }

    // 보호자가 직접 데려오는 어르신 (노선에 배정되지 않는다)
    for (final name in ['장치분', '최손분', '하금선']) {
      seniors.add(
        Senior(
          id: 's$elderlyId',
          name: name,
          routeId: '',
          boardingOrder: 0,
          elderlyId: elderlyId,
          personalPickup: true,
        ),
      );
      elderlyId++;
    }

    settings = DispatchSettings(routes: routes, seniors: seniors);
  });

  test('카톡 공지와 글자 단위로 같은 배차표를 만든다', () {
    final daily = dailyDispatch(DateTime.parse(monday), settings, []);
    final text = buildDispatchBoardText(daily, RouteType.toWork);

    expect(text, '''8/31 (월) 등원   [개인등원 : 장치분, 최손분, 하금선]
총 18명
- 레이2/이광성팀장
1차) 강문자 조복수 이종술 유임생
2차) 김태선 이옥자2 박옥자
- 스타리아/황인후 박성은팀장
1차) 박윤철 김필수 정순효
2차) 김성숙 황쌍자
- 스타렉스/김형인
김안자 정경남 김옥남''');
  });

  test('총원은 차량 탑승 + 개인등하원 (결석자는 빠진다)', () {
    final daily = dailyDispatch(
      DateTime.parse(monday),
      settings,
      [],
      attendances: [
        // 강문자(1) 결석
        const ElderDayAttendance(elderlyId: 1, date: monday, status: '결석'),
      ],
    );

    // 15명 탑승 + 개인등원 3명 = 18명인데, 한 명 결석이라 17명
    expect(countAttending(daily, RouteType.toWork), 17);
    expect(buildDispatchBoardText(daily, RouteType.toWork), contains('총 17명'));
    expect(buildDispatchBoardText(daily, RouteType.toWork), isNot(contains('강문자')));
  });

  test('개인등하원이 없으면 대괄호를 붙이지 않는다', () {
    final plain = DispatchSettings(
      routes: settings.routes,
      seniors: settings.seniors.where((s) => !s.personalPickup).toList(),
    );
    final daily = dailyDispatch(DateTime.parse(monday), plain, []);

    expect(buildDispatchBoardText(daily, RouteType.toWork), startsWith('8/31 (월) 등원\n'));
  });

  test('운행이 없는 노선은 명단 자리에 사유를 적는다', () {
    final noDriver = DispatchSettings(
      routes: const [DispatchRoute(id: 'x', name: '모닝', type: RouteType.toWork)],
      seniors: const [],
    );
    final daily = dailyDispatch(DateTime.parse(monday), noDriver, []);

    expect(
      buildDispatchBoardText(daily, RouteType.toWork),
      contains('- 모닝\n운전자가 배정되지 않음'),
    );
  });
}
