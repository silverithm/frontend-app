import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/user.dart';

/// User.copyWith가 isAdminAccount/permissions 같은 플래그를 보존하는가.
///
/// 예전에는 프로필 사진·역할을 바꿀 때 User를 필드 몇 개만 채워 새로 만들어서
/// isAdminAccount/permissions가 기본값으로 떨어졌다 — 관리자의 chatUserId가
/// admin_<id>에서 <id>로 바뀌고 권한이 사라지는 사고였다.
void main() {
  User baseUser() => User(
        id: '7',
        email: 'admin@carev.kr',
        name: '김도형',
        role: 'ADMIN',
        createdAt: DateTime(2026, 1, 1),
        username: 'admin7',
        position: '원장',
        isAdminAccount: true,
        permissions: const ['NOTICE_MANAGE', 'MEMBER_VIEW'],
        profileImageUrl: 'https://example.com/old.jpg',
      );

  test('profileImageUrl만 바꿔도 isAdminAccount/permissions가 유지된다', () {
    final updated = baseUser().copyWith(
      profileImageUrl: 'https://example.com/new.jpg',
    );

    expect(updated.profileImageUrl, 'https://example.com/new.jpg');
    expect(updated.isAdminAccount, isTrue);
    expect(updated.permissions, const ['NOTICE_MANAGE', 'MEMBER_VIEW']);
    expect(updated.chatUserId, 'admin_7');
  });

  test('clearProfileImageUrl:true면 사진이 삭제되고 나머지는 그대로다', () {
    final updated = baseUser().copyWith(clearProfileImageUrl: true);

    expect(updated.profileImageUrl, isNull);
    expect(updated.isAdminAccount, isTrue);
    expect(updated.permissions, const ['NOTICE_MANAGE', 'MEMBER_VIEW']);
    expect(updated.position, '원장');
  });

  test('role만 바꿔도 profileImageUrl/isAdminAccount/permissions/position이 유지된다', () {
    final updated = baseUser().copyWith(role: 'OFFICE');

    expect(updated.role, 'OFFICE');
    expect(updated.profileImageUrl, 'https://example.com/old.jpg');
    expect(updated.isAdminAccount, isTrue);
    expect(updated.permissions, const ['NOTICE_MANAGE', 'MEMBER_VIEW']);
    expect(updated.position, '원장');
  });
}
