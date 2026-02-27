import 'chat_message.dart';
import 'chat_participant.dart';

enum ChatRoomStatus { active, archived, deleted }

class ChatRoom {
  final int id;
  final String name;
  final String? description;
  final int companyId;
  final String createdBy;
  final String createdByName;
  final String? thumbnailUrl;
  final int participantCount;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final ChatRoomStatus status;
  final List<ChatParticipant> participants;

  ChatRoom({
    required this.id,
    required this.name,
    this.description,
    required this.companyId,
    required this.createdBy,
    required this.createdByName,
    this.thumbnailUrl,
    this.participantCount = 0,
    this.lastMessage,
    this.unreadCount = 0,
    required this.createdAt,
    this.lastMessageAt,
    this.status = ChatRoomStatus.active,
    this.participants = const [],
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      companyId: json['companyId'] as int? ?? 0,
      createdBy: json['createdBy']?.toString() ?? '',
      createdByName: json['createdByName']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      participantCount: json['participantCount'] as int? ?? 0,
      lastMessage: json['lastMessage'] != null
          ? ChatMessage.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'].toString())
          : null,
      status: _parseStatus(json['status']?.toString()),
      participants: json['participants'] != null
          ? (json['participants'] as List<dynamic>)
              .map((p) => ChatParticipant.fromJson(p as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'companyId': companyId,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'thumbnailUrl': thumbnailUrl,
      'participantCount': participantCount,
      'lastMessage': lastMessage?.toJson(),
      'unreadCount': unreadCount,
      'createdAt': createdAt.toIso8601String(),
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'status': status.name.toUpperCase(),
      'participants': participants.map((p) => p.toJson()).toList(),
    };
  }

  static ChatRoomStatus _parseStatus(String? status) {
    switch (status?.toUpperCase()) {
      case 'ARCHIVED':
        return ChatRoomStatus.archived;
      case 'DELETED':
        return ChatRoomStatus.deleted;
      case 'ACTIVE':
      default:
        return ChatRoomStatus.active;
    }
  }

  ChatRoom copyWith({
    int? id,
    String? name,
    String? description,
    int? companyId,
    String? createdBy,
    String? createdByName,
    String? thumbnailUrl,
    int? participantCount,
    ChatMessage? lastMessage,
    int? unreadCount,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    ChatRoomStatus? status,
    List<ChatParticipant>? participants,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      companyId: companyId ?? this.companyId,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      participantCount: participantCount ?? this.participantCount,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      status: status ?? this.status,
      participants: participants ?? this.participants,
    );
  }
}
