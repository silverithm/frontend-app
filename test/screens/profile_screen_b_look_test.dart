import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/company.dart';
import 'package:frontend_app/models/user.dart';
import 'package:frontend_app/providers/app_version_provider.dart';
import 'package:frontend_app/providers/auth_provider.dart';
import 'package:frontend_app/screens/profile_screen.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/theme/app_theme.dart';
import 'package:provider/provider.dart';

/// 묶음 ① 프로필 B안 — 회색 바탕 위 테두리 없는 흰 카드, 구분선 없음,
/// 비밀번호 변경·회원탈퇴는 아래 시트. 글자를 1.6배로 키워도 넘치지 않아야 한다.
void main() {
  Future<void> pumpProfile(
    WidgetTester tester, {
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = const Size(1080, 1920); // 360×640
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // updateUser는 서버에 다시 묻는 저장을 함께 걸어 테스트에서는 쓰지 않는다 —
    // 화면은 currentUser만 읽으니 같은 값을 주는 하위 클래스로 넣는다.
    final fake = _FakeAuth(
      User(
        id: '3',
        email: 'admin@carev.kr',
        name: '김관리',
        role: 'admin',
        username: 'admin',
        createdAt: DateTime(2026, 11, 12),
        lastLoginAt: DateTime(2026, 11, 12, 9, 5),
        position: '센터장',
        company: Company(
          id: '4',
          name: '햇살주간보호센터',
          addressName: '서울시',
          companyCode: 'SUN2026',
        ),
      ),
    );
    // 프로필은 열릴 때 Firebase 분석 기록을 남기는데 테스트에는 Firebase가 없다 —
    // 그 기록 실패(LateInitializationError)만 삼키고 화면 그리기는 그대로 본다.
    await runZonedGuarded(
      () async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: fake),
              ChangeNotifierProvider<AppVersionProvider>(
                create: (_) => AppVersionProvider(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.withAppChrome(ThemeData()),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: const ProfileScreen(),
            ),
          ),
        );
        // 첫 화면의 떠오르기(0.5초)가 끝날 때까지 — 위치를 재기 전에
      await tester.pumpAndSettle();
      },
      (error, _) {
        if (!'$error'.contains('LateInitializationError')) throw error;
      },
    );
  }

  for (final scale in [1.0, 1.6]) {
    testWidgets('프로필 — 회색 바탕·구분선 없음, 글자 $scale배에서도 넘치지 않는다', (tester) async {
      await pumpProfile(tester, textScale: scale);
      expect(tester.takeException(), isNull);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, AppSemanticColors.backgroundCanvas);
      expect(find.byType(Divider), findsNothing);
      expect(find.text('기본 정보'), findsOneWidget);

      // 기본 정보 라벨 칸은 글자 배율만큼 넓어진다(88 × 배율) — 글자를 키워도 라벨이 꺾이지 않게
      final labelBox = find
          .ancestor(of: find.text('이름'), matching: find.byType(SizedBox))
          .first;
      expect(tester.getSize(labelBox).width, closeTo(88 * scale, 0.01));

      // 사진 바꾸기 단추 — 누르는 자리 42 이상(보이는 원 36)
      final semantics = tester.ensureSemantics();
      final camera = find.bySemanticsLabel('프로필 사진 변경');
      expect(camera, findsOneWidget);
      expect(tester.getSize(camera).width, greaterThanOrEqualTo(42));
      semantics.dispose();

      // 끝까지 내려 보며 넘침이 없는지 — 회사 코드·설정·약관·로그아웃
      for (final text in ['회사 코드', '복사', '약관 및 정책', '로그아웃']) {
        await tester.scrollUntilVisible(
          find.text(text),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: text);
      }
      expect(find.byType(Divider), findsNothing);
    });
  }

  testWidgets('비밀번호 변경은 아래 시트, 취소로 닫힌다', (tester) async {
    await pumpProfile(tester);
    await tester.scrollUntilVisible(
      find.text('비밀번호 변경'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('비밀번호 변경'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('비밀번호 변경'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('새 비밀번호 확인'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('회원탈퇴는 아래 시트이고 바깥을 눌러도 닫히지 않는다', (tester) async {
    await pumpProfile(tester);
    await tester.scrollUntilVisible(
      find.text('회원탈퇴'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('회원탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('회원탈퇴'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('정말로 회원탈퇴를 진행하시겠습니까?'), findsOneWidget);
    await tester.tapAt(const Offset(180, 20));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });
}

class _FakeAuth extends AuthProvider {
  _FakeAuth(this._user);
  final User _user;

  @override
  User? get currentUser => _user;
}
