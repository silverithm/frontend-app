import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/services/member_directory.dart';
import 'package:frontend_app/widgets/common/member_avatar.dart';
import 'package:frontend_app/widgets/seed/seed_avatar.dart';

/// 직원 사진첩(2026-11-16) — 사람 번호로 사진을 찾되, 번호가 겹친 남의 사진은 붙이지 않는다.
void main() {
  final directory = MemberDirectory.instance;

  setUp(() {
    directory.replaceAll('1', const [
      DirectoryMember(
        id: '3',
        name: '박지훈',
        isAdmin: false,
        email: 'p@x.kr',
        imageUrl: '/p3.png',
      ),
      DirectoryMember(
        id: '7',
        name: '조은비',
        isAdmin: false,
        imageUrl: '/p7.png',
      ),
      DirectoryMember(id: '9', name: '김민지', isAdmin: false),
      DirectoryMember(
        id: '10',
        name: '김민지',
        isAdmin: false,
        imageUrl: '/p10.png',
      ),
      // 시설장 id 3은 직원 id 3과 겹친다
      DirectoryMember(
        id: '3',
        name: '김관리',
        isAdmin: true,
        email: 'boss@x.kr',
        imageUrl: '/a3.png',
      ),
    ]);
  });
  tearDown(directory.clear);

  test('직원 번호로 찾는다', () {
    expect(directory.photoFor(memberId: '7'), '/p7.png');
    expect(directory.photoFor(memberId: '7', name: '조은비'), '/p7.png');
  });

  test('번호가 같아도 이름이 다르면 그 사람이 아니다 — 겹친 시설장 번호면 시설장 사진', () {
    // 휴무처럼 직원/시설장 구분 없이 번호만 오는 곳
    expect(directory.photoFor(memberId: '3', name: '김관리'), '/a3.png');
    expect(directory.photoFor(memberId: '3', name: '박지훈'), '/p3.png');
    expect(directory.photoFor(memberId: '3', name: '모르는사람'), isNull);
  });

  test('시설장 번호·이메일로 찾는다', () {
    expect(directory.photoFor(adminId: '3'), '/a3.png');
    expect(directory.photoFor(email: 'BOSS@x.kr'), '/a3.png');
    expect(directory.photoFor(email: 'p@x.kr', name: '박지훈'), '/p3.png');
  });

  test('이름만 있으면 회사에 한 명뿐일 때만', () {
    expect(directory.photoFor(name: '조 은비'), '/p7.png');
    // 김민지가 둘이면 누구 사진인지 모른다
    expect(directory.photoFor(name: '김민지'), isNull);
    expect(directory.find(name: '김민지'), isNull);
  });

  test('비우면 아무도 못 찾는다', () {
    directory.clear();
    expect(directory.isLoaded, isFalse);
    expect(directory.photoFor(memberId: '7'), isNull);
  });

  testWidgets('MemberAvatar — 사진이 있으면 사진 주소, 없으면 이름 첫 글자', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            MemberAvatar(name: '조은비', memberId: '7'),
            MemberAvatar(name: '김민지', memberId: '9', size: 24),
          ],
        ),
      ),
    );
    final avatars = tester
        .widgetList<SeedAvatar>(find.byType(SeedAvatar))
        .toList();
    expect(avatars[0].imageUrl, '/p7.png');
    expect(avatars[1].imageUrl, isNull);
    expect(avatars[1].diameter, 24);
    expect(find.text('김'), findsOneWidget);
    // 사진첩이 늦게 오면 그때 바뀐다
    directory.replaceAll('1', const [
      DirectoryMember(
        id: '9',
        name: '김민지',
        isAdmin: false,
        imageUrl: '/p9.png',
      ),
    ]);
    await tester.pump();
    expect(
      tester.widgetList<SeedAvatar>(find.byType(SeedAvatar)).last.imageUrl,
      '/p9.png',
    );
  });
}
