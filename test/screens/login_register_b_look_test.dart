import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/providers/auth_provider.dart';
import 'package:frontend_app/providers/company_provider.dart';
import 'package:frontend_app/screens/login_screen.dart';
import 'package:frontend_app/screens/register_screen.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/theme/app_theme.dart';
import 'package:frontend_app/widgets/common/app_sheet_frame.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 묶음 ⑥ 로그인·가입 B안(2026-11-12) — 회색 바탕 위 흰 카드, 테두리 상자·고정 높이 없음,
/// 비밀번호 찾기는 아래 시트. 좁은 폰에서 글자를 1.6배로 키워도 넘치지 않아야 한다.
class _FakeCompany extends CompanyProvider {
  @override
  Future<void> loadCompanies() async {}
}

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required double textScale,
  required Widget home,
}) async {
  tester.view.physicalSize = Size(width * 3, 1400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<CompanyProvider>(create: (_) => _FakeCompany()),
      ],
      child: MaterialApp(
        theme: AppTheme.withAppChrome(ThemeData()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      testWidgets('로그인 — 폭 $width · 글자 $scale배, 넘치지 않는다', (tester) async {
        await _pump(
          tester,
          width: width,
          textScale: scale,
          home: const LoginScreen(),
        );
        expect(tester.takeException(), isNull);

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.backgroundColor, AppSemanticColors.backgroundCanvas);
        // 글자는 그대로
        expect(find.text('직원 계정으로 로그인'), findsOneWidget);
        expect(find.text('이메일 기억하기'), findsOneWidget);
        expect(find.text('계정이 없으신가요?'), findsOneWidget);
        expect(find.text('사용방법 보러가기'), findsOneWidget);
      });

      testWidgets('가입 — 폭 $width · 글자 $scale배, 넘치지 않는다', (tester) async {
        await _pump(
          tester,
          width: width,
          textScale: scale,
          home: const RegisterScreen(),
        );
        expect(tester.takeException(), isNull);

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.backgroundColor, AppSemanticColors.backgroundCanvas);
        expect(find.text('회원가입 절차 안내'), findsOneWidget);
        expect(find.text('가입 유형 선택'), findsOneWidget);
        expect(find.text('약관 동의 (필수)'), findsOneWidget);
        expect(find.text('약관 동의 후 회원가입 가능'), findsOneWidget);
      });
    }
  }

  testWidgets('로그인 — 관리자를 고르면 부제가 바뀐다', (tester) async {
    await _pump(
      tester,
      width: 390,
      textScale: 1.0,
      home: const LoginScreen(),
    );
    await tester.tap(find.text('관리자'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('관리자 계정으로 로그인'), findsOneWidget);
  });

  testWidgets('로그인 — 비밀번호 찾기는 아래 시트로 열린다(1.3배에서도 넘치지 않음)', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 360,
      textScale: 1.3,
      home: const LoginScreen(),
    );
    await tester.tap(find.text('비밀번호 찾기'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.byType(AppSheetFrame), findsOneWidget);
    expect(find.text('사용자 타입'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('가입 — 관리자를 고르면 회사명 칸, 전체 동의를 누르면 단추 글자가 바뀐다', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 390,
      textScale: 1.0,
      home: const RegisterScreen(),
    );

    final admin = find.text('근무표 관리');
    await tester.ensureVisible(admin);
    await tester.tap(admin);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('회사명 *'), findsOneWidget);

    final agreeAll = find.text('위 약관에 모두 동의합니다');
    await tester.ensureVisible(agreeAll);
    await tester.tap(agreeAll);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('약관 동의 후 회원가입 가능'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
