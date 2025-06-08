enum VacationStatus { pending, approved, rejected }

enum VacationType { mandatory, personal }

enum VacationDuration {
  fullDay, // 연차 (1.0일)
  halfDayAm, // 오전 반차 (0.5일)
  halfDayPm, // 오후 반차 (0.5일)
}

class VacationRequest {
  final String id;
  final String userId;
  final String userName;
  final String role;
  final DateTime date;
  final VacationStatus status;
  final VacationType type;
  final VacationDuration duration;
  final String? reason;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? rejectionReason;

  VacationRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.role,
    required this.date,
    this.status = VacationStatus.pending,
    this.type = VacationType.personal,
    this.duration = VacationDuration.fullDay,
    this.reason,
    required this.createdAt,
    this.updatedAt,
    this.approvedAt,
    this.approvedBy,
    this.rejectionReason,
  });

  String get userRole => role;

  factory VacationRequest.fromJson(Map<String, dynamic> json) {
    return VacationRequest(
      id: json['id']?.toString() ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      role: json['role'] ?? 'CAREGIVER',
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      status: _parseStatus(json['status']),
      type: _parseType(json['type']),
      duration: _parseDuration(json['duration']),
      reason: json['reason'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
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
      'role': role,
      'date': date.toIso8601String(),
      'status': status.toString().split('.').last,
      'type': type.toString().split('.').last,
      'duration': duration.toString().split('.').last,
      'reason': reason,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
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

  static VacationDuration _parseDuration(String? duration) {
    switch (duration) {
      case 'HALF_DAY_AM':
        return VacationDuration.halfDayAm;
      case 'HALF_DAY_PM':
        return VacationDuration.halfDayPm;
      case 'FULL_DAY':
      default:
        return VacationDuration.fullDay;
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
        return '일반';
    }
  }

  String get durationText {
    switch (duration) {
      case VacationDuration.fullDay:
        return '연차';
      case VacationDuration.halfDayAm:
        return '오전 반차';
      case VacationDuration.halfDayPm:
        return '오후 반차';
    }
  }

  String get displayName {
    return '$userName ($durationText)';
  }

  VacationRequest copyWith({
    String? id,
    String? userId,
    String? userName,
    String? role,
    DateTime? date,
    VacationStatus? status,
    VacationType? type,
    VacationDuration? duration,
    String? reason,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? approvedAt,
    String? approvedBy,
    String? rejectionReason,
  }) {
    return VacationRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      role: role ?? this.role,
      date: date ?? this.date,
      status: status ?? this.status,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}
