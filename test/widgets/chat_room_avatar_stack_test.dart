// 채팅방 아이콘 칸 나누기 — 카카오톡처럼 사람 수대로, 넷을 넘으면 앞의 넷만
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/chat_room.dart';
import 'package:frontend_app/widgets/chat/chat_room_avatar_stack.dart';

List<ChatRoomAvatar> _people(int n) => List.generate(
      n,
      (i) => ChatRoomAvatar(userId: '$i', userName: ['김민지', '박지훈', '이서연', '최유진', '한소연', '오하늘'][i]),
    );

Future<void> _pump(WidgetTester tester, int n) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: Center(child: ChatRoomAvatarStack(roomName: '햇살방', avatars: _people(n)))),
  ));
}

int _cells(WidgetTester tester) => List.generate(6, (i) => find.byKey(ValueKey('chat-room-avatar-cell-$i')))
    .where((f) => f.evaluate().isNotEmpty)
    .length;

void main() {
  for (final (n, want) in [(1, 1), (2, 2), (3, 3), (4, 4), (6, 4)]) {
    testWidgets('$n명 방은 $want칸', (tester) async {
      await _pump(tester, n);
      expect(_cells(tester), want);
    });
  }

  testWidgets('4명 방은 네 사람 첫 글자가 모두 보인다', (tester) async {
    await _pump(tester, 4);
    for (final ch in ['김', '박', '이', '최']) {
      expect(find.text(ch), findsOneWidget);
    }
    // 다섯째부터는 넣지 않는다
    expect(find.text('한'), findsNothing);
  });

  testWidgets('3명 방은 왼쪽 한 칸이 오른쪽 칸보다 크다', (tester) async {
    await _pump(tester, 3);
    final left = tester.getSize(find.byKey(const ValueKey('chat-room-avatar-cell-0')));
    final right = tester.getSize(find.byKey(const ValueKey('chat-room-avatar-cell-1')));
    expect(left.height, greaterThan(right.height * 1.8));
    expect((left.width - right.width).abs(), lessThan(1.0));
  });

  testWidgets('참여자가 없으면 방 이름 첫 글자 한 칸', (tester) async {
    await _pump(tester, 0);
    expect(find.text('햇'), findsOneWidget);
  });
}
