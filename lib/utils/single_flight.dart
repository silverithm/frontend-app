/// 같은 작업이 동시에 여러 번 불리면 하나만 실제로 돌리고, 나머지는 그 결과를 함께 기다린다.
///
/// 토큰 갱신에 쓴다. 앱이 백그라운드에서 돌아오면 결재·채팅·알림 요청이 한꺼번에 나가서 만료된
/// 토큰으로 동시에 401을 받는데, 각 요청이 따로 갱신을 부르면 같은 초에 갱신이 5~17번 겹쳤다
/// (운영 nginx 2026-10-10~13, 3일간 갱신 1,880번). 한 번만 갱신하고 모두 그 토큰으로 재시도한다.
class SingleFlight<T> {
  Future<T>? _inFlight;

  /// 지금 돌고 있는 작업이 있으면 그 결과를, 없으면 [task]를 새로 돌린 결과를 돌려준다.
  /// 작업이 끝나면(성공·실패 모두) 비워서 다음 호출은 새로 돌린다.
  Future<T> run(Future<T> Function() task) async {
    final existing = _inFlight;
    if (existing != null) return existing;

    final future = task();
    _inFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight, future)) _inFlight = null;
    }
  }

  bool get isRunning => _inFlight != null;
}
