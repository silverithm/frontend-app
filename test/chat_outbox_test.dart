import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/chat_message.dart';
import 'package:frontend_app/services/chat_outbox.dart';

OutboxEntry _entry(String localId, {int roomId = 1, String? key, DateTime? at}) =>
    OutboxEntry(
      localId: localId,
      clientMessageId: key ?? 'key-$localId',
      roomId: roomId,
      senderId: '7',
      senderName: '나',
      content: '안녕',
      createdAt: at ?? DateTime(2026, 9, 14, 11, 0),
    );

ChatMessage _serverEcho({required String key, String senderId = '7', String content = '안녕'}) =>
    ChatMessage(
      id: 3312,
      chatRoomId: 1,
      senderId: senderId,
      senderName: '나',
      content: content,
      createdAt: DateTime(2026, 9, 14, 11, 0, 1),
      clientMessageId: key,
    );

ChatMessage _pending({required String key, String senderId = '7', String content = '안녕'}) =>
    ChatMessage(
      id: -1789353131192,
      chatRoomId: 1,
      senderId: senderId,
      senderName: '나',
      content: content,
      createdAt: DateTime(2026, 9, 14, 11, 0),
      sendingStatus: MessageSendingStatus.sending,
      localId: 'local_1',
      clientMessageId: key,
    );

