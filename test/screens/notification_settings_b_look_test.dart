import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/user.dart';
import 'package:frontend_app/providers/auth_provider.dart';
import 'package:frontend_app/screens/notification_settings_screen.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/theme/app_theme.dart';
import 'package:frontend_app/utils/app_haptics.dart';
import 'package:frontend_app/widgets/seed/seed_list_cell.dart';
import 'package:provider/provider.dart';

/// 알림 설정 B안 — 테두리 Card 대신 흰 카드(SeedListSection), 스위치 줄 높이 60 이상,
/// '진동 반응' 스위치는 예전처럼 켜고 끈다. 글자 1.6배에서도 넘치지 않는다.
void main() {
  setUp(() {
    AppHaptics.debugPerformOverride = (_) async {};
    AppHaptics.enabled.value = true;
  });
  tearDown(() {
    AppHaptics.debugPerformOverride = null;
    AppHaptics.enabled.value = true;
  });

  Future<void> pumpScreen(WidgetTester tester, {double textScale = 1.0}) async {
    tester.view.physicalSize = const Size(1080, 1920); // 360×640
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
      // 사용자가 없으면 서버에 묻지 않고 바로 화면을 그린다(기본값 켬)
      value: AuthProvider(),
      child: MaterialApp(
        theme: AppTheme.withAppChrome(ThemeData()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const NotificationSettingsScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final scale in [1.0, 1.6]) {
    testWidgets('흰 카드 두 개, 스위치 줄 60 이상, 테두리 Card 없음 — 글자 $scale배', (tester) async {
      await pumpScreen(tester, textScale: scale);
      expect(tester.takeException(), isNull);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppSemanticColors.backgroundCanvas);
      expect(find.byType(Card), findsNothing);
      expect(find.byType(SeedListSection), findsNWidgets(2));
      for (final title in ['푸시 알림 받기', '진동 반응']) {
        final tile = find.ancestor(
          of: find.text(title),
          matching: find.byType(SwitchListTile),
        );
        expect(tester.getSize(tile).height, greaterThanOrEqualTo(60));
      }
    });
  }

  testWidgets('진동 반응 스위치는 그대로 켜고 끈다', (tester) async {
    await pumpScreen(tester);
    expect(AppHaptics.enabled.value, isTrue);
    await tester.tap(find.text('진동 반응'));
    await tester.pumpAndSettle();
    expect(AppHaptics.enabled.value, isFalse);
    await tester.tap(find.text('진동 반응'));
    await tester.pumpAndSettle();
    expect(AppHaptics.enabled.value, isTrue);
  });
}
