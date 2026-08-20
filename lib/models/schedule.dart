/// 일정 모델
class Schedule {
  final int id;
  final String title;
  final String? content;
  final String category;
  final String? categoryDisplayName;
  final ScheduleLabel? label;
  // 일정 자체 색상 (V2 색상 전환). "#RRGGBB" 또는 null(색 미지정 → 카테고리 기본색으로 폴백).
  // 색을 실제로 그릴 땐 이 필드를 직접 읽지 말고 schedule_colors.dart의 scheduleDisplayColor()를 쓴다.
  final String? color;
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
    this.color,
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
      // 신 필드(color) 우선, 없으면 구 응답의 label.color로 폴백.
      // 신 백엔드는 label을 항상 effectiveColor로 채운 shim으로 내려주므로 이 폴백이
      // 결과적으로 카테고리 기본색까지 이어진다 — 별개로 화면단에서도 한 번 더 폴백한다.
      color: json['color']?.toString() ??
          (json['label'] is Map
              ? (json['label'] as Map)['color']?.toString()
              : null),
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

  /// 카테고리 표시 텍스트 — 커스텀 구분(label)이 있으면 그 이름을 우선한다.
  /// 구분 없는 일정도 서버가 색 폴백용 shim(label.name == '')을 내려주므로
  /// 빈 이름은 걸러야 기본 카테고리명이 나온다.
  String get categoryText {
    final labelName = label?.name;
    if (labelName != null && labelName.isNotEmpty) return labelName;
    return categoryDisplayName ?? _getCategoryDisplayName(category);
  }

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

/// 기본 일정 구분(회의·행사·교육·기타)의 기관별 설정 상태.
/// 서버가 enum 기본값과 기관 설정을 머지해 내려준다.
/// 기본 구분은 기존 일정이 물고 있어 삭제 대신 숨김(hidden)만 지원한다.
class ScheduleCategorySetting {
  final String category;
  final String name;
  final String color;
  final bool hidden;
  final String defaultName;
  final String defaultColor;

  /// 이름·색·숨김 중 하나라도 기본에서 바뀌었는지 (되돌리기 노출용)
  final bool customized;

  ScheduleCategorySetting({
    required this.category,
    required this.name,
    required this.color,
    required this.hidden,
    required this.defaultName,
    required this.defaultColor,
    required this.customized,
  });

  factory ScheduleCategorySetting.fromJson(Map<String, dynamic> json) {
    return ScheduleCategorySetting(
      category: json['category']?.toString() ?? 'OTHER',
      name: json['name']?.toString() ?? '',
      color: json['color']?.toString() ?? '#14B8A6',
      hidden: json['hidden'] == true,
      defaultName: json['defaultName']?.toString() ?? '',
      defaultColor: json['defaultColor']?.toString() ?? '#14B8A6',
      customized: json['customized'] == true,
    );
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
