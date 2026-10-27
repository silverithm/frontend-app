import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/utils/korean_keep_all.dart';

void main() {
  const wj = wordJoiner;

  group('keepAll — 낱말 안 한글 옆에만 이음표', () {
    test('한글 음절 사이에 넣고 띄어쓰기는 그대로', () {
      expect(keepAll('전원 참석'), '전$wj원 참$wj석');
    });

    test('숫자·문장부호와 맞닿은 한글 쪽에도 넣는다 — 영숫자끼리는 그대로', () {
      expect(keepAll('10시입니다.'), '10$wj시$wj입$wj니$wj다$wj.');
    });

    test('줄바꿈은 줄을 바꾸는 자리로 남긴다', () {
      expect(keepAll('첫줄\n둘째'), '첫$wj줄\n둘$wj째');
    });

    test('이모지 조합 안쪽은 건드리지 않는다 (❤️ = U+2764 U+FE0F)', () {
      final out = keepAll('좋아요❤️');
      expect(out, '좋$wj아$wj요$wj❤️');
      expect(out.contains('❤$wj️'), isFalse);
      expect(keepAll('👨‍👩‍👧'), '👨‍👩‍👧');
    });

    test('영어·URL만 있는 낱말은 그대로', () {
      expect(keepAll('https://carev.kr/a?b=1 ok'), 'https://carev.kr/a?b=1 ok');
    });

    test('두 번 돌려도 같다', () {
      const s = '오늘 오전 프로그램 사진입니다';
      expect(keepAll(keepAll(s)), keepAll(s));
    });

    test('이음표를 빼면 원문으로 돌아온다 (보이는 글자를 바꾸지 않는다)', () {
      const s = '내일 안전점검 교육 오전 10시입니다. 전원 참석 부탁드립니다.';
      expect(keepAll(s).replaceAll(wj, ''), s);
      expect(keepAll(''), '');
    });
  });

  testWidgets('좁은 폭에서 낱말 중간이 아니라 띄어쓰기에서 줄을 바꾼다', (tester) async {
    const text = '내일 안전점검 교육 오전 10시입니다. 전원 참석 부탁드립니다.';
    List<String> linesAt(String s) {
      final painter = TextPainter(
        text: TextSpan(text: s, style: const TextStyle(fontSize: 14)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 160);
      final lines = <String>[];
      var start = 0;
      for (final metric in painter.computeLineMetrics()) {
        final end = painter
            .getPositionForOffset(Offset(10000, metric.baseline - metric.ascent / 2))
            .offset;
        lines.add(s.substring(start, end).replaceAll(wordJoiner, '').trim());
        start = end;
      }
      return lines;
    }

    final words = text.split(' ').toSet();
    bool hasBrokenWord(List<String> lines) =>
        lines.any((line) => line.split(' ').any((piece) => !words.contains(piece)));

    // 대조: 원문 그대로면 같은 폭에서 낱말 중간이 잘린다 — 이 검사가 눈을 감고 있지 않다
    expect(hasBrokenWord(linesAt(text)), isTrue);
    expect(hasBrokenWord(linesAt(keepAll(text))), isFalse);
  });
}
