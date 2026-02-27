/// 일정 모델
class Schedule {
  final int id;
  final String title;
  final String? content;
  final String category;
  final String? categoryDisplayName;
  final ScheduleLabel? label;
  final String? location;
  final DateTime startDate;
  final String? startTime;
  final DateTime? endDate;
  final String? endTime;
  final bool isAllDay;
  final bool sendNotification;
  final List<ScheduleParticipant>? participants;
  final String? authorId;
  final String? authorName;
  final int companyId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Schedule({
    required this.id,
    required this.title,
    this.content,
    required this.category,
    this.categoryDisplayName,
    this.label,
    this.location,
    required this.startDate,
    this.startTime,
    this.endDate,
    this.endTime,
    this.isAllDay = false,
    this.sendNotification = false,
    this.participants,
    this.authorId,
    this.authorName,
    required this.companyId,
    this.createdAt,
    this.updatedAt,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    // 날짜 파싱 헬퍼 - UTC를 로컬로 변환하고 날짜만 사용
    DateTime parseDate(String? dateStr) {
      if (dateStr == null) return DateTime.now();
      final parsed = DateTime.parse(dateStr);
      // UTC인 경우 로컬로 변환
      return parsed.isUtc ? parsed.toLocal() : parsed;
    }

    return Schedule(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString(),
      category: json['category']?.toString() ?? 'OTHER',
      categoryDisplayName: json['categoryDisplayName']?.toString(),
      label: json['label'] != null
          ? ScheduleLabel.fromJson(json['label'])
          : null,
      location: json['location']?.toString(),
      startDate: parseDate(json['startDate']?.toString()),
      startTime: json['startTime']?.toString(),
      endDate: json['endDate'] != null
          ? parseDate(json['endDate']?.toString())
          : null,
      endTime: json['endTime']?.toString(),
      isAllDay: json['isAllDay'] ?? false,
      sendNotification: json['sendNotification'] ?? false,
      participants: json['participants'] != null
          ? (json['participants'] as List)
              .map((p) => ScheduleParticipant.fromJson(p as Map<String, dynamic>))
              .toList()
          : null,
      authorId: json['authorId']?.toString(),
      authorName: json['authorName']?.toString(),
      companyId: json['companyId'] is int ? json['companyId'] : int.tryParse(json['companyId']?.toString() ?? '0') ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString())
          : null,
    );
  }

  /// 카테고리 표시 텍스트
  String get categoryText => categoryDisplayName ?? _getCategoryDisplayName(category);

  String _getCategoryDisplayName(String cat) {
    switch (cat) {
      case 'MEETING':
        return '회의';
      case 'EVENT':
        return '행사';
      case 'TRAINING':
        return '교육';
      case 'OTHER':
      default:
        return '기타';
    }
  }

  /// 시간 표시 텍스트
  String get timeText {
    if (isAllDay) return '종일';
    if (startTime != null) {
      return startTime!.substring(0, 5); // HH:mm
    }
    return '';
  }
}

/// 일정 라벨
class ScheduleLabel {
  final int id;
  final String name;
  final String color;

  ScheduleLabel({
    required this.id,
    required this.name,
    required this.color,
  });

  factory ScheduleLabel.fromJson(Map<String, dynamic> json) {
    return ScheduleLabel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      color: json['color'] ?? '#2196F3',
    );
  }
}

/// 일정 참가자
class ScheduleParticipant {
  final int id;
  final String memberId;
  final String memberName;

  ScheduleParticipant({
    required this.id,
    required this.memberId,
    required this.memberName,
  });

  factory ScheduleParticipant.fromJson(Map<String, dynamic> json) {
    return ScheduleParticipant(
      id: json['id'] ?? 0,
      memberId: json['memberId']?.toString() ?? '',
      memberName: json['memberName']?.toString() ?? '',
    );
  }
}

/// 일정 카테고리 enum
enum ScheduleCategory {
  meeting('MEETING', '회의'),
  event('EVENT', '행사'),
  training('TRAINING', '교육'),
  other('OTHER', '기타');

  const ScheduleCategory(this.value, this.displayName);
  final String value;
  final String displayName;
}
