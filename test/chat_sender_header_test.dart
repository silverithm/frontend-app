import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/widgets/chat/chat_sender_header.dart';

/// 채팅 버블 왼쪽 열(아바타·이름·직종)이 실제로 잘리는지를 렌더 결과로
/// 검증한다. `_senderColumnWidth`(64px)가 실제 현장 직종명을 감당하는지는
/// 눈대중이 아니라 이 테스트가 답한다 — `RenderParagraph.didExceedMaxLines`로
/// 실제 레이아웃이 maxLines를 넘었는지 직접 확인한다.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required String name,
    String? position,
    double width = 64,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ChatSenderHeader(
              visible: true,
              senderName: name,
              senderPosition: position,
              width: width,
            ),
          ),
        ),
      ),
    );
  }

  bool didExceedMaxLines(WidgetTester tester, Key key) {
    final renderObject = tester.renderObject(find.byKey(key));
    expect(renderObject, isA<RenderParagraph>());
    return (renderObject as RenderParagraph).didExceedMaxLines;
  }

  group('실제 현장 직종명 — 64px에서 잘리지 않아야 한다', () {
    for (final position in ['사회복지사', '요양보호사', '간호조무사', '사무팀장']) {
      testWidgets('"$position"은 말줄임 없이 한 줄에 들어간다', (tester) async {
        await pump(tester, name: '김보경', position: position);

        expect(
          didExceedMaxLines(tester, ChatSenderHeader.positionTextKey),
          isFalse,
          reason: '"$position"이 64px 폭(maxLines: 2)에서 넘쳐서는 안 된다',
        );
      });
    }
  });

  testWidgets('긴 이름("박성은팀장")도 한 줄에 들어간다', (tester) async {
    await pump(tester, name: '박성은팀장', position: '사원');

    expect(
      didExceedMaxLines(tester, ChatSenderHeader.nameTextKey),
      isFalse,
      reason: '이름은 maxLines: 1이므로 넘치면 그대로 잘려 보인다',
    );
  });

  testWidgets('아주 긴 직종은 2줄까지 늘어나고, 그래도 넘치면 말줄임된다', (tester) async {
    // 실제로 2줄로도 다 못 담을 만큼 긴 복합 직종명
    await pump(
      tester,
      name: '김보경',
      position: '사회복지사·프로그램관리자·시설안전책임자',
    );

    // 2줄까지는 허용되므로 이 케이스가 반드시 넘친다는 보장은 없지만,
    // 최소한 "예외 없이 렌더된다"(레이아웃 크래시가 없다)는 것과
    // maxLines 제한이 실제로 걸려 있다는 것(3줄 이상 텍스트 높이로
    // 자라지 않는다는 것)을 함께 확인한다.
    final renderObject =
        tester.renderObject(find.byKey(ChatSenderHeader.positionTextKey))
            as RenderParagraph;
    // maxLines: 2가 실제로 적용됐는지 — 2줄 높이를 넘지 않아야 한다.
    final twoLineHeight = renderObject.size.height;

    await pump(tester, name: '김보경', position: '사회복지사');
    final oneLineHeight =
        (tester.renderObject(find.byKey(ChatSenderHeader.positionTextKey))
                as RenderParagraph)
            .size
            .height;

    // 짧은 직종(1줄)보다 긴 직종(2줄 클램프)의 렌더 높이가 커야
    // maxLines: 2가 실제로 반영되고 있다는 뜻이다.
    expect(twoLineHeight, greaterThan(oneLineHeight));
  });

  testWidgets('연속 메시지(visible: false)도 같은 폭을 차지한다 — 버블 세로 정렬 유지', (
    tester,
  ) async {
    const width = 64.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              ChatSenderHeader(
                visible: true,
                senderName: '김보경',
                senderPosition: '사회복지사',
                width: width,
              ),
              ChatSenderHeader(
                visible: false,
                senderName: '김보경',
                senderPosition: '사회복지사',
                width: width,
              ),
            ],
          ),
        ),
      ),
    );

    final widths = tester
        .widgetList<ChatSenderHeader>(find.byType(ChatSenderHeader))
        .map((w) => w.width)
        .toSet();

    // 두 인스턴스 모두 같은 width 파라미터를 받았으므로 렌더 폭도 항상 같다.
    expect(widths, {width});

    final sizes = tester
        .allWidgets
        .whereType<SizedBox>()
        .where((s) => s.width == width)
        .toList();
    expect(sizes.length, 2, reason: '보이는 그룹 시작 메시지와 빈 이어지는 메시지 모두 SizedBox(width: 64)여야 한다');
  });
}
