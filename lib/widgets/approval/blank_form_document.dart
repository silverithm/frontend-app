import 'package:flutter/material.dart';

import '../../utils/blank_form.dart';
import '../../utils/form_field_width.dart';

/// 손으로 채우는 빈 서식(2026-11-15) — 제출된 기안과 같은 공문 틀(OfficialDocumentView)에 값 대신 쓸 자리를 그린다.
/// 웹 BlankFormDocument.tsx와 같은 모양·치수(px). 종이에 쓴 서식과 전자결재로 올린 문서가 같은 칸 배치가 된다.
///
/// 인쇄할 때는 머리([BlankFormHeader])와 본문 줄([BlankFormRow])을 따로 그림으로 떠서
/// 줄이 두 장에 걸쳐 잘리지 않게 장을 나눈다(services/blank_form_printer.dart).
/// 그래서 각 조각은 글꼴·글자 배율을 스스로 정한다 — 화면 테마 밖(그림 뜨는 곳)에서도 같은 크기로 그려진다.

/// 종이 안쪽 폭 — 공문 794px(A4 @96dpi) − 좌우 여백 44×2
const double blankFormContentWidth = 706;

const _ink = Color(0xFF111827);
const _sub = Color(0xFF374151);
const _line = Color(0xFF9CA3AF);
const _labelBg = Color(0xFFF3F4F6);
const _sectionBg = Color(0xFFE5E7EB);
const _font = 'Pretendard';

TextStyle _text(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = _ink,
  double? height,
  double? letterSpacing,
}) => TextStyle(
  fontFamily: _font,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  letterSpacing: letterSpacing,
  decoration: TextDecoration.none,
);

/// 조각마다 씌우는 바탕 — 흰 종이, 글자 배율 고정, 공문 안쪽 폭
class _Paper extends StatelessWidget {
  const _Paper({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.noScaling),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: DefaultTextStyle(
          style: _text(13),
          child: Container(
            width: blankFormContentWidth,
            color: Colors.white,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// '　　년　　월　　일' — 손으로 숫자를 써넣을 자리
class _BlankDate extends StatelessWidget {
  const _BlankDate({this.size = 13});
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = _text(size, color: _ink);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 44),
        Text('년', style: style),
        const SizedBox(width: 26),
        Text('월', style: style),
        const SizedBox(width: 26),
        Text('일', style: style),
      ],
    );
  }
}

/// 공문 머리 — 기관명 레터헤드, 문서번호·기안일자·시행일자(빈칸), 결재란(빈 서명 칸), 양식 이름
class BlankFormHeader extends StatelessWidget {
  const BlankFormHeader({
    super.key,
    required this.companyName,
    required this.title,
    required this.approvalHeaders,
  });

  final String companyName;
  final String title;
  final List<String> approvalHeaders;

