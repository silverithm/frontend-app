enum MessageType { text, image, file, system }

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
      userNames: (json['userNames'] as List<dynamic>?)
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
  final MessageType type;
  final String? content;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final int readCount;
  final DateTime createdAt;
  final bool isDeleted;
  final MessageSendingStatus sendingStatus;
  final String? localId; // 로컬에서 생성한 임시 ID
  final List<ReactionSummary> reactions; // 이모지 리액션

  ChatMessage({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    required this.senderName,
    this.type = MessageType.text,
    this.content,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.readCount = 0,
    required this.createdAt,
    this.isDeleted = false,
    this.sendingStatus = MessageSendingStatus.sent,
    this.localId,
    this.reactions = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int? ?? 0,
      chatRoomId: json['chatRoomId'] as int? ?? 0,
      senderId: json['senderId']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? '',
      type: _parseMessageType(json['type']?.toString()),
      content: json['content']?.toString(),
      fileUrl: json['fileUrl']?.toString(),
      fileName: json['fileName']?.toString(),
      fileSize: json['fileSize'] as int?,
      mimeType: json['mimeType']?.toString(),
      readCount: json['readCount'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      isDeleted: json['isDeleted'] as bool? ?? false,
      sendingStatus: MessageSendingStatus.sent, // 서버에서 온 메시지는 이미 전송됨
      localId: json['localId']?.toString(),
      reactions: (json['reactions'] as List<dynamic>?)
              ?.map((e) => ReactionSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatRoomId': chatRoomId,
      'senderId': senderId,
      'senderName': senderName,
      'type': type.name.toUpperCase(),
      'content': content,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'readCount': readCount,
      'createdAt': createdAt.toIso8601String(),
      'isDeleted': isDeleted,
      'reactions': reactions.map((e) => e.toJson()).toList(),
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

  bool get isFileMessage => type == MessageType.image || type == MessageType.file;

  String get displayContent {
    if (isDeleted) return '삭제된 메시지입니다.';
    switch (type) {
      case MessageType.text:
        return content ?? '';
      case MessageType.image:
        return '[사진]';
      case MessageType.file:
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
    MessageType? type,
    String? content,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? mimeType,
    int? readCount,
    DateTime? createdAt,
    bool? isDeleted,
    MessageSendingStatus? sendingStatus,
    String? localId,
    List<ReactionSummary>? reactions,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      type: type ?? this.type,
      content: content ?? this.content,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      readCount: readCount ?? this.readCount,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
      sendingStatus: sendingStatus ?? this.sendingStatus,
      localId: localId ?? this.localId,
      reactions: reactions ?? this.reactions,
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
      readAt: DateTime.tryParse(json['readAt']?.toString() ?? '') ?? DateTime.now(),
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
