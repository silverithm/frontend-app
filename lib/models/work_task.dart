/// 업무진행도 — 원장 요청(2026-10-22): 담당자·기한·업무 내용·중요도·수행도를 적고,
/// 끝날 때까지 매일 아침 알린다. 웹 대시보드 오른쪽 패널과 같은 목록·규칙을 쓴다
/// (frontend-admin `src/lib/workTasks.ts`). 서버(/api/v1/work-tasks)가 순서까지 정해 준다 —
/// 진행 중(중요 → 기한 → 등록순)이 위, 최근 끝낸 것이 아래.
library;

enum WorkTaskImportance {
  high('HIGH', '중요'),
  normal('NORMAL', '보통'),
  low('LOW', '낮음');

  const WorkTaskImportance(this.code, this.label);

  /// 서버 값
  final String code;

  /// 색만으로 구분하지 않도록 글자도 함께 쓴다
  final String label;

  static WorkTaskImportance fromCode(String? code) {
    for (final value in values) {
      if (value.code == code) return value;
    }
    return WorkTaskImportance.normal;
  }
}

/// 수행도는 10% 단위로 고른다 — 1% 단위는 손으로 맞추기만 어렵고 뜻이 없다
const int workTaskProgressStep = 10;

/// 업무 내용 글자 수 한도(웹과 같다)
const int workTaskContentMax = 300;

/// 담당자·등록한 사람 — id는 채팅 식별자(직원 "12", 관리자 "admin_3")
class WorkTaskPerson {
  final String id;
  final String? name;

  const WorkTaskPerson({required this.id, this.name});

  factory WorkTaskPerson.fromJson(Map<String, dynamic> json) =>
      WorkTaskPerson(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString(),
      );
}

class WorkTask {
  final int id;
  final String content;
  final WorkTaskImportance importance;
  final int progress;

  /// 기한(날짜만) — 없을 수 있다
  final DateTime? dueDate;
  final List<WorkTaskPerson> assignees;
  final WorkTaskPerson createdBy;
  final DateTime? createdAt;
  final DateTime? completedAt;

  /// 관리자·등록한 사람·담당자만 고칠 수 있다(서버가 정해 준다)
  final bool canEdit;

  /// 관리자·등록한 사람만 지울 수 있다
  final bool canDelete;

  const WorkTask({
    required this.id,
    required this.content,
    required this.importance,
    required this.progress,
    required this.assignees,
    required this.createdBy,
    this.dueDate,
    this.createdAt,
    this.completedAt,
    this.canEdit = false,
    this.canDelete = false,
  });

  factory WorkTask.fromJson(Map<String, dynamic> json) {
    final rawProgress = json['progress'];
    final progress = rawProgress is num
        ? rawProgress.toInt()
        : int.tryParse(rawProgress?.toString() ?? '') ?? 0;
    return WorkTask(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      content: json['content']?.toString() ?? '',
      importance: WorkTaskImportance.fromCode(json['importance']?.toString()),
      progress: progress.clamp(0, 100),
      dueDate: parseWorkTaskDate(json['dueDate']),
      assignees: (json['assignees'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WorkTaskPerson.fromJson)
          .toList(),
      createdBy: json['createdBy'] is Map<String, dynamic>
          ? WorkTaskPerson.fromJson(json['createdBy'] as Map<String, dynamic>)
          : const WorkTaskPerson(id: ''),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? ''),
      canEdit: json['canEdit'] == true,
      canDelete: json['canDelete'] == true,
    );
  }

  bool get isDone => completedAt != null || progress >= 100;
}

/// 'yyyy-MM-dd' → 그날 0시(시간대에 흔들리지 않게 날짜만 쓴다)
DateTime? parseWorkTaskDate(Object? raw) {
  final text = raw?.toString() ?? '';
  if (text.length < 10) return null;
  final parsed = DateTime.tryParse(text.substring(0, 10));
  return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
}

