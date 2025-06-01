enum VacationStatus { pending, approved, rejected }

enum VacationType { mandatory, personal }

class VacationRequest {
  final String id;
  final String userId;
  final String userName;
  final String userRole;
  final DateTime date;
  final VacationStatus status;
  final VacationType type;
  final String? reason;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? rejectionReason;

  VacationRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.date,
    this.status = VacationStatus.pending,
    this.type = VacationType.personal,
    this.reason,
    required this.createdAt,
    this.approvedAt,
    this.approvedBy,
    this.rejectionReason,
  });

  factory VacationRequest.fromJson(Map<String, dynamic> json) {
    return VacationRequest(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      userRole: json['userRole'] ?? 'caregiver',
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      status: _parseStatus(json['status']),
      type: _parseType(json['type']),
      reason: json['reason'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      approvedAt: json['approvedAt'] != null
          ? DateTime.tryParse(json['approvedAt'])
          : null,
      approvedBy: json['approvedBy'],
      rejectionReason: json['rejectionReason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userRole': userRole,
      'date': date.toIso8601String(),
      'status': status.toString().split('.').last,
      'type': type.toString().split('.').last,
      'reason': reason,
      'createdAt': createdAt.toIso8601String(),
      'approvedAt': approvedAt?.toIso8601String(),
      'approvedBy': approvedBy,
      'rejectionReason': rejectionReason,
    };
  }

  static VacationStatus _parseStatus(String? status) {
    switch (status) {
      case 'approved':
        return VacationStatus.approved;
      case 'rejected':
        return VacationStatus.rejected;
      default:
        return VacationStatus.pending;
    }
  }

  static VacationType _parseType(String? type) {
    switch (type) {
      case 'mandatory':
        return VacationType.mandatory;
      default:
        return VacationType.personal;
    }
  }

  String get statusText {
    switch (status) {
      case VacationStatus.pending:
        return '대기';
      case VacationStatus.approved:
        return '승인';
      case VacationStatus.rejected:
        return '거절';
    }
  }

  String get typeText {
    switch (type) {
      case VacationType.mandatory:
        return '필수';
      case VacationType.personal:
        return '개인';
    }
  }

  VacationRequest copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userRole,
    DateTime? date,
    VacationStatus? status,
    VacationType? type,
    String? reason,
    DateTime? createdAt,
    DateTime? approvedAt,
    String? approvedBy,
    String? rejectionReason,
  }) {
    return VacationRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userRole: userRole ?? this.userRole,
      date: date ?? this.date,
      status: status ?? this.status,
      type: type ?? this.type,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}
