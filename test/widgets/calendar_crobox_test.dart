import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/approval.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/widgets/approval/approval_line_stepper.dart';
import 'package:frontend_app/widgets/calendar/month_chip_grid.dart';
import 'package:frontend_app/widgets/common/app_choice_grid.dart';

/// 크로박스식 달력·결재 단계·고르기 칸(2026-11-14).
void main() {
  Widget host(Widget child, {Size size = const Size(390, 700), double scale = 1}) =>
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: SizedBox(width: size.width, height: size.height, child: child)),
        ),
      );

  CalendarChipData chip(String name) =>
      CalendarChipData(label: name, color: AppColors.green200);

  MonthChipGrid grid({
    required List<CalendarChipData> Function(DateTime) chipsFor,
    bool expanded = false,
    double bodyHeight = 700,
    ValueChanged<DateTime>? onTapDay,
    ValueChanged<int>? onSwipeMonth,
    Widget? Function(DateTime)? footerFor,
  }) =>
      MonthChipGrid(
        month: DateTime(2026, 11),
        selected: DateTime(2026, 11, 14),
        showSelection: false,
        expanded: expanded,
        chipsFor: chipsFor,
        onTapDay: onTapDay ?? (_) {},
        onSwipeMonth: onSwipeMonth ?? (_) {},
        bodyHeight: bodyHeight,
        sheet: DraggableScrollableController(),
        sheetSplit: 0.55,
        sheetOpen: false,
        footerFor: footerFor,
      );

  group('꽉 찬 달력', () {
    testWidgets('칸에 다 안 들어가면 앞쪽 이름 + +n, 펼치면 전부', (tester) async {
      final names = ['가나다', '라마바', '사아자', '차카타', '파하가'];
      List<CalendarChipData> chipsFor(DateTime d) =>
          d.day == 10 ? [for (final n in names) chip(n)] : const [];

      await tester.pumpWidget(host(grid(chipsFor: chipsFor)));
      expect(tester.takeException(), isNull);
      expect(find.text('가나다'), findsOneWidget);
      expect(find.text('파하가'), findsNothing);
      expect(find.textContaining('+'), findsOneWidget);

      await tester.pumpWidget(host(grid(chipsFor: chipsFor, expanded: true)));
      expect(tester.takeException(), isNull);
      for (final n in names) {
        expect(find.text(n), findsOneWidget);
      }
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('작은 폰(360x640)에서도 마지막 주까지 넘겨 볼 수 있다', (tester) async {
      await tester.pumpWidget(host(
        grid(chipsFor: (_) => const [], bodyHeight: 330),
        size: const Size(360, 330),
      ));
      expect(tester.takeException(), isNull);
      // 다 안 들어가 위아래로 넘긴다
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('30'), findsOneWidget);
      expect(tester.getRect(find.text('30')).bottom, lessThanOrEqualTo(330));
    });

    testWidgets('칸에 한 줄밖에 안 들어가면 첫 이름과 +n을 한 칩에', (tester) async {
      await tester.pumpWidget(host(
        grid(
          chipsFor: (d) => d.day == 10 ? [chip('가나다'), chip('라마바'), chip('사아자')] : const [],
          bodyHeight: 330,
        ),
        size: const Size(360, 330),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('가나다'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('라마바'), findsNothing);
    });

    testWidgets('날짜를 누르면 그 날, 앞뒤 달 날짜를 누르면 그 달 날짜를 알린다', (tester) async {
      DateTime? tapped;
      await tester.pumpWidget(host(grid(chipsFor: (_) => const [], onTapDay: (d) => tapped = d)));
      await tester.tap(find.text('15'));
      expect(tapped, DateTime(2026, 11, 15));
      // 11월 30일 다음 칸은 12월 1일(흐리게)
      await tester.tap(find.text('5').last);
      expect(tapped!.month, 12);
    });

    testWidgets('좌우로 쓸면 달이 바뀐다', (tester) async {
      int? moved;
      await tester.pumpWidget(host(grid(chipsFor: (_) => const [], onSwipeMonth: (d) => moved = d)));
      await tester.fling(find.text('15'), const Offset(-300, 0), 1200);
      await tester.pumpAndSettle();
      expect(moved, 1);
      await tester.fling(find.text('15'), const Offset(300, 0), 1200);
      await tester.pumpAndSettle();
      expect(moved, -1);
    });

    testWidgets('칸 맨 아래 한 줄(인원/한도)은 이름 칩과 겹치지 않는다', (tester) async {
      await tester.pumpWidget(host(grid(
        chipsFor: (d) => d.day == 10 ? [chip('가나다'), chip('라마바'), chip('사아자')] : const [],
        footerFor: (d) => d.day == 10 ? const Text('3/2') : null,
      )));
      expect(tester.takeException(), isNull);
      final footer = tester.getRect(find.text('3/2'));
      for (final n in ['가나다', '라마바', '사아자']) {
        final f = find.text(n);
        if (f.evaluate().isEmpty) continue;
        expect(tester.getRect(f).bottom, lessThanOrEqualTo(footer.top + 1));
      }
    });

    testWidgets('칸 안 글자는 폰 글자 배율과 상관없이 같은 크기다', (tester) async {
      await tester.pumpWidget(host(
        grid(chipsFor: (d) => d.day == 10 ? [chip('가나다')] : const []),
        scale: 1.3,
      ));
      final text = tester.widget<Text>(find.text('가나다'));
      final scaler = MediaQuery.textScalerOf(tester.element(find.text('가나다')));
      expect(scaler.scale(text.style!.fontSize!), text.style!.fontSize);
    });
  });

  group('결재 단계', () {
    ApprovalStepModel step(int order, String name, String status, {String role = 'REVIEWER'}) =>
        ApprovalStepModel.fromJson({
          'id': order,
          'stepOrder': order,
          'approverType': 'MEMBER',
          'approverId': '$order',
          'approverName': name,
          'roleLabel': role,
          'status': status,
          if (status == 'APPROVED') 'processedAt': '2026-11-12T10:00:00',
        });

    testWidgets('끝난 단계·지금 차례·남은 단계', (tester) async {
      await tester.pumpWidget(host(ApprovalLineStepper(
        requesterName: '조은비',
        requestedAt: DateTime(2026, 11, 13),
        steps: [
          step(1, '한소연', 'APPROVED'),
          step(2, '김관리', 'PENDING', role: 'FINAL'),
        ],
      )));
      expect(tester.takeException(), isNull);
      expect(find.text('기안'), findsOneWidget);
      expect(find.text('검토'), findsOneWidget);
      expect(find.text('결재'), findsOneWidget);
      expect(find.text('지금 차례'), findsOneWidget);
      expect(find.text('11/12'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    });

    testWidgets('반려되면 그 단계가 반려, 뒤 단계는 대기', (tester) async {
      await tester.pumpWidget(host(ApprovalLineStepper(
        requesterName: '박지훈',
        requestedAt: DateTime(2026, 11, 6),
        steps: [
          step(1, '한소연', 'REJECTED'),
          step(2, '김관리', 'PENDING', role: 'FINAL'),
        ],
      )));
      expect(find.text('반려'), findsOneWidget);
      expect(find.text('지금 차례'), findsNothing);
      expect(find.text('대기'), findsOneWidget);
    });
  });

  group('고르기 칸', () {
    testWidgets('같은 폭으로 줄 세우고, 누르면 고른 값을 알린다', (tester) async {
      String? picked;
      await tester.pumpWidget(host(Padding(
        padding: const EdgeInsets.all(16),
        child: AppChoiceGrid<String>(
          values: const ['일반휴무', '필수휴무', '대체휴무', '연차', '오전반차'],
          selected: '일반휴무',
          labelOf: (v) => v,
          onSelected: (v) => picked = v,
        ),
      )));
      final a = tester.getSize(find.ancestor(of: find.text('일반휴무'), matching: find.byType(AnimatedContainer)));
      final b = tester.getSize(find.ancestor(of: find.text('연차'), matching: find.byType(AnimatedContainer)));
      expect(a.width, closeTo(b.width, 0.5));
      expect(a.height, greaterThanOrEqualTo(48));
      await tester.tap(find.text('오전반차'));
      expect(picked, '오전반차');
    });
  });
}
