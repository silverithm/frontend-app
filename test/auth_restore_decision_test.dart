import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/services/auth_restore.dart';

/// 앱을 켤 때 저장된 로그인을 언제 지우는지에 대한 규칙.
///
/// "자동로그인이 안되는 경우가 아직 발생함" 제보의 정체는 여기였다 —
/// 서버를 잠깐 못 만난 것을 토큰이 무효인 것과 똑같이 취급해 세션을 지웠다.
/// **로그아웃은 서버가 분명히 "무효"라고 답했을 때만 한다.**
void main() {
  group('서버가 답을 준 경우', () {
    test('유효하면 그대로 들어간다', () {
      expect(
        resolveAuthRestore(check: TokenCheck.valid),
        AuthRestore.proceed,
      );
    });

    test('무효 + 리프레시 토큰도 만료 → 로그아웃 (진짜 다시 로그인해야 한다)', () {
      expect(
        resolveAuthRestore(
          check: TokenCheck.invalid,
          refresh: RefreshOutcome.expired,
        ),
        AuthRestore.logout,
      );
    });

    test('무효 + 갱신 성공 + 재검증도 유효 → 들어간다', () {
      expect(
        resolveAuthRestore(
          check: TokenCheck.invalid,
          refresh: RefreshOutcome.success,
          recheck: TokenCheck.valid,
        ),
        AuthRestore.proceed,
      );
    });

    test('무효 + 갱신 성공 + 새 토큰마저 무효 → 로그아웃', () {
      expect(
        resolveAuthRestore(
          check: TokenCheck.invalid,
          refresh: RefreshOutcome.success,
          recheck: TokenCheck.invalid,
        ),
        AuthRestore.logout,
      );
    });
  });

  group('서버를 못 만난 경우 — 로그아웃하지 않는다', () {
    test('첫 검증부터 답을 못 들으면 저장된 로그인을 유지한다', () {
      expect(
        resolveAuthRestore(check: TokenCheck.unavailable),
        AuthRestore.keepSaved,
      );
    });

    test('갱신 요청이 서버에 닿지 못하면 저장된 로그인을 유지한다', () {
      expect(
        resolveAuthRestore(
          check: TokenCheck.invalid,
          refresh: RefreshOutcome.unavailable,
        ),
        AuthRestore.keepSaved,
      );
    });

    test('갱신은 됐는데 재검증만 못 하면 저장된 로그인을 유지한다 — 예전엔 여기서 로그아웃시켰다', () {
      expect(
        resolveAuthRestore(
          check: TokenCheck.invalid,
          refresh: RefreshOutcome.success,
          recheck: TokenCheck.unavailable,
        ),
        AuthRestore.keepSaved,
      );
    });

    test('어떤 경우에도 "확인 못 함"만으로는 로그아웃이 나오지 않는다', () {
      final casesWithUnavailable = <AuthRestore>[
        resolveAuthRestore(check: TokenCheck.unavailable),
        resolveAuthRestore(
          check: TokenCheck.invalid,
          refresh: RefreshOutcome.unavailable,
        ),
        resolveAuthRestore(
          check: TokenCheck.invalid,
          refresh: RefreshOutcome.success,
          recheck: TokenCheck.unavailable,
        ),
      ];
      expect(casesWithUnavailable, everyElement(isNot(AuthRestore.logout)));
    });
  });

  group('호출자가 단계를 빠뜨리면 조용히 넘어가지 않는다', () {
    test('무효인데 갱신 결과가 없으면 예외', () {
      expect(
        () => resolveAuthRestore(check: TokenCheck.invalid),
        throwsArgumentError,
      );
    });

    test('갱신에 성공했는데 재검증 결과가 없으면 예외', () {
      expect(
        () => resolveAuthRestore(
          check: TokenCheck.invalid,
          refresh: RefreshOutcome.success,
        ),
        throwsArgumentError,
      );
    });
  });
}
