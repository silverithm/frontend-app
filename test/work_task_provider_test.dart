import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/work_task.dart';
import 'package:frontend_app/providers/work_task_provider.dart';
import 'package:frontend_app/services/api_service.dart';

Map<String, dynamic> _task(int id, {int progress = 0, String? content}) => {
  'id': id,
  'content': content ?? '업무$id',
  'importance': 'NORMAL',
  'progress': progress,
  'dueDate': null,
  'assignees': [
    {'id': '12', 'name': '박소향'},
  ],
  'createdBy': {'id': 'admin_3', 'name': '김원장'},
  'createdAt': '2026-10-22T09:00:00',
  'completedAt': progress >= 100 ? '2026-10-22T10:00:00' : null,
  'canEdit': true,
  'canDelete': true,
};

/// 업무진행도 API를 흉내 낸다 — 서버처럼 저장하면 목록에도 반영한다
class _FakeWorkTaskApi implements ApiService {
  List<Map<String, dynamic>> serverTasks = [];
  Object? failWith;
  int listCalls = 0;
  int candidateCalls = 0;
  final List<String> calls = [];
  Map<String, dynamic>? lastBody;
  Map<String, dynamic> candidates = {'candidates': []};

  void _maybeFail() {
    final error = failWith;
    if (error != null) throw error;
  }

  @override
  Future<Map<String, dynamic>> getWorkTasks() async {
    listCalls++;
    calls.add('list');
    _maybeFail();
    return {'tasks': serverTasks};
  }

  @override
  Future<Map<String, dynamic>> createWorkTask(Map<String, dynamic> body) async {
    calls.add('create');
    lastBody = body;
    _maybeFail();
    final created = _task(100, content: body['content'] as String);
    serverTasks = [created, ...serverTasks];
    return created;
  }

  @override
  Future<Map<String, dynamic>> updateWorkTask(
    int taskId,
    Map<String, dynamic> body,
  ) async {
    calls.add('update:$taskId');
    lastBody = body;
    _maybeFail();
    final updated = _task(taskId, content: body['content'] as String);
    serverTasks = [
      for (final t in serverTasks) t['id'] == taskId ? updated : t,
    ];
    return updated;
  }

  @override
  Future<Map<String, dynamic>> updateWorkTaskProgress(
    int taskId,
    int progress,
  ) async {
    calls.add('progress:$taskId:$progress');
    _maybeFail();
    final updated = _task(taskId, progress: progress);
    serverTasks = [
      for (final t in serverTasks) t['id'] == taskId ? updated : t,
    ];
    return updated;
  }

  @override
  Future<Map<String, dynamic>> deleteWorkTask(int taskId) async {
    calls.add('delete:$taskId');
    _maybeFail();
    serverTasks = serverTasks.where((t) => t['id'] != taskId).toList();
    return {};
  }

