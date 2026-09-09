/// 채팅 소켓이 끊겼을 때 언제 다시 붙을지.
///
/// **왜 규칙이 필요한가.** 앱이 만료된 토큰으로 소켓에 계속 매달려 있었다. 운영 로그에서
/// `/ws/chat`이 20분에 401을 629번 받았고, 한 시간에 4,580번까지 올라갔다(초당 여섯 번).
/// 원인은 두 가지였다 — ① 붙을 때 읽은 토큰을 그대로 들고 5초마다 영원히 다시 시도했고,
/// ② 실패한 클라이언트를 끄지 않은 채 새 클라이언트를 또 만들어 재시도가 겹겹이 쌓였다.
///
/// 사용자에게는 채팅이 실시간으로 오지 않는 상태였고, 서버는 그동안 계속 두들겨 맞았다.
///
/// 그래서 다시 붙는 간격을 점점 늘리고(2·4·8·16·32·60초), 인증 문제로 실패했으면
/// 토큰부터 새로 받고 붙는다. 세션이 진짜로 끝난 경우(리프레시 토큰 만료)에는 멈춘다.
library;

import 'dart:math' as math;

/// 처음 실패 뒤 기다리는 시간
const Duration firstRetryDelay = Duration(seconds: 2);

/// 아무리 오래 실패해도 이 간격보다 자주 두드리지 않는다
const Duration maxRetryDelay = Duration(seconds: 60);

/// [attempt]번째 재시도까지 기다릴 시간 (0부터 시작).
///
/// 2초에서 시작해 두 배씩 늘리고 60초에서 멈춘다. 신호가 잠깐 나쁜 경우는 몇 초 안에
/// 회복되고, 오래 끊긴 경우에는 서버를 두드리지 않는다.
Duration socketRetryDelay(int attempt) {
  if (attempt <= 0) return firstRetryDelay;
  // 지수를 먼저 자른다. 안 자르면 시도 횟수가 커졌을 때 2의 거듭제곱이 넘쳐
  // 간격이 상한을 지키지 못하고, 0이나 음수가 되면 쉬지 않고 다시 붙는다.
  final capped = math.min(attempt, 16);
  final seconds = firstRetryDelay.inSeconds << capped;
  return Duration(seconds: math.min(seconds, maxRetryDelay.inSeconds));
}

/// 이번 실패가 '인증 문제'로 보이는지.
///
/// 소켓 핸드셰이크가 401로 막히면 패키지마다 문구가 달라 예외 종류로는 가릴 수 없다.
/// 그래서 메시지에 남는 흔적으로 본다 — 틀려도 토큰을 한 번 더 받아올 뿐이라 손해가 없고,
/// 놓치면 만료된 토큰으로 영원히 두드리게 되므로 넉넉하게 잡는다.
bool looksLikeAuthFailure(Object? error) {
  if (error == null) return false;
  final text = error.toString().toLowerCase();
  return text.contains('401')
      || text.contains('unauthorized')
      || text.contains('not upgraded')
      || text.contains('forbidden')
      || text.contains('403');
}
