import '../utils/chat_media.dart';

enum MessageType { text, image, file, system }

/// 첨부를 화면에서 어떻게 그릴지. 저장된 [MessageType]과 달리 **파생** 값이다.
/// (왜 서버 type에 video를 넣지 않았는지는 chat_media.dart 주석 참고)
enum ChatMediaKind { image, video, file }

enum MessageSendingStatus { sending, sent, failed }

/// 이모지 리액션 요약
class ReactionSummary {
  final String emoji;
  final int count;
  final List<String> userNames;
  final bool myReaction;

  ReactionSummary({
    required this.emoji,
    required this.count,
    this.userNames = const [],
    this.myReaction = false,
  });

  factory ReactionSummary.fromJson(Map<String, dynamic> json) {
    return ReactionSummary(
      emoji: json['emoji']?.toString() ?? '',
      count: json['count'] as int? ?? 0,
      userNames:
          (json['userNames'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      myReaction: json['myReaction'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'emoji': emoji,
      'count': count,
      'userNames': userNames,
      'myReaction': myReaction,
    };
  }

  ReactionSummary copyWith({
    String? emoji,
    int? count,
    List<String>? userNames,
    bool? myReaction,
  }) {
    return ReactionSummary(
      emoji: emoji ?? this.emoji,
      count: count ?? this.count,
      userNames: userNames ?? this.userNames,
      myReaction: myReaction ?? this.myReaction,
    );
  }
}

class ChatMessage {
  final int id;
  final int chatRoomId;
  final String senderId;
  final String senderName;
  final String? senderPosition;
  final MessageType type;
  final String? content;
  final String? fileUrl;
  // 서버가 만들어 내려주는 축소본 URL. 목록에서 이미지를 빠르게 띄우는 용도이고,
  // 전체화면 보기는 항상 fileUrl(원본)을 쓴다. 예전 메시지엔 이 값이 없을 수
  // 있으므로(백엔드가 나중에 붙인 필드) 항상 null 가능성을 열어둔다.
  final String? thumbnailUrl;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  /// 서버가 내려주는 파생 값 — 'IMAGE' | 'VIDEO' | 'FILE'.
  /// 아직 새 서버가 배포되지 않았으면 null이고, 그때는 mimeType·확장자로 판정한다.
  final String? mediaType;
  final int readCount;
  final DateTime createdAt;
  final bool isDeleted;
  final MessageSendingStatus sendingStatus;
  final String? localId; // 로컬에서 생성한 임시 ID
  final List<ReactionSummary> reactions; // 이모지 리액션
  final DateTime? editedAt; // 수정된 시각. null이면 수정된 적 없음

  ChatMessage({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    required this.senderName,
    this.senderPosition,
    this.type = MessageType.text,
    this.content,
    this.fileUrl,
    this.thumbnailUrl,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.mediaType,
    this.readCount = 0,
    required this.createdAt,
    this.isDeleted = false,
    this.sendingStatus = MessageSendingStatus.sent,
    this.localId,
    this.reactions = const [],
    this.editedAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int? ?? 0,
      chatRoomId: json['chatRoomId'] as int? ?? 0,
      senderId: json['senderId']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? '',
      senderPosition: json['senderPosition']?.toString(),
      type: _parseMessageType(json['type']?.toString()),
      content: json['content']?.toString(),
      fileUrl: json['fileUrl']?.toString(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      fileName: json['fileName']?.toString(),
      fileSize: json['fileSize'] as int?,
      mimeType: json['mimeType']?.toString(),
      mediaType: json['mediaType']?.toString(),
      readCount: json['readCount'] as int? ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      isDeleted: json['isDeleted'] as bool? ?? false,
      sendingStatus: MessageSendingStatus.sent, // 서버에서 온 메시지는 이미 전송됨
      localId: json['localId']?.toString(),
      reactions:
          (json['reactions'] as List<dynamic>?)
              ?.map((e) => ReactionSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      editedAt: DateTime.tryParse(json['editedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatRoomId': chatRoomId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPosition': senderPosition,
      'type': type.name.toUpperCase(),
      'content': content,
      'fileUrl': fileUrl,
      'thumbnailUrl': thumbnailUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'readCount': readCount,
      'createdAt': createdAt.toIso8601String(),
      'isDeleted': isDeleted,
      'mediaType': mediaType,
      'reactions': reactions.map((e) => e.toJson()).toList(),
      'editedAt': editedAt?.toIso8601String(),
    };
  }

  static MessageType _parseMessageType(String? type) {
    switch (type?.toUpperCase()) {
      case 'IMAGE':
        return MessageType.image;
      case 'FILE':
        return MessageType.file;
      case 'SYSTEM':
        return MessageType.system;
      case 'TEXT':
      default:
        return MessageType.text;
    }
  }

  String get typeText {
    switch (type) {
      case MessageType.text:
        return '텍스트';
      case MessageType.image:
        return '이미지';
      case MessageType.file:
        return '파일';
      case MessageType.system:
        return '시스템';
    }
  }

  bool get isFileMessage =>
      type == MessageType.image || type == MessageType.file;

  /// 첨부를 어떻게 그릴지. 첨부가 아닌 메시지(글·시스템)면 null.
  ///
  /// 판정 순서와 이유:
  ///  1. 서버가 준 [mediaType] — 이미 서버가 내용까지 보고 정한 값이라 가장 믿을 만하다.
  ///  2. [mimeType] — 새 서버가 아직 안 올라갔을 때. api-server는 수동 배포라
  ///     앱이 먼저 나가는 일이 실제로 있다.
  ///  3. 파일명 확장자 — mimeType이 비었거나 application/octet-stream인 옛 메시지 구제.
  ChatMediaKind? get mediaKind {
    if (type != MessageType.image && type != MessageType.file) return null;

    switch (mediaType?.toUpperCase()) {
      case 'VIDEO':
        return ChatMediaKind.video;
      case 'IMAGE':
        return ChatMediaKind.image;
      case 'FILE':
        return ChatMediaKind.file;
    }

    final mime = mimeType?.toLowerCase();
    if (mime != null) {
      if (mime.startsWith('video/')) return ChatMediaKind.video;
      if (mime.startsWith('image/')) return ChatMediaKind.image;
      // 회의 녹음(webm/m4a)이 확장자 표를 타고 동영상으로 둔갑하지 않게 여기서 끊는다.
      if (mime.startsWith('audio/')) return ChatMediaKind.file;
    }

    if (isVideoFileName(fileName)) return ChatMediaKind.video;

    return type == MessageType.image ? ChatMediaKind.image : ChatMediaKind.file;
  }

  /// 동영상 첨부인지.
  bool get isVideoMessage => mediaKind == ChatMediaKind.video;

  /// 사진 첨부인지(동영상은 제외).
  bool get isPhotoMessage => mediaKind == ChatMediaKind.image;

  String get displayContent {
    if (isDeleted) return '삭제된 메시지입니다.';
    switch (type) {
      case MessageType.text:
        return content ?? '';
      case MessageType.image:
        return '[사진]';
      case MessageType.file:
        if (isVideoMessage) return '[동영상]';
        return '[파일] ${fileName ?? ''}';
      case MessageType.system:
        return content ?? '';
    }
  }

  ChatMessage copyWith({
    int? id,
    int? chatRoomId,
    String? senderId,
    String? senderName,
    String? senderPosition,
    MessageType? type,
    String? content,
    String? fileUrl,
    String? thumbnailUrl,
    String? fileName,
    int? fileSize,
    String? mimeType,
    String? mediaType,
    int? readCount,
    DateTime? createdAt,
    bool? isDeleted,
    MessageSendingStatus? sendingStatus,
    String? localId,
    List<ReactionSummary>? reactions,
    DateTime? editedAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderPosition: senderPosition ?? this.senderPosition,
      type: type ?? this.type,
      content: content ?? this.content,
      fileUrl: fileUrl ?? this.fileUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      mediaType: mediaType ?? this.mediaType,
      readCount: readCount ?? this.readCount,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
      sendingStatus: sendingStatus ?? this.sendingStatus,
      localId: localId ?? this.localId,
      reactions: reactions ?? this.reactions,
      editedAt: editedAt ?? this.editedAt,
    );
  }
}

// 메시지 읽음 확인
class ChatMessageReader {
  final int id;
  final int messageId;
  final String userId;
  final String userName;
  final DateTime readAt;

  ChatMessageReader({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.userName,
    required this.readAt,
  });

  factory ChatMessageReader.fromJson(Map<String, dynamic> json) {
    return ChatMessageReader(
      id: json['id'] as int? ?? 0,
      messageId: json['messageId'] as int? ?? 0,
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      readAt:
          DateTime.tryParse(json['readAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'messageId': messageId,
      'userId': userId,
      'userName': userName,
      'readAt': readAt.toIso8601String(),
    };
  }
}
