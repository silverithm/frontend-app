import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/position_option.dart';
import 'package:frontend_app/utils/role_utils.dart';

PositionOption _position(String id, String name, {int? sortOrder}) {
  return PositionOption(id: id, name: name, sortOrder: sortOrder);
}

/// 휴무 한도 화면의 직종 탭은 기관이 등록한 직책에서 나와야 한다.
/// 웹(roleUtils.buildRoleNames)과 같은 목록이 아니면, 앱에서는 보이지도 설정되지도 않는
/// 직책이 생겨 한도가 조용히 틀린다.
void main() {
  group('buildRoleNames', () {
    test('기관이 등록한 직책을 sortOrder 순으로 세운다', () {
      final roles = RoleUtils.buildRoleNames(positions: [
        _position('3', '사회복지사', sortOrder: 3),
        _position('1', '간호조무사', sortOrder: 1),
        _position('2', '조리원', sortOrder: 2),
      ]);

      expect(roles, ['간호조무사', '조리원', '사회복지사']);
    });

    test('sortOrder가 없으면 이름 순으로 뒤에 붙는다', () {
      final roles = RoleUtils.buildRoleNames(positions: [
        _position('2', '나직책'),
        _position('1', '가직책', sortOrder: 1),
      ]);

      expect(roles.first, '가직책');
      expect(roles, contains('나직책'));
    });

    test('요양보호사·사무직은 웹과 같은 키로 모인다', () {
      final roles = RoleUtils.buildRoleNames(positions: [
        _position('1', '요양보호사', sortOrder: 1),
        _position('2', '사무직', sortOrder: 2),
      ]);

      expect(roles, ['caregiver', 'office']);
      expect(RoleUtils.displayName('caregiver'), '요양보호사');
    });

    test('저장된 한도에만 남은 역할도 탭으로 잇는다', () {
      final roles = RoleUtils.buildRoleNames(
        positions: [_position('1', '간호조무사')],
        extraRoles: ['영양사', 'CAREGIVER'],
      );

      expect(roles, ['간호조무사', '영양사', 'caregiver']);
    });

    test("'전체(all)'와 관리자는 직종 탭에 섞이지 않는다", () {
      final roles = RoleUtils.buildRoleNames(
        positions: [_position('1', '간호조무사')],
        extraRoles: ['all', 'ALL', 'admin', '관리자'],
      );

      expect(roles, ['간호조무사']);
    });

    test('같은 역할이 두 번 들어와도 한 번만 선다', () {
      final roles = RoleUtils.buildRoleNames(
        positions: [_position('1', '요양보호사')],
        extraRoles: ['caregiver', 'CAREGIVER', '요양보호사'],
      );

      expect(roles, ['caregiver']);
    });

    test('직책이 한 곳도 없으면 예전 두 분류로 되돌린다 — 화면이 비지 않는다', () {
      expect(RoleUtils.buildRoleNames(), ['caregiver', 'office']);
    });
  });
}