  @override
  Future<Map<String, dynamic>> getApproverCandidates({
    required String companyId,
  }) async {
    candidateCalls++;
    calls.add('candidates:$companyId');
    _maybeFail();
    return candidates;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _input = WorkTaskInput(
  content: '  사업계획서  ',
  importance: WorkTaskImportance.high,
  progress: 33,
  assigneeIds: ['12'],
);

void main() {
  late _FakeWorkTaskApi api;
  late WorkTaskProvider provider;
  late int notified;

  setUp(() {
    api = _FakeWorkTaskApi();
    provider = WorkTaskProvider(apiService: api);
    notified = 0;
    provider.addListener(() => notified++);
  });

  group('load', () {
    test('서버가 준 순서 그대로 받고, 진행 중·끝낸 것으로 나눈다', () async {
      api.serverTasks = [_task(3), _task(1, progress: 100), _task(2, progress: 50)];

      await provider.load();

      expect(provider.status, WorkTaskLoadStatus.loaded);
      expect(provider.tasks.map((t) => t.id), [3, 1, 2]);
      expect(provider.inProgress.map((t) => t.id), [3, 2]);
      expect(provider.done.map((t) => t.id), [1]);
      expect(notified, greaterThanOrEqualTo(2)); // loading → loaded
    });

    test('처음 받기에 실패하면 error', () async {
      api.failWith = Exception('네트워크');

      await provider.load();

      expect(provider.status, WorkTaskLoadStatus.error);
      expect(provider.tasks, isEmpty);
    });

    test('이미 받은 목록은 다시 받기에 실패해도 지우지 않는다', () async {
      api.serverTasks = [_task(1)];
      await provider.load();
      api.failWith = Exception('잠깐 끊김');

      await provider.load();

      expect(provider.status, WorkTaskLoadStatus.loaded);
      expect(provider.tasks.map((t) => t.id), [1]);
    });

    test('tasks가 목록이 아니면 빈 목록', () async {
      await provider.load();
      expect(provider.tasks, isEmpty);
      expect(provider.hasLoaded, isTrue);
    });
  });

  group('저장', () {
    test('등록 — 서버 모양으로 보내고(공백 걷기·10% 단위), 새 목록을 다시 받는다', () async {
      api.serverTasks = [_task(1)];
      await provider.load();
      api.calls.clear();

      final saved = await provider.create(_input);

      expect(saved.id, 100);
      expect(api.lastBody!['content'], '사업계획서');
      expect(api.lastBody!['importance'], 'HIGH');
      expect(api.lastBody!['progress'], 30);
      expect(api.calls, ['create', 'list']);
      expect(provider.tasks.map((t) => t.id), [100, 1]);
    });

    test('수정 — 그 업무만 바뀐다', () async {
      api.serverTasks = [_task(1), _task(2)];
      await provider.load();

      await provider.update(2, _input);

      expect(api.calls, contains('update:2'));
      expect(provider.byId(2)!.content, '사업계획서');
      expect(provider.byId(1)!.content, '업무1');
    });

    test('수행도만 올리기 — 10% 단위로 맞춰 보낸다', () async {
      api.serverTasks = [_task(5)];
      await provider.load();

      final saved = await provider.updateProgress(5, 67);

      expect(api.calls, contains('progress:5:70'));
      expect(saved.progress, 70);
      expect(provider.byId(5)!.progress, 70);
    });

    test('100%가 되면 끝낸 업무로 내려간다', () async {
      api.serverTasks = [_task(5), _task(6)];
      await provider.load();

      await provider.updateProgress(5, 100);

      expect(provider.inProgress.map((t) => t.id), [6]);
      expect(provider.done.map((t) => t.id), [5]);
    });

    test('서버가 거절하면 그 문구로 알린다(권한 없음 등)', () async {
      api.serverTasks = [_task(1)];
      await provider.load();
      api.failWith = ApiException('관리자·등록한 사람·담당자만 고칠 수 있습니다', 403);

      await expectLater(
        provider.update(1, _input),
        throwsA(
          isA<WorkTaskException>().having(
            (e) => e.message,
            'message',
            '관리자·등록한 사람·담당자만 고칠 수 있습니다',
          ),
        ),
      );
      expect(provider.byId(1)!.content, '업무1'); // 그대로
    });

    test('서버 문구가 없으면 화면용 기본 문구', () async {
      api.failWith = Exception('socket');
      await expectLater(
        provider.create(_input),
        throwsA(
          isA<WorkTaskException>().having(
            (e) => e.message,
            'message',
            '업무를 등록하지 못했습니다',
          ),
        ),
      );
      await expectLater(
        provider.updateProgress(1, 10),
        throwsA(
          isA<WorkTaskException>().having(
            (e) => e.message,
            'message',
            '수행도를 바꾸지 못했습니다',
          ),
        ),
      );
    });
  });

  group('삭제', () {
    test('지우면 목록에서 빠지고 새 목록을 받는다', () async {
      api.serverTasks = [_task(1), _task(2)];
      await provider.load();
      api.calls.clear();

      await provider.delete(1);

      expect(api.calls, ['delete:1', 'list']);
      expect(provider.tasks.map((t) => t.id), [2]);
    });

    test('실패하면 목록은 그대로 두고 알린다', () async {
      api.serverTasks = [_task(1)];
      await provider.load();
      api.failWith = ApiException('관리자나 등록한 사람만 지울 수 있습니다', 403);

      await expectLater(
        provider.delete(1),
        throwsA(
          isA<WorkTaskException>().having(
            (e) => e.message,
            'message',
            '관리자나 등록한 사람만 지울 수 있습니다',
          ),
        ),
      );
      expect(provider.tasks.map((t) => t.id), [1]);
    });
  });

  group('담당자 후보', () {
    setUp(() {
      api.candidates = {
        'candidates': [
          {'approverType': 'ADMIN', 'approverId': 3, 'name': '김원장', 'position': '시설장'},
          {'approverType': 'MEMBER', 'approverId': 3, 'name': '박소향', 'position': ' '},
          {'approverType': 'MEMBER', 'approverId': '12', 'name': '이순자'},
          {'approverType': 'MEMBER', 'approverId': 12, 'name': '이순자'}, // 중복
          {'approverType': 'MEMBER', 'approverId': 'x', 'name': '잘못된 행'},
        ],
      };
    });

    test('관리자는 admin_<id>, 직원은 <id> — 겹치는 번호를 다른 사람으로 본다', () async {
      final people = await provider.loadPeople('1');

      expect(people.map((p) => p.id), ['admin_3', '3', '12']);
      expect(people.first.position, '시설장');
      expect(people[1].position, isNull); // 빈 직책은 없음으로
    });

    test('같은 기관은 한 번만 받고, 기관이 바뀌거나 로그아웃하면 다시 받는다', () async {
      await provider.loadPeople('1');
      await provider.loadPeople('1');
      expect(api.candidateCalls, 1);

      await provider.loadPeople('2');
      expect(api.candidateCalls, 2);

      provider.clear();
      await provider.loadPeople('2');
      expect(api.candidateCalls, 3);
    });
  });

  test('로그아웃하면 목록도 비운다', () async {
    api.serverTasks = [_task(1)];
    await provider.load();

    provider.clear();

    expect(provider.tasks, isEmpty);
    expect(provider.status, WorkTaskLoadStatus.idle);
  });

  test('내가 맡은 진행 중 업무 수', () async {
    api.serverTasks = [_task(1), _task(2, progress: 100)];
    await provider.load();

    expect(provider.myInProgressCount('12'), 1);
    expect(provider.myInProgressCount('admin_3'), 0);
  });
}
