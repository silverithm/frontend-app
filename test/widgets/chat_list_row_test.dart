import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/chat_room.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/theme/app_spacing.dart';
import 'package:frontend_app/widgets/chat/chat_list_row.dart';
import 'package:frontend_app/widgets/chat/chat_room_list_tile.dart';

/// 채팅 화면들(방 목록·직원·참가자·새 방)의 B안 줄 — 채팅 목록 방 줄([ChatRoomListTile])이
/// 큰 글자·좁은 폭에서도 넘치지 않고, 줄 높이는 60 이상, 카드 조각은 묶음 첫·끝에서만 둥글다.
void main() {
  Widget host(Widget child, {double width = 320, double textScale = 1.0}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 640),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          backgroundColor: AppSemanticColors.backgroundCanvas,
          body: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );
  }

  ChatRoom room({
    String name = '요양보호사 1팀 주간보호 오후 근무자 단체방',
    int participants = 13,
    int unread = 0,
    bool pinned = false,
  }) => ChatRoom(
    id: 1,
    name: name,
    companyId: 1,
    createdBy: 'u1',
    createdByName: '김관리',
    participantCount: participants,
    unreadCount: unread,
    pinned: pinned,
    createdAt: DateTime(2026, 11, 12, 9),
    avatars: const [
      ChatRoomAvatar(userId: 'a', userName: '김민지'),
      ChatRoomAvatar(userId: 'b', userName: '이서연'),
      ChatRoomAvatar(userId: 'c', userName: '박지훈'),
    ],
  );

  Widget tile(
    ChatRoom r, {
    String timeLabel = '1시간 전',
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return ChatCardSlice(
      isFirst: true,
      isLast: true,
      child: ChatRoomListTile(
        room: r,
        timeLabel: timeLabel,
        onTap: onTap ?? () {},
        onLongPress: onLongPress ?? () {},
      ),
    );
  }

  testWidgets('방 줄: 글자 1.3배·폭 320, 고정·안 읽은 99+여도 넘치지 않고 줄 높이는 60 이상', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        tile(room(unread: 120, pinned: true), timeLabel: '10/28'),
        textScale: 1.3,
      ),
    );
    expect(tester.takeException(), isNull);
    final rowSize = tester.getSize(find.byType(ChatListRow));
    expect(rowSize.height, greaterThanOrEqualTo(AppSpacing.listRowMinHeight));
    expect(find.text('99+'), findsOneWidget);
    expect(find.byIcon(Icons.push_pin), findsOneWidget);
    expect(find.text('13명'), findsOneWidget);
    expect(find.text('10/28'), findsOneWidget);
    // 마지막 말이 없으면 기본 문구
    expect(find.text('새로운 채팅방'), findsOneWidget);
  });

  testWidgets('방 줄: 안 읽은 게 없으면 배지·핀이 없다', (tester) async {
    await tester.pumpWidget(host(tile(room())));
    expect(find.byIcon(Icons.push_pin), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('짧은 줄도 높이 60을 지킨다', (tester) async {
    await tester.pumpWidget(host(const ChatListRow(child: Text('나'))));
    expect(
      tester.getSize(find.byType(ChatListRow)).height,
      greaterThanOrEqualTo(AppSpacing.listRowMinHeight),
    );
  });

  testWidgets('방 줄을 누르면 onTap, 길게 누르면 onLongPress(방 메뉴)', (tester) async {
    var taps = 0;
    var longPresses = 0;
    await tester.pumpWidget(
      host(tile(room(), onTap: () => taps++, onLongPress: () => longPresses++)),
    );
    await tester.tap(find.byType(ChatListRow));
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(ChatListRow));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(longPresses, 1);
  });

  testWidgets('카드 조각은 묶음 첫 줄 위·끝 줄 아래만 둥글고, 끝 줄 뒤에 카드 간격', (tester) async {
    await tester.pumpWidget(
      host(
        const Column(
          children: [
            ChatCardSlice(isFirst: true, isLast: false, child: Text('첫')),
            ChatCardSlice(isFirst: false, isLast: false, child: Text('가운데')),
            ChatCardSlice(isFirst: false, isLast: true, child: Text('끝')),
          ],
        ),
      ),
    );

    BorderRadius radiusOf(String label) {
      final box = tester.widget<DecoratedBox>(
        find
            .ancestor(of: find.text(label), matching: find.byType(DecoratedBox))
            .first,
      );
      return (box.decoration as BoxDecoration).borderRadius! as BorderRadius;
    }

    const r = Radius.circular(AppBorderRadius.card);
    expect(radiusOf('첫').topLeft, r);
    expect(radiusOf('첫').bottomLeft, Radius.zero);
    expect(radiusOf('가운데').topLeft, Radius.zero);
    expect(radiusOf('가운데').bottomLeft, Radius.zero);
    expect(radiusOf('끝').topLeft, Radius.zero);
    expect(radiusOf('끝').bottomLeft, r);

    // 끝 줄 아래에만 카드 간격 12
    final lastPadding = tester.widget<Padding>(
      find.ancestor(of: find.text('끝'), matching: find.byType(Padding)).last,
    );
    expect(
      lastPadding.padding,
      const EdgeInsets.only(bottom: AppSpacing.cardGap),
    );
  });
}
