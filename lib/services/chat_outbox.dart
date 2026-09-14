/// 보낸 메시지가 **반드시 도착하거나 반드시 실패로 보이게** 하는 발신함.
///
/// **왜 필요한가.** 앱은 소켓으로 메시지를 보내고 서버 응답을 기다리지 않은 채 성공으로
/// 여겼다. 폰이 화면을 끄거나 망을 옮겨 소켓이 조용히 죽어 있으면 그 메시지는 아무 데도
/// 가지 않는데, 화면에는 '전송 중'으로 영원히 남았다(운영 2026-09-14, 세 사람이 각각 겪음).
/// 사용자가 그 말풍선을 고치거나 지우려 하자 서버는 "메시지를 찾을 수 없음"으로 답했다.
///
/// **규칙.**
/// - 모든 메시지에 보내는 쪽이 식별자([newClientMessageId])를 붙인다. 서버는 이 값을
///   되돌려주고, 같은 값으로 다시 보내면 새로 저장하지 않는다. 그래서 재전송이 안전하다.
/// - 소켓으로 보낸 뒤 [ackTimeout] 안에 서버 에코가 없으면 REST로 같은 식별자로 다시 보낸다.
/// - 그것도 실패하면 '실패'로 남기고, 소켓이 다시 붙으면 **이 세션에서** 실패한 것만
///   자동으로 다시 보낸다. 앱을 껐다 켠 뒤 남은 실패는 자동으로 보내지 않는다 — 어젯밤
///   실패한 말이 아침에 혼자 나가면 안 된다. 그건 '다시 보내기'를 눌러야 나간다.
///
/// 이 파일은 순수 Dart다(Flutter·네트워크 없음) — 규칙을 테스트로 못 박기 위해서다.
library;

import 'dart:convert';
import 'dart:math';

import '../models/chat_message.dart';

/// 소켓으로 보낸 뒤 서버 에코를 기다리는 시간. 넘기면 REST로 다시 보낸다.
const Duration ackTimeout = Duration(seconds: 5);

/// 실패한 메시지를 발신함에 두는 최대 시간. 이보다 오래된 것은 '다시 보내기' 대상에서 뺀다.
const Duration outboxRetention = Duration(days: 3);

final Random _random = Random.secure();

/// UUID v4. 패키지를 더하지 않으려 직접 만든다 — 서버 컬럼은 64자, 이건 36자다.
String newClientMessageId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// 발신함에 든 메시지 하나. 텍스트면 [content], 파일이면 [filePath]가 있다.
class OutboxEntry {
  final String localId;
  final String clientMessageId;
  final int roomId;
  final String senderId;
  final String senderName;
  final String? content;
  final int? replyToId;
  final String? filePath;
  final String? batchId;
  final int? batchSize;
  final DateTime createdAt;

  /// 이 앱 실행 중에 만들어진 것인가. 저장소에서 되살린 것은 false —
  /// 그런 것은 자동으로 다시 보내지 않는다.
  final bool inSession;

  const OutboxEntry({
    required this.localId,
    required this.clientMessageId,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.content,
    this.replyToId,
    this.filePath,
    this.batchId,
    this.batchSize,
    required this.createdAt,
    this.inSession = true,
  });

  bool get isFile => filePath != null;

  /// 사용자가 직접 '다시 보내기'를 눌렀다 — 이제부터는 이 세션의 것이다.
  OutboxEntry asInSession() => OutboxEntry(
        localId: localId,
        clientMessageId: clientMessageId,
        roomId: roomId,
        senderId: senderId,
        senderName: senderName,
        content: content,
        replyToId: replyToId,
        filePath: filePath,
        batchId: batchId,
        batchSize: batchSize,
        createdAt: createdAt,
        inSession: true,
      );

  Map<String, dynamic> toJson() => {
        'localId': localId,
        'clientMessageId': clientMessageId,
        'roomId': roomId,
        'senderId': senderId,
        'senderName': senderName,
        if (content != null) 'content': content,
        if (replyToId != null) 'replyToId': replyToId,
        if (filePath != null) 'filePath': filePath,
        if (batchId != null) 'batchId': batchId,
        if (batchSize != null) 'batchSize': batchSize,
        'createdAt': createdAt.toIso8601String(),
      };

  /// 저장소에서 읽은 것은 언제나 [inSession] false다.
  factory OutboxEntry.fromJson(Map<String, dynamic> json) => OutboxEntry(
        localId: json['localId'] as String,
        clientMessageId: json['clientMessageId'] as String,
        roomId: (json['roomId'] as num).toInt(),
        senderId: json['senderId'] as String,
        senderName: json['senderName'] as String,
        content: json['content'] as String?,
        replyToId: (json['replyToId'] as num?)?.toInt(),
        filePath: json['filePath'] as String?,
        batchId: json['batchId'] as String?,
        batchSize: (json['batchSize'] as num?)?.toInt(),
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        inSession: false,
      );

  /// 화면에 그릴 '실패한' 말풍선. 앱을 다시 열어 방에 들어갔을 때 쓴다.
  ChatMessage toFailedMessage() => ChatMessage(
        id: -createdAt.millisecondsSinceEpoch,
        chatRoomId: roomId,
        senderId: senderId,
        senderName: senderName,
        type: isFile ? _typeForFile(filePath!) : MessageType.text,
        content: isFile ? filePath!.split('/').last : content,
        fileName: isFile ? filePath!.split('/').last : null,
        createdAt: createdAt,
        readCount: 1,
        sendingStatus: MessageSendingStatus.failed,
        localId: localId,
        clientMessageId: clientMessageId,
        replyToId: replyToId,
      );

