/// 역할(직책) 표기 유틸.
///
/// 서버는 관리자 화면에서 만든 역할(Position) 이름을 그대로 내려주되,
/// '요양보호사'/'사무직'처럼 예전 분류에 해당하는 이름은 caregiver/office로 정규화해서 준다.
/// (백엔드 VacationRequest.normalizeRole과 같은 규칙)
/// 앱에서도 같은 규칙으로 맞춰야 역할이 두 개로 갈라져 보이지 않는다.
class RoleUtils {
  static const String allRole = 'all';

  static const Map<String, String> _aliases = {
    'CAREGIVER': 'caregiver',
    'ROLE_CAREGIVER': 'caregiver',
    '요양보호사': 'caregiver',
    'OFFICE': 'office',
    'ROLE_OFFICE': 'office',
    '사무직': 'office',
    '사무실': 'office',
    'ADMIN': 'admin',
    'ROLE_ADMIN': 'admin',
    '관리자': 'admin',
    'EMPLOYEE': 'employee',
    'ROLE_EMPLOYEE': 'employee',
    'ALL': allRole,
  };

  static const Map<String, String> _labels = {
    'caregiver': '요양보호사',
    'office': '사무직',
    'admin': '관리자',
    'employee': '직원',
  };

  /// 서버/로컬에 섞여 있는 역할 표기를 하나의 키로 모은다.
  static String normalize(String? role) {
    final trimmedRole = role?.trim() ?? '';
    if (trimmedRole.isEmpty) {
      return '';
    }

    return _aliases[trimmedRole.toUpperCase()] ?? trimmedRole;
  }

  /// 화면에 보여줄 역할 이름. 관리자가 직접 만든 역할은 이름 그대로 쓴다.
  static String displayName(String? role) {
    final normalizedRole = normalize(role);
    if (normalizedRole.isEmpty) {
      return '직원';
    }

    return _labels[normalizedRole] ?? normalizedRole;
  }

  static bool matches(String? role, String? filter) {
    final normalizedFilter = normalize(filter);
    if (normalizedFilter.isEmpty || normalizedFilter == allRole) {
      return true;
    }

    return normalize(role) == normalizedFilter;
  }
}
