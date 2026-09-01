import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/chat_message.dart';
import 'package:frontend_app/utils/chat_image_url.dart';

/// 백엔드가 채팅 이미지 응답에 thumbnailUrl을 실어 보내기 시작했다
/// (ChatMessageDTO.thumbnailUrl). 앱이 이를 파싱해서 목록 표시에 쓰고,
/// 전체화면 보기는 계속 원본(fileUrl)을 쓰는지를 확인한다.
void main() {
  Map<String, dynamic> baseJson({String? thumbnailUrl}) => {
    'id': 1,
    'chatRoomId': 10,
    'senderId': 'u1',
    'senderName': '김보경',
    'type': 'IMAGE',
    'fileUrl': 'https://cdn.example.com/original/1.jpg',
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    'fileName': '1.jpg',
    'createdAt': '2026-08-29T10:00:00',
  };

  group('ChatMessage.fromJson — thumbnailUrl 파싱', () {
    test('thumbnailUrl이 있는 JSON은 그대로 파싱된다', () {
      final message = ChatMessage.fromJson(
        baseJson(thumbnailUrl: 'https://cdn.example.com/thumb/1.jpg'),
      );

      expect(message.thumbnailUrl, 'https://cdn.example.com/thumb/1.jpg');
      expect(message.fileUrl, 'https://cdn.example.com/original/1.jpg');
    });

    test('thumbnailUrl이 없는 예전 메시지 JSON도 크래시 없이 null로 파싱된다', () {
      final json = baseJson(); // thumbnailUrl 키 자체가 없음
      expect(json.containsKey('thumbnailUrl'), isFalse);

      final message = ChatMessage.fromJson(json);

      expect(message.thumbnailUrl, isNull);
      expect(message.fileUrl, 'https://cdn.example.com/original/1.jpg');
    });

    test('toJson 왕복에서도 thumbnailUrl이 보존된다', () {
      final message = ChatMessage.fromJson(
        baseJson(thumbnailUrl: 'https://cdn.example.com/thumb/1.jpg'),
      );
      final roundTripped = ChatMessage.fromJson(message.toJson());

      expect(roundTripped.thumbnailUrl, message.thumbnailUrl);
    });

    test('copyWith은 명시하지 않으면 기존 thumbnailUrl을 유지한다', () {
      final message = ChatMessage.fromJson(
        baseJson(thumbnailUrl: 'https://cdn.example.com/thumb/1.jpg'),
      );
      final copied = message.copyWith(readCount: 3);

      expect(copied.thumbnailUrl, 'https://cdn.example.com/thumb/1.jpg');
    });
  });

  group('resolveChatImageUrl — 목록 표시용 이미지 URL 선택 규칙', () {
    ChatMessage msg({String? fileUrl, String? thumbnailUrl}) {
      return ChatMessage(
        id: 1,
        chatRoomId: 1,
        senderId: 'u1',
        senderName: '김보경',
        type: MessageType.image,
        fileUrl: fileUrl,
        thumbnailUrl: thumbnailUrl,
        createdAt: DateTime(2026, 8, 29),
      );
    }

    test('썸네일이 있으면 썸네일을 고른다', () {
      final message = msg(
        fileUrl: 'https://cdn.example.com/original.jpg',
        thumbnailUrl: 'https://cdn.example.com/thumb.jpg',
      );
      expect(resolveChatImageUrl(message), 'https://cdn.example.com/thumb.jpg');
    });

    test('썸네일이 없으면(예전 메시지) 원본으로 물러난다', () {
      final message = msg(
        fileUrl: 'https://cdn.example.com/original.jpg',
        thumbnailUrl: null,
      );
      expect(resolveChatImageUrl(message), 'https://cdn.example.com/original.jpg');
    });

    test('썸네일이 빈 문자열이면(방어적으로) 원본으로 물러난다', () {
      final message = msg(
        fileUrl: 'https://cdn.example.com/original.jpg',
        thumbnailUrl: '   ',
      );
      expect(resolveChatImageUrl(message), 'https://cdn.example.com/original.jpg');
    });

    test('업로드 중인 낙관적 버블처럼 둘 다 없으면 null(빈 콘텐츠, 스피너만 표시)', () {
      final message = msg(fileUrl: null, thumbnailUrl: null);
      expect(resolveChatImageUrl(message), isNull);
    });
  });
}
