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

  /// 목록에서 방 아이콘 자리에 겹쳐 그릴 참여자(최대 4명, 나는 빠져 있다).
  /// 서버가 목록 응답에만 채워 준다 — 참가자 전체를 받지 않아도 얼굴을 보여주려는 것이다.
  final List<ChatRoomAvatar> avatars;

  // 공지 — 기존 메시지 하나를 방 상단에 고정한다 (카카오톡과 같은 방식)
  final int? noticeMessageId;
  final String? noticeContent;
  final String? noticeByName;
  final DateTime? noticeAt;
  // 공지로 고정된 메시지가 파일이었을 때의 스냅샷
  final String? noticeFileName;
  final String? noticeFileUrl;

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
    this.avatars = const [],
    this.noticeMessageId,
    this.noticeContent,
    this.noticeByName,
    this.noticeAt,
    this.noticeFileName,
    this.noticeFileUrl,
  });

  bool get hasNotice =>
      noticeMessageId != null && (noticeContent?.isNotEmpty ?? false);

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
      avatars: json['avatars'] != null
          ? (json['avatars'] as List<dynamic>)
              .map((a) => ChatRoomAvatar.fromJson(a as Map<String, dynamic>))
              .toList()
          : const [],
      noticeMessageId: (json['noticeMessageId'] as num?)?.toInt(),
      noticeContent: json['noticeContent']?.toString(),
      noticeByName: json['noticeByName']?.toString(),
      noticeAt: json['noticeAt'] != null
          ? DateTime.tryParse(json['noticeAt'].toString())
          : null,
      noticeFileName: json['noticeFileName']?.toString(),
      noticeFileUrl: json['noticeFileUrl']?.toString(),
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
      'noticeMessageId': noticeMessageId,
      'noticeContent': noticeContent,
      'noticeByName': noticeByName,
      'noticeAt': noticeAt?.toIso8601String(),
      'noticeFileName': noticeFileName,
      'noticeFileUrl': noticeFileUrl,
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
    List<ChatRoomAvatar>? avatars,
    int? noticeMessageId,
    String? noticeContent,
    String? noticeByName,
    DateTime? noticeAt,
    String? noticeFileName,
    String? noticeFileUrl,
    // 공지는 '없음'으로도 되돌려야 해서 ??로는 표현이 안 된다
    bool clearNotice = false,
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
      avatars: avatars ?? this.avatars,
      noticeMessageId: clearNotice
          ? null
          : (noticeMessageId ?? this.noticeMessageId),
      noticeContent: clearNotice ? null : (noticeContent ?? this.noticeContent),
      noticeByName: clearNotice ? null : (noticeByName ?? this.noticeByName),
      noticeAt: clearNotice ? null : (noticeAt ?? this.noticeAt),
      noticeFileName: clearNotice ? null : (noticeFileName ?? this.noticeFileName),
      noticeFileUrl: clearNotice ? null : (noticeFileUrl ?? this.noticeFileUrl),
    );
  }
}

/// 목록에서 방 아이콘 자리에 겹쳐 그릴 참여자 한 명.
/// 사진이 없으면 이름 첫 글자로 그린다.
class ChatRoomAvatar {
  final String userId;
  final String userName;
  final String? profileImageUrl;

  const ChatRoomAvatar({
    required this.userId,
    required this.userName,
    this.profileImageUrl,
  });

  factory ChatRoomAvatar.fromJson(Map<String, dynamic> json) {
    return ChatRoomAvatar(
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      profileImageUrl: json['profileImageUrl']?.toString(),
    );
  }
}
