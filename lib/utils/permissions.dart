import '../models/user.dart';
import 'admin_utils.dart';

/// 웹(frontend-admin)의 `Permission` 타입과 1:1로 같은 목록.
/// 백엔드 MemberService.VALID_PERMISSIONS 와도 같아야 한다.
class AppPermission {
  static const String noticeManage = 'NOTICE_MANAGE'; // 공지사항 관리
  static const String scheduleManage = 'SCHEDULE_MANAGE'; // 일정 관리
  static const String scheduleDispatch = 'SCHEDULE_DISPATCH'; // 배차 관리
  static const String approvalManage = 'APPROVAL_MANAGE'; // 결재 승인/거절
  static const String approvalTemplate = 'APPROVAL_TEMPLATE'; // 결재 양식 관리
  static const String workManage = 'WORK_MANAGE'; // 근무조정(휴무) 관리
  static const String memberView = 'MEMBER_VIEW'; // 회원 조회
  static const String memberManage = 'MEMBER_MANAGE'; // 회원 승인/거절/상태변경
  static const String seniorManage = 'SENIOR_MANAGE'; // 어르신 관리

  static const List<String> all = [
    noticeManage,
    scheduleManage,
    scheduleDispatch,
    approvalManage,
    approvalTemplate,
    workManage,
    memberView,
    memberManage,
    seniorManage,
  ];

  static const Map<String, String> labels = {
    noticeManage: '공지사항 관리',
    scheduleManage: '일정 관리',
    scheduleDispatch: '배차 관리',
    approvalManage: '결재 관리',
    approvalTemplate: '결재 양식 관리',
    workManage: '근무조정 관리',
    memberView: '회원 조회',
    memberManage: '회원 관리',
    seniorManage: '어르신 관리',
  };
}

/// 세부 권한 판정.
///
/// 규칙(웹 employee/page.tsx와 같은 규칙):
/// - 기관 관리자(app_user 로그인 등 AdminUtils가 관리자로 보는 계정)는 모든 권한을 가진 것으로 본다.
///   관리자에게 보이던 화면이 권한 도입 때문에 사라지면 안 되기 때문이다.
/// - 그 밖의 직원은 서버가 내려준 permissions 목록에 있는 것만 가진다.
/// - **목록이 비었거나 없으면(null) 아무 세부 권한도 없다.** 이는 권한 도입 이전과
///   정확히 같은 상태다 — 예전에도 직원에게는 관리 화면이 하나도 보이지 않았다.
///   따라서 "권한이 안 내려왔다"고 해서 직원이 쓰던 것을 잃지 않는다(관리 화면은
///   애초에 없었고, 내 휴무·공지 열람·결재 신청 같은 직원 기능은 권한과 무관하게 열려 있다).
class PermissionUtils {
  /// 관리자 계정인지 — 관리자는 모든 세부 권한을 가진 것으로 취급한다.
  static bool isAdmin(User? user) => AdminUtils.hasAdminPermission(user);

  static List<String> permissionsOf(User? user) => user?.permissions ?? const [];

  static bool has(User? user, String permission) {
    if (user == null) return false;
    if (isAdmin(user)) return true;
    return user.permissions.contains(permission);
  }

  static bool hasAny(User? user, List<String> permissions) {
    if (user == null) return false;
    if (isAdmin(user)) return true;
    return permissions.any((p) => user.permissions.contains(p));
  }

  static bool hasAll(User? user, List<String> permissions) {
    if (user == null) return false;
    if (isAdmin(user)) return true;
    return permissions.every((p) => user.permissions.contains(p));
  }

  /// 서버가 준 목록에서 우리가 아는 권한만 남긴다(오타·구버전 값 방어).
  static List<String> sanitize(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e?.toString() ?? '')
        .where((e) => AppPermission.all.contains(e))
        .toSet()
        .toList();
  }
}
