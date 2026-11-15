import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/approval.dart';
import 'package:frontend_app/services/blank_form_printer.dart';
import 'package:frontend_app/utils/blank_form.dart';
import 'package:frontend_app/widgets/approval/blank_form_document.dart';

/// 빈 서식 인쇄(2026-11-15) — 웹 blankForm.ts와 같은 규칙, 줄이 장에 걸쳐 잘리지 않는 장 나누기, PDF 만들기.
ApprovalTemplate _template({String? line}) => ApprovalTemplate.fromJson({
  'id': 1,
  'companyId': 1,
  'name': '차량 운행 점검표',
  'templateType': 'form',
  'defaultApprovalLine': line,
  'formSchema': {
    'fields': [
      {'id': 's1', 'type': 'section', 'label': '기본 정보'},
      {'id': 'd', 'type': 'date', 'label': '점검일', 'width': 'half'},
      {'id': 'n', 'type': 'text', 'label': '차량번호', 'width': 'half'},
      {'id': 'p', 'type': 'dateRange', 'label': '운행 기간'},
      {
        'id': 'c',
        'type': 'checkbox',
        'label': '점검 항목',
        'options': [
          {'value': 'a', 'label': '타이어'},
          {'value': 'b', 'label': '브레이크'},
          {'value': 'c', 'label': '등화장치'},
        ],
      },
      {
        'id': 'k',
        'type': 'computed',
        'label': '주행거리',
        'computed': {'unit': 'km'},
      },
      {
        'id': 'r',
        'type': 'repeater',
        'label': '운행 기록',
        'repeater': {
          'fields': [
            {'id': 'x', 'label': '시각'},
            {'id': 'y', 'label': '탑승 어르신'},
          ],
          'maxRows': 8,
        },
      },
      {'id': 't', 'type': 'textarea', 'label': '특이사항'},
      {'id': 'i', 'type': 'image', 'label': '사진', 'width': 'half'},
    ],
  },
});

void main() {
  group('칸 → 종이 모양', () {
    test('웹과 같은 규칙', () {
      final fields = _template().formFields;
      Map<String, dynamic> f(String id) => fields.firstWhere((e) => e['id'] == id);
      expect(blankCellFor(f('d')), isA<BlankDate>());
      expect(blankCellFor(f('p')), isA<BlankDateRange>());
      expect(blankCellFor(f('n')), isA<BlankLine>());
      expect((blankCellFor(f('c')) as BlankChoices).options, ['타이어', '브레이크', '등화장치']);
      expect((blankCellFor(f('k')) as BlankUnit).unit, 'km');
      final table = blankCellFor(f('r')) as BlankTable;
      expect(table.columns, ['시각', '탑승 어르신']);
      expect(table.rows, 5);
      expect((blankCellFor(f('t')) as BlankBox).lines, 4);
      expect((blankCellFor(f('i')) as BlankBox).lines, 6);
      // 보기가 없는 고르기 칸은 한 줄 쓸 자리
      expect(blankCellFor({'type': 'select', 'options': []}), isA<BlankLine>());
      // 양식이 정한 최소 줄 수가 더 많으면 그만큼, 최대가 작으면 거기까지
      expect(blankRepeaterRowsFor({'repeater': {'minRows': 7}}), 7);
      expect(blankRepeaterRowsFor({'repeater': {'maxRows': 3}}), 3);
    });

    test('결재란 머리와 인쇄 가능 여부', () {
      expect(blankApprovalHeaders(0), ['기안', '검토', '결재']);
      expect(blankApprovalHeaders(1), ['기안', '결재']);
      expect(blankApprovalHeaders(3), ['기안', '검토', '검토', '결재']);
      expect(canPrintBlankForm(_template()), isTrue);
      final file = ApprovalTemplate.fromJson({'id': 2, 'companyId': 1, 'name': 'x', 'templateType': 'file'});
      expect(canPrintBlankForm(file), isFalse);
    });
  });

  group('장 나누기', () {
    test('들어가지 않는 줄은 다음 장으로, 장마다 첫 줄 위 선 자리를 센다', () {
      final pages = blankFormPages(
        headerHeight: 200,
        rowHeights: [100, 100, 100, 100, 100],
        pageHeight: 500,
        lineHeight: 1,
      );
      // 첫 장: 머리 200 + 선 1 + 100×2 = 401, 세 번째 줄(501)은 넘친다
      expect(pages, [
        [0, 1],
        [2, 3, 4],
      ]);
    });

    test('한 장보다 긴 줄은 혼자 한 장', () {
      final pages = blankFormPages(
        headerHeight: 100,
        rowHeights: [50, 900, 50],
        pageHeight: 500,
        lineHeight: 1,
      );
      expect(pages, [
        [0],
        [1],
        [2],
      ]);
    });
  });

  testWidgets('종이 조각이 넘치지 않고 그려진다', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final t = _template();
    await tester.pumpWidget(
      SingleChildScrollView(
        child: Column(
          children: [
            BlankFormHeader(companyName: '숲속주간보호센터', title: t.name, approvalHeaders: blankApprovalHeaders(2)),
            for (final row in blankFormRows(t.formFields)) BlankFormRow(fields: row),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('문서번호 :'), findsOneWidget);
    expect(find.text('타이어'), findsOneWidget);
    expect(find.text('km'), findsOneWidget);
    expect(find.text('탑승 어르신'), findsOneWidget);
    // 반복 항목 번호 1~5
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('A4 PDF가 만들어진다', (tester) async {
    // 앱 글꼴을 실제로 실어 종이 모양을 확인할 수 있게 한다(OUT이 있으면 파일로 남긴다)
    final loader = FontLoader('Pretendard');
    for (final w in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    }
    await loader.load();
    final bytes = await tester.runAsync(
      () => BlankFormPrinter.buildPdf(template: _template(), companyName: '숲속주간보호센터'),
    );
    expect(bytes, isNotNull);
    expect(String.fromCharCodes(bytes!.take(5)), '%PDF-');
    const out = String.fromEnvironment('OUT');
    if (out.isNotEmpty) File('$out/blank_form.pdf').writeAsBytesSync(bytes);
  });
}