  static MessageType _typeForFile(String path) {
    final lower = path.toLowerCase();
    const images = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic'];
    return images.any(lower.endsWith) ? MessageType.image : MessageType.file;
  }
}

/// 실패한 메시지를 앱 재시작 너머로 남기는 곳. 실제로는 shared_preferences 한 칸이다.
abstract class OutboxStore {
  String? read();
  Future<void> write(String json);
}

class InMemoryOutboxStore implements OutboxStore {
  String? _value;
  @override
  String? read() => _value;
  @override
  Future<void> write(String json) async => _value = json;
}

/// 발신함. '기다리는 중'(소켓 에코 대기)과 '실패'를 나눠 둔다.
class ChatOutbox {
  final OutboxStore _store;
  final DateTime Function() _now;

  /// 소켓으로 보내고 에코를 기다리는 것들 — localId → entry
  final Map<String, OutboxEntry> _awaitingAck = {};

  /// 끝내 실패한 것들 — localId → entry
  final Map<String, OutboxEntry> _failed = {};

  ChatOutbox(this._store, {DateTime Function()? now})
      : _now = now ?? DateTime.now {
    _restore();
  }

  Iterable<OutboxEntry> get awaitingAck => _awaitingAck.values;
  Iterable<OutboxEntry> get failed => _failed.values;

  OutboxEntry? entry(String localId) => _awaitingAck[localId] ?? _failed[localId];

  /// 보내기 시작했다 — 에코를 기다린다.
  void expectAck(OutboxEntry entry) {
    _failed.remove(entry.localId);
    _awaitingAck[entry.localId] = entry;
  }

  /// 서버가 받았다. 어느 쪽에 있든 지운다. 지운 것을 돌려준다(없으면 null).
  OutboxEntry? acknowledge(String localId) {
    final awaiting = _awaitingAck.remove(localId);
    if (awaiting != null) return awaiting;
    final failed = _failed.remove(localId);
    if (failed != null) _persist();
    return failed;
  }

  /// 서버 에코를 식별자로 찾아 지운다. 내용이 같은 다른 메시지와 섞이지 않는다.
  OutboxEntry? acknowledgeByClientMessageId(String clientMessageId) {
    final key = _awaitingAck.entries
        .cast<MapEntry<String, OutboxEntry>?>()
        .firstWhere((e) => e!.value.clientMessageId == clientMessageId,
            orElse: () => null)
        ?.key;
    return key == null ? null : acknowledge(key);
  }

  /// 에코도 REST도 실패했다. 재시작 너머로 남긴다.
  void markFailed(String localId) {
    final entry = _awaitingAck.remove(localId) ?? _failed[localId];
    if (entry == null) return;
    _failed[localId] = entry;
    _persist();
  }

  /// 사용자가 '보내지 않고 삭제'를 눌렀다.
  void discard(String localId) {
    _awaitingAck.remove(localId);
    if (_failed.remove(localId) != null) _persist();
  }

  /// 소켓이 다시 붙었을 때 자동으로 다시 보낼 것들 — **이 세션에서** 실패한 것만.
  List<OutboxEntry> autoResendCandidates() =>
      _failed.values.where((e) => e.inSession).toList();

  /// 방에 들어갔을 때 '실패'로 그려 줄 것들(재시작 너머에서 온 것 포함).
  List<OutboxEntry> failedForRoom(int roomId) =>
      _failed.values.where((e) => e.roomId == roomId).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  void _restore() {
    final raw = _store.read();
    if (raw == null || raw.isEmpty) return;
    try {
      final list = json.decode(raw) as List<dynamic>;
      final cutoff = _now().subtract(outboxRetention);
      for (final item in list) {
        final entry = OutboxEntry.fromJson(item as Map<String, dynamic>);
        if (entry.createdAt.isBefore(cutoff)) continue;
        _failed[entry.localId] = entry;
      }
    } catch (_) {
      // 깨진 저장 값은 버린다 — 발신함 때문에 채팅이 못 열리면 안 된다
    }
  }

  void _persist() {
    _store.write(json.encode(_failed.values.map((e) => e.toJson()).toList()));
  }
}

/// 서버 에코가 내 '전송 중' 말풍선인지 — 식별자로만 본다.
///
/// 전에는 (보낸 사람, 내용)으로 찾았다. "네", "네"처럼 같은 말을 연달아 보내면
/// 두 번째 에코가 첫 번째 말풍선에 붙거나 사라졌다.
int indexOfPending(List<ChatMessage> messages, ChatMessage incoming) {
  final key = incoming.clientMessageId;
  if (key == null || key.isEmpty) return -1;
  return messages.indexWhere(
    (m) =>
        m.isLocalOnly &&
        m.clientMessageId == key &&
        m.senderId == incoming.senderId,
  );
}

/// 이 메시지를 서버에서 고치거나 지울 수 있는가.
bool canEditOrDelete(ChatMessage message) =>
    !message.isLocalOnly && message.sendingStatus == MessageSendingStatus.sent;
