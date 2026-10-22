import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/work_task.dart';
import 'package:frontend_app/widgets/work_task/work_task_row.dart';

WorkTask _task({
  int progress = 40,
  WorkTaskImportance importance = WorkTaskImportance.high,
  DateTime? due,
  String? completedAt,
}) => WorkTask(
  id: 1,
  content: '10월 사업계획서 작성',
  importance: importance,
  progress: progress,
  dueDate: due,
  assignees: const [
    WorkTaskPerson(id: '12', name: '박소향'),
    WorkTaskPerson(id: '7', name: '이순자'),
  ],
  createdBy: const WorkTaskPerson(id: 'admin_3', name: '김원장'),
  completedAt: completedAt == null ? null : DateTime.parse(completedAt),
);

Future<void> _pump(WidgetTester tester, WorkTask task, {VoidCallback? onTap}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WorkTaskRow(task: task, today: DateTime(2026, 10, 22), onTap: onTap),
      ),
    ),
  );
}

/// 원장 그림대로 한 줄에 [중요도] 업무 · 기한, 아랫줄에 담당자 뒤 진행도 게이지.
void main() {
  testWidgets('중요도·내용·기한·담당자·수행도를 한 줄씩 보여 준다', (tester) async {
    await _pump(tester, _task(due: DateTime(2026, 10, 24)));

    expect(find.text('중요'), findsOneWidget);
    expect(find.text('10월 사업계획서 작성'), findsOneWidget);
    expect(find.text('D-2'), findsOneWidget);
    expect(find.text('박소향 외 1'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.byType(WorkTaskGauge), findsOneWidget);
  });

  testWidgets('끝낸 업무는 기한을 숨기고 완료로 적는다', (tester) async {
    await _pump(
      tester,
      _task(progress: 100, due: DateTime(2026, 10, 20), completedAt: '2026-10-21T09:00:00'),
    );

    expect(find.text('완료'), findsOneWidget);
    expect(find.textContaining('지남'), findsNothing);
  });

  testWidgets('누르면 onTap — 그 업무 창을 연다', (tester) async {
    var tapped = 0;
    await _pump(tester, _task(), onTap: () => tapped++);

    await tester.tap(find.byType(WorkTaskRow));
    expect(tapped, 1);
  });

  testWidgets('화면 읽기 프로그램에 한 문장으로 읽힌다', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _task(due: DateTime(2026, 10, 22)), onTap: () {});

    expect(
      find.bySemanticsLabel('중요 · 10월 사업계획서 작성 · 박소향 외 1 · 진행 40% · 오늘까지'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('누를 자리가 48px 이상', (tester) async {
    await _pump(tester, _task(), onTap: () {});
    expect(tester.getSize(find.byType(InkWell)).height, greaterThanOrEqualTo(48));
  });
}
