import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/chat_message.dart';
import 'package:frontend_app/widgets/chat/chat_photo_group.dart';

/// 사진을 여러 장 보냈을 때 못 간 칸만 "전송 실패"로 덮이는지 — 버그제보방 10/16
/// ("전송이 안된 사진이나 동영상이 어떤건지 알수가 없어요").
void main() {
  ChatMessage photo(int id, MessageSendingStatus status) => ChatMessage(
        id: id,
        chatRoomId: 1,
        senderId: 'me',
        senderName: 'me',
        type: MessageType.image,
        fileUrl: 'https://example.com/$id.jpg',
        fileName: '사진$id.jpg',
        mediaType: 'IMAGE',
        createdAt: DateTime(2026, 10, 16, 10, id),
        sendingStatus: status,
      );

  testWidgets('못 간 사진 칸에만 전송 실패가 뜬다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatPhotoGroup(
            messages: [
              photo(1, MessageSendingStatus.sent),
              photo(2, MessageSendingStatus.failed),
              photo(3, MessageSendingStatus.sent),
              photo(4, MessageSendingStatus.failed),
            ],
            maxWidth: 300,
            onTap: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('전송 실패'), findsNWidgets(2));
  });

  testWidgets('모두 갔으면 전송 실패가 없다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatPhotoGroup(
            messages: [
              photo(1, MessageSendingStatus.sent),
              photo(2, MessageSendingStatus.sending),
            ],
            maxWidth: 300,
            onTap: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('전송 실패'), findsNothing);
  });
}
