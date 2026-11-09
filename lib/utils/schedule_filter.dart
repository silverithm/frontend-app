/// 월간일정 '일정 필터' 규칙.
///
/// 웹 관리자 화면(frontend-admin `src/lib/scheduleFilter.ts`)과 같은 규칙·같은 값을 쓴다.
///   일정 구분 — 'label:{id}' · 'noLabel'
///   담당자    — 'myTasks'(나) · 'person:MEMBER:9' · 'person:ADMIN:3'
///
/// 같은 묶음 안에서는 하나라도 맞으면 보이고(OR), 두 묶음을 다 골랐으면 둘 다 맞아야 보인다(AND).
/// '김요양 + 목욕'은 김요양이 맡은 목욕 일정이다(2026-11-09, 원장 요청 "담당자별로 월간업무 점검").
library;

import '../models/schedule.dart';

const String kMySchedulesFilter = 'myTasks';
const String kNoLabelFilter = 'noLabel';
const String _labelPrefix = 'label:';
const String _personPrefix = 'person:';

String labelFilterValue(int labelId) => '$_labelPrefix$labelId';
String personFilterValue(String personKey) => '$_personPrefix$personKey';

bool isKindFilterValue(String value) =>
    value == kNoLabelFilter || value.startsWith(_labelPrefix);
bool isPersonFilterValue(String value) =>
    value == kMySchedulesFilter || value.startsWith(_personPrefix);

/// 사람 키 "MEMBER:9" / "ADMIN:3".
/// 담당자 id는 종류에 따라 members.id 또는 app_user.id라 숫자만으로는 겹칠 수 있다(V1.88 사고).
String? managerPersonKey(Schedule schedule) {
  final id = schedule.managerId;
  if (id == null) return null;
  return '${schedule.managerType == 'ADMIN' ? 'ADMIN' : 'MEMBER'}:$id';
}

/// 이 일정을 맡은 사람들(키 → 이름) — 일정 담당자와 할 일 담당자.
/// 할 일 담당자는 늘 직원(members.id)이다. 참석자는 '맡은 사람'이 아니라 넣지 않는다.
Map<String, String> schedulePeople(Schedule schedule) {
  final people = <String, String>{};
  final managerKey = managerPersonKey(schedule);
  if (managerKey != null) {
    people[managerKey] = schedule.managerName?.trim() ?? '';
  }
  for (final task in schedule.tasks) {
    final assignee = task.assigneeMemberId;
    if (assignee == null) continue;
    final key = 'MEMBER:$assignee';
    if ((people[key] ?? '').isEmpty) {
      people[key] = task.assigneeName?.trim() ?? '';
    }
  }
  return people;
}

/// 구분이 없는 일정인지. 서버는 구분 없는 일정에도 빈 label을 실어 보내고
/// (옛 앱이 label.color만 읽어서다) 모델이 그 id를 0으로 읽는다.
bool hasNoLabel(Schedule schedule) {
  final label = schedule.label;
  return label == null || label.id == 0;
}

/// 일정 구분 묶음만 따진다. 이 묶음에서 아무것도 안 골랐으면 통과.
bool matchesKindFilter(Schedule schedule, List<String> values) {
  final kindValues = values.where(isKindFilterValue).toList();
  if (kindValues.isEmpty) return true;
  return kindValues.any((value) => value == kNoLabelFilter
      ? hasNoLabel(schedule)
      : !hasNoLabel(schedule) &&
          '${schedule.label!.id}' == value.substring(_labelPrefix.length));
}

/// 담당자 묶음만 따진다. 'myTasks'는 [isMine]으로 판정한다.
bool matchesPersonFilter(
  Schedule schedule,
  List<String> values,
  bool Function(Schedule) isMine,
) {
  final personValues = values.where(isPersonFilterValue).toList();
  if (personValues.isEmpty) return true;
  final people = schedulePeople(schedule);
  return personValues.any((value) => value == kMySchedulesFilter
      ? isMine(schedule)
      : people.containsKey(value.substring(_personPrefix.length)));
}

