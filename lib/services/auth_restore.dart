/// 앱을 켰을 때 저장된 로그인을 어떻게 할지 정하는 규칙.
///
/// 화면·네트워크와 떨어져 있어 그대로 단위 테스트할 수 있다. 규칙이 코드 흐름 속에
/// 흩어져 있으면 "서버를 잠깐 못 만난 것"과 "토큰이 무효인 것"이 뒤섞이고,
/// 그 결과가 **까닭 없는 로그아웃**이다. 실제로 그 제보가 반복해서 올라왔다
/// ("자동로그인이 안되는 경우가 아직 발생함").
library;

/// 저장된 토큰을 서버에 물어본 결과.
enum TokenCheck {
  /// 서버가 유효하다고 답했다 (200)
  valid,

  /// 서버가 무효라고 답했다 (400) — 다시 로그인하거나 갱신해야 한다
  invalid,

  /// **답을 못 들었다** — 네트워크 끊김, 시간 초과, 서버 5xx, 배포 중 전환 등.
  /// 토큰이 무효라는 증거가 아니다. 이걸 무효로 취급하면 신호가 잠깐 나빴다는
  /// 이유만으로 로그인 화면을 만난다.
  unavailable,
}

/// 리프레시 토큰으로 갱신을 시도한 결과.
enum RefreshOutcome {
  /// 새 토큰을 받았다
  success,

  /// 리프레시 토큰이 만료됐거나 아예 없다 — 진짜로 다시 로그인해야 한다
  expired,

  /// 갱신 요청 자체가 실패했다 (네트워크·서버 오류). 세션은 멀쩡할 수 있다
  unavailable,
}

/// 저장된 로그인을 어떻게 할지.
enum AuthRestore {
  /// 검증된 세션으로 들어간다
  proceed,

  /// 확인은 못 했지만 저장된 정보로 들어간다 — 토큰은 다음 요청이 다시 갱신한다
  keepSaved,

  /// 저장된 것을 지우고 로그인 화면으로 보낸다
  logout,
}

/// 앱 시작 시 인증 복원 판단.
///
/// [check]는 첫 검증 결과, [refresh]는 첫 검증이 무효였을 때의 갱신 결과,
/// [recheck]는 갱신이 성공한 뒤의 재검증 결과다. 아직 시도하지 않은 단계는 null이다.
///
/// **로그아웃은 서버가 "무효"라고 분명히 답했을 때만 한다.**
AuthRestore resolveAuthRestore({
  required TokenCheck check,
  RefreshOutcome? refresh,
  TokenCheck? recheck,
}) {
  switch (check) {
    case TokenCheck.valid:
      return AuthRestore.proceed;

    case TokenCheck.unavailable:
      // 서버를 못 만났다. 토큰이 무효라는 증거가 없으므로 세션을 지우지 않는다.
      return AuthRestore.keepSaved;

    case TokenCheck.invalid:
      switch (refresh) {
        case null:
          // 무효인데 갱신을 시도하지 않았다면 판단할 근거가 없다 — 호출자의 실수다
          throw ArgumentError('토큰이 무효면 갱신 결과가 있어야 한다');
        case RefreshOutcome.expired:
          return AuthRestore.logout;
        case RefreshOutcome.unavailable:
          // 갱신 요청이 서버에 닿지도 못했다. 리프레시 토큰이 죽었다는 증거가 아니다.
          return AuthRestore.keepSaved;
        case RefreshOutcome.success:
          switch (recheck) {
            case null:
              throw ArgumentError('갱신에 성공했으면 재검증 결과가 있어야 한다');
            case TokenCheck.valid:
              return AuthRestore.proceed;
            case TokenCheck.invalid:
              // 새로 받은 토큰마저 무효다 — 이건 진짜 문제다
              return AuthRestore.logout;
            case TokenCheck.unavailable:
              // 갱신은 됐는데 재검증만 못 했다. 예전에는 여기서 로그아웃시켰다.
              return AuthRestore.keepSaved;
          }
      }
  }
}
