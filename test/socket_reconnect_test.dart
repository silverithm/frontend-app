import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/services/socket_reconnect.dart';

/// 채팅 소켓 재연결 규칙.
///
/// 운영 로그에서 앱이 만료된 토큰으로 `/ws/chat`을 초당 여섯 번까지 두드리고 있었다
/// (20분에 401을 629번, 한 시간에 4,580번). 사용자에게는 채팅이 실시간으로 오지 않는
/// 상태였고 서버는 계속 맞고 있었다.
void main() {
  group('다시 붙는 간격', () {
    test('처음에는 몇 초만 기다린다 — 신호가 잠깐 나쁜 경우가 대부분이다', () {
      expect(socketRetryDelay(0), firstRetryDelay);
      expect(firstRetryDelay.inSeconds, lessThanOrEqualTo(5));
    });

    test('실패가 이어지면 간격이 늘어난다', () {
      var previous = socketRetryDelay(0);
      for (var attempt = 1; attempt <= 5; attempt++) {
        final current = socketRetryDelay(attempt);
        expect(current, greaterThan(previous), reason: '$attempt번째');
        previous = current;
      }
    });

    test('아무리 오래 실패해도 상한을 넘지 않는다 — 여기서 서버를 두드렸다', () {
      for (final attempt in [6, 10, 50, 1000]) {
        expect(socketRetryDelay(attempt), maxRetryDelay, reason: '$attempt번째');
      }
    });

    test('상한이 터무니없이 길지도 짧지도 않다', () {
      expect(maxRetryDelay.inSeconds, greaterThanOrEqualTo(30));
      expect(maxRetryDelay.inSeconds, lessThanOrEqualTo(300));
    });

    test('한 시간 동안 계속 실패해도 시도 횟수가 백 번을 넘지 않는다', () {
      // 예전에는 5초 고정이라 한 시간에 720번, 그것도 클라이언트가 쌓여 그 몇 배였다
      var elapsed = Duration.zero;
      var attempts = 0;
      while (elapsed.inSeconds < 3600) {
        elapsed += socketRetryDelay(attempts);
        attempts++;
      }
      expect(attempts, lessThan(100));
    });
  });

  group('인증 문제 판별', () {
    test('401·권한 관련 흔적은 인증 문제로 본다 — 토큰을 새로 받아야 한다', () {
      for (final message in [
        'WebSocketException: Connection to ... was not upgraded to websocket',
        'HttpException: 401 Unauthorized',
        'status 403 forbidden',
        'Error: 401',
      ]) {
        expect(looksLikeAuthFailure(message), isTrue, reason: message);
      }
    });

    test('그냥 끊긴 것은 인증 문제로 보지 않는다 — 괜히 토큰을 갈지 않는다', () {
      for (final message in [
        'SocketException: Failed host lookup',
        'Connection closed',
        'timeout',
      ]) {
        expect(looksLikeAuthFailure(message), isFalse, reason: message);
      }
    });

    test('오류가 없으면 인증 문제도 아니다', () {
      expect(looksLikeAuthFailure(null), isFalse);
    });
  });
}
