import 'package:flutter/foundation.dart';

import 'api_service.dart';

/// 회사 구성원 한 사람 — 사진을 찾는 데 필요한 것만.
@immutable
class DirectoryMember {
  final String id;
  final String name;
  final String? email;
  final String? imageUrl;

  /// 시설장(app_user) 계정이면 true — 직원(members)과 id가 겹칠 수 있어 따로 찾는다
  final bool isAdmin;

  const DirectoryMember({
    required this.id,
    required this.name,
    required this.isAdmin,
    this.email,
    this.imageUrl,
  });
}

/// 직원 이름 옆에 그 사람 프로필 사진을 보여주기 위한 회사 구성원 사진첩(2026-11-16 "직원과 관련된
/// 정보에는 그 직원의 프로필 사진을").
///
/// 휴무·일정·결재 응답에는 사진 주소가 없고 사람 번호(직원 id·시설장 id·이메일)와 이름만 온다.
/// 그래서 구성원 목록(`/v1/members?includeAdmins=true`, 직원도 부를 수 있다)을 한 번 받아 두고
/// 번호로 찾는다. 서버의 직원 이름은 암호화돼 있어 이름만으로는 DB에서 맞출 수 없다.
/// 번호가 같아도 이름이 다르면(직원 id와 시설장 id가 겹친 경우) 쓰지 않는다 — 남의 사진이 붙는 것이
/// 사진이 없는 것보다 나쁘다.
///
/// 앱 어디서나 같은 한 벌을 쓴다(싱글턴). 화면은 [ListenableBuilder]로 듣는다.
class MemberDirectory extends ChangeNotifier {
  MemberDirectory._();

  static final MemberDirectory instance = MemberDirectory._();

  /// 사진을 바꾼 사람이 있어도 이만큼 지나면 다시 받는다
  static const Duration maxAge = Duration(minutes: 30);

  String? _companyId;
  DateTime? _loadedAt;
  Future<void>? _loading;

  final Map<String, DirectoryMember> _members = {};
  final Map<String, DirectoryMember> _admins = {};
  final Map<String, DirectoryMember> _byEmail = {};
  final Map<String, List<DirectoryMember>> _byName = {};

  bool get isLoaded => _loadedAt != null;

  /// 회사가 바뀌었거나 오래됐으면 받는다. 이미 받는 중이면 그 결과를 기다린다.
  Future<void> ensureLoaded(String companyId, {bool force = false}) {
    final fresh =
        _companyId == companyId &&
        _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < maxAge;
    if (fresh && !force) return Future.value();
    return _loading ??= _load(companyId).whenComplete(() => _loading = null);
  }

  Future<void> _load(String companyId) async {
    try {
      final response = await ApiService().getCompanyMembers(
        companyId: companyId,
        includeAdmins: true,
      );
      final list = response['members'];
      if (list is! List) return;
      replaceAll(companyId, [
        for (final raw in list)
          if (raw is Map) _fromJson(Map<String, dynamic>.from(raw)),
      ]);
    } catch (e) {
      // 사진이 없으면 이름 첫 글자로 보이니 화면은 그대로 쓸 수 있다 — 다음에 다시 받는다
      debugPrint('[MemberDirectory] 구성원 사진 목록을 받지 못함: $e');
    }
  }

  static DirectoryMember _fromJson(Map<String, dynamic> json) {
    String? text(Object? v) {
      final s = v?.toString().trim();
      return s == null || s.isEmpty ? null : s;
    }

    return DirectoryMember(
      id: json['id']?.toString() ?? '',
      name: text(json['name']) ?? text(json['username']) ?? '',
      email: text(json['email']),
      imageUrl: text(json['profileImageUrl']),
      isAdmin: json['role']?.toString() == 'facility_admin',
    );
  }

  /// 목록을 통째로 바꾼다 — 받아 온 결과와 테스트가 쓴다.
  @visibleForTesting
  void replaceAll(String companyId, List<DirectoryMember> people) {
    _members.clear();
    _admins.clear();
    _byEmail.clear();
    _byName.clear();
    for (final p in people) {
      if (p.id.isEmpty) continue;
      (p.isAdmin ? _admins : _members)[p.id] = p;
      if (p.email != null) _byEmail[p.email!.toLowerCase()] = p;
      if (p.name.isNotEmpty) (_byName[_norm(p.name)] ??= []).add(p);
    }
    _companyId = companyId;
    _loadedAt = DateTime.now();
    notifyListeners();
  }

  /// 로그아웃·회사 전환 때 비운다
  void clear() {
    _members.clear();
    _admins.clear();
    _byEmail.clear();
    _byName.clear();
    _companyId = null;
    _loadedAt = null;
    notifyListeners();
  }

  static String _norm(String name) => name.replaceAll(RegExp(r'\s+'), '');

  /// 사람 찾기 — 아는 것을 다 넘긴다. 순서: 직원 번호 → 시설장 번호 → 이메일 → 이름(회사에 한 명뿐일 때).
  /// [name]을 같이 넘기면 번호로 찾은 사람의 이름이 다를 때 버린다(번호가 겹친 남의 사진 방지).
  DirectoryMember? find({
    String? memberId,
    String? adminId,
    String? email,
    String? name,
  }) {
    final wanted = name == null ? null : _norm(name);
    bool sameName(DirectoryMember p) =>
        wanted == null || wanted.isEmpty || _norm(p.name) == wanted;

    final byMember = memberId == null ? null : _members[memberId.trim()];
    if (byMember != null && sameName(byMember)) return byMember;
    // 휴무처럼 사람 번호가 직원인지 시설장인지 모르고 오는 곳 — 이름이 맞는 시설장이면 그 사람
    final byAdmin = _admins[(adminId ?? memberId)?.trim()];
    if (byAdmin != null &&
        (adminId != null || wanted != null) &&
        sameName(byAdmin)) {
      return byAdmin;
    }
    final byEmail = email == null ? null : _byEmail[email.trim().toLowerCase()];
    if (byEmail != null && sameName(byEmail)) return byEmail;
    if (wanted != null && wanted.isNotEmpty) {
      final same = _byName[wanted];
      if (same != null && same.length == 1) return same.first;
    }
    return null;
  }

  String? photoFor({
    String? memberId,
    String? adminId,
    String? email,
    String? name,
  }) => find(
    memberId: memberId,
    adminId: adminId,
    email: email,
    name: name,
  )?.imageUrl;
}
