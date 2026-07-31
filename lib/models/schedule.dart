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
  // 수행완료 (V1.26)
  final bool isCompleted;
  final DateTime? completedAt;
  final String? completedByName;
  // 담당자 (참석자와 별개, V1.35)
  final int? managerId;
  final String? managerName;
  // 할 일 (V1.32)
  final List<ScheduleTask> tasks;
  final int taskTotal;
  final int taskCompleted;
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
    this.isCompleted = false,
    this.completedAt,
    this.completedByName,
    this.managerId,
    this.managerName,
    this.tasks = const [],
    this.taskTotal = 0,
    this.taskCompleted = 0,
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
      isCompleted: json['isCompleted'] ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
      completedByName: json['completedByName']?.toString(),
      managerId: json['managerId'] is int
          ? json['managerId']
          : int.tryParse(json['managerId']?.toString() ?? ''),
      managerName: json['managerName']?.toString(),
      tasks: json['tasks'] != null
          ? (json['tasks'] as List)
              .map((t) => ScheduleTask.fromJson(t as Map<String, dynamic>))
              .toList()
          : const [],
      taskTotal: json['taskTotal'] is int ? json['taskTotal'] : 0,
      taskCompleted: json['taskCompleted'] is int ? json['taskCompleted'] : 0,
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

/// 일정 할 일 (담당자별 업무)
class ScheduleTask {
  final int id;
  final int scheduleId;
  final String content;
  final int? assigneeMemberId;
  final String? assigneeName;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? completedByName;
  // 내 할 일 목록(/my-tasks)에서만 내려오는 일정 요약
  final String? scheduleTitle;
  final DateTime? scheduleStartDate;

  ScheduleTask({
    required this.id,
    required this.scheduleId,
    required this.content,
    this.assigneeMemberId,
    this.assigneeName,
    this.isCompleted = false,
    this.completedAt,
    this.completedByName,
    this.scheduleTitle,
    this.scheduleStartDate,
  });

  factory ScheduleTask.fromJson(Map<String, dynamic> json) {
    return ScheduleTask(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      scheduleId: json['scheduleId'] is int
          ? json['scheduleId']
          : int.tryParse(json['scheduleId']?.toString() ?? '0') ?? 0,
      content: json['content']?.toString() ?? '',
      assigneeMemberId: json['assigneeMemberId'] is int
          ? json['assigneeMemberId']
          : int.tryParse(json['assigneeMemberId']?.toString() ?? ''),
      assigneeName: json['assigneeName']?.toString(),
      isCompleted: json['isCompleted'] ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
      completedByName: json['completedByName']?.toString(),
      scheduleTitle: json['scheduleTitle']?.toString(),
      scheduleStartDate: json['scheduleStartDate'] != null
          ? DateTime.tryParse(json['scheduleStartDate'].toString())
          : null,
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