bool matchesScheduleFilter(
  Schedule schedule,
  List<String> values,
  bool Function(Schedule) isMine,
) {
  if (values.isEmpty) return true;
  return matchesKindFilter(schedule, values) &&
      matchesPersonFilter(schedule, values, isMine);
}

/// '나'에 해당하는 일정인지 — 웹 월간일정과 같은 규칙(작성자·일정 담당자·할 일 담당자·참석자).
/// 관리자 계정은 담당자 종류가 ADMIN일 때만 본인이다(id 공간이 다르다).
bool isMySchedule(
  Schedule schedule, {
  required String myId,
  required String myEmail,
  required bool isAdminAccount,
}) {
  if (myEmail.isNotEmpty && schedule.authorId == myEmail) return true;
  if (myId.isEmpty) return false;
  final myKey = '${isAdminAccount ? 'ADMIN' : 'MEMBER'}:$myId';
  if (managerPersonKey(schedule) == myKey) return true;
  if (isAdminAccount) return false;
  if (schedule.tasks.any((t) => '${t.assigneeMemberId}' == myId)) return true;
  return schedule.participants?.any((p) => p.memberId == myId) ?? false;
}

class SchedulePersonOption {
  /// "MEMBER:9" / "ADMIN:3"
  final String key;
  final String name;

  /// 이 사람이 맡은 일정 수 / 그중 수행완료된 수
  final int total;
  final int done;

  const SchedulePersonOption({
    required this.key,
    required this.name,
    required this.total,
    required this.done,
  });
}

/// 필터에 띄울 담당자 목록 — 넘겨받은 일정(보고 있는 달)에 담당으로 걸린 사람만, 이름순.
/// 이미 골라 둔 사람은 이번 달에 맡은 일정이 없어도 남긴다 — 사라지면 선택을 풀 길이 없다.
/// 완료 수는 일정 단위다(웹 달력·진행도와 같은 기준).
List<SchedulePersonOption> collectPersonOptions(
  Iterable<Schedule> schedules,
  List<String> selectedValues, {
  String? Function(String personKey)? fallbackName,
}) {
  final names = <String, String>{};
  final totals = <String, int>{};
  final dones = <String, int>{};
  for (final schedule in schedules) {
    schedulePeople(schedule).forEach((key, name) {
      totals[key] = (totals[key] ?? 0) + 1;
      if (schedule.isCompleted) dones[key] = (dones[key] ?? 0) + 1;
      if ((names[key] ?? '').isEmpty && name.isNotEmpty) names[key] = name;
    });
  }
  for (final value in selectedValues) {
    if (!value.startsWith(_personPrefix)) continue;
    totals.putIfAbsent(value.substring(_personPrefix.length), () => 0);
  }
  final options = totals.keys.map((key) {
    final known = names[key] ?? '';
    final name = known.isNotEmpty
        ? known
        : ((fallbackName?.call(key) ?? '').isNotEmpty
            ? fallbackName!(key)!
            : '이름 없음');
    return SchedulePersonOption(
      key: key,
      name: name,
      total: totals[key] ?? 0,
      done: dones[key] ?? 0,
    );
  }).toList()
    ..sort((a, b) {
      final byName = a.name.compareTo(b.name);
      return byName != 0 ? byName : a.key.compareTo(b.key);
    });
  return options;
}

/// '일정 필터' 단추 글자. 한 사람만 골랐으면 이름을 보인다 — 지금 누구의 일정인지
/// 단추만 봐도 알게(점검하면서 사람을 바꿔 가며 본다). 그 밖에는 고른 개수.
String scheduleFilterButtonLabel(
  List<String> values,
  Iterable<Schedule> schedules, {
  String? Function(String personKey)? fallbackName,
}) {
  if (values.isEmpty) return '일정 필터';
  if (values.length == 1 && values.first == kMySchedulesFilter) {
    return '일정 필터 · 나';
  }
  if (values.length == 1 && values.first.startsWith(_personPrefix)) {
    final key = values.first.substring(_personPrefix.length);
    for (final option in collectPersonOptions(
      schedules,
      values,
      fallbackName: fallbackName,
    )) {
      if (option.key == key) return '일정 필터 · ${option.name}';
    }
  }
  return '일정 필터 (${values.length})';
}
