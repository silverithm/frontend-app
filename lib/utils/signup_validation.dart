/// 가입 화면 입력 검증. 웹(frontend-admin `src/app/signup/page.tsx`)과 같은 기준이다.
///
/// 앱에서만 더 까다로우면 정상적인 사용자가 앱에서만 거부된다.
/// 실제로 그랬던 것들:
///   - 이메일 TLD를 2~4자로 묶어 `.online` `.center` 기관 메일이 앱에서만 반려됐다.
///   - 이름·회사명에 2자 이상을 강요해 외자 이름이 앱에서만 반려됐다.
/// 그래서 여기 규칙을 웹보다 좁히지 않는다. 넓히려면 웹도 같이 고쳐야 한다.
class SignupValidation {
  /// 웹 signup/page.tsx의 isValidEmail과 같은 정규식.
  /// TLD 길이를 제한하지 않는다 — 실제 도메인이 훨씬 다양하고, 최종 판정은 서버가 한다.
  static final RegExp emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static bool isValidEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return false;
    return emailPattern.hasMatch(email);
  }

  /// 이메일 입력 검증. 통과하면 null.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '이메일을 입력해주세요';
    }
    if (!isValidEmail(value)) {
      return '올바른 이메일 형식을 입력해주세요';
    }
    return null;
  }

  /// 이름 검증 — 웹과 같이 '비어 있지 않을 것'만 본다 (외자 이름 허용).
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '이름을 입력해주세요';
    }
    return null;
  }

  /// 회사명 검증 — 이름과 같은 기준.
  static String? validateCompanyName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '회사명을 입력해주세요';
    }
    return null;
  }

  /// 전화번호는 선택 입력(웹과 동일) — 비어 있으면 통과.
  /// 적은 경우에만 숫자 9~11자리인지 본다(하이픈·공백은 무시).
  static String? validatePhoneNumber(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return null;

    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 9 || digits.length > 11) {
      return '올바른 전화번호를 입력해주세요';
    }
    return null;
  }
}
