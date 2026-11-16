import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/approval.dart';
import 'package:frontend_app/widgets/approval/official_document_view.dart';

ApprovalRequest _approval({Map<String, dynamic>? formData}) => ApprovalRequest.fromJson({
      'id': 1,
      'templateId': 1,
      'templateName': '회의록',
      'title': '2026년8월24일 입소',
      'requesterId': '7',
      'requesterName': '배정민',
      'status': 'PENDING',
      'formData': formData,
      'createdAt': '2026-08-25T09:00:00',
      'hasApprovalLine': true,
      'approvalLine': [
        {'id': 1, 'stepOrder': 1, 'approverId': '8', 'approverName': '이수나', 'roleLabel': 'REVIEWER', 'status': 'PENDING'},
        {'id': 2, 'stepOrder': 2, 'approverId': '9', 'approverName': '김도형', 'roleLabel': 'FINAL', 'status': 'PENDING'},
      ],
    });

ApprovalTemplate _template() => ApprovalTemplate.fromJson({
      'id': 1,
      'name': '회의록',
      'templateType': 'form',
      'isActive': true,
      'formSchema': '{"fields":[{"id":"f1","type":"checkbox","label":"입소 상담 서류 제공","width":"full","options":['
          '{"value":"msplrdcq2ibd551yedh","label":"주민등록등본"},'
          '{"value":"msplvmbz0122t6xzchvwf","label":"건강진단서"}]}]}',
    });

void main() {
  testWidgets('체크박스 값이 내부 ID가 아니라 라벨로 나온다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: OfficialDocumentView(
            approval: _approval(formData: {
              'f1': ['msplrdcq2ibd551yedh', 'msplvmbz0122t6xzchvwf'],
            }),
            template: _template(),
            companyName: '숲속재활어르신재가복지센터',
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.textContaining('주민등록등본, 건강진단서'), findsOneWidget);
    expect(find.textContaining('msplrdcq'), findsNothing);
  });

  testWidgets('결재란은 웹처럼 2행 — 이름·날짜 행이 따로 없다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: OfficialDocumentView(
            approval: _approval(formData: {'f1': []}),
            template: _template(),
            companyName: '숲속재활어르신재가복지센터',
          ),
        ),
      ),
    ));
    await tester.pump();

    final table = tester.widget<Table>(find.byType(Table));
    expect(table.children.length, 2);
    // 현재 차례(1단계 이수나)만 결재중, 대기 단계는 빈 칸
    expect(find.text('결재중'), findsOneWidget);
    // 기안자 이름은 서명 칸에 남는다
    expect(find.text('배정민'), findsOneWidget);
  });

  testWidgets('양식을 고친 뒤 지난 문서 — 지운 항목 내용이 이전 양식 항목으로, 내부 키·빈 항목 없이', (tester) async {
    // 2026-11-16 업무일지: 'content'(행정 업무)를 복제한 뒤 원본을 지운 양식
    final template = ApprovalTemplate.fromJson({
      'id': 1,
      'name': '업무일지',
      'templateType': 'form',
      'isActive': true,
      'formSchema': '{"fields":['
          '{"id":"report-date","type":"date","label":"업무 일자","width":"half"},'
          '{"id":"mwimrby44qj5y9343e3","type":"textarea","label":"행정 업무 사본","width":"full"},'
          '{"id":"issues","type":"textarea","label":"어르신 특이사항"}],'
          '"retiredFields":[{"id":"content","type":"textarea","label":"행정 업무"}]}',
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: OfficialDocumentView(
            approval: _approval(formData: {
              'report-date': '2026-11-14',
              'content': '10:00 급여 서류 정리',
              'issues': '없음',
              'msocv159to0qjd38i7d': '',
            }),
            template: template,
            companyName: '숲속재활어르신재가복지센터',
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('이전 양식 항목'), findsOneWidget);
    expect(find.text('행정 업무'), findsOneWidget);
    expect(find.text('10:00 급여 서류 정리'), findsOneWidget);
    expect(find.text('content'), findsNothing);
    expect(find.textContaining('msocv159'), findsNothing);
  });

  testWidgets('지금 양식에 다 있는 문서에는 이전 양식 항목이 없다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: OfficialDocumentView(
            approval: _approval(formData: {'f1': ['msplrdcq2ibd551yedh'], 'stale': ''}),
            template: _template(),
            companyName: '숲속재활어르신재가복지센터',
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('이전 양식 항목'), findsNothing);
    expect(find.text('stale'), findsNothing);
  });
}
