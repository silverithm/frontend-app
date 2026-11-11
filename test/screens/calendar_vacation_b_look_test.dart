import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/providers/auth_provider.dart';
import 'package:frontend_app/providers/vacation_provider.dart';
import 'package:frontend_app/theme/app_theme.dart';
import 'package:frontend_app/widgets/common/app_sheet_frame.dart';
import 'package:frontend_app/widgets/seed/seed_chip.dart';
import 'package:frontend_app/widgets/vacation_calendar_widget.dart';
import 'package:frontend_app/widgets/vacation_request_dialog.dart';
import 'package:provider/provider.dart';

/// 묶음 ③ 일정·휴무 B안(2026-11-12) — 근무조정 달력과 휴무 신청 시트.
/// 좁은 폰(320)·보통 폰(390)에서 글자를 앱 최대(1.6배)까지 키워도 넘치지 않아야 한다.
Future<void> _pumpApp(
  WidgetTester tester, {
  required double width,
  required double textScale,
  required Widget home,
}) async {
  tester.view.physicalSize = Size(width * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<VacationProvider>(
          create: (_) => VacationProvider(),
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
  await tester.pump(const Duration(milliseconds: 400));
}

Widget _calendarHome() => Scaffold(
  body: SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: VacationCalendarWidget(
      currentDate: DateTime(2026, 11),
      onDateChanged: (_) {},
      onDateSelected: (_) {},
      onRoleFiltersChanged: (_) {},
    ),
  ),
);

/// 화면에서 '휴무 추가'를 누르면 이렇게 뜬다(calendar_screen._showVacationRequestDialog).
Widget _sheetOpener() => Scaffold(
  body: Builder(
    builder: (context) => Center(
      child: TextButton(
        onPressed: () => showAppSheet(
          context,
          isDismissible: false,
          builder: (_) =>
              VacationRequestDialog(selectedDate: DateTime(2026, 11, 28)),
        ),
        child: const Text('열기'),
      ),
    ),
  ),
);

void main() {
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      testWidgets('근무조정 달력 — 폭 $width · 글자 $scale배, 접힘·펼침 모두 넘치지 않는다', (
        tester,
      ) async {
        await _pumpApp(
          tester,
          width: width,
          textScale: scale,
          home: _calendarHome(),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('2026년 11월'), findsOneWidget);
        // 직종 거르기는 B안 거르기 칩, '전체'가 골라져 있다
        final all = find.widgetWithText(SeedChip, '전체');
        expect(all, findsOneWidget);
        expect(tester.widget<SeedChip>(all).selected, isTrue);
        // 범례 글자는 그대로
        for (final label in ['승인', '대기', '거절', '연차', '반차', '필수']) {
          expect(find.text(label), findsOneWidget);
        }

        // 휴무자 이름 펼치기
        await tester.tap(find.text('보기'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(find.text('숨기기'), findsOneWidget);
      });

      testWidgets('휴무 신청 시트 — 폭 $width · 글자 $scale배, 넘치지 않고 문구가 그대로다', (
        tester,
      ) async {
        await _pumpApp(
          tester,
          width: width,
          textScale: scale,
          home: _sheetOpener(),
        );
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 가운데 대화상자가 아니라 아래 시트(손잡이)다
        expect(find.byType(Dialog), findsNothing);
        expect(find.byType(AppSheetHandle), findsOneWidget);
        expect(find.text('휴무 신청'), findsOneWidget);
        expect(find.byTooltip('닫기'), findsOneWidget);
        expect(find.text('선택된 날짜'), findsOneWidget);
        expect(find.text('2026년 11월 28일 (토)'), findsOneWidget);
        expect(find.text('휴무 등록 전 필수 숙지 사항'), findsOneWidget);
        expect(find.text('휴무 종류'), findsOneWidget);
        expect(find.text('세부 유형'), findsOneWidget);

        // 종류는 거르기 칩 — 연차를 고르면 세부 유형이 사라진다(예전과 같은 규칙)
        await tester.ensureVisible(find.widgetWithText(SeedChip, '연차'));
        await tester.tap(find.widgetWithText(SeedChip, '연차'));
        await tester.pump();
        expect(
          tester.widget<SeedChip>(find.widgetWithText(SeedChip, '연차')).selected,
          isTrue,
        );
        expect(find.text('세부 유형'), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.text('휴무 신청하기'));
        expect(find.text('휴무 신청하기'), findsOneWidget);

        // 닫기 단추로 닫힌다(시트 안에서 아래로 내렸으니 다시 올려서 누른다)
        await tester.ensureVisible(find.byTooltip('닫기'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('닫기'));
        await tester.pumpAndSettle();
        expect(find.text('휴무 신청'), findsNothing);
      });
    }
  }
}
