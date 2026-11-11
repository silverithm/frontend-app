import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/subscription.dart';
import 'package:frontend_app/providers/auth_provider.dart';
import 'package:frontend_app/providers/subscription_provider.dart';
import 'package:frontend_app/screens/admin_payment_screen.dart';
import 'package:frontend_app/screens/payment_screen.dart';
import 'package:frontend_app/screens/subscription_check_screen.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 묶음 ⑥ 결제·구독 B안(2026-11-12) — 겉모습(바탕·카드·간격)만 바꿨다. 토스 심사 중이라
/// 결제·약관 문구가 그대로 보이는지, 글자를 키워도 넘치지 않는지만 본다.
class _FakeSubscription extends SubscriptionProvider {
  @override
  Future<bool> loadSubscription() async => true;
}

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required double textScale,
  required Widget home,
}) async {
  tester.view.physicalSize = Size(width * 3, 2400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<SubscriptionProvider>(
          create: (_) => _FakeSubscription(),
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
        home: home,
      ),
    ),
  );
  // 화면 등장 연출(0.8~1초)이 끝날 때까지
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 2));
}

SubscriptionPlan _basicPlan() => SubscriptionPlan.getAvailablePlans().firstWhere(
  (plan) => plan.type == SubscriptionType.BASIC,
  orElse: () => SubscriptionPlan.getAvailablePlans().last,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      testWidgets('결제 — 폭 $width · 글자 $scale배, 넘치지 않고 문구 그대로', (
        tester,
      ) async {
        await _pump(
          tester,
          width: width,
          textScale: scale,
          home: PaymentScreen(plan: _basicPlan()),
        );
        expect(tester.takeException(), isNull);

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.backgroundColor, AppSemanticColors.backgroundCanvas);
        expect(find.text('결제 정보'), findsOneWidget);
        expect(find.text('결제 수단'), findsOneWidget);
        expect(find.text('토스페이먼츠'), findsOneWidget);
        expect(find.text('신용카드, 계좌이체, 간편결제'), findsOneWidget);
        expect(
          find.text('결제 정보는 암호화되어 안전하게 보호됩니다.\n언제든지 구독을 취소할 수 있습니다.'),
          findsOneWidget,
        );
        expect(
          find.text('결제 시 이용약관과 개인정보처리방침에 동의한 것으로 간주됩니다.'),
          findsOneWidget,
        );
        // 구분선은 없다(간격으로 나눈다)
        expect(find.byType(Divider), findsNothing);
      });

      testWidgets('관리자 구독 결제 — 폭 $width · 글자 $scale배, 넘치지 않고 문구 그대로', (
        tester,
      ) async {
        await _pump(
          tester,
          width: width,
          textScale: scale,
          home: const AdminPaymentScreen(),
        );
        expect(tester.takeException(), isNull);

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.backgroundColor, AppSemanticColors.backgroundCanvas);
        expect(find.text('결제 회사 정보'), findsOneWidget);
        expect(find.text('서비스 이용약관'), findsOneWidget);
        expect(find.text('위 서비스 이용약관에 동의합니다.'), findsOneWidget);
        expect(find.text('약관에 동의해주세요'), findsOneWidget);
        expect(find.text('토스페이먼츠를 통한 안전한 결제'), findsOneWidget);
        expect(find.byType(Divider), findsNothing);
      });

      testWidgets('요금제 선택 — 폭 $width · 글자 $scale배, 넘치지 않고 문구 그대로', (
        tester,
      ) async {
        await _pump(
          tester,
          width: width,
          textScale: scale,
          home: const SubscriptionCheckScreen(isAdmin: true),
        );
        expect(tester.takeException(), isNull);

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.backgroundColor, AppSemanticColors.backgroundCanvas);
        expect(find.text('서비스를 이용하시려면 요금제를 선택해주세요.'), findsOneWidget);
        expect(find.text('모든 플랜에 포함된 기능'), findsOneWidget);
        expect(find.text('토스페이먼츠를 통한 안전하고 편리한 결제'), findsOneWidget);
        expect(find.byType(Card), findsNothing);
      });
    }
  }
}
