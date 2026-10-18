import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/utils/schedule_repeat.dart';

/// 웹 src/lib/scheduleRepeat.test.ts와 같은 사례 — 앱과 웹이 같은 날짜를 만들어야 한다
void main() {
  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  ScheduleRepeatRule weekly(Set<int> days, DateTime until) =>
      ScheduleRepeatRule(
        kind: ScheduleRepeatKind.weekly,
        weekdays: days,
        until: until,
      );

  ScheduleRepeatRule monthly(DateTime until) =>
      ScheduleRepeatRule(kind: ScheduleRepeatKind.monthly, until: until);

  test('반복 없음은 시작일 하나', () {
    expect(
      expandScheduleRepeatDates(d(2026, 10, 16), ScheduleRepeatRule.none),
      [d(2026, 10, 16)],
    );
  });

  test('끝나는 날이 없거나 시작일보다 빠르면 시작일 하나', () {
    expect(
      expandScheduleRepeatDates(
        d(2026, 10, 16),
        const ScheduleRepeatRule(kind: ScheduleRepeatKind.weekly),
      ),
      [d(2026, 10, 16)],
    );
    expect(
      expandScheduleRepeatDates(
        d(2026, 10, 16),
        weekly({DateTime.monday}, d(2026, 10, 1)),
      ),
      [d(2026, 10, 16)],
    );
  });

  test('매주 월·수 — 시작일(금) 이후부터 2주', () {
    expect(
      expandScheduleRepeatDates(
        d(2026, 10, 16),
        weekly({DateTime.monday, DateTime.wednesday}, d(2026, 10, 30)),
      ),
      [d(2026, 10, 19), d(2026, 10, 21), d(2026, 10, 26), d(2026, 10, 28)],
    );
  });

  test('요일을 안 고르면 시작일의 요일로 매주', () {
    expect(
      expandScheduleRepeatDates(d(2026, 10, 16), weekly({}, d(2026, 11, 6))),
      [d(2026, 10, 16), d(2026, 10, 23), d(2026, 10, 30), d(2026, 11, 6)],
    );
  });

  test('매주 화·목, 10/20~12/31은 22건 — 달이 바뀌어도 끊기지 않는다', () {
    final dates = expandScheduleRepeatDates(
      d(2026, 10, 20),
      weekly({DateTime.tuesday, DateTime.thursday}, d(2026, 12, 31)),
    );
    expect(dates.length, 22);
    expect(dates.first, d(2026, 10, 20));
    expect(dates.last, d(2026, 12, 31));
  });

  test('매월 같은 날짜, 없는 날은 건너뛴다', () {
    expect(expandScheduleRepeatDates(d(2026, 1, 31), monthly(d(2026, 5, 31))), [
      d(2026, 1, 31),
      d(2026, 3, 31),
      d(2026, 5, 31),
    ]);
    expect(expandScheduleRepeatDates(d(2026, 10, 5), monthly(d(2027, 1, 4))), [
      d(2026, 10, 5),
      d(2026, 11, 5),
      d(2026, 12, 5),
    ]);
  });

  test('최대 건수를 넘기지 않는다', () {
    expect(
      expandScheduleRepeatDates(
        d(2026, 1, 1),
        weekly(scheduleRepeatWeekdayOrder.toSet(), d(2030, 12, 31)),
      ).length,
      maxScheduleRepeatCount,
    );
  });

  test('여러 날 일정의 종료일을 같은 간격으로 옮긴다', () {
    expect(
      shiftScheduleDate(d(2026, 10, 18), d(2026, 10, 16), d(2026, 10, 23)),
      d(2026, 10, 25),
    );
    // 달을 넘겨도 같은 간격
    expect(
      shiftScheduleDate(d(2026, 10, 21), d(2026, 10, 20), d(2026, 12, 31)),
      d(2027, 1, 1),
    );
  });

  test('한 줄 설명은 일~토 순서로', () {
    final rule = weekly({DateTime.thursday, DateTime.tuesday}, d(2026, 12, 31));
    expect(describeScheduleRepeat(rule, d(2026, 10, 20), 22), '매주 화·목요일마다 22건');
    expect(
      describeScheduleRepeat(monthly(d(2027, 3, 31)), d(2026, 10, 20), 6),
      '매월 20일마다 6건',
    );
    // 요일을 안 골랐으면 시작일 요일로 말한다
    expect(
      describeScheduleRepeat(weekly({}, d(2026, 11, 6)), d(2026, 10, 16), 4),
      '매주 금요일마다 4건',
    );
  });
}
