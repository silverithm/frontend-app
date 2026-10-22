import 'package:flutter/foundation.dart';

import '../models/work_task.dart';
import '../services/api_service.dart';

enum WorkTaskLoadStatus { idle, loading, loaded, error }

/// 저장·삭제가 실패했을 때 화면에 그대로 보여줄 문구를 담는다
class WorkTaskException implements Exception {
  final String message;
  const WorkTaskException(this.message);

  @override
  String toString() => message;
}

/// 담당자로 고를 수 있는 사람 — id는 채팅 식별자(직원 "12", 관리자 "admin_3")
class WorkTaskCandidate {
  final String id;
  final String name;
  final String? position;

  const WorkTaskCandidate({
    required this.id,
    required this.name,
    this.position,
  });
}

/// 업무진행도 목록 — 기관 전체가 같은 목록을 본다(웹 대시보드 오른쪽 패널과 같다).
///
/// 순서는 서버가 정한다(진행 중: 중요 → 기한 → 등록순, 그 아래 최근 끝낸 것).
/// 그래서 저장·수행도·삭제 뒤에는 목록을 새로 받아 순서를 서버와 맞춘다.
class WorkTaskProvider extends ChangeNotifier {
  WorkTaskProvider({ApiService? apiService})
    : _api = apiService ?? ApiService();

  final ApiService _api;

  List<WorkTask> _tasks = const [];
  WorkTaskLoadStatus _status = WorkTaskLoadStatus.idle;

  List<WorkTask> get tasks => _tasks;
  WorkTaskLoadStatus get status => _status;
  bool get hasLoaded => _status == WorkTaskLoadStatus.loaded;

  List<WorkTask> get inProgress => splitWorkTasks(_tasks).inProgress;
  List<WorkTask> get done => splitWorkTasks(_tasks).done;

  WorkTask? byId(int id) {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  int myInProgressCount(String? meId) => myInProgressWorkTaskCount(_tasks, meId);

  /// 목록을 받는다. 이미 받아 둔 목록이 있으면 실패해도 그대로 둔다 —
  /// 잠깐 신호가 끊겼다고 보던 목록을 지우지 않는다.
  Future<void> load() async {
    if (_status != WorkTaskLoadStatus.loaded) {
      _status = WorkTaskLoadStatus.loading;
      notifyListeners();
    }
    try {
      final response = await _api.getWorkTasks();
      _tasks = _parseList(response);
      _status = WorkTaskLoadStatus.loaded;
    } catch (e) {
      debugPrint('[WorkTaskProvider] 목록을 받지 못했습니다: $e');
      if (_status != WorkTaskLoadStatus.loaded) {
        _status = WorkTaskLoadStatus.error;
      }
    }
    notifyListeners();
  }

  Future<WorkTask> create(WorkTaskInput input) => _save(
    () => _api.createWorkTask(input.toJson()),
    fallback: '업무를 등록하지 못했습니다',
  );

  Future<WorkTask> update(int id, WorkTaskInput input) => _save(
    () => _api.updateWorkTask(id, input.toJson()),
    fallback: '업무를 저장하지 못했습니다',
  );

  /// 목록에서 바로 수행도만 올린다(10% 단위로 맞춘다)
  Future<WorkTask> updateProgress(int id, int progress) => _save(
    () => _api.updateWorkTaskProgress(id, snapWorkTaskProgress(progress)),
    fallback: '수행도를 바꾸지 못했습니다',
  );

  Future<void> delete(int id) async {
    try {
      await _api.deleteWorkTask(id);
    } catch (e) {
      throw WorkTaskException(_messageOf(e, '업무를 지우지 못했습니다'));
    }
    _tasks = _tasks.where((t) => t.id != id).toList();
    notifyListeners();
    await load();
  }

  List<WorkTaskCandidate>? _people;
  String? _peopleCompanyId;

  /// 담당자 후보 — 결재선 후보 명단을 쓴다(관리자까지 들어 있는 가장 온전한 명단, 웹과 같다).
  /// 자주 바뀌지 않아 기관마다 한 번 받아 둔다.
  Future<List<WorkTaskCandidate>> loadPeople(String companyId) async {
    final cached = _people;
    if (cached != null && _peopleCompanyId == companyId) return cached;
    final response = await _api.getApproverCandidates(companyId: companyId);
    final raw = response['candidates'];
    final seen = <String>{};
    final people = <WorkTaskCandidate>[];
    for (final item in raw is List ? raw : const []) {
      if (item is! Map) continue;
      final rawId = item['approverId'];
      final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
      if (id == null) continue;
      final personId = workTaskPersonIdOf(
        type: item['approverType']?.toString() ?? 'MEMBER',
        id: id,
      );
      if (!seen.add(personId)) continue;
      final position = item['position']?.toString().trim();
      people.add(
        WorkTaskCandidate(
          id: personId,
          name: item['name']?.toString() ?? '',
          position: position == null || position.isEmpty ? null : position,
        ),
      );
    }
    _people = people;
    _peopleCompanyId = companyId;
    return people;
  }

  /// 로그아웃 — 다른 기관 계정으로 들어왔을 때 옛 목록이 비치지 않게
  void clear() {
    _tasks = const [];
    _status = WorkTaskLoadStatus.idle;
    _people = null;
    _peopleCompanyId = null;
    notifyListeners();
  }

  Future<WorkTask> _save(
    Future<Map<String, dynamic>> Function() request, {
    required String fallback,
  }) async {
    final WorkTask saved;
    try {
      saved = WorkTask.fromJson(await request());
    } catch (e) {
      throw WorkTaskException(_messageOf(e, fallback));
    }
    // 화면이 바로 바뀌게 먼저 끼워 두고, 순서는 새로 받은 목록으로 맞춘다
    final index = _tasks.indexWhere((t) => t.id == saved.id);
    _tasks = index < 0
        ? [saved, ..._tasks]
        : ([..._tasks]..[index] = saved);
    notifyListeners();
    await load();
    return saved;
  }

  static List<WorkTask> _parseList(Map<String, dynamic> response) {
    final raw = response['tasks'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(WorkTask.fromJson)
        .toList();
  }

  static String _messageOf(Object error, String fallback) {
    if (error is ApiException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    return fallback;
  }
}
