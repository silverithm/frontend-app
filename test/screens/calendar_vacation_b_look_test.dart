import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/vacation_kind.dart';
import 'package:frontend_app/providers/auth_provider.dart';
import 'package:frontend_app/providers/vacation_provider.dart';
import 'package:frontend_app/theme/app_theme.dart';
import 'package:frontend_app/widgets/common/app_choice_grid.dart';
import 'package:frontend_app/widgets/common/app_sheet_frame.dart';
import 'package:frontend_app/widgets/seed/seed_chip.dart';
import 'package:frontend_app/widgets/vacation_calendar_widget.dart';
import 'package:frontend_app/widgets/vacation_request_dialog.dart';
import 'package:provider/provider.dart';

/// 묶음 ③ 일정·휴무 B안(2026-11-12) — 근무조정 달력과 휴무 신청 시트.
/// 좁은 폰(320)·보통 폰(390)에서 글자를 앱 최대(1.3배)까지 키워도 넘치지 않아야 한다.
/// (2026-11-14 크로박스식: 꽉 찬 달력·펼치기, 휴무 종류는 같은 폭 칸)
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
  body: VacationCalendarWidget(
    currentDate: DateTime(2026, 11),
    selectedDate: DateTime(2026, 11, 14),
    showSelection: false,
    expanded: false,
    sheetOpen: false,
    bodyHeight: 700,
    sheet: DraggableScrollableController(),
    sheetSplit: 0.55,
    onMoveMonth: (_) {},
    onToday: () {},
    onToggleExpanded: () {},
    onDayTap: (_) {},
    onRoleFiltersChanged: (_) {},
  ),
);

/// 펼치기를 누르면 실제로 펼쳐지게 — 화면(calendar_screen)이 들고 있는 상태를 흉내 낸다.
class _ExpandableCalendar extends StatefulWidget {
  const _ExpandableCalendar();

  @override
  State<_ExpandableCalendar> createState() => _ExpandableCalendarState();
}

class _ExpandableCalendarState extends State<_ExpandableCalendar> {
  bool _expanded = false;
  final _sheet = DraggableScrollableController();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: VacationCalendarWidget(
      currentDate: DateTime(2026, 11),
      selectedDate: DateTime(2026, 11, 14),
      showSelection: false,
      expanded: _expanded,
      sheetOpen: false,
      bodyHeight: 700,
      sheet: _sheet,
      sheetSplit: 0.55,
      onMoveMonth: (_) {},
      onToday: () {},
      onToggleExpanded: () => setState(() => _expanded = !_expanded),
      onDayTap: (_) {},
      onRoleFiltersChanged: (_) {},
    ),
  );
}

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
    // 앱 전체 글자 상한이 1.3배다(theme/text_scale.dart)
    for (final scale in [1.0, 1.3]) {
      testWidgets('근무조정 달력 — 폭 $width · 글자 $scale배, 꽉 찬 판·펼침 모두 넘치지 않는다', (
        tester,
      ) async {
        await _pumpApp(
          tester,
          width: width,
          textScale: scale,
          home: _calendarHome(),
        );
        expect(tester.takeException(), isNull);
        // 크로박스식 머리줄 — 큰 달 이름 + 연도, 이동 단추, 오늘
        expect(find.text('11월'), findsOneWidget);
        expect(find.text('2026년'), findsOneWidget);
        expect(find.byTooltip('이전 달'), findsOneWidget);
        expect(find.byTooltip('다음 달'), findsOneWidget);
        expect(find.text('오늘'), findsOneWidget);
        // 직종 거르기는 거르기 칩, '전체'가 골라져 있다
        final all = find.widgetWithText(SeedChip, '전체');
        expect(all, findsOneWidget);
        expect(tester.widget<SeedChip>(all).selected, isTrue);
        // 이번 달 날짜가 다 있다(30일) — 다음 달 1~5일은 흐리게 따로
        expect(find.text('30'), findsOneWidget);

        // 펼치기 — 좁은 폭·큰 글씨에선 아이콘만 남는다
        await _pumpApp(
          tester,
          width: width,
          textScale: scale,
          home: const _ExpandableCalendar(),
        );
        await tester.tap(find.byIcon(Icons.unfold_more_rounded));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.unfold_less_rounded), findsOneWidget);
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

        // 종류는 같은 폭 칸 — 연차를 고르면 세부 유형이 사라진다(예전과 같은 규칙)
        expect(find.byType(AppChoiceGrid<VacationKind>), findsOneWidget);
        await tester.ensureVisible(find.text('연차'));
        await tester.tap(find.text('연차'));
        await tester.pump();
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
