/// 고충·신고 / 건의함 (VoiceBox) 유형.
/// 백엔드 VoiceMessage.VoiceType과 1:1 대응 — GRIEVANCE(고충·신고) / SUGGESTION(건의)
enum VoiceMessageType {
  grievance,
  suggestion;

  static VoiceMessageType fromApi(String? raw) {
    switch (raw) {
      case 'SUGGESTION':
        return VoiceMessageType.suggestion;
      case 'GRIEVANCE':
      default:
        return VoiceMessageType.grievance;
    }
  }

  String get apiValue =>
      this == VoiceMessageType.suggestion ? 'SUGGESTION' : 'GRIEVANCE';

  String get label =>
      this == VoiceMessageType.suggestion ? '건의' : '고충·신고';
}

/// 백엔드 VoiceMessage.VoiceStatus와 1:1 대응.
enum VoiceMessageStatus {
  received,
  inReview,
  resolved,
  onHold;

  static VoiceMessageStatus fromApi(String? raw) {
    switch (raw) {
      case 'IN_REVIEW':
        return VoiceMessageStatus.inReview;
      case 'RESOLVED':
        return VoiceMessageStatus.resolved;
      case 'ON_HOLD':
        return VoiceMessageStatus.onHold;
      case 'RECEIVED':
      default:
        return VoiceMessageStatus.received;
    }
  }

  String get label {
    switch (this) {
      case VoiceMessageStatus.received:
        return '접수됨';
      case VoiceMessageStatus.inReview:
        return '확인중';
      case VoiceMessageStatus.resolved:
        return '처리완료';
      case VoiceMessageStatus.onHold:
        return '보류';
    }
  }
}

/// 고충·신고 / 건의함 항목.
/// 백엔드 VoiceMessageService.VoiceMessageDTO와 대응.
class VoiceMessage {
  final int id;
  final VoiceMessageType type;
  final String title;
  final String content;
  final bool isAnonymous;
  final String authorName;
  final VoiceMessageStatus status;
  final String? adminReply;
  final DateTime? repliedAt;
  final DateTime? createdAt;

  VoiceMessage({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.isAnonymous,
    required this.authorName,
    required this.status,
    this.adminReply,
    this.repliedAt,
    this.createdAt,
  });

  factory VoiceMessage.fromJson(Map<String, dynamic> json) {
    return VoiceMessage(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      type: VoiceMessageType.fromApi(json['type']?.toString()),
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      isAnonymous: json['isAnonymous'] == true,
      authorName: json['authorName']?.toString() ?? '익명',
      status: VoiceMessageStatus.fromApi(json['status']?.toString()),
      adminReply: json['adminReply']?.toString(),
      repliedAt: json['repliedAt'] != null
          ? DateTime.tryParse(json['repliedAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  bool get hasReply => adminReply != null && adminReply!.trim().isNotEmpty;
}
