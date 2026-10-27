import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/chat_message.dart';
import 'package:frontend_app/widgets/chat/chat_bubble_layout.dart';
import 'package:frontend_app/widgets/chat/chat_file_card.dart';

/// 말풍선 사이 간격·시각 표시 규칙(채팅 2차 점검 R1-03) 단위 테스트.
/// 목록은 reverse 순서(index 0 = 최신)다.
void main() {
  ChatMessage msg(
    int id,
    String sender,
    DateTime at, {
    MessageType type = MessageType.text,
    bool deleted = false,
  }) => ChatMessage(
    id: id,
    chatRoomId: 1,
    senderId: sender,
    senderName: sender,
    type: type,
    content: '내용',
    createdAt: at,
    isDeleted: deleted,
  );

  final t = DateTime(2026, 10, 27, 9, 30);

  group('chatBubbleTopGap', () {
    test('같은 사람 · 같은 분이면 2px', () {
      final m = [
        msg(3, 'a', t.add(const Duration(seconds: 20))),
        msg(2, 'a', t.add(const Duration(seconds: 5))),
        msg(1, 'a', t),
      ];
      expect(chatBubbleTopGap(m, 0), chatGapSameMinute);
      expect(chatBubbleTopGap(m, 1), chatGapSameMinute);
    });

    test('같은 사람 · 분이 다르면 4px', () {
      final m = [
        msg(2, 'a', t.add(const Duration(minutes: 1))),
        msg(1, 'a', t),
      ];
      expect(chatBubbleTopGap(m, 0), chatGapSameSender);
    });

    test('사람이 바뀌면 16px — 내↔남 교대도 같다', () {
      final m = [msg(2, 'me', t), msg(1, 'other', t)];
      expect(chatBubbleTopGap(m, 0), chatGapNewRun);
    });

    test('날짜 구분선 바로 아래 첫 메시지는 0(구분선이 자기 여백을 가진다)', () {
      final m = [
        msg(2, 'a', t.add(const Duration(days: 1))),
        msg(1, 'a', t),
      ];
      expect(chatBubbleTopGap(m, 0), 0);
      expect(chatBubbleTopGap(m, 1), 0); // 가장 오래된 끝
    });

    test('시스템 안내 아래는 안내 알약의 아래 여백이 대신한다', () {
      final m = [
        msg(2, 'a', t, type: MessageType.text),
        msg(1, 'sys', t, type: MessageType.system),
      ];
      expect(chatBubbleTopGap(m, 0), chatGapAfterSystem);
    });

    test('지운 메시지 다음은 새 묶음(이름을 다시 그리므로 16px)', () {
      final m = [msg(2, 'a', t), msg(1, 'a', t, deleted: true)];
      expect(chatBubbleTopGap(m, 0), chatGapNewRun);
    });

    test('범위 밖은 0', () {
      expect(chatBubbleTopGap([], 0), 0);
    });
  });

  group('isMinuteRunEnd — 시각은 묶음의 마지막에만', () {
    test('같은 사람·같은 분 연속이면 마지막만 true', () {
      final m = [
        msg(3, 'a', t.add(const Duration(seconds: 30))),
        msg(2, 'a', t.add(const Duration(seconds: 10))),
        msg(1, 'a', t),
      ];
      expect(isMinuteRunEnd(m, 0), isTrue);
      expect(isMinuteRunEnd(m, 1), isFalse);
      expect(isMinuteRunEnd(m, 2), isFalse);
    });

    test('분이 바뀌면 각자 시각을 가진다', () {
      final m = [
        msg(2, 'a', t.add(const Duration(minutes: 1))),
        msg(1, 'a', t),
      ];
      expect(isMinuteRunEnd(m, 1), isTrue);
    });

    test('바로 다음이 다른 사람이면 시각을 둔다', () {
      final m = [msg(2, 'b', t), msg(1, 'a', t)];
      expect(isMinuteRunEnd(m, 1), isTrue);
    });
  });

  group('파일 카드 표기', () {
    test('크기', () {
      expect(formatChatFileSize(null), '');
      expect(formatChatFileSize(512), '512B');
      expect(formatChatFileSize(33 * 1024), '33KB');
      expect(formatChatFileSize((1.2 * 1024 * 1024).round()), '1.2MB');
      expect(formatChatFileSize(25 * 1024 * 1024), '25MB');
    });

    test('확장자', () {
      expect(chatFileExtension('10월_급여대장.xlsx'), 'XLSX');
      expect(chatFileExtension('README'), '');
      expect(chatFileExtension('끝에점.'), '');
    });
  });

  testWidgets('파일 카드는 이름·크기·종류를 보여주고 눌린다', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatFileCard(
            name: '급여대장.xlsx',
            fileSize: 33 * 1024,
            isVideo: false,
            onBrand: false,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    expect(find.text('급여대장.xlsx'), findsOneWidget);
    expect(find.text('33KB · XLSX'), findsOneWidget);
    await tester.tap(find.byType(ChatFileCard));
    expect(tapped, isTrue);
  });
}
