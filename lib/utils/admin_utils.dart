import '../models/user.dart';

class AdminUtils {
  /// 사용자가 관리자인지 확인
  static bool isAdmin(User? user) {
    return user?.role == 'admin' || user?.role == 'ADMIN' || user?.role == 'ROLE_ADMIN';
  }

  /// 사용자가 활성 관리자인지 확인
  static bool isActiveAdmin(User? user) {
    return isAdmin(user) && user?.isActive == true && user?.status == 'active';
  }

  /// 관리자 권한이 있는지 확인
  static bool hasAdminPermission(User? user) {
    return isActiveAdmin(user) && user?.company != null;
  }

  /// 사용자 역할에 따른 한국어 표시명 반환
  static String getRoleDisplayName(String role) {
    switch (role) {
      case 'admin':
        return '관리자';
      case 'CAREGIVER':
        return '요양보호사';
      case 'OFFICE':
        return '사무실';
      default:
        return '직원';
    }
  }

  /// 사용자 상태에 따른 한국어 표시명 반환
  static String getStatusDisplayName(String status) {
    switch (status) {
      case 'active':
        return '활성';
      case 'inactive':
        return '비활성';
      case 'pending':
        return '승인 대기';
      case 'rejected':
        return '거부됨';
      default:
        return '알 수 없음';
    }
  }

  /// 관리자 전용 페이지 접근 권한 확인
  static bool canAccessAdminPages(User? user) {
    print('[AdminUtils] canAccessAdminPages 호출');
    print('[AdminUtils] - user: ${user?.name}');
    print('[AdminUtils] - role: ${user?.role}');
    print('[AdminUtils] - isActive: ${user?.isActive}');
    print('[AdminUtils] - status: ${user?.status}');
    print('[AdminUtils] - company: ${user?.company?.name}');
    print('[AdminUtils] - isAdmin: ${isAdmin(user)}');
    print('[AdminUtils] - isActiveAdmin: ${isActiveAdmin(user)}');
    print('[AdminUtils] - hasAdminPermission: ${hasAdminPermission(user)}');
    
    final result = hasAdminPermission(user);
    print('[AdminUtils] - 최종 결과: $result');
    return result;
  }

  /// 사용자 관리 권한 확인
  static bool canManageUsers(User? user) {
    return hasAdminPermission(user);
  }

  /// 휴무 관리 권한 확인
  static bool canManageVacations(User? user) {
    return hasAdminPermission(user);
  }

  /// 회사 설정 관리 권한 확인
  static bool canManageCompanySettings(User? user) {
    return hasAdminPermission(user);
  }
}