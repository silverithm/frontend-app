import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/work_task.dart';

/// 업무진행도 규칙은 웹(frontend-admin src/lib/workTasks.ts)과 같아야 한다 —
/// 같은 업무가 웹에서는 "D-3", 앱에서는 "10/25"로 보이면 안 된다.
void main() {
  Map<String, dynamic> json({
    Object? id = 41,
    Object? progress = 40,
    String? importance = 'HIGH',
    String? dueDate = '2026-10-25',
    String? completedAt,
  }) => {
    'id': id,
    'content': '10월 사업계획서 작성',
    'importance': importance,
    'progress': progress,
    'dueDate': dueDate,
    'assignees': [
      {'id': '12', 'name': '박소향'},
      {'id': 'admin_3', 'name': '김원장'},
    ],
    'createdBy': {'id': 'admin_3', 'name': '김원장'},
    'createdAt': '2026-10-22T09:00:00',
    'updatedAt': '2026-10-22T09:00:00',
    'completedAt': completedAt,
    'canEdit': true,
    'canDelete': false,
  };

  WorkTask task({
    int id = 1,
    int progress = 0,
    String? completedAt,
    List<WorkTaskPerson> assignees = const [WorkTaskPerson(id: '12', name: '박소향')],
  }) => WorkTask(
    id: id,
    content: '업무$id',
    importance: WorkTaskImportance.normal,
    progress: progress,
    assignees: assignees,
    createdBy: const WorkTaskPerson(id: 'admin_3', name: '김원장'),
    completedAt: completedAt == null ? null : DateTime.parse(completedAt),
  );

  group('WorkTask.fromJson', () {
    test('서버 응답(WorkTaskDto.View)을 그대로 읽는다', () {
      final t = WorkTask.fromJson(json());

      expect(t.id, 41);
      expect(t.content, '10월 사업계획서 작성');
      expect(t.importance, WorkTaskImportance.high);
      expect(t.progress, 40);
      expect(t.dueDate, DateTime(2026, 10, 25));
      expect(t.assignees.map((a) => a.id), ['12', 'admin_3']);
      expect(t.createdBy.name, '김원장');
      expect(t.createdAt, DateTime(2026, 10, 22, 9));
      expect(t.canEdit, isTrue);
      expect(t.canDelete, isFalse);
      expect(t.isDone, isFalse);
    });

    test('숫자가 문자열로 와도 읽고, 수행도는 0~100으로 자른다', () {
      expect(WorkTask.fromJson(json(id: '7', progress: '30')).id, 7);
      expect(WorkTask.fromJson(json(progress: '30')).progress, 30);
      expect(WorkTask.fromJson(json(progress: 130)).progress, 100);
      expect(WorkTask.fromJson(json(progress: -10)).progress, 0);
      expect(WorkTask.fromJson(json(progress: null)).progress, 0);
    });

    test('모르는 중요도는 보통으로 본다', () {
      expect(
        WorkTask.fromJson(json(importance: 'URGENT')).importance,
        WorkTaskImportance.normal,
      );
      expect(
        WorkTask.fromJson(json(importance: null)).importance,
        WorkTaskImportance.normal,
      );
    });

    test('기한이 없거나 이상하면 null', () {
      expect(WorkTask.fromJson(json(dueDate: null)).dueDate, isNull);
      expect(WorkTask.fromJson(json(dueDate: '10/25')).dueDate, isNull);
    });

    test('끝낸 업무 — 완료 시각이 있거나 수행도 100', () {
      expect(WorkTask.fromJson(json(progress: 100)).isDone, isTrue);
      expect(
        WorkTask.fromJson(json(progress: 60, completedAt: '2026-10-22T10:00:00')).isDone,
        isTrue,
      );
    });

    test('담당자·등록한 사람이 비어 와도 죽지 않는다', () {
      final t = WorkTask.fromJson({'id': 1, 'content': 'x'});
      expect(t.assignees, isEmpty);
      expect(t.createdBy.id, '');
      expect(t.canEdit, isFalse);
    });
  });

  group('workTaskDueLabel — 웹 dueLabel과 같은 글자', () {
    final today = DateTime(2026, 10, 22, 15, 30); // 시각은 무시한다

    test('지난 기한', () {
      final label = workTaskDueLabel(DateTime(2026, 10, 20), today)!;
      expect(label.text, '10/20 지남');
      expect(label.tone, WorkTaskDueTone.overdue);
    });

    test('오늘·내일', () {
      expect(workTaskDueLabel(DateTime(2026, 10, 22), today)!.text, '오늘까지');
      expect(
        workTaskDueLabel(DateTime(2026, 10, 22), today)!.tone,
        WorkTaskDueTone.overdue,
      );
      expect(workTaskDueLabel(DateTime(2026, 10, 23), today)!.text, '내일까지');
      expect(
        workTaskDueLabel(DateTime(2026, 10, 23), today)!.tone,
        WorkTaskDueTone.soon,
      );
    });

    test('사흘 안은 D-n, 그 뒤는 날짜', () {
      expect(workTaskDueLabel(DateTime(2026, 10, 24), today)!.text, 'D-2');
      expect(workTaskDueLabel(DateTime(2026, 10, 25), today)!.text, 'D-3');
      final far = workTaskDueLabel(DateTime(2026, 10, 26), today)!;
      expect(far.text, '10/26');
      expect(far.tone, WorkTaskDueTone.normal);
    });

    test('달·해가 바뀌어도 날 수로 센다', () {
      expect(
        workTaskDueLabel(DateTime(2027, 1, 1), DateTime(2026, 12, 31))!.text,
        '내일까지',
      );
      expect(
        workTaskDueLabel(DateTime(2026, 11, 1), DateTime(2026, 10, 30))!.text,
        'D-2',
      );
    });

    test('기한이 없으면 글자도 없다', () {
      expect(workTaskDueLabel(null, today), isNull);
    });
  });

  group('workTaskAssigneeLabel', () {
    test('한 명·여러 명·없음', () {
      expect(
        workTaskAssigneeLabel(const [WorkTaskPerson(id: '1', name: '박소향')]),
        '박소향',
      );
      expect(
        workTaskAssigneeLabel(const [
          WorkTaskPerson(id: '1', name: '박소향'),
          WorkTaskPerson(id: '2', name: '이순자'),
          WorkTaskPerson(id: '3', name: '김원장'),
        ]),
        '박소향 외 2',
      );
      expect(workTaskAssigneeLabel(const []), '담당자 없음');
    });

    test('이름이 빈 사람은 세지 않는다', () {
      expect(
        workTaskAssigneeLabel(const [
          WorkTaskPerson(id: '1', name: '  '),
          WorkTaskPerson(id: '2'),
          WorkTaskPerson(id: '3', name: '김원장'),
        ]),
        '김원장',
      );
    });
  });

  test('수행도는 10% 단위로 맞춘다', () {
    expect(snapWorkTaskProgress(0), 0);
    expect(snapWorkTaskProgress(4), 0);
    expect(snapWorkTaskProgress(5), 10);
    expect(snapWorkTaskProgress(44), 40);
    expect(snapWorkTaskProgress(95), 100);
    expect(snapWorkTaskProgress(37.5), 40);
    expect(snapWorkTaskProgress(130), 100);
    expect(snapWorkTaskProgress(-5), 0);
  });

  group('WorkTaskInput.toJson — 서버 WorkTaskDto.Input 모양', () {
    test('내용은 앞뒤 공백을 걷고, 기한은 yyyy-MM-dd, 중요도는 서버 값', () {
      final body = WorkTaskInput(
        content: '  사업계획서  ',
        importance: WorkTaskImportance.low,
        progress: 44,
        dueDate: DateTime(2026, 3, 5),
        assigneeIds: const ['12', 'admin_3'],
      ).toJson();

      expect(body, {
        'content': '사업계획서',
        'importance': 'LOW',
        'progress': 40,
        'dueDate': '2026-03-05',
        'assigneeIds': ['12', 'admin_3'],
      });
    });

    test('기한이 없으면 null을 보낸다(기한 지우기)', () {
      final body = const WorkTaskInput(
        content: 'x',
        importance: WorkTaskImportance.normal,
        progress: 0,
        assigneeIds: ['12'],
      ).toJson();
      expect(body.containsKey('dueDate'), isTrue);
      expect(body['dueDate'], isNull);
    });

    test('기존 업무에서 시작하면 그 값 그대로', () {
      final input = WorkTaskInput.of(WorkTask.fromJson(json()));
      expect(input.content, '10월 사업계획서 작성');
      expect(input.importance, WorkTaskImportance.high);
      expect(input.progress, 40);
      expect(input.dueDate, DateTime(2026, 10, 25));
      expect(input.assigneeIds, ['12', 'admin_3']);
    });
  });

  test('진행 중·끝낸 것으로 나눠도 서버가 준 순서는 그대로', () {
    final tasks = [
      task(id: 3),
      task(id: 1, progress: 100),
      task(id: 2, progress: 50),
      task(id: 4, completedAt: '2026-10-21T09:00:00'),
    ];
    final split = splitWorkTasks(tasks);
    expect(split.inProgress.map((t) => t.id), [3, 2]);
    expect(split.done.map((t) => t.id), [1, 4]);
  });

  test('내가 맡은 진행 중 업무 수 — 끝낸 것과 남의 것은 빼고, 관리자 id도 구분한다', () {
    final tasks = [
      task(id: 1),
      task(id: 2, progress: 100),
      task(id: 3, assignees: const [WorkTaskPerson(id: 'admin_12')]),
      task(
        id: 4,
        assignees: const [WorkTaskPerson(id: '7'), WorkTaskPerson(id: '12')],
      ),
    ];
    expect(myInProgressWorkTaskCount(tasks, '12'), 2);
    expect(myInProgressWorkTaskCount(tasks, 'admin_12'), 1);
    expect(myInProgressWorkTaskCount(tasks, null), 0);
    expect(myInProgressWorkTaskCount(tasks, ''), 0);
  });

  test('담당자 후보 id — 관리자 3번과 직원 3번은 다른 사람', () {
    expect(workTaskPersonIdOf(type: 'ADMIN', id: 3), 'admin_3');
    expect(workTaskPersonIdOf(type: 'admin', id: 3), 'admin_3');
    expect(workTaskPersonIdOf(type: 'MEMBER', id: 3), '3');
  });

  test('중요도 글자 — 색만으로 구분하지 않는다', () {
    expect(WorkTaskImportance.values.map((i) => i.label), ['중요', '보통', '낮음']);
    expect(WorkTaskImportance.fromCode('LOW'), WorkTaskImportance.low);
  });
}