void main() {
  group('식별자', () {
    test('UUID v4 모양이고 매번 다르다', () {
      final a = newClientMessageId();
      final b = newClientMessageId();
      expect(a, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(a, isNot(equals(b)));
      expect(a.length, lessThanOrEqualTo(64)); // 서버 컬럼 길이
    });
  });

  group('에코 짝맞춤', () {
    test('내용이 같아도 식별자가 다른 말풍선에는 붙지 않는다 — "네", "네"를 연달아 보낼 때', () {
      final first = _pending(key: 'k1');
      final second = _pending(key: 'k2');
      final messages = [second, first]; // 최신이 앞

      expect(indexOfPending(messages, _serverEcho(key: 'k2')), 0);
      expect(indexOfPending(messages, _serverEcho(key: 'k1')), 1);
    });

    test('식별자가 없는 에코(구버전 서버·남의 메시지)는 어떤 말풍선에도 붙지 않는다', () {
      final messages = [_pending(key: 'k1')];
      expect(indexOfPending(messages, _serverEcho(key: '')), -1);
    });

    test('남이 우연히 같은 식별자를 써도 내 말풍선에 붙지 않는다', () {
      final messages = [_pending(key: 'k1')];
      expect(indexOfPending(messages, _serverEcho(key: 'k1', senderId: '8')), -1);
    });

    test('이미 서버에 있는 메시지는 짝맞춤 대상이 아니다', () {
      final sent = _serverEcho(key: 'k1');
      expect(indexOfPending([sent], _serverEcho(key: 'k1')), -1);
    });
  });

  group('발신함', () {
    test('에코를 받으면 기다리던 것이 사라진다', () {
      final outbox = ChatOutbox(InMemoryOutboxStore());
      outbox.expectAck(_entry('a'));

      expect(outbox.acknowledgeByClientMessageId('key-a')?.localId, 'a');
      expect(outbox.awaitingAck, isEmpty);
      expect(outbox.failed, isEmpty);
    });

    test('실패로 표시하면 저장소에 남고, 다시 만들면 되살아난다', () {
      final store = InMemoryOutboxStore();
      final outbox = ChatOutbox(store);
      outbox.expectAck(_entry('a'));
      outbox.markFailed('a');

      final revived = ChatOutbox(store);
      expect(revived.failed.map((e) => e.localId), ['a']);
      expect(revived.failedForRoom(1).single.content, '안녕');
    });

    test('되살아난 실패는 자동 재전송 후보가 아니다 — 어젯밤 실패가 아침에 혼자 나가면 안 된다', () {
      final store = InMemoryOutboxStore();
      final outbox = ChatOutbox(store);
      outbox.expectAck(_entry('a'));
      outbox.markFailed('a');
      expect(outbox.autoResendCandidates().map((e) => e.localId), ['a']);

      final revived = ChatOutbox(store);
      expect(revived.autoResendCandidates(), isEmpty);
      expect(revived.failedForRoom(1), hasLength(1)); // 화면에는 실패로 보인다
    });

    test('사흘 넘은 실패는 되살리지 않는다', () {
      final store = InMemoryOutboxStore();
      final old = DateTime(2026, 9, 10, 11, 0);
      ChatOutbox(store, now: () => old)
        ..expectAck(_entry('a', at: old))
        ..markFailed('a');

      final later = ChatOutbox(store, now: () => DateTime(2026, 9, 14, 11, 0));
      expect(later.failed, isEmpty);
    });

    test('보내지 않고 삭제하면 저장소에서도 사라진다', () {
      final store = InMemoryOutboxStore();
      final outbox = ChatOutbox(store);
      outbox.expectAck(_entry('a'));
      outbox.markFailed('a');
      outbox.discard('a');

      expect(ChatOutbox(store).failed, isEmpty);
    });

    test('다시 보내기를 시작하면 실패에서 기다림으로 옮겨진다', () {
      final outbox = ChatOutbox(InMemoryOutboxStore());
      outbox.expectAck(_entry('a'));
      outbox.markFailed('a');
      outbox.expectAck(outbox.entry('a')!);

      expect(outbox.failed, isEmpty);
      expect(outbox.awaitingAck.single.localId, 'a');
    });

    test('방별 실패 목록은 보낸 순서대로다', () {
      final outbox = ChatOutbox(InMemoryOutboxStore());
      outbox.expectAck(_entry('b', at: DateTime(2026, 9, 14, 12)));
      outbox.expectAck(_entry('a', at: DateTime(2026, 9, 14, 11)));
      outbox.expectAck(_entry('c', roomId: 2));
      outbox.markFailed('a');
      outbox.markFailed('b');
      outbox.markFailed('c');

      expect(outbox.failedForRoom(1).map((e) => e.localId), ['a', 'b']);
    });

    test('깨진 저장 값이 있어도 발신함은 열린다', () {
      final store = InMemoryOutboxStore()..write('{not json');
      expect(ChatOutbox(store).failed, isEmpty);
    });

    test('실패 말풍선은 음수 id·실패 상태·같은 식별자를 가진다', () {
      final message = _entry('a').toFailedMessage();
      expect(message.isLocalOnly, isTrue);
      expect(message.sendingStatus, MessageSendingStatus.failed);
      expect(message.clientMessageId, 'key-a');
      expect(message.type, MessageType.text);
    });

    test('파일 항목은 파일 이름과 종류로 그려진다', () {
      final entry = OutboxEntry(
        localId: 'f',
        clientMessageId: 'key-f',
        roomId: 1,
        senderId: '7',
        senderName: '나',
        filePath: '/tmp/IMG_2834.jpg',
        createdAt: DateTime(2026, 9, 14),
      );
      final message = entry.toFailedMessage();
      expect(message.type, MessageType.image);
      expect(message.fileName, 'IMG_2834.jpg');
      expect(OutboxEntry.fromJson(entry.toJson()).filePath, '/tmp/IMG_2834.jpg');
    });
  });

  group('수정·삭제 가능 여부', () {
    test('전송 중·실패한 말풍선은 서버에 없으니 수정·삭제할 수 없다 — 운영 500의 자리', () {
      expect(canEditOrDelete(_pending(key: 'k1')), isFalse);
      expect(canEditOrDelete(_pending(key: 'k1').copyWith(sendingStatus: MessageSendingStatus.failed)), isFalse);
      expect(canEditOrDelete(_serverEcho(key: 'k1')), isTrue);
    });
  });
}
