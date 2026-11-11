import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/dispatch.dart';
import 'package:frontend_app/utils/dispatch_algorithm.dart';
import 'package:frontend_app/widgets/dispatch/dispatch_calendar_view.dart';

/// 배차 달력 — 칸 높이를 못 박지 않았으니 글자를 1.3배로 키우고 좁은 폰(360)에서
/// 이름을 펼쳐도 넘치지 않아야 한다(B안, 2026-11-12).
Map<String, DispatchDaySummary> _summary(DateTime month) {
  final map = <String, DispatchDaySummary>{};
  final days = DateTime(month.year, month.month + 1, 0).day;
  for (var day = 1; day <= days; day++) {
    final date = DateTime(month.year, month.month, day);
    final key = formatDate(date);
    map[key] = DispatchDaySummary(
      date: key,
      normalCount: 5,
      substituteCount: day % 3 == 0 ? 2 : 0,
      noServiceCount: day % 4 == 0 ? 4 : 0,
      totalRoutes: 6,
      isHoliday: date.weekday == DateTime.sunday,
      driverNames: const ['김하늘', '박바다', '이구름', '최별빛', '정노을'],
    );
  }
  return map;
}

Future<void> _pump(
  WidgetTester tester, {
  required double textScale,
  required bool expanded,
}) async {
  tester.view.physicalSize = const Size(360 * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final month = DateTime(2026, 11);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 1600),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DispatchCalendarView(
                month: month,
                summary: _summary(month),
                subtitle: '등원 3 · 하원 3 · 어르신 24',
                isExpanded: expanded,
                onToggleExpanded: () {},
                onDateSelected: (_) {},
                onPreviousMonth: () {},
                onNextMonth: () {},
                onToday: () {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final scale in [1.0, 1.3]) {
    for (final expanded in [false, true]) {
      testWidgets('글자 $scale배 · ${expanded ? '펼침' : '접힘'} — 넘치지 않는다', (
        tester,
      ) async {
        await _pump(tester, textScale: scale, expanded: expanded);

        expect(tester.takeException(), isNull);
        expect(find.text('2026년 11월'), findsOneWidget);
        // 일요일은 휴무로 적힌다
        expect(find.text('휴무'), findsWidgets);
        if (expanded) expect(find.text('+2'), findsWidgets);
      });
    }
  }

  testWidgets('날짜 칸을 누르면 그 날짜를 넘긴다', (tester) async {
    DateTime? picked;
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final month = DateTime(2026, 11);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              DispatchCalendarView(
                month: month,
                summary: _summary(month),
                onToggleExpanded: () {},
                onDateSelected: (date) => picked = date,
                onPreviousMonth: () {},
                onNextMonth: () {},
                onToday: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('12'));
    expect(picked, DateTime(2026, 11, 12));
  });
}
