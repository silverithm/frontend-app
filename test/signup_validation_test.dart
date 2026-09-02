import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/utils/signup_validation.dart';

/// 앱 가입 검증이 웹(frontend-admin signup/page.tsx)보다 좁아지지 않게 못박는다.
/// 여기서 통과하던 입력이 다시 거부되기 시작하면 정상적인 사용자가 앱에서만 가입에 실패한다.
void main() {
  group('이메일 — 웹과 같은 기준', () {
    test('긴 TLD를 거부하지 않는다 (.online / .center 등)', () {
      // 앱에만 있던 TLD 2~4자 제한 때문에 기관 메일이 반려됐던 사례
      expect(SignupValidation.validateEmail('center@carev.online'), isNull);
      expect(SignupValidation.validateEmail('a@b.center'), isNull);
      expect(SignupValidation.validateEmail('a@b.technology'), isNull);
    });

    test('흔한 형식은 모두 통과한다', () {
      expect(SignupValidation.validateEmail('hong@example.com'), isNull);
      expect(SignupValidation.validateEmail('hong.gil-dong@sub.example.co.kr'), isNull);
      expect(SignupValidation.validateEmail('  hong@example.com  '), isNull);
    });

    test('형식이 아닌 것은 거부한다', () {
      expect(SignupValidation.validateEmail(''), isNotNull);
      expect(SignupValidation.validateEmail(null), isNotNull);
      expect(SignupValidation.validateEmail('hong'), isNotNull);
      expect(SignupValidation.validateEmail('hong@example'), isNotNull);
      expect(SignupValidation.validateEmail('hong example@a.com'), isNotNull);
    });
  });

  group('이름·회사명 — 길이를 강요하지 않는다', () {
    test('외자 이름이 통과한다', () {
      // 앱에만 있던 '2자 이상' 규칙 때문에 외자 이름이 반려됐던 사례
      expect(SignupValidation.validateName('김'), isNull);
      expect(SignupValidation.validateName('이'), isNull);
    });

    test('한 글자 회사명도 통과한다', () {
      expect(SignupValidation.validateCompanyName('솔'), isNull);
    });

    test('비어 있으면 거부한다', () {
      expect(SignupValidation.validateName(''), isNotNull);
      expect(SignupValidation.validateName('   '), isNotNull);
      expect(SignupValidation.validateCompanyName(null), isNotNull);
    });
  });

  group('전화번호 — 선택 입력', () {
    test('비워두면 통과한다', () {
      expect(SignupValidation.validatePhoneNumber(''), isNull);
      expect(SignupValidation.validatePhoneNumber(null), isNull);
      expect(SignupValidation.validatePhoneNumber('   '), isNull);
    });

    test('하이픈이 있든 없든 통과한다', () {
      expect(SignupValidation.validatePhoneNumber('010-1234-5678'), isNull);
      expect(SignupValidation.validatePhoneNumber('01012345678'), isNull);
      expect(SignupValidation.validatePhoneNumber('02-123-4567'), isNull);
    });

    test('자릿수가 말이 안 되면 거부한다', () {
      expect(SignupValidation.validatePhoneNumber('123'), isNotNull);
      expect(SignupValidation.validatePhoneNumber('0101234567890'), isNotNull);
    });
  });
}
