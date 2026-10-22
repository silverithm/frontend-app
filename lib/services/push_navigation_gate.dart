/// 알림을 눌러 들어온 이동을 **앱이 받을 준비가 될 때까지** 붙잡아 둔다.
///
/// 꺼져 있던 앱을 알림으로 켜면 탭 신호(getInitialMessage)가 로그인 복원보다 먼저 온다.
/// 예전에는 네비게이터만 생기면 바로 화면을 띄웠다. 그러면 사용자 정보가 아직 없어 채팅방 목록이
/// 비어 있었고, 그 방을 못 찾아 목록에서 멈췄다(2026-10-22 "채팅 알림을 누르면 그 방이 아니라
/// 채팅 목록으로 간다"). 결재·일정도 같은 이유로 빈 화면이 떴다.
/// 이제는 로그인된 메인 화면이 [open]을 부른 뒤에야 이동한다.
///
/// 메인 화면이 겹쳐 떠 있는 순간(다시 로그인 등)이 있어 열림을 횟수로 센다.
/// 새 화면의 [open]이 옛 화면의 [close]보다 먼저 불려도 닫히지 않는다.
class PushNavigationGate {
  PushNavigationGate(
    this._navigate, {
    DateTime Function()? now,
    this.maxPendingAge = const Duration(minutes: 10),
  }) : _now = now ?? DateTime.now;

  final void Function(Map<String, dynamic> data) _navigate;
  final DateTime Function() _now;

  /// 이보다 오래 붙잡혀 있던 이동은 버린다 — 알림을 누르고 로그인 화면에 한참 머물다
  /// 들어왔는데 엉뚱하게 옛 대화방이 열리면 안 된다.
  final Duration maxPendingAge;

  int _openCount = 0;
  Map<String, dynamic>? _pending;
  DateTime? _pendingAt;

  bool get isOpen => _openCount > 0;

  /// 아직 못 간 이동(테스트·로그용)
  Map<String, dynamic>? get pending => _pending;

  /// 알림 탭 하나. 준비됐으면 바로 가고, 아니면 가장 최근 것 하나만 붙잡아 둔다.
  void handle(Map<String, dynamic> data) {
    if (isOpen) {
      _navigate(data);
      return;
    }
    _pending = Map<String, dynamic>.from(data);
    _pendingAt = _now();
  }

  /// 로그인된 메인 화면이 떴다 — 붙잡아 둔 이동이 있으면 지금 간다.
  void open() {
    _openCount++;
    final pending = _pending;
    final at = _pendingAt;
    _pending = null;
    _pendingAt = null;
    if (pending == null || at == null) return;
    if (_now().difference(at) > maxPendingAge) return;
    _navigate(pending);
  }

  /// 메인 화면이 내려갔다(로그아웃 등).
  void close() {
    if (_openCount > 0) _openCount--;
  }
}
