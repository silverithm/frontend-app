import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/company.dart';
import 'package:frontend_app/models/member_signin_response.dart';
import 'package:frontend_app/models/user.dart';
import 'package:frontend_app/utils/permissions.dart';

/// 세부 권한 판정 규약을 고정한다.
/// - 관리자: 권한 목록과 무관하게 전부 통과 (권한 도입 전과 똑같이 보여야 한다)
/// - 직원: 서버가 준 목록에 있는 것만
/// - 목록이 비었거나 없으면: 세부 권한 없음 = 권한 도입 이전과 같은 상태
User _user({
  required String role,
  List<String> permissions = const [],
  bool isAdminAccount = false,
}) {
  return User(
    id: '1',
    username: 'u',
    email: 'u@example.com',
    name: '홍길동',
    role: role,
    status: 'active',
    isActive: true,
    isAdminAccount: isAdminAccount,
    createdAt: DateTime(2026, 1, 1),
    company: Company(id: '1', name: '케어브이', addressName: '서울'),
    permissions: permissions,
  );
}

void main() {
  group('관리자', () {
    test('권한 목록이 비어 있어도 모든 세부 권한을 가진다', () {
      final admin = _user(role: 'ADMIN', isAdminAccount: true);
      for (final p in AppPermission.all) {
        expect(PermissionUtils.has(admin, p), isTrue, reason: p);
      }
      expect(PermissionUtils.hasAll(admin, AppPermission.all), isTrue);
      expect(
        PermissionUtils.hasAny(admin, const [AppPermission.scheduleDispatch]),
        isTrue,
      );
    });

    test('role이 admin/ROLE_ADMIN 표기여도 동일하다', () {
      for (final role in ['admin', 'ADMIN', 'ROLE_ADMIN']) {
        expect(
          PermissionUtils.has(_user(role: role), AppPermission.memberManage),
          isTrue,
          reason: role,
        );
      }
    });
  });

  group('직원', () {
    test('가진 권한만 통과한다', () {
      final driver = _user(
        role: 'CAREGIVER',
        permissions: const [AppPermission.scheduleDispatch],
      );

      expect(
        PermissionUtils.has(driver, AppPermission.scheduleDispatch),
        isTrue,
      );
      for (final p in AppPermission.all
          .where((p) => p != AppPermission.scheduleDispatch)) {
        expect(PermissionUtils.has(driver, p), isFalse, reason: p);
      }
      expect(
        PermissionUtils.hasAny(driver, const [
          AppPermission.memberView,
          AppPermission.scheduleDispatch,
        ]),
        isTrue,
      );
      expect(
        PermissionUtils.hasAll(driver, const [
          AppPermission.memberView,
          AppPermission.scheduleDispatch,
        ]),
        isFalse,
      );
    });

    test('권한 목록이 비면 세부 권한이 하나도 없다(기본값)', () {
      final plain = _user(role: 'CAREGIVER');
      for (final p in AppPermission.all) {
        expect(PermissionUtils.has(plain, p), isFalse, reason: p);
      }
    });

    test('여러 권한을 동시에 가질 수 있다', () {
      final officer = _user(
        role: 'OFFICE',
        permissions: const [
          AppPermission.noticeManage,
          AppPermission.approvalManage,
        ],
      );
      expect(PermissionUtils.has(officer, AppPermission.noticeManage), isTrue);
      expect(PermissionUtils.has(officer, AppPermission.approvalManage), isTrue);
      expect(PermissionUtils.has(officer, AppPermission.workManage), isFalse);
    });

    test('회사 정보가 없는 미승인 계정은 관리자로 취급되지 않는다', () {
      final noCompany = User(
        id: '2',
        username: 'u2',
        email: 'u2@example.com',
        name: '신규',
        role: 'ADMIN',
        status: 'pending',
        isActive: false,
        createdAt: DateTime(2026, 1, 1),
      );
      expect(
        PermissionUtils.has(noCompany, AppPermission.memberManage),
        isFalse,
      );
    });
  });

  test('사용자가 없으면 모든 권한이 없다', () {
    expect(PermissionUtils.has(null, AppPermission.noticeManage), isFalse);
    expect(PermissionUtils.hasAny(null, AppPermission.all), isFalse);
  });

  group('서버 응답 파싱', () {
    test('로그인 응답의 permissions가 User로 전달된다', () {
      final response = MemberSigninResponse.fromJson({
        'memberId': 7,
        'username': 'driver',
        'name': '김기사',
        'email': 'driver@example.com',
        'role': 'caregiver',
        'status': 'active',
        'company': {'id': '1', 'name': '케어브이'},
        'permissions': ['SCHEDULE_DISPATCH', 'MEMBER_VIEW'],
        'tokenInfo': {'accessToken': 'a', 'refreshToken': 'r'},
      });

      final user = response.toUser();
      expect(user.permissions, containsAll(const [
        AppPermission.scheduleDispatch,
        AppPermission.memberView,
      ]));
      expect(
        PermissionUtils.has(user, AppPermission.scheduleDispatch),
        isTrue,
      );
      expect(PermissionUtils.has(user, AppPermission.noticeManage), isFalse);
    });

    test('구버전 응답처럼 permissions가 없으면 빈 목록이 된다', () {
      final user = MemberSigninResponse.fromJson({
        'memberId': 8,
        'username': 'x',
        'name': '이직원',
        'email': 'x@example.com',
        'role': 'caregiver',
        'status': 'active',
        'company': {'id': '1', 'name': '케어브이'},
        'tokenInfo': {'accessToken': 'a'},
      }).toUser();

      expect(user.permissions, isEmpty);
      expect(PermissionUtils.has(user, AppPermission.workManage), isFalse);
    });

    test('null이나 모르는 값은 걸러낸다', () {
      expect(PermissionUtils.sanitize(null), isEmpty);
      expect(PermissionUtils.sanitize('NOTICE_MANAGE'), isEmpty);
      expect(
        PermissionUtils.sanitize(['NOTICE_MANAGE', 'UNKNOWN_PERMISSION', null]),
        const [AppPermission.noticeManage],
      );
    });

    test('앱 재시작(저장본 복원) 후에도 권한이 유지된다', () {
      final user = _user(
        role: 'CAREGIVER',
        permissions: const [AppPermission.approvalTemplate],
      );
      final restored = User.fromJson(user.toJson());
      expect(
        PermissionUtils.has(restored, AppPermission.approvalTemplate),
        isTrue,
      );
      expect(PermissionUtils.has(restored, AppPermission.memberManage), isFalse);
    });
  });
}
