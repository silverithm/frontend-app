enum ParticipantRole { admin, member }

enum LeaveReason { selfLeft, kicked, accountDeleted }

class ChatParticipant {
  final int id;
  final int chatRoomId;
  final String userId;
  final String userName;
  final ParticipantRole role;
  final DateTime joinedAt;
  final DateTime? lastReadAt;
  final int? lastReadMessageId;
  final bool isActive;
  final DateTime? leftAt;
  final LeaveReason? leaveReason;

  ChatParticipant({
    required this.id,
    required this.chatRoomId,
    required this.userId,
    required this.userName,
    this.role = ParticipantRole.member,
    required this.joinedAt,
    this.lastReadAt,
    this.lastReadMessageId,
    this.isActive = true,
    this.leftAt,
    this.leaveReason,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      id: json['id'] as int? ?? 0,
      chatRoomId: json['chatRoomId'] as int? ?? 0,
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      role: _parseRole(json['role']?.toString()),
      joinedAt: DateTime.tryParse(json['joinedAt']?.toString() ?? '') ?? DateTime.now(),
      lastReadAt: json['lastReadAt'] != null
          ? DateTime.tryParse(json['lastReadAt'].toString())
          : null,
      lastReadMessageId: json['lastReadMessageId'] as int?,
      isActive: json['isActive'] as bool? ?? true,
      leftAt: json['leftAt'] != null
          ? DateTime.tryParse(json['leftAt'].toString())
          : null,
      leaveReason: json['leaveReason'] != null
          ? _parseLeaveReason(json['leaveReason'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatRoomId': chatRoomId,
      'userId': userId,
      'userName': userName,
      'role': role.name.toUpperCase(),
      'joinedAt': joinedAt.toIso8601String(),
      'lastReadAt': lastReadAt?.toIso8601String(),
      'lastReadMessageId': lastReadMessageId,
      'isActive': isActive,
      'leftAt': leftAt?.toIso8601String(),
      'leaveReason': leaveReason?.name.toUpperCase(),
    };
  }

  static ParticipantRole _parseRole(String? role) {
    switch (role?.toUpperCase()) {
      case 'ADMIN':
        return ParticipantRole.admin;
      case 'MEMBER':
      default:
        return ParticipantRole.member;
    }
  }

  static LeaveReason? _parseLeaveReason(String? reason) {
    switch (reason?.toUpperCase()) {
      case 'SELF_LEFT':
        return LeaveReason.selfLeft;
      case 'KICKED':
        return LeaveReason.kicked;
      case 'ACCOUNT_DELETED':
        return LeaveReason.accountDeleted;
      default:
        return null;
    }
  }

  String get roleText {
    switch (role) {
      case ParticipantRole.admin:
        return '방장';
      case ParticipantRole.member:
        return '멤버';
    }
  }

  bool get isAdmin => role == ParticipantRole.admin;

  ChatParticipant copyWith({
    int? id,
    int? chatRoomId,
    String? userId,
    String? userName,
    ParticipantRole? role,
    DateTime? joinedAt,
    DateTime? lastReadAt,
    int? lastReadMessageId,
    bool? isActive,
    DateTime? leftAt,
    LeaveReason? leaveReason,
  }) {
    return ChatParticipant(
      id: id ?? this.id,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      lastReadMessageId: lastReadMessageId ?? this.lastReadMessageId,
      isActive: isActive ?? this.isActive,
      leftAt: leftAt ?? this.leftAt,
      leaveReason: leaveReason ?? this.leaveReason,
    );
  }
}
