import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/chat_message.dart';
import 'package:frontend_app/utils/chat_message_grouping.dart';

/// 사진 묶음(카톡식 격자) 판정 단위 테스트.
///
/// 목록은 화면과 같은 **reverse 순서**(index 0 = 최신)로 만든다.
/// 여기서 인덱스 판정이 맞으면 chat_room_screen의 ListView.builder에서도 맞는다.
void main() {
  ChatMessage photo({
    required int id,
    required String senderId,
    required DateTime createdAt,
    bool isDeleted = false,
    String fileName = '사진.jpg',
    String? mediaType = 'IMAGE',
  }) {
    return ChatMessage(
      id: id,
      chatRoomId: 1,
      senderId: senderId,
      senderName: senderId,
      type: MessageType.image,
      fileUrl: 'https://example.com/$id.jpg',
      thumbnailUrl: 'https://example.com/${id}_thumb.jpg',
      fileName: fileName,
      mediaType: mediaType,
      createdAt: createdAt,
      isDeleted: isDeleted,
    );
  }

  ChatMessage text({
    required int id,
    required String senderId,
    required DateTime createdAt,
  }) {
    return ChatMessage(
      id: id,
      chatRoomId: 1,
      senderId: senderId,
      senderName: senderId,
      type: MessageType.text,
      content: '안녕하세요',
      createdAt: createdAt,
    );
  }

  ChatMessage video({
    required int id,
    required String senderId,
    required DateTime createdAt,
  }) {
    return ChatMessage(
      id: id,
      chatRoomId: 1,
      senderId: senderId,
      senderName: senderId,
      type: MessageType.file,
      fileUrl: 'https://example.com/$id.mp4',
      fileName: '동영상.mp4',
      mimeType: 'video/mp4',
      mediaType: 'VIDEO',
      createdAt: createdAt,
    );
  }

  /// reverse 목록을 만든다 — 인자는 오래된 것부터 주고, 뒤집어 돌려준다.
  List<ChatMessage> reversed(List<ChatMessage> oldestFirst) =>
      oldestFirst.reversed.toList();

  final base = DateTime(2026, 9, 1, 14, 0, 0);

  group('묶이는 경우', () {
    test('같은 사람이 연속으로 보낸 사진 3장은 한 묶음', () {
      final messages = reversed([
        photo(id: 1, senderId: 'a', createdAt: base),
        photo(id: 2, senderId: 'a', createdAt: base.add(const Duration(seconds: 4))),
        photo(id: 3, senderId: 'a', createdAt: base.add(const Duration(seconds: 9))),
      ]);

      final map = buildPhotoGroupMap(messages);

      expect(map.length, 3);
      // 오래된 것부터 담기므로 인덱스는 [2, 1, 0]
      expect(map[0], [2, 1, 0]);
      expect(map[1], [2, 1, 0]);
      expect(map[2], [2, 1, 0]);
      // 대표(격자를 그릴 자리)는 가장 오래된 인덱스
      expect(map[0]!.first, 2);
    });

    test('60초 정확히 차이나는 사진도 아직 한 묶음', () {
      final messages = reversed([
        photo(id: 1, senderId: 'a', createdAt: base),
        photo(id: 2, senderId: 'a', createdAt: base.add(const Duration(seconds: 60))),
      ]);

      expect(buildPhotoGroupMap(messages).length, 2);
    });
  });

  group('끊기는 경우', () {
    test('사이에 글이 끼면 안 묶인다', () {
      final messages = reversed([
        photo(id: 1, senderId: 'a', createdAt: base),
        text(id: 2, senderId: 'a', createdAt: base.add(const Duration(seconds: 3))),
        photo(id: 3, senderId: 'a', createdAt: base.add(const Duration(seconds: 6))),
      ]);

      // 사진이 한 장씩 떨어져 있으므로 묶음이 하나도 없다
      expect(buildPhotoGroupMap(messages), isEmpty);
    });

    test('글을 사이에 두고 앞뒤로 두 장씩이면 묶음이 둘로 갈린다', () {
      final messages = reversed([
        photo(id: 1, senderId: 'a', createdAt: base),
        photo(id: 2, senderId: 'a', createdAt: base.add(const Duration(seconds: 2))),
        text(id: 3, senderId: 'a', createdAt: base.add(const Duration(seconds: 4))),
        photo(id: 4, senderId: 'a', createdAt: base.add(const Duration(seconds: 6))),
        photo(id: 5, senderId: 'a', createdAt: base.add(const Duration(seconds: 8))),
      ]);

      final map = buildPhotoGroupMap(messages);

      // reverse 인덱스: 0=id5, 1=id4, 2=id3(글), 3=id2, 4=id1
      expect(map[4], [4, 3]);
      expect(map[3], [4, 3]);
      expect(map.containsKey(2), isFalse);
      expect(map[1], [1, 0]);
      expect(map[0], [1, 0]);
    });

    test('보낸 사람이 다르면 안 묶인다', () {
      final messages = reversed([
        photo(id: 1, senderId: 'a', createdAt: base),
        photo(id: 2, senderId: 'b', createdAt: base.add(const Duration(seconds: 3))),
      ]);

      expect(buildPhotoGroupMap(messages), isEmpty);
    });

    test('60초를 넘기면 끊긴다', () {
      final messages = reversed([
        photo(id: 1, senderId: 'a', createdAt: base),
        photo(id: 2, senderId: 'a', createdAt: base.add(const Duration(seconds: 61))),
      ]);

      expect(buildPhotoGroupMap(messages), isEmpty);
    });

    test('날짜가 바뀌면 30초 차이여도 끊긴다', () {
      final messages = reversed([
        photo(id: 1, senderId: 'a', createdAt: DateTime(2026, 9, 1, 23, 59, 40)),
        photo(id: 2, senderId: 'a', createdAt: DateTime(2026, 9, 2, 0, 0, 10)),
      ]);

      expect(buildPhotoGroupMap(messages), isEmpty);
      // 날짜 구분선 규칙과도 어긋나지 않는다 — 최신 쪽(index 0) 위에 구분선이 선다
      expect(shouldShowDateSeparatorAbove(messages, 0), isTrue);
    });

    test('삭제된 사진은 묶이지 않고 묶음을 끊는다', () {
      final messages = reversed([
        photo(id: 1, senderId: 'a', createdAt: base),
        photo(id: 2, senderId: 'a', createdAt: base.add(const Duration(seconds: 2)), isDeleted: true),
        photo(id: 3, senderId: 'a', createdAt: base.add(const Duration(seconds: 4))),
      ]);

      expect(buildPhotoGroupMap(messages), isEmpty);
    });

    test('동영상은 사진 묶음에 들어가지 않는다', () {
      final messages = reversed([
        photo(id: 1, senderId: 'a', createdAt: base),
        video(id: 2, senderId: 'a', createdAt: base.add(const Duration(seconds: 2))),
        photo(id: 3, senderId: 'a', createdAt: base.add(const Duration(seconds: 4))),
      ]);

      expect(buildPhotoGroupMap(messages), isEmpty);
    });

    test('사진 한 장은 묶음이 아니다', () {
      final messages = reversed([
        photo(id: 1, senderId: 'a', createdAt: base),
      ]);

      expect(buildPhotoGroupMap(messages), isEmpty);
    });
  });

  group('최대 장수', () {
    test('11장이면 9장 + 2장으로 갈리고 한 장도 사라지지 않는다', () {
      final messages = reversed([
        for (var i = 0; i < 11; i++)
          photo(id: i + 1, senderId: 'a', createdAt: base.add(Duration(seconds: i * 2))),
      ]);

      final map = buildPhotoGroupMap(messages);

      // 11장 모두 어딘가의 묶음에 속한다
      expect(map.length, 11);

      final groups = map.values.toSet();
      expect(groups.length, 2);
      final sizes = groups.map((g) => g.length).toList()..sort();
      expect(sizes, [2, 9]);

      // 오래된 쪽부터 9장이 먼저 차고(인덱스 10~2), 남은 2장이 새 묶음
      expect(map[10]!.length, 9);
      expect(map[10]!.first, 10);
      expect(map[0]!.length, 2);
      expect(map[0], [1, 0]);
    });
  });

  group('기존 규칙과의 정합성', () {
    test('묶음의 대표는 발신자 헤더 판정 자리와 같다', () {
      final messages = reversed([
        text(id: 1, senderId: 'b', createdAt: base),
        photo(id: 2, senderId: 'a', createdAt: base.add(const Duration(seconds: 5))),
        photo(id: 3, senderId: 'a', createdAt: base.add(const Duration(seconds: 7))),
      ]);

      final map = buildPhotoGroupMap(messages);
      final anchor = map[0]!.first; // 가장 오래된 사진의 인덱스 = 1

      expect(anchor, 1);
      // 그 자리가 곧 "발신자 헤더를 그려야 하는" 그룹 시작이다
      expect(isSenderGroupStart(messages, anchor), isTrue);
    });

    test('서버 mediaType이 아직 없어도 mimeType/확장자로 사진을 알아본다', () {
      final messages = reversed([
        photo(id: 1, senderId: 'a', createdAt: base, mediaType: null),
        photo(id: 2, senderId: 'a', createdAt: base.add(const Duration(seconds: 2)), mediaType: null),
      ]);

      expect(buildPhotoGroupMap(messages).length, 2);
    });
  });
}
