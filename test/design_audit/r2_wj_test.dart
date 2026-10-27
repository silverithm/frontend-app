// R1 보조: U+2060 WORD JOINER 로 한글 어절 단위 줄바꿈이 되는지, 글자 폭이 늘지 않는지 확인
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

String keepAll(String s) => s.split(' ').map((w) {
      final r = w.runes.toList();
      return r.length < 2 ? w : r.map(String.fromCharCode).join('⁠');
    }).join(' ');

List<String> lines(String text, double w) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: const TextStyle(fontFamily: 'Pretendard', fontSize: 14, height: 1.5)),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: w);
  final out = <String>[];
  for (final m in tp.computeLineMetrics()) {
    final pos = tp.getPositionForOffset(Offset(1, m.baseline - 2));
    out.add('${pos.offset}');
  }
  return [for (var i = 0; i < tp.computeLineMetrics().length; i++) tp.getLineBoundary(tp.getPositionForOffset(Offset(1, tp.computeLineMetrics()[i].baseline - 2))).toString()];
}

void main() {
  testWidgets('wj', (t) async {
    await t.runAsync(() async {
    final l = FontLoader('Pretendard');
    final b = File('assets/fonts/Pretendard-Regular.otf').readAsBytesSync();
    l.addFont(Future.value(ByteData.view(b.buffer)));
    await l.load();
    });
    const s = '내일 안전점검 교육 오전 10시입니다. 전원 참석 부탁드립니다.';
    final k = keepAll(s);
    double wid(String x) => (TextPainter(text: TextSpan(text: x, style: const TextStyle(fontFamily: 'Pretendard', fontSize: 14)), textDirection: TextDirection.ltr)..layout()).width;
    // ignore: avoid_print
    print('R2WJ width plain=${wid("전원 참석")} wj=${wid(keepAll("전원 참석"))}');
    for (final mw in [150.0,170.0,190.0,200.0,210.0,220.0,230.0]) for (final src in [s, k]) {
      final tp = TextPainter(text: TextSpan(text: src, style: const TextStyle(fontFamily: 'Pretendard', fontSize: 14, height: 1.5)), textDirection: TextDirection.ltr)..layout(maxWidth: mw);
      final lm = tp.computeLineMetrics();
      var start = 0;
      final buf = <String>[];
      for (var i = 0; i < lm.length; i++) {
        final end = tp.getLineBoundary(tp.getPositionForOffset(Offset(1, lm[i].baseline - 3))).end;
        buf.add(src.substring(start, end).replaceAll('⁠', ''));
        start = end;
      }
      // ignore: avoid_print
      print('R2WJ w=$mw ${src==k?"WJ ":"raw"} lines(${lm.length}): ${buf.join(" | ")}');
    }
  });
}
