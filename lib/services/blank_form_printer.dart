import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:screenshot/screenshot.dart';

import '../models/approval.dart';
import '../utils/blank_form.dart';
import '../widgets/approval/blank_form_document.dart';

/// 결재 양식을 손으로 채울 빈 서식으로 인쇄한다(2026-11-15 "결재서식을 인쇄하여 체크리스트로").
///
/// 앱 글꼴(Pretendard)은 OTF라 PDF에 글자로 넣을 수 없어서, 공문 조각(머리·본문 줄)을 앱과 같은 글꼴로
/// 그려 3배 해상도 그림으로 뜬 뒤 A4에 붙인다. 줄 단위로 떠서 한 줄이 두 장에 걸쳐 잘리지 않는다.
/// 인쇄 창은 printing 라이브러리가 띄운다(아이폰 AirPrint·안드로이드 인쇄, PDF 저장·공유도 된다).
class BlankFormPrinter {
  BlankFormPrinter._();

  /// 그림 해상도 — 공문 706px 폭이 A4 180mm에 들어가므로 3배면 약 300dpi
  static const double pixelRatio = 3;

  /// A4 여백 15mm(웹 인쇄와 같다)
  static const double marginMm = 15;

  static Future<void> print({
    required ApprovalTemplate template,
    required String companyName,
  }) async {
    final bytes = await buildPdf(template: template, companyName: companyName);
    await Printing.layoutPdf(
      name: '${template.name} (빈 서식)',
      format: PdfPageFormat.a4,
      onLayout: (_) async => bytes,
    );
  }

  static Future<Uint8List> buildPdf({
    required ApprovalTemplate template,
    required String companyName,
  }) async {
    final shot = ScreenshotController();
    Future<Uint8List> capture(Widget widget) => shot.captureFromLongWidget(
      widget,
      pixelRatio: pixelRatio,
      delay: Duration.zero,
      constraints: const BoxConstraints(maxWidth: blankFormContentWidth),
    );

    final header = await capture(
      BlankFormHeader(
        companyName: companyName,
        title: template.name,
        approvalHeaders: blankApprovalHeaders(
          template.defaultApprovalLineCandidates.length,
        ),
      ),
    );
    final rows = <Uint8List>[];
    for (final row in blankFormRows(template.formFields)) {
      rows.add(await capture(BlankFormRow(fields: row)));
    }
    return compose(title: template.name, header: header, rows: rows);
  }

  /// 조각 그림을 A4 장에 붙인다. 장마다 첫 줄 위에는 표의 위 선을 긋는다(줄 그림은 위 선이 없다).
  static Future<Uint8List> compose({
    required String title,
    required Uint8List header,
    required List<Uint8List> rows,
  }) async {
    const margin = marginMm * PdfPageFormat.mm;
    final format = PdfPageFormat.a4.copyWith(
      marginLeft: margin,
      marginRight: margin,
      marginTop: margin,
      marginBottom: margin,
    );
    final width = format.availableWidth;
    // 공문 1px 선을 종이에서 같은 굵기로
    final hairline = width / blankFormContentWidth;

    final headerImage = pw.MemoryImage(header);
    final rowImages = [for (final r in rows) pw.MemoryImage(r)];
    double heightOf(pw.MemoryImage image) =>
        image.height! * width / image.width!;

    final pages = blankFormPages(
      headerHeight: heightOf(headerImage),
      rowHeights: [for (final image in rowImages) heightOf(image)],
      pageHeight: format.availableHeight,
      lineHeight: hairline,
    );

    final doc = pw.Document(title: '$title (빈 서식)', creator: '케어브이');
    for (var p = 0; p < pages.length; p++) {
      final children = <pw.Widget>[
        if (p == 0)
          pw.Image(headerImage, width: width, height: heightOf(headerImage)),
        if (pages[p].isNotEmpty)
          pw.Container(
            width: width,
            height: hairline,
            color: PdfColor.fromInt(0xFF9CA3AF),
          ),
        for (final i in pages[p])
          pw.Image(
            rowImages[i],
            width: width,
            // 한 줄이 한 장보다 길면(아주 긴 표) 그 장에 맞춰 줄인다
            height: heightOf(
              rowImages[i],
            ).clamp(0, format.availableHeight - hairline),
            fit: pw.BoxFit.contain,
          ),
      ];
      doc.addPage(
        pw.Page(
          pageFormat: format,
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: children,
          ),
        ),
      );
    }
    return doc.save();
  }
}

/// 본문 줄을 장에 나눈다 — 줄이 들어가지 않으면 다음 장으로 넘기고, 장마다 첫 줄 위에 선([lineHeight])을 둔다.
/// 첫 장에는 머리가 먼저 온다. 한 장보다 긴 줄은 그 줄 혼자 한 장을 쓴다.
/// 돌려주는 값: 장마다 그 장에 놓을 줄 번호.
List<List<int>> blankFormPages({
  required double headerHeight,
  required List<double> rowHeights,
  required double pageHeight,
  required double lineHeight,
}) {
  final pages = <List<int>>[<int>[]];
  var used = headerHeight;
  for (var i = 0; i < rowHeights.length; i++) {
    var page = pages.last;
    var need = rowHeights[i] + (page.isEmpty ? lineHeight : 0);
    // 아무것도 없는 장(머리도 없는)이면 넘겨 봐야 똑같다 — 길어도 이 장에 둔다
    final blank = page.isEmpty && (pages.length > 1 || headerHeight <= 0);
    if (used + need > pageHeight && !blank) {
      pages.add(page = <int>[]);
      used = 0;
      need = rowHeights[i] + lineHeight;
    }
    used += need;
    page.add(i);
  }
  return pages;
}
