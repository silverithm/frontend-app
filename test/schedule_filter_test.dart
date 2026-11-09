// 월간일정 '일정 필터' — 웹 src/lib/scheduleFilter.test.ts와 같은 사례.
//
// 여기서 못 박는 것:
// - 담당자로 고르면 일정 담당자·할 일 담당자 어느 쪽이든 잡히고, 참석자만인 일정은 안 잡힌다
// - 직원 3번과 관리자 3번은 다른 사람이다
// - 구분과 담당자를 같이 고르면 둘 다 맞아야 보인다(같은 묶음 안은 하나만 맞아도)
// - 서버가 실어 보내는 빈 label(모델에선 id 0)도 '구분 없음'으로 잡힌다
// - 담당자 목록은 이름순, 완료 수는 일정 단위, 골라 둔 사람은 이번 달에 없어도 남는다
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/schedule.dart';
import 'package:frontend_app/utils/schedule_filter.dart';

Schedule _schedule({
  required int id,
  Map<String, dynamic>? label,
  int? managerId,
  String? managerType,
  String? managerName,
  bool isCompleted = false,
  List<Map<String, dynamic>> tasks = const [],
  List<Map<String, dynamic>> participants = const [],
  String? authorId,
}) {
  return Schedule.fromJson({
    'id': id,
    'title': '일정 $id',
    'category': 'OTHER',
    'startDate': '2026-09-02',
    'endDate': '2026-09-02',
    'label': label,
    'managerId': managerId,
    'managerType': managerType,
    'managerName': managerName,
    'isCompleted': isCompleted,
    'tasks': tasks,
    'participants': participants,
    'authorId': authorId,
    'companyId': 1,
  });
}

void main() {
  final bath = _schedule(
    id: 1,
    label: {'id': 7, 'name': '목욕', 'color': '#3B82F6'},
    managerId: 9,
    managerType: 'MEMBER',
    managerName: '김요양',
    isCompleted: true,
  );
  final program = _schedule(
    id: 2,
    label: {'id': 8, 'name': '프로그램', 'color': '#8B5CF6'},
    managerId: 3,
    managerType: 'ADMIN',
    managerName: '박원장',
    tasks: [
      {'id': 1, 'scheduleId': 2, 'content': 'a', 'assigneeMemberId': 9, 'assigneeName': '김요양'},
      {'id': 2, 'scheduleId': 2, 'content': 'b', 'assigneeMemberId': 12, 'assigneeName': '이사회'},
    ],
  );
  // 서버는 구분 없는 일정에도 빈 label을 붙여 보낸다
  final meeting = _schedule(
    id: 3,
    label: {'id': null, 'name': '', 'color': '#14B8A6'},
    participants: [
      {'id': 1, 'memberId': 9, 'memberName': '김요양'},
    ],
  );
  final legacy = _schedule(
    id: 4,
    managerId: 12,
    managerName: '이사회',
    isCompleted: true,
  );
  final all = [bath, program, meeting, legacy];

  List<int> ids(List<String> values, [bool Function(Schedule)? isMine]) => all
      .where((s) => matchesScheduleFilter(s, values, isMine ?? (_) => false))
      .map((s) => s.id)
      .toList();

  test('아무것도 안 고르면 전부 보인다', () {
    expect(ids([]), [1, 2, 3, 4]);
  });

  test('담당자 — 일정 담당자와 할 일 담당자 둘 다, 참석자만인 일정은 뺀다', () {
    expect(ids([personFilterValue('MEMBER:9')]), [1, 2]);
    expect(ids([personFilterValue('MEMBER:12')]), [2, 4]);
  });

  test('직원 3번과 관리자 3번은 다른 사람', () {
    expect(ids([personFilterValue('ADMIN:3')]), [2]);
    expect(ids([personFilterValue('MEMBER:3')]), <int>[]);
  });

  test('같은 묶음 안은 하나만 맞아도, 두 묶음은 둘 다 맞아야', () {
    expect(ids([personFilterValue('MEMBER:9'), personFilterValue('ADMIN:3')]), [1, 2]);
    expect(ids([labelFilterValue(7), labelFilterValue(8)]), [1, 2]);
    expect(ids([labelFilterValue(7), personFilterValue('MEMBER:12')]), <int>[]);
    expect(ids([labelFilterValue(8), personFilterValue('MEMBER:9')]), [2]);
  });

  test("'구분 없음'은 label이 없거나 빈 label인 일정", () {
    expect(ids([kNoLabelFilter]), [3, 4]);
  });

  test("'나' — 작성자·담당자·할 일·참석자, 관리자는 ADMIN 담당만", () {
    bool member9(Schedule s) =>
        isMySchedule(s, myId: '9', myEmail: 'kim@carev.kr', isAdminAccount: false);
    expect(all.where(member9).map((s) => s.id).toList(), [1, 2, 3]);
    bool admin3(Schedule s) =>
        isMySchedule(s, myId: '3', myEmail: 'boss@carev.kr', isAdminAccount: true);
    expect(all.where(admin3).map((s) => s.id).toList(), [2]);
    bool admin9(Schedule s) =>
        isMySchedule(s, myId: '9', myEmail: 'boss@carev.kr', isAdminAccount: true);
    expect(all.where(admin9).map((s) => s.id).toList(), <int>[]);
    expect(ids([kMySchedulesFilter], member9), [1, 2, 3]);
  });

  test('모르는 값만 남아 있으면 거르지 않는다', () {
    expect(ids(['something-old']), [1, 2, 3, 4]);
  });

  test('담당자 목록 — 이름순, 일정 단위 완료 수', () {
    final options = collectPersonOptions(all, []);
    expect(
      options.map((o) => '${o.key} ${o.name} ${o.done}/${o.total}').toList(),
      ['MEMBER:9 김요양 1/2', 'ADMIN:3 박원장 0/1', 'MEMBER:12 이사회 1/2'],
    );
  });

  test('골라 둔 사람은 이번 달에 맡은 일정이 없어도 남는다', () {
    final options = collectPersonOptions(
      [bath],
      [personFilterValue('MEMBER:40')],
      fallbackName: (key) => key == 'MEMBER:40' ? '최간호' : null,
    );
    expect(
      options.map((o) => '${o.name} ${o.done}/${o.total}').toList(),
      ['김요양 1/1', '최간호 0/0'],
    );
    expect(
      collectPersonOptions([], [personFilterValue('MEMBER:41')]).single.name,
      '이름 없음',
    );
  });

  test('단추 글자 — 한 사람만 고르면 이름, 그 밖에는 개수', () {
    expect(scheduleFilterButtonLabel([], all), '일정 필터');
    expect(scheduleFilterButtonLabel([personFilterValue('MEMBER:9')], all), '일정 필터 · 김요양');
    expect(scheduleFilterButtonLabel([kMySchedulesFilter], all), '일정 필터 · 나');
    expect(scheduleFilterButtonLabel([labelFilterValue(7)], all), '일정 필터 (1)');
    expect(
      scheduleFilterButtonLabel([personFilterValue('MEMBER:9'), labelFilterValue(7)], all),
      '일정 필터 (2)',
    );
  });
}
