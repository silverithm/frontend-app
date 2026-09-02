import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/widgets/chat/chat_sender_header.dart';

/// 발신자 표시("이름 (직종)")가 실제 렌더에서 잘리는지를 검증한다.
///
/// 예전 배치는 아바타 아래 64px 열에 이름·직종을 세로로 쌓아서 "사회복지사"
/// 같은 흔한 직종명이 말줄임됐다. 지금은 아바타 오른쪽 한 줄에 놓여 남는
/// 가로폭을 전부 쓰므로 잘리지 않는다 — 그 회귀를 막는 게 이 테스트다.
/// 눈대중이 아니라 `RenderParagraph.didExceedMaxLines`로 직접 확인한다.
void main() {
  /// 아바타 열(32) + 사이 여백 + 시각 열을 뺀, 실제 채팅 화면에서 발신자
  /// 표시가 쓸 수 있는 폭을 흉내 낸다. iPhone SE(320) 기준으로도 넉넉히
  /// 좁게 잡아 최악의 경우를 본다.
  const availableWidth = 240.0;

  Future<void> pump(
    WidgetTester tester, {
    required String name,
    String? position,
    double width = availableWidth,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: ChatSenderHeader(
                senderName: name,
                senderPosition: position,
              ),
            ),
          ),
        ),
      ),
    );
  }

  RenderParagraph paragraph(WidgetTester tester) {
    final renderObject = tester.renderObject(
      find.byKey(ChatSenderHeader.textKey),
    );
    expect(renderObject, isA<RenderParagraph>());
    return renderObject as RenderParagraph;
  }

  group('실제 현장 직종명 — 좁은 폭에서도 잘리지 않아야 한다', () {
    for (final position in [
      '사회복지사',
      '요양보호사',
      '간호조무사',
      '사무팀장',
      '주간보호센터장',
      '프로그램관리자',
    ]) {
      testWidgets('"$position"은 이름과 함께 한 줄에 말줄임 없이 들어간다', (tester) async {
        await pump(tester, name: '김보경', position: position);

        expect(
          paragraph(tester).didExceedMaxLines,
          isFalse,
          reason: '"김보경 ($position)"이 ${availableWidth}px에서 넘쳐서는 안 된다',
        );
      });
    }
  });

  testWidgets('긴 이름("박성은팀장")과 긴 직종이 함께 와도 한 줄에 들어간다', (tester) async {
    await pump(tester, name: '박성은팀장', position: '사회복지사');

    expect(paragraph(tester).didExceedMaxLines, isFalse);
  });

  testWidgets('직종이 없으면 이름만 그린다', (tester) async {
    await pump(tester, name: '김보경', position: '   ');

    expect(paragraph(tester).text.toPlainText(), '김보경');
    expect(paragraph(tester).didExceedMaxLines, isFalse);
  });

  testWidgets('직종은 이름 오른쪽에 괄호로 붙는다 — 세로로 쌓지 않는다', (tester) async {
    await pump(tester, name: '김보경', position: '사회복지사');

    expect(paragraph(tester).text.toPlainText(), '김보경 (사회복지사)');
    expect(paragraph(tester).maxLines, 1);
  });

  testWidgets('정말 화면을 넘길 만큼 길면 그때만 말줄임된다', (tester) async {
    await pump(
      tester,
      name: '김보경',
      position: '사회복지사·프로그램관리자·시설안전책임자·야간전담요양보호사',
    );

    expect(
      paragraph(tester).didExceedMaxLines,
      isTrue,
      reason: '가로폭을 실제로 넘길 때는 말줄임으로 처리돼야 한다(줄바꿈·오버플로 금지)',
    );
  });

  testWidgets('아바타 자리는 보이든 안 보이든 같은 폭 — 말풍선 세로 정렬 유지', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChatAvatarSlot(visible: true, senderName: '김보경'),
              ChatAvatarSlot(visible: false, senderName: '김보경'),
            ],
          ),
        ),
      ),
    );

    final widths = tester
        .renderObjectList<RenderBox>(find.byType(ChatAvatarSlot))
        .map((box) => box.size.width)
        .toSet();

    expect(widths, {ChatAvatarSlot.width});
  });
}
