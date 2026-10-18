import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/providers/schedule_provider.dart';
import 'package:frontend_app/services/api_service.dart';
import 'package:frontend_app/utils/schedule_repeat.dart';

/// 일정 등록 요청을 기록만 하는 가짜 — [failAt]번째(0부터) 요청에서 실패한다
class _FakeScheduleApi implements ApiService {
  final int? failAt;
  final List<Map<String, dynamic>> created = [];
  int calendarLoads = 0;

  _FakeScheduleApi({this.failAt});

  @override
  Future<Map<String, dynamic>> createSchedule({
    required String companyId,
    required Map<String, dynamic> scheduleData,
  }) async {
    if (created.length == failAt) throw Exception('서버 오류');
    created.add(scheduleData);
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> getSchedules({
    required String companyId,
    String? startDate,
    String? endDate,
    String? category,
    int? labelId,
    String? searchQuery,
  }) async {
    calendarLoads++;
    return {'schedules': []};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final base = <String, dynamic>{
    'title': '주간 프로그램 회의',
    'category': 'MEETING',
    'isAllDay': true,
    'sendNotification': true,
  };

  test('날짜마다 한 건씩, 알림은 첫 건에만, 달력은 마지막에 한 번만 다시 받는다', () async {
    final api = _FakeScheduleApi();
    final provider = ScheduleProvider(apiService: api);
    final starts = expandScheduleRepeatDates(
      DateTime(2026, 10, 20),
      ScheduleRepeatRule(
        kind: ScheduleRepeatKind.weekly,
        weekdays: {DateTime.tuesday, DateTime.thursday},
        until: DateTime(2026, 10, 29),
      ),
    );

    final result = await provider.createRepeatedSchedules(
      companyId: '4',
      scheduleData: base,
      startDate: DateTime(2026, 10, 20),
      endDate: DateTime(2026, 10, 20),
      starts: starts,
    );

    expect(result, (created: 4, total: 4));
    expect(api.created.map((s) => s['startDate']), [
      '2026-10-20',
      '2026-10-22',
      '2026-10-27',
      '2026-10-29',
    ]);
    expect(api.created.map((s) => s['sendNotification']), [
      true,
      false,
      false,
      false,
    ]);
    expect(api.created.every((s) => s['title'] == '주간 프로그램 회의'), isTrue);
    expect(api.calendarLoads, 1);
  });

  test('여러 날 일정은 종료일 간격을 그대로 옮긴다', () async {
    final api = _FakeScheduleApi();
    await ScheduleProvider(apiService: api).createRepeatedSchedules(
      companyId: '4',
      scheduleData: {...base, 'sendNotification': false},
      startDate: DateTime(2026, 10, 20),
      endDate: DateTime(2026, 10, 21),
      starts: [DateTime(2026, 10, 20), DateTime(2026, 11, 20)],
    );

    expect(api.created.map((s) => '${s['startDate']}~${s['endDate']}'), [
      '2026-10-20~2026-10-21',
      '2026-11-20~2026-11-21',
    ]);
    expect(api.created.map((s) => s['sendNotification']), [false, false]);
  });

  test('중간에 실패하면 멈추고, 만든 건은 두고 만든 건수를 알려 준다', () async {
    final api = _FakeScheduleApi(failAt: 2);
    final provider = ScheduleProvider(apiService: api);

    final result = await provider.createRepeatedSchedules(
      companyId: '4',
      scheduleData: base,
      startDate: DateTime(2026, 10, 20),
      endDate: DateTime(2026, 10, 20),
      starts: [
        DateTime(2026, 10, 20),
        DateTime(2026, 11, 20),
        DateTime(2026, 12, 20),
        DateTime(2027, 1, 20),
      ],
    );

    expect(result, (created: 2, total: 4));
    expect(provider.error, '일정 등록에 실패했습니다');
    // 만든 두 건이 달력에 보이도록 한 번은 다시 받는다
    expect(api.calendarLoads, 1);
  });

  test('첫 건부터 실패하면 달력을 다시 받지 않는다', () async {
    final api = _FakeScheduleApi(failAt: 0);
    final result = await ScheduleProvider(apiService: api)
        .createRepeatedSchedules(
          companyId: '4',
          scheduleData: base,
          startDate: DateTime(2026, 10, 20),
          endDate: DateTime(2026, 10, 20),
          starts: [DateTime(2026, 10, 20), DateTime(2026, 11, 20)],
        );

    expect(result, (created: 0, total: 2));
    expect(api.calendarLoads, 0);
  });
}
