import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/work_task.dart';
import 'package:frontend_app/providers/work_task_provider.dart';
import 'package:frontend_app/services/api_service.dart';
import 'package:frontend_app/widgets/work_task/work_task_edit_sheet.dart';
import 'package:provider/provider.dart';

class _FakeApi implements ApiService {
  final List<String> calls = [];
  Map<String, dynamic>? lastBody;

  Map<String, dynamic> _view(int id, Map<String, dynamic> body) => {
    'id': id,
    'content': body['content'],
    'importance': body['importance'],
    'progress': body['progress'],
    'assignees': [
      for (final id in body['assigneeIds'] as List) {'id': id, 'name': id},
    ],
    'createdBy': {'id': 'admin_3', 'name': '김원장'},
    'canEdit': true,
    'canDelete': true,
  };

  @override
  Future<Map<String, dynamic>> getWorkTasks() async {
    calls.add('list');
    return {'tasks': []};
  }

  @override
  Future<Map<String, dynamic>> createWorkTask(Map<String, dynamic> body) async {
    calls.add('create');
    lastBody = body;
    return _view(100, body);
  }

  @override
  Future<Map<String, dynamic>> updateWorkTask(
    int taskId,
    Map<String, dynamic> body,
  ) async {
    calls.add('update:$taskId');
    lastBody = body;
    return _view(taskId, body);
  }

  @override
  Future<Map<String, dynamic>> deleteWorkTask(int taskId) async {
    calls.add('delete:$taskId');
    return {};
  }

  @override
  Future<Map<String, dynamic>> getApproverCandidates({
    required String companyId,
  }) async => {
    'candidates': [
      {'approverType': 'ADMIN', 'approverId': 3, 'name': '김원장'},
      {'approverType': 'MEMBER', 'approverId': 12, 'name': '박소향'},
    ],
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WorkTask _task({bool canEdit = true, bool canDelete = true}) => WorkTask(
  id: 41,
  content: '사업계획서',
  importance: WorkTaskImportance.high,
  progress: 40,
  assignees: const [WorkTaskPerson(id: '12', name: '박소향')],
  createdBy: const WorkTaskPerson(id: 'admin_3', name: '김원장'),
  createdAt: DateTime(2026, 10, 22, 9),
  canEdit: canEdit,
  canDelete: canDelete,
);

/// 시트를 띄우고, 닫힐 때 돌려준 값을 [result]에 담는다
Future<_FakeApi> _open(
  WidgetTester tester, {
  WorkTask? task,
  required List<bool?> result,
}) async {
  // 폼이 다 보이도록 화면을 길게
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  final api = _FakeApi();
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => WorkTaskProvider(apiService: api),
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result.add(
                await WorkTaskEditSheet.show(
                  context,
                  task: task,
                  meId: 'admin_3',
                  companyId: '1',
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('새 업무 — 내용을 적기 전엔 등록이 안 되고, 기본 담당자는 나', (tester) async {
    final result = <bool?>[];
    final api = await _open(tester, result: result);

    expect(find.text('업무 등록'), findsOneWidget);
    expect(find.text('김원장 (나)'), findsOneWidget); // 명단에서 이름을 받아 온다

    await tester.tap(find.text('등록'));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('create')));

    await tester.enterText(find.byType(TextField), '  10월 사업계획서  ');
    await tester.pump();
    await tester.tap(find.text('중요'));
    await tester.pump();
    await tester.tap(find.text('등록'));
    await tester.pumpAndSettle();

    expect(api.calls, contains('create'));
    expect(api.lastBody, {
      'content': '10월 사업계획서',
      'importance': 'HIGH',
      'progress': 0,
      'dueDate': null,
      'assigneeIds': ['admin_3'],
    });
    expect(result, [true]);
    expect(find.text('업무 등록'), findsNothing); // 시트가 닫혔다
  });

  testWidgets('수정 — 지금 값으로 채워져 있고 저장하면 그 업무를 고친다', (tester) async {
    final result = <bool?>[];
    final api = await _open(tester, task: _task(), result: result);

    expect(find.text('업무 수정'), findsOneWidget);
    expect(find.text('사업계획서'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('박소향'), findsOneWidget);

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(api.calls, contains('update:41'));
    expect(api.lastBody!['importance'], 'HIGH');
    expect(api.lastBody!['progress'], 40);
    expect(api.lastBody!['assigneeIds'], ['12']);
    expect(result, [true]);
  });

  testWidgets('고칠 수 없는 사람에게는 읽기 전용 — 저장·지우기가 없다', (tester) async {
    final result = <bool?>[];
    await _open(
      tester,
      task: _task(canEdit: false, canDelete: false),
      result: result,
    );

    expect(find.text('업무 보기'), findsOneWidget);
    expect(find.text('관리자·등록한 사람·담당자만 고칠 수 있습니다'), findsOneWidget);
    expect(find.text('저장'), findsNothing);
    expect(find.text('지우기'), findsNothing);
    expect(find.text('바꾸기'), findsNothing);

    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(result, [false]);
  });

  testWidgets('지우기는 한 번 더 묻고 지운다', (tester) async {
    final result = <bool?>[];
    final api = await _open(tester, task: _task(), result: result);

    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();
    expect(find.text('업무 지우기'), findsOneWidget);
    expect(api.calls, isNot(contains('delete:41')));

    // 확인 창의 '지우기'
    await tester.tap(find.text('지우기').last);
    await tester.pumpAndSettle();

    expect(api.calls, contains('delete:41'));
    expect(result, [true]);
  });

  testWidgets('지울 수 없는 담당자에게는 지우기 단추가 없다', (tester) async {
    await _open(tester, task: _task(canDelete: false), result: []);

    expect(find.text('저장'), findsOneWidget);
    expect(find.text('지우기'), findsNothing);
  });
}
