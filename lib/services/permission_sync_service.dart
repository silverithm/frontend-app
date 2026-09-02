import '../providers/auth_provider.dart';
import '../utils/permissions.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// 관리자가 웹에서 바꾼 세부 권한을 재로그인 없이 앱에 반영한다.
///
/// 로그인 응답(MemberSigninResponseDTO.permissions)에 이미 권한이 실려 오므로
/// 로그인 직후에는 최신이다. 문제는 그 다음이다 — 앱을 켜 둔 채 권한을 받은 사람은
/// 저장된(예전) 권한으로 앱을 다시 켜게 된다. 그래서 앱 진입 시 한 번 재조회한다.
/// 웹 employee/page.tsx가 getMemberPermissions로 하는 일과 같다.
///
/// 실패해도 아무것도 지우지 않는다(저장된 권한 유지) — 신호가 잠깐 나빴다는 이유로
/// 쓰던 메뉴가 사라지면 안 된다.
class PermissionSyncService {
  static Future<void> refresh(AuthProvider authProvider) async {
    final user = authProvider.currentUser;
    if (user == null) return;
    // 관리자 계정(app_user)은 members 테이블에 없다 — 조회할 대상이 아니고,
    // 어차피 모든 권한을 가진 것으로 취급한다.
    if (user.isAdminAccount) return;

    try {
      final fetched = await ApiService().getMemberPermissions(user.id);
      final permissions = PermissionUtils.sanitize(fetched);

      final same = permissions.length == user.permissions.length &&
          permissions.every(user.permissions.contains);
      if (same) return;

      authProvider.updateUser(user.copyWith(permissions: permissions));

      // 앱 재시작 시 복원되는 저장본에도 반영한다.
      final saved = StorageService().getSavedUserData();
      if (saved != null) {
        saved['permissions'] = permissions;
        await StorageService().saveUserData(saved);
      }
    } catch (e) {
      print('[PermissionSync] 권한 재조회 실패(저장된 권한 유지): $e');
    }
  }
}
