enum VacationStatus { pending, approved, rejected }

enum VacationType { mandatory, personal, substitute }

/// 연차 미사용 휴무의 세부 유형 (서버 vacation_type 컬럼)
enum VacationDetailType { personal, sick, emergency, family, other }

extension VacationDetailTypeX on VacationDetailType {
  String get serverValue => toString().split('.').last;

  String get label {
    switch (this) {
      case VacationDetailType.personal:
        return '개인 사정';
      case VacationDetailType.sick:
        return '병가';
      case VacationDetailType.emergency:
        return '긴급';
      case VacationDetailType.family:
        return '가족 행사';
      case VacationDetailType.other:
        return '기타';
    }
  }
}

enum VacationDuration {
  unused, // 미사용 (0.0일)
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
  final String? vacationType; // 연차 미사용 세부 유형 (personal/sick/emergency/family/other/substitute)
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
    this.vacationType,
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
      vacationType: json['vacationType']?.toString(),
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
      case 'substitute':
        return VacationType.substitute;
      default:
        return VacationType.personal;
    }
  }

  /// 대체휴무 여부 (type 또는 세부유형 기준 — 백엔드 isSubstitute와 동일 규칙)
  bool get isSubstitute => type == VacationType.substitute || vacationType == 'substitute';

  static VacationDuration _parseDuration(String? duration) {
    switch (duration) {
      case 'UNUSED':
        return VacationDuration.unused;
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
      case VacationType.substitute:
        return '대체휴무';
      case VacationType.personal:
        return '일반';
    }
  }

  /// 연차 미사용 세부 유형 라벨 (없으면 null)
  String? get vacationTypeText {
    switch (vacationType) {
      case 'personal':
        return '개인 사정';
      case 'sick':
        return '병가';
      case 'emergency':
        return '긴급';
      case 'family':
        return '가족 행사';
      case 'other':
        return '기타';
      case 'substitute':
        return '대체휴무';
      default:
        return null;
    }
  }

  String get durationText {
    switch (duration) {
      case VacationDuration.unused:
        return ''; // 미사용일 때는 아무것도 표시하지 않음
      case VacationDuration.fullDay:
        return '연차';
      case VacationDuration.halfDayAm:
        return '오전 반차';
      case VacationDuration.halfDayPm:
        return '오후 반차';
    }
  }

  String get displayName {
    final duration = durationText;
    return duration.isEmpty ? userName : '$userName ($duration)';
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
    String? vacationType,
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
      vacationType: vacationType ?? this.vacationType,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}
