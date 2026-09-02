import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/chat_message.dart';
import 'package:frontend_app/utils/chat_message_pagination.dart';

/// 위로 올려 옛 대화를 불러올 때(무한 스크롤) 이어 붙이는 규칙의 단위 테스트.
void main() {
  ChatMessage msg(int id, {String? localId}) => ChatMessage(
        id: id,
        chatRoomId: 1,
        senderId: 'a',
        senderName: 'a',
        type: MessageType.text,
        content: '$id',
        createdAt: DateTime(2026, 8, 29, 9),
        localId: localId,
      );

  test('겹치지 않는 옛 페이지는 그대로 뒤에 붙는다', () {
    final messages = [msg(5), msg(4)];
    appendOlderMessages(messages, [msg(3), msg(2)]);

    expect(messages.map((m) => m.id).toList(), [5, 4, 3, 2]);
  });

  test('새 메시지 때문에 페이지가 밀려 겹쳐 내려와도 중복되지 않는다', () {
    // 목록을 보는 사이 6이 새로 들어와 서버 페이지 경계가 한 칸 밀린 상황:
    // 다음 페이지가 이미 갖고 있는 4를 다시 내려준다.
    final messages = [msg(6), msg(5), msg(4)];
    appendOlderMessages(messages, [msg(4), msg(3), msg(2)]);

    expect(messages.map((m) => m.id).toList(), [6, 5, 4, 3, 2]);
  });

  test('페이지 전체가 이미 가진 것이면 아무것도 붙지 않는다', () {
    final messages = [msg(3), msg(2)];
    appendOlderMessages(messages, [msg(3), msg(2)]);

    expect(messages.map((m) => m.id).toList(), [3, 2]);
  });

  test('전송 중(local) 메시지는 옛 페이지를 붙여도 그대로 남는다', () {
    final messages = [msg(-1, localId: 'local_1'), msg(3)];
    appendOlderMessages(messages, [msg(2)]);

    expect(messages.map((m) => m.localId).toList(), ['local_1', null, null]);
    expect(messages.map((m) => m.id).toList(), [-1, 3, 2]);
  });

  /// 스크롤이 "옛 대화를 더 불러올 자리"에 왔는지 판단하는 규칙.
  ///
  /// 목록이 reverse:true라 maxScrollExtent 쪽이 가장 오래된 끝이다. 이 방향을
  /// 뒤집어 놓으면 아무리 위로 올려도 옛 대화가 안 붙는다 — 그 회귀를 막는다.
  group('shouldLoadOlderMessages', () {
    test('가장 오래된 끝(maxScrollExtent)에 다가가면 불러온다', () {
      expect(
        shouldLoadOlderMessages(
          pixels: 900,
          maxScrollExtent: 1000,
          hasMore: true,
          isLoadingOlder: false,
        ),
        isTrue,
      );
    });

    test('최신 쪽(pixels 0, 방금 연 화면)에서는 부르지 않는다', () {
      expect(
        shouldLoadOlderMessages(
          pixels: 0,
          maxScrollExtent: 1000,
          hasMore: true,
          isLoadingOlder: false,
        ),
        isFalse,
      );
    });

    test('임계값 200px 경계 — 딱 걸치면 부른다', () {
      expect(
        shouldLoadOlderMessages(
          pixels: 800,
          maxScrollExtent: 1000,
          hasMore: true,
          isLoadingOlder: false,
        ),
        isTrue,
      );
      expect(
        shouldLoadOlderMessages(
          pixels: 799,
          maxScrollExtent: 1000,
          hasMore: true,
          isLoadingOlder: false,
        ),
        isFalse,
      );
    });

    test('이미 불러오는 중이면 연달아 오는 스크롤에도 다시 부르지 않는다', () {
      expect(
        shouldLoadOlderMessages(
          pixels: 1000,
          maxScrollExtent: 1000,
          hasMore: true,
          isLoadingOlder: true,
        ),
        isFalse,
      );
    });

    test('더 없다고 알고 있으면 끝까지 올려도 부르지 않는다', () {
      expect(
        shouldLoadOlderMessages(
          pixels: 1000,
          maxScrollExtent: 1000,
          hasMore: false,
          isLoadingOlder: false,
        ),
        isFalse,
      );
    });

    test('내용이 한 화면보다 짧아 스크롤이 없으면(0/0) 남은 게 있을 때만 부른다', () {
      expect(
        shouldLoadOlderMessages(
          pixels: 0,
          maxScrollExtent: 0,
          hasMore: true,
          isLoadingOlder: false,
        ),
        isTrue,
      );
      expect(
        shouldLoadOlderMessages(
          pixels: 0,
          maxScrollExtent: 0,
          hasMore: false,
          isLoadingOlder: false,
        ),
        isFalse,
      );
    });
  });
}
