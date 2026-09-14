import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 글자를 그리는 방법에 대한 가드.
///
/// 채팅 말풍선 본문이 `RichText`로 그려지고 있었다. `RichText`는 `Text`와 달리
/// 글자 배율(기본값 `TextScaler.noScaling`)도, 앱 서체(`DefaultTextStyle`)도 물려받지 않는다.
/// 그래서 글자 크기를 '아주 크게'로 바꾸면 이름·시간·답장 인용문은 커지는데 본문만 그대로였고,
/// 서체도 본문만 달랐다 (제보 2026-09-08 "폰트와 크기가 제각각").
void main() {
  test('lib 안에서 RichText를 직접 쓰지 않는다 — Text.rich를 쓴다', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'\bRichText\(').hasMatch(lines[i])) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty, reason: 'RichText는 글자 크기 설정을 무시한다');
  });

  testWidgets('Text.rich는 앱의 글자 배율과 서체를 따르고 RichText는 따르지 않는다', (tester) async {
    const span = TextSpan(text: '어르신 12명');
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: DefaultTextStyle(
          style: const TextStyle(fontFamily: 'Pretendard', fontSize: 14),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                const Text.rich(span, key: Key('rich')),
                RichText(key: const Key('raw'), text: span),
              ],
            ),
          ),
        ),
      ),
    );
    final rich = tester.renderObject<RenderParagraph>(find.byKey(const Key('rich')));
    final raw = tester.renderObject<RenderParagraph>(find.byKey(const Key('raw')));
    expect(rich.textScaler, const TextScaler.linear(1.5));
    expect(rich.text.style?.fontFamily, 'Pretendard');
    expect(raw.textScaler, TextScaler.noScaling);
  });
}
