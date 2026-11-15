/// 빈 서식 인쇄 — 온라인 양식을 종이에 손으로 채울 수 있게 칸마다 쓸 자리를 정한다.
///
/// 웹(frontend-admin `src/lib/blankForm.ts`, 2026-11-11 버그제보방 "결재 서식을 인쇄하여 쓸 수 있게")과
/// 같은 규칙이다. 2026-11-15 앱 요청 "결재서식을 인쇄하여 체크리스트로 — 작성된 보고서가 아닌 사용 전 양식".
/// 여기서는 칸 종류 → 종이에 그릴 모양만 정한다. 그리는 건 widgets/approval/blank_form_document.dart.
library;

import '../models/approval.dart';

/// 칸 하나를 종이에 어떻게 그릴지
sealed class BlankCell {
  const BlankCell();
}

/// 한 줄 쓸 자리 (글·숫자·첨부)
class BlankLine extends BlankCell {
  const BlankLine();
}

/// 여러 줄 쓸 자리 (긴 글·사진)
class BlankBox extends BlankCell {
  const BlankBox(this.lines);
  final int lines;
}

/// '　　년　　월　　일'
class BlankDate extends BlankCell {
  const BlankDate();
}

/// '　　년　　월　　일 ~ 　　년　　월　　일'
class BlankDateRange extends BlankCell {
  const BlankDateRange();
}

/// □ 보기 목록 — 하나만 고르는 칸도 종이에서는 표시해서 고른다
class BlankChoices extends BlankCell {
  const BlankChoices(this.options);
  final List<String> options;
}

/// 빈칸 뒤에 단위 (자동 합계 등)
class BlankUnit extends BlankCell {
  const BlankUnit(this.unit);
  final String unit;
}

/// 반복 항목 — 열 머리와 빈 줄
class BlankTable extends BlankCell {
  const BlankTable(this.columns, this.rows);
  final List<String> columns;
  final int rows;
}

/// 긴 글 칸 줄 수 — 넷이면 손글씨로 두세 문장이 들어간다
const int blankTextareaLines = 4;

/// 반쪽 이하 폭의 긴 글 칸 — 한 줄 줄인다
const int blankNarrowTextareaLines = 3;

/// 사진 칸 줄 수 — 명함판 사진을 붙일 만한 높이
const int blankImageLines = 6;

/// 반복 항목 기본 빈 줄 수
const int blankRepeaterRows = 5;

Map<String, dynamic>? _asMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

/// 반복 항목에 그릴 빈 줄 수 — 기본 다섯 줄, 양식이 정한 최소·최대가 있으면 그 안에서.
int blankRepeaterRowsFor(Map<String, dynamic> field) {
  final repeater = _asMap(field['repeater']);
  final min = (repeater?['minRows'] as num?)?.toInt() ?? 0;
  final max = (repeater?['maxRows'] as num?)?.toInt();
  var rows = blankRepeaterRows > min ? blankRepeaterRows : min;
  if (max != null && max > 0 && rows > max) rows = max;
  return rows < 1 ? 1 : rows;
}

List<String> _optionLabels(Map<String, dynamic> field) {
  final options = field['options'];
  if (options is! List) return const [];
  return [
    for (final option in options)
      if (option is Map)
        (option['label'] ?? option['value'] ?? '').toString().trim()
      else if (option != null)
        option.toString().trim(),
  ].where((label) => label.isNotEmpty).toList();
}

BlankCell blankCellFor(Map<String, dynamic> field) {
  switch (field['type']?.toString()) {
    case 'textarea':
      final width = field['width']?.toString();
      return BlankBox(
        width == null || width == 'full' || width == 'twoThirds'
            ? blankTextareaLines
            : blankNarrowTextareaLines,
      );
    case 'image':
      return const BlankBox(blankImageLines);
    case 'date':
      return const BlankDate();
    case 'dateRange':
      return const BlankDateRange();
    case 'select':
    case 'radio':
    case 'checkbox':
      final options = _optionLabels(field);
      return options.isEmpty ? const BlankLine() : BlankChoices(options);
    case 'computed':
      final unit = _asMap(field['computed'])?['unit']?.toString().trim() ?? '';
      return unit.isEmpty ? const BlankLine() : BlankUnit(unit);
    case 'repeater':
      final cols = _asMap(field['repeater'])?['fields'];
      final columns = [
        if (cols is List)
          for (final col in cols)
            if (col is Map) (col['label'] ?? '').toString(),
      ];
      return columns.isEmpty
          ? const BlankBox(blankTextareaLines)
          : BlankTable(columns, blankRepeaterRowsFor(field));
    default:
      return const BlankLine();
  }
}

/// 빈 서식을 찍을 수 있는 양식인지 — 화면에서 채우는 칸이 있는 온라인·혼합 양식
bool canPrintBlankForm(ApprovalTemplate template) {
  if (template.templateType != 'form' && template.templateType != 'hybrid') {
    return false;
  }
  return template.formFields.any((f) => f['type']?.toString() != 'section');
}

/// 결재란 머리 — 첫 칸은 기안, 기본 결재선이 있으면 그 단계 수만큼(마지막이 결재, 그 앞은 검토).
/// 기본 결재선이 없는 양식은 흔히 쓰는 기안·검토·결재 세 칸으로 둔다.
List<String> blankApprovalHeaders(int stepCount) {
  if (stepCount <= 0) return const ['기안', '검토', '결재'];
  return [
    '기안',
    for (var i = 0; i < stepCount; i++) i == stepCount - 1 ? '결재' : '검토',
  ];
}