/// 서버로 보낼 'yyyy-MM-dd'
String formatWorkTaskDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// 등록·수정 요청 — 담당자가 비면 서버가 등록한 사람 자신으로 정한다
class WorkTaskInput {
  final String content;
  final WorkTaskImportance importance;
  final int progress;
  final DateTime? dueDate;
  final List<String> assigneeIds;

  const WorkTaskInput({
    required this.content,
    required this.importance,
    required this.progress,
    required this.assigneeIds,
    this.dueDate,
  });

  factory WorkTaskInput.of(WorkTask task) => WorkTaskInput(
    content: task.content,
    importance: task.importance,
    progress: task.progress,
    dueDate: task.dueDate,
    assigneeIds: task.assignees.map((a) => a.id).toList(),
  );

  Map<String, dynamic> toJson() => {
    'content': content.trim(),
    'importance': importance.code,
    'progress': snapWorkTaskProgress(progress),
    'dueDate': dueDate == null ? null : formatWorkTaskDate(dueDate!),
    'assigneeIds': assigneeIds,
  };
}

/// 수행도를 0~100, 10% 단위로 맞춘다
int snapWorkTaskProgress(num value) {
  final clamped = value.clamp(0, 100);
  return ((clamped / workTaskProgressStep).round() * workTaskProgressStep)
      .toInt();
}

/// 진행 중·끝낸 것으로 나눈다 — 서버가 준 순서는 그대로 둔다
({List<WorkTask> inProgress, List<WorkTask> done}) splitWorkTasks(
  List<WorkTask> tasks,
) => (
  inProgress: tasks.where((t) => !t.isDone).toList(),
  done: tasks.where((t) => t.isDone).toList(),
);

enum WorkTaskDueTone { overdue, soon, normal }

/// 목록 한 줄에 붙이는 기한 — 지난 것 "10/20 지남", 오늘 "오늘까지", 내일 "내일까지",
/// 사흘 안 "D-3", 나머지 "10/31". 끝낸 업무에는 붙이지 않는다.
({String text, WorkTaskDueTone tone})? workTaskDueLabel(
  DateTime? due,
  DateTime today,
) {
  if (due == null) return null;
  final from = DateTime.utc(today.year, today.month, today.day);
  final to = DateTime.utc(due.year, due.month, due.day);
  final days = to.difference(from).inDays;
  if (days < 0) {
    return (text: '${due.month}/${due.day} 지남', tone: WorkTaskDueTone.overdue);
  }
  if (days == 0) return (text: '오늘까지', tone: WorkTaskDueTone.overdue);
  if (days == 1) return (text: '내일까지', tone: WorkTaskDueTone.soon);
  if (days <= 3) return (text: 'D-$days', tone: WorkTaskDueTone.soon);
  return (text: '${due.month}/${due.day}', tone: WorkTaskDueTone.normal);
}

/// "박소향", "박소향 외 2"
String workTaskAssigneeLabel(List<WorkTaskPerson> assignees) {
  final names = assignees
      .map((a) => a.name?.trim() ?? '')
      .where((n) => n.isNotEmpty)
      .toList();
  if (names.isEmpty) return '담당자 없음';
  return names.length == 1 ? names.first : '${names.first} 외 ${names.length - 1}';
}

/// 내가 맡은 진행 중 업무 수
int myInProgressWorkTaskCount(List<WorkTask> tasks, String? meId) {
  if (meId == null || meId.isEmpty) return 0;
  return tasks
      .where((t) => !t.isDone && t.assignees.any((a) => a.id == meId))
      .length;
}

/// 담당자 후보(결재선 후보 = 관리자까지 포함한 기관 명단)를 채팅 식별자로 —
/// 관리자 3번과 직원 3번은 다른 사람이다
String workTaskPersonIdOf({required String type, required int id}) =>
    type.toUpperCase() == 'ADMIN' ? 'admin_$id' : '$id';
