import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/approval.dart';
import 'package:frontend_app/widgets/approval/approval_card.dart';
import 'package:frontend_app/widgets/approval/approval_status_badge.dart';
import 'package:frontend_app/widgets/approval/document_form_fields.dart';
import 'package:frontend_app/widgets/approval/template_card.dart';
import 'package:frontend_app/widgets/common/app_tag.dart';

/// B안(2026-11-12) 결재 부품 — 좁은 폰(320)에서 글자를 1.3배로 키워도 넘치지 않는지 본다.
/// (넘치면 RenderFlex overflowed 오류로 테스트가 실패한다)
ApprovalRequest _approval({String status = 'REJECTED'}) => ApprovalRequest.fromJson({
      'id': 1,
      'templateId': 1,
      'templateName': '지출결의서',
      'title': '보수교육 참석 출장 신청서 — 광주 평생교육원 2일 과정',
      'requesterId': '7',
      'requesterName': '햇살주간보호센터 사회복지사 조은비',
      'status': status,
      'rejectReason': '증빙 영수증을 붙여 다시 올려 주세요',
      'processedByName': '김관리',
      'processedAt': '2026-11-07T10:00:00',
      'attachmentFileName': '보수교육_영수증_스캔본_2026-11-07.pdf',
      'createdAt': '2026-11-07T13:00:00',
    });

ApprovalTemplate _template() => ApprovalTemplate.fromJson({
      'id': 1,
      'name': '지출결의서(비품·소모품 구매 전 결재용)',
      'description': '비용 지출 전 결재 — 영수증은 첨부파일로 올려 주세요',
      'templateType': 'form',
      'isActive': true,
      'fileName': '지출결의서_원본양식_2026.hwp',
      'createdAt': '2026-10-01T09:00:00',
      'formSchema': '{"fields":['
          '{"id":"item","type":"text","label":"지출 항목","width":"half","required":true},'
          '{"id":"amount","type":"number","label":"금액(원)","width":"half","required":true},'
          '{"id":"date","type":"date","label":"사용 일자","width":"half"},'
          '{"id":"pay","type":"select","label":"결제 방법","width":"half","options":['
          '{"value":"card","label":"법인카드"},{"value":"cash","label":"현금"}]},'
          '{"id":"sec","type":"section","label":"상세 내용"},'
          '{"id":"period","type":"dateRange","label":"출장 기간","width":"half"},'
          '{"id":"photo","type":"image","label":"영수증 사진","width":"half"},'
          '{"id":"kind","type":"radio","label":"구분","width":"full","options":['
          '{"value":"a","label":"교육"},{"value":"b","label":"출장"},{"value":"c","label":"구매"}]},'
          '{"id":"reason","type":"textarea","label":"사유","width":"full","required":true}'
          ']}',
    });

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(320, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(320, 1400),
        textScaler: TextScaler.linear(1.3),
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('결재 카드 — 긴 이름·날짜·처리 줄·반려 사유가 넘치지 않는다', (tester) async {
    await _pump(
      tester,
      Column(children: [
        ApprovalCard(approval: _approval(), onTap: () {}),
        ApprovalCard(
          approval: _approval(status: 'PENDING'),
          isSelected: true,
          showCheckbox: true,
          onCheckChanged: (_) {},
        ),
      ]),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('반려됨'), findsOneWidget);
    expect(find.text('진행중'), findsOneWidget);
  });

  testWidgets('상태 알약은 AppTag(색 뜻 그대로)', (tester) async {
    await _pump(
      tester,
      const Wrap(children: [
        ApprovalStatusBadge(status: ApprovalStatus.draft),
        ApprovalStatusBadge(status: ApprovalStatus.pending),
        ApprovalStatusBadge(status: ApprovalStatus.approved),
        ApprovalStatusBadge(status: ApprovalStatus.rejected, compact: true),
      ]),
    );
    final tones = tester.widgetList<AppTag>(find.byType(AppTag)).map((t) => t.tone).toList();
    expect(tones, [
      AppTagTone.neutral,
      AppTagTone.warning,
      AppTagTone.success,
      AppTagTone.error,
    ]);
  });

  testWidgets('양식 카드 두 가지 — 긴 양식 이름·파일 이름이 넘치지 않는다', (tester) async {
    await _pump(
      tester,
      Column(children: [
        TemplateCard(template: _template(), onTap: () {}, onEdit: () {}),
        TemplateSelectionCard(template: _template(), onTap: () {}),
        TemplateSelectionCard(template: _template(), isSelected: true, onTap: () {}),
      ]),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('활성'), findsOneWidget);
  });

  testWidgets('양식 칸 묶음(작성) — 반 칸 두 개·구획·날짜·고르기·이미지가 넘치지 않는다', (tester) async {
    await _pump(
      tester,
      DocumentFormFields(
        fields: _template().formFields,
        values: {},
        header: const Text('온라인 양식 작성'),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('온라인 양식 작성'), findsOneWidget);
    expect(find.text('상세 내용'), findsOneWidget);
    expect(find.text('날짜 선택'), findsOneWidget);
  });

  testWidgets('양식 칸 묶음(미리보기) — 회색 채움 칸으로 항목 구성만 보인다', (tester) async {
    await _pump(
      tester,
      DocumentFormFields(
        fields: _template().formFields,
        values: const {},
        readOnly: true,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('법인카드 / 현금'), findsOneWidget);
    expect(find.text('시작일 ~ 종료일'), findsOneWidget);
  });
}