  Widget _meta(String label, {bool date = false}) => SizedBox(
    height: 12 * 1.9,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: _text(12, color: _sub)),
        if (date) ...[const SizedBox(width: 4), const _BlankDate(size: 12)],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return _Paper(
      child: Padding(
        // 아래 본문 표와 떨어지는 자리까지 머리에 담는다(웹 제목 아래 24)
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  companyName,
                  textAlign: TextAlign.center,
                  style: _text(
                    24,
                    weight: FontWeight.w800,
                    letterSpacing: 24 * 0.35,
                  ),
                ),
              ),
            ),
            Container(height: 2, color: _ink),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _meta('문서번호 :'),
                      _meta('기안일자 :', date: true),
                      _meta('시행일자 :', date: true),
                    ],
                  ),
                ),
                Table(
                  defaultColumnWidth: const FixedColumnWidth(72),
                  border: TableBorder.all(color: _ink, width: 1),
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: _labelBg),
                      children: [
                        for (final label in approvalHeaders)
                          Container(
                            height: 24,
                            alignment: Alignment.center,
                            child: Text(
                              label,
                              style: _text(11, weight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                    TableRow(
                      children: [
                        for (var i = 0; i < approvalHeaders.length; i++)
                          const SizedBox(height: 52),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: _text(20, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 본문 한 줄 — 구역 제목이거나, 라벨/쓸 자리 칸 묶음.
/// 위 테두리는 그리지 않는다 — 줄을 쌓으면 윗줄의 아래 테두리가 이어 준다. 장의 첫 줄 위 선은 인쇄할 때 따로 긋는다.
class BlankFormRow extends StatelessWidget {
  const BlankFormRow({super.key, required this.fields});

  /// 이 줄의 칸(양식 formSchema 항목). 구역 제목이면 한 개.
  final List<Map<String, dynamic>> fields;

  static const _cellPad = EdgeInsets.symmetric(vertical: 8, horizontal: 10);
  static const _border = BorderSide(color: _line, width: 1);

  @override
  Widget build(BuildContext context) {
    final isSection =
        fields.length == 1 && fields.first['type']?.toString() == 'section';
    return _Paper(
      child: DecoratedBox(
        // 테두리를 칸 바탕 위에 긋는다 — 아래에 그리면 회색 라벨 칸이 왼쪽·아래 선을 덮는다
        position: DecorationPosition.foreground,
        decoration: const BoxDecoration(
          border: Border(left: _border, right: _border, bottom: _border),
        ),
        child: isSection
            ? Container(
                width: double.infinity,
                color: _sectionBg,
                padding: _cellPad,
                child: Text(
                  fields.first['label']?.toString() ?? '',
                  textAlign: TextAlign.center,
                  style: _text(
                    13,
                    weight: FontWeight.w700,
                    letterSpacing: 13 * 0.15,
                  ),
                ),
              )
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _cells(),
                ),
              ),
      ),
    );
  }

  /// 공문(OfficialDocumentView)과 같은 배분 — 라벨은 개수가 늘수록 좁히고(2개면 18%씩),
  /// 남는 자리를 각 칸의 폭 비율대로 나눈다
  List<Widget> _cells() {
    final labelPercent = (44 / fields.length).clamp(0, 18).toDouble();
    final labelFlex = (labelPercent * 100).round();
    final valueFlexTotal = ((100 - labelPercent * fields.length) * 100).round();
    final spans = [for (final f in fields) fieldWidthSpan(f['width'])];
    final spanTotal = spans.fold<int>(0, (a, b) => a + b);
    final cells = <Widget>[];
    for (var i = 0; i < fields.length; i++) {
      final field = fields[i];
      final last = i == fields.length - 1;
      final valueFlex =
          (valueFlexTotal * spans[i] / (spanTotal == 0 ? 1 : spanTotal))
              .round()
              .clamp(1, 100000);
      cells.add(
        Expanded(
          flex: labelFlex,
          child: Container(
            decoration: const BoxDecoration(
              color: _labelBg,
              border: Border(right: _border),
            ),
            padding: _cellPad,
            alignment: Alignment.center,
            child: Text(
              field['label']?.toString() ?? '',
              textAlign: TextAlign.center,
              style: _text(13, weight: FontWeight.w600),
            ),
          ),
        ),
      );
      cells.add(
        Expanded(
          flex: valueFlex,
          child: Container(
            // 한 줄 칸 — 손글씨 한 줄이 들어가는 높이(웹 36px)
            constraints: const BoxConstraints(minHeight: 36),
            decoration: BoxDecoration(
              border: Border(right: last ? BorderSide.none : _border),
            ),
            padding: _cellPad,
            alignment: Alignment.centerLeft,
            child: _BlankValue(cell: blankCellFor(field)),
          ),
        ),
      );
    }
    return cells;
  }
}

class _BlankValue extends StatelessWidget {
  const _BlankValue({required this.cell});
  final BlankCell cell;

  @override
  Widget build(BuildContext context) {
    return switch (cell) {
      BlankBox(:final lines) => SizedBox(
        height: lines * 22.0,
        width: double.infinity,
      ),
      BlankDate() => const _BlankDate(),
      BlankDateRange() => const Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 4,
        children: [_BlankDate(), Text('~'), _BlankDate()],
      ),
      BlankChoices(:final options) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            for (final option in options)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // □ — 글자(□)는 글꼴마다 크기가 달라 테두리 상자로 그린다(웹과 같다)
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(border: Border.all(color: _ink)),
                  ),
                  const SizedBox(width: 6),
                  Text(option, style: _text(13, height: 1.5)),
                ],
              ),
          ],
        ),
      ),
      BlankUnit(:final unit) => Align(
        alignment: Alignment.centerRight,
        child: Text(unit, style: _text(13, color: _sub)),
      ),
      BlankTable(:final columns, :final rows) => _BlankTable(
        columns: columns,
        rows: rows,
      ),
      BlankLine() => const SizedBox.shrink(),
    };
  }
}

class _BlankTable extends StatelessWidget {
  const _BlankTable({required this.columns, required this.rows});
  final List<String> columns;
  final int rows;

  @override
  Widget build(BuildContext context) {
    Widget cell(String text, {double height = 28, bool head = false}) =>
        Container(
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _text(
              12,
              weight: head ? FontWeight.w600 : FontWeight.w400,
              color: head ? _ink : _sub,
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Table(
        border: TableBorder.all(color: _line, width: 1),
        columnWidths: const {0: FixedColumnWidth(40)},
        defaultColumnWidth: const FlexColumnWidth(),
        children: [
          TableRow(
            decoration: const BoxDecoration(color: _labelBg),
            children: [
              cell('번호', height: 24, head: true),
              for (final c in columns) cell(c, height: 24, head: true),
            ],
          ),
          for (var r = 0; r < rows; r++)
            TableRow(
              children: [
                cell('${r + 1}'),
                for (var c = 0; c < columns.length; c++) cell(''),
              ],
            ),
        ],
      ),
    );
  }
}

/// 양식 항목을 공문과 같은 규칙으로 줄에 묶는다 — 12칸이 찰 때까지 한 줄에, 구역 제목은 한 줄 통째로.
List<List<Map<String, dynamic>>> blankFormRows(
  List<Map<String, dynamic>> fields,
) {
  return groupIntoRowsBySpan<Map<String, dynamic>>(
    fields,
    spanOf: (f) => fieldWidthSpan(f['width']),
    isBlock: (f) => f['type']?.toString() == 'section',
    maxPerRow: 4,
  );
}
