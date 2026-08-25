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
}
