/// 반복 일정 펼치기 — 서버에는 "반복" 개념이 없으므로, 반복 설정을 날짜 목록으로 풀어
/// 일정을 날짜마다 한 건씩 등록한다(웹 src/lib/scheduleRepeat.ts와 같은 규칙).
///
/// 버그제보방 2026-10-16 "매주/매월 반복되는 업무는 일정에 요일마다 또는 날짜마다
/// 반복해서 한번에 추가할 수 있는 기능이 있으면 좋겠습니다".
library;

enum ScheduleRepeatKind { none, weekly, monthly }

/// 한 번에 등록할 수 있는 최대 건수 — 실수로 수백 건을 만들지 않게 한다 (웹과 같은 값)
const int maxScheduleRepeatCount = 60;

/// 화면에 늘어놓는 요일 순서 (일~토). 값은 [DateTime.weekday] — 월=1 … 일=7
const List<int> scheduleRepeatWeekdayOrder = [
  DateTime.sunday,
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
  DateTime.saturday,
];

String scheduleRepeatWeekdayName(int weekday) =>
    const ['월', '화', '수', '목', '금', '토', '일'][weekday - 1];

class ScheduleRepeatRule {
  final ScheduleRepeatKind kind;

  /// 매주일 때 반복할 요일([DateTime.weekday]). 비면 시작일의 요일을 쓴다
  final Set<int> weekdays;

  /// 마지막 날(포함). 반복이 없으면 null
  final DateTime? until;

  const ScheduleRepeatRule({
    this.kind = ScheduleRepeatKind.none,
    this.weekdays = const {},
    this.until,
  });

  static const none = ScheduleRepeatRule();

  bool get isRepeating => kind != ScheduleRepeatKind.none;

  ScheduleRepeatRule copyWith({
    ScheduleRepeatKind? kind,
    Set<int>? weekdays,
    DateTime? until,
    bool clearUntil = false,
  }) {
    return ScheduleRepeatRule(
      kind: kind ?? this.kind,
      weekdays: weekdays ?? this.weekdays,
      until: clearUntil ? null : (until ?? this.until),
    );
  }

  /// 매주인데 요일을 안 골랐으면 시작일의 요일 하나로 본다
  Set<int> weekdaysFor(DateTime start) =>
      weekdays.isNotEmpty ? weekdays : {start.weekday};
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// 시작일부터 종료일까지 규칙에 맞는 날짜 목록(시작일 포함, 날짜만).
/// 규칙이 없거나 종료일이 비었거나 시작일보다 빠르면 시작일 하나.
List<DateTime> expandScheduleRepeatDates(
  DateTime start,
  ScheduleRepeatRule rule,
) {
  final first = _day(start);
  final until = rule.until == null ? null : _day(rule.until!);
  if (!rule.isRepeating || until == null || until.isBefore(first)) {
    return [first];
  }

  final out = <DateTime>[];
  if (rule.kind == ScheduleRepeatKind.weekly) {
    final days = rule.weekdaysFor(first);
    for (var i = 0; out.length < maxScheduleRepeatCount; i++) {
      // DateTime 생성자가 달·해 넘김을 맞춰 준다 (시간대에 흔들리지 않게 날짜로만 센다)
      final d = DateTime(first.year, first.month, first.day + i);
      if (d.isAfter(until)) break;
      if (days.contains(d.weekday)) out.add(d);
    }
    return out.isEmpty ? [first] : out;
  }

  // 매월 — 같은 날짜. 그 달에 없는 날(31일 등)은 건너뛴다
  for (var i = 0; out.length < maxScheduleRepeatCount; i++) {
    final monthStart = DateTime(first.year, first.month + i, 1);
    if (monthStart.isAfter(until)) break;
    final candidate = DateTime(monthStart.year, monthStart.month, first.day);
    if (candidate.month != monthStart.month) continue;
    if (candidate.isAfter(until)) break;
    out.add(candidate);
  }
  return out.isEmpty ? [first] : out;
}

/// 여러 날 일정의 종료일을 시작일에서 떨어진 일수만큼 그대로 옮긴다
DateTime shiftScheduleDate(
  DateTime date,
  DateTime fromStart,
  DateTime toStart,
) {
  final diff = _day(date).difference(_day(fromStart)).inDays;
  final to = _day(toStart);
  return DateTime(to.year, to.month, to.day + diff);
}

/// 반복 설정을 사람이 읽을 한 줄로 — "매주 화·목요일마다 22건", "매월 20일마다 6건"
String describeScheduleRepeat(
  ScheduleRepeatRule rule,
  DateTime start,
  int count,
) {
  switch (rule.kind) {
    case ScheduleRepeatKind.weekly:
      final names = scheduleRepeatWeekdayOrder
          .where(rule.weekdaysFor(start).contains)
          .map(scheduleRepeatWeekdayName)
          .join('·');
      return '매주 $names요일마다 $count건';
    case ScheduleRepeatKind.monthly:
      return '매월 ${start.day}일마다 $count건';
    case ScheduleRepeatKind.none:
      return '';
  }
}
