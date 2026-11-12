import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/schedule.dart';
import 'package:frontend_app/providers/app_provider.dart';
import 'package:frontend_app/screens/text_size_settings_screen.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/theme/app_theme.dart';
import 'package:frontend_app/theme/text_scale.dart';
import 'package:frontend_app/widgets/common/app_sheet_frame.dart';
import 'package:frontend_app/widgets/seed/seed_button.dart';
import 'package:frontend_app/widgets/today_schedule_dialog.dart';
import 'package:frontend_app/widgets/update_dialog.dart';
import 'package:provider/provider.dart';

/// 묶음 ① B안 — 오늘 일정은 아래 시트, 업데이트 창·글자 크기는 테두리 없는 모양.
/// 쓰는 분이 50~60대라 글자를 1.3배·1.6배로 키워도 넘치지 않아야 한다.
void main() {
  void setPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920); // 360×640 — 작은 폰
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Widget host(Widget home, {double textScale = 1.0}) => MaterialApp(
        theme: AppTheme.withAppChrome(ThemeData()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: home,
      );

  List<Schedule> schedules(int n) => [
        for (var i = 0; i < n; i++)
          Schedule(
            id: i,
            title: '요양보호사 1팀 주간 회의와 어르신 생신잔치 준비 $i',
            category: 'MEETING',
            startDate: DateTime(2026, 11, 12),
            startTime: '09:30:00',
            companyId: 1,
          ),
      ];

  Future<BuildContext> pumpHost(WidgetTester tester, {double textScale = 1.0}) async {
    setPhone(tester);
    late BuildContext captured;
    await tester.pumpWidget(host(
      Scaffold(body: Builder(builder: (context) {
        captured = context;
        return const SizedBox.expand();
      })),
      textScale: textScale,
    ));
    return captured;
  }

  for (final scale in [1.0, 1.3, 1.6]) {
    testWidgets('오늘 일정 — 아래 시트, 글자 $scale배에서도 넘치지 않는다', (tester) async {
      final context = await pumpHost(tester, textScale: scale);
      var viewed = false;
      showAppSheet<void>(
        context,
        builder: (_) => TodayScheduleDialog(
          schedules: schedules(8),
          onViewSchedule: () => viewed = true,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('오늘 일정 8건'), findsOneWidget);
      expect(find.text('외 2건'), findsOneWidget);
      // 시각 칸이 둘로 갈라지지 않는다(한 줄)
      final time = tester.getSize(find.text('09:30').first);
      expect(time.height, lessThan(14 * scale * 2));

      await tester.tap(find.text('일정 보기'));
      await tester.pumpAndSettle();
      expect(viewed, isTrue);
      expect(find.byType(BottomSheet), findsNothing);
    });
  }

  testWidgets('오늘 일정 — 닫기는 일정 화면으로 넘기지 않는다', (tester) async {
    final context = await pumpHost(tester);
    var viewed = false;
    showAppSheet<void>(
      context,
      builder: (_) => TodayScheduleDialog(
        schedules: schedules(2),
        onViewSchedule: () => viewed = true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(viewed, isFalse);
    expect(find.byType(BottomSheet), findsNothing);
  });

  for (final force in [false, true]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('업데이트 창 — 강제 $force, 글자 $scale배, 단추 큰 52·테두리 없음', (tester) async {
        final context = await pumpHost(tester, textScale: scale);
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => UpdateDialog(
            currentVersion: '1.19.7',
            latestVersion: '1.20.0',
            updateMessage: '새 버전이 나왔어요. 업무진행도와 알림 이동이 추가되었습니다.',
            forceUpdate: force,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('업데이트 알림'), findsOneWidget);
        expect(find.text('1.19.7 → 1.20.0'), findsOneWidget);
        expect(find.text('나중에'), force ? findsNothing : findsOneWidget);
        // Dialog 위젯 크기에는 바깥 여백이 들어 있다 — 흰 면(Material) 폭으로 잰다
        final dialog = tester.getSize(find
            .descendant(of: find.byType(Dialog), matching: find.byType(Material))
            .first);
        final update = tester.getSize(find.ancestor(
          of: find.text('업데이트').last,
          matching: find.byType(SeedButton),
        ));
        expect(update.height, greaterThanOrEqualTo(52));
        if (!force) {
          final later = tester.widget<SeedButton>(find.ancestor(
            of: find.text('나중에'),
            matching: find.byType(SeedButton),
          ));
          expect(later.variant, SeedButtonVariant.neutralWeak);
        }
        // 강제면 '업데이트' 하나가 창 폭을 거의 다 쓴다(안쪽 여백 24씩 뺀 폭)
        if (force) {
          final button = find.ancestor(
            of: find.text('업데이트').last,
            matching: find.byType(AppSheetActions),
          );
          expect(tester.getSize(button).width, dialog.width - 48);
        }
        final shape = tester.widget<Dialog>(find.byType(Dialog)).shape
            as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(24));
      });
    }
  }

  for (final scale in [1.0, 1.6]) {
    testWidgets('글자 크기 — 흰 카드 하나에 네 줄(52 이상), 고르면 옅은 틸 바탕, 글자 $scale배', (tester) async {
      setPhone(tester);
      final provider = AppProvider();
      await tester.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: host(const TextSizeSettingsScreen(), textScale: scale),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppSemanticColors.backgroundCanvas);
      for (final size in AppTextSize.values) {
        final row = find.ancestor(
          of: find.text(size.label),
          matching: find.byType(InkWell),
        );
        expect(tester.getSize(row).height, greaterThanOrEqualTo(52));
      }

      Color? rowColor(String label) => tester
          .widget<Material>(find
              .ancestor(of: find.text(label), matching: find.byType(Material))
              .first)
          .color;
      expect(rowColor('보통'), AppSemanticColors.brandWeak);
      expect(rowColor('크게'), AppColors.transparent);

      await tester.tap(find.text('크게'));
      await tester.pumpAndSettle();
      expect(provider.textSize, AppTextSize.large);
      expect(rowColor('크게'), AppSemanticColors.brandWeak);
      expect(rowColor('보통'), AppColors.transparent);
    });
  }
}
