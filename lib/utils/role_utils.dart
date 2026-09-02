import '../models/position_option.dart';

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

  /// 화면에 세울 역할 탭 목록을 만든다. 웹(roleUtils.buildRoleNames)과 같은 규칙:
  /// 1) 기관이 등록한 직책을 sortOrder → 이름 순으로 먼저 세우고
  /// 2) 이미 저장된 한도에만 남아 있는 역할을 뒤에 잇는다.
  /// '전체(all)'는 직종이 아니라 날짜 총인원 제한이라 목록에 섞지 않고,
  /// 관리자(admin)도 휴무 한도 대상이 아니라 기본적으로 뺀다.
  /// 어느 쪽에서도 역할을 못 찾으면 예전 두 분류로 되돌린다.
  static List<String> buildRoleNames({
    List<PositionOption> positions = const [],
    Iterable<String?> extraRoles = const [],
    bool includeAdmin = false,
    bool includeLegacyFallback = true,
  }) {
    final roleNames = <String>[];
    final seen = <String>{};

    void add(String? role) {
      final normalizedRole = normalize(role);
      if (normalizedRole.isEmpty || seen.contains(normalizedRole)) {
        return;
      }
      if (normalizedRole.toLowerCase() == allRole) {
        return;
      }
      if (!includeAdmin && normalizedRole == 'admin') {
        return;
      }
      seen.add(normalizedRole);
      roleNames.add(normalizedRole);
    }

    final sortedPositions = positions.toList()
      ..sort((a, b) {
        final orderA = a.sortOrder ?? 1 << 30;
        final orderB = b.sortOrder ?? 1 << 30;
        if (orderA != orderB) {
          return orderA.compareTo(orderB);
        }
        return a.name.compareTo(b.name);
      });

    for (final position in sortedPositions) {
      add(position.name);
    }

    for (final role in extraRoles) {
      add(role);
    }

    if (includeLegacyFallback && roleNames.isEmpty) {
      add('caregiver');
      add('office');
    }

    return roleNames;
  }

  static bool matches(String? role, String? filter) {
    final normalizedFilter = normalize(filter);
    if (normalizedFilter.isEmpty || normalizedFilter == allRole) {
      return true;
    }

    return normalize(role) == normalizedFilter;
  }
}
