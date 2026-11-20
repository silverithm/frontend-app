import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/widgets/common/app_notice_toasts.dart';
import 'package:frontend_app/widgets/calendar/calendar_top_bar.dart';
import 'package:frontend_app/widgets/calendar/role_filter_sheet.dart';
import 'package:frontend_app/widgets/common/main_tab_visibility.dart';

/// 일정 탭 초록 띠 한 줄 머리 · 근무조정 안내 알림 카드 · 직종 시트(2026-11-15).
void main() {
  Widget host(Widget child, {double width = 390, double scale = 1}) =>
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 800),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: ColoredBox(
              color: AppSemanticColors.headerBackground,
              child: SizedBox(width: width, child: child),
            ),
          ),
        ),
      );

  group('한 줄 머리', () {
    for (final width in [320.0, 360.0, 390.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('폭 $width · 글자 $scale배 — 넘치지 않고 한 줄에 다 있다', (tester) async {
          final controller = TabController(length: 2, vsync: const TestVSync());
          addTearDown(controller.dispose);
          await tester.pumpWidget(host(
            CalendarOneLineHeader(
              month: DateTime(2026, 11),
              subtitle: '2026년',
              controller: controller,
              filterActive: false,
              filterTooltip: '직종으로 보기',
              onFilter: () {},
              expanded: false,
              onToggleExpanded: () {},
              onToday: () {},
              onPrevious: () {},
              onNext: () {},
            ),
            width: width,
            scale: scale,
          ));
          expect(tester.takeException(), isNull);
          final items = [
            find.text('11월'),
            find.text('근무'),
            find.text('일정'),
            find.byTooltip('직종으로 보기'),
            find.byTooltip('펼치기'),
            find.text('오늘'),
          ];
          final rowCenter = tester.getCenter(find.text('근무')).dy;
          for (final f in items) {
            expect(f, findsOneWidget);
            // 같은 줄 — 세로 가운데가 크게 다르지 않다
            expect((tester.getCenter(f).dy - rowCenter).abs(), lessThan(14));
            expect(tester.getRect(f).right, lessThanOrEqualTo(width + 0.5));
          }
          // 옛 ‹ › 단추는 없다(좌우로 쓸어 넘긴다)
          expect(find.byTooltip('이전 달'), findsNothing);
        });
      }
    }

    testWidgets('근무|일정은 화면 읽기에 원래 이름으로, 펼치기·필터는 켜짐이 읽힌다', (tester) async {
      final controller = TabController(length: 2, vsync: const TestVSync());
      addTearDown(controller.dispose);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host(
        CalendarOneLineHeader(
          month: DateTime(2026, 11),
          subtitle: '요양보호사',
          controller: controller,
          filterActive: true,
          filterTooltip: '직종으로 보기',
          onFilter: () {},
          expanded: true,
          onToggleExpanded: () {},
          onToday: () {},
          onPrevious: () {},
          onNext: () {},
        ),
      ));
      expect(find.bySemanticsLabel('근무조정'), findsOneWidget);
      expect(find.bySemanticsLabel('월간일정'), findsOneWidget);
      expect(find.bySemanticsLabel('직종으로 보기, 켜짐'), findsOneWidget);
      expect(find.bySemanticsLabel('접기, 켜짐'), findsOneWidget);
      expect(find.text('요양보호사'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('일정을 누르면 탭이 바뀌고, 오늘·필터·펼치기가 불린다', (tester) async {
      final controller = TabController(length: 2, vsync: const TestVSync());
      addTearDown(controller.dispose);
      var today = 0, filter = 0, expand = 0;
      await tester.pumpWidget(host(
        CalendarOneLineHeader(
          month: DateTime(2026, 11),
          subtitle: '2026년',
          controller: controller,
          filterActive: false,
          filterTooltip: '일정 필터',
          onFilter: () => filter++,
          expanded: false,
          onToggleExpanded: () => expand++,
          onToday: () => today++,
          onPrevious: () {},
          onNext: () {},
        ),
      ));
      await tester.tap(find.text('일정'));
      await tester.pumpAndSettle();
      expect(controller.index, 1);
      await tester.tap(find.text('오늘'));
      await tester.tap(find.byTooltip('일정 필터'));
      await tester.tap(find.byTooltip('펼치기'));
      expect([today, filter, expand], [1, 1, 1]);
    });
  });

  group('안내 알림 카드(AppNoticeHost)', () {
    const a = AppNotice(
      icon: Icons.event_available_rounded,
      background: Color(0xFFE8F1FF),
      iconColor: Color(0xFF2563EB),
      title: '2026년 12월 휴무만 신청할 수 있어요',
      description: '다른 달 휴무가 필요하면 관리자에게 말씀해주세요.',
    );
    const b = AppNotice(
      icon: Icons.event_busy_rounded,
      background: Color(0xFFFDECEC),
      iconColor: Color(0xFFDC2626),
      title: '11월 휴무 신청이 10월 20일에 마감됐어요',
      description: '마감을 놓친 휴무는 관리자에게 직접 문의해주세요.',
    );

    Widget host({bool visible = true, bool tabVisible = true}) => MaterialApp(
      home: Scaffold(
        body: MainTabVisibility(
          visible: tabVisible,
          child: AppNoticeHost(
            noticeKey: 'test-2026-11',
            visible: visible,
            notices: const [a, b],
            child: const Placeholder(),
          ),
        ),
      ),
    );

    // 라이브러리는 다음 장면 뒤에 카드를 끼우고 내려온다
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    setUp(AppNoticeHost.resetClosed);

    testWidgets('겹쳐 쌓여 맨 앞 한 장만 보이고, 누르면 펼치고, X는 한 장씩, 8초 뒤 들어간다', (tester) async {
      await tester.pumpWidget(host());
      await settle(tester);
      // 접힌 더미 — 맨 앞(첫 안내)만 글이 보이고 뒤 카드는 종이만 비친다
      expect(find.text(a.title), findsOneWidget);
      expect(find.text(b.title), findsNothing);
      expect(find.text('+1'), findsOneWidget);

      // 누르면 펼쳐 두 장이 위아래로, 첫 안내가 위
      await tester.tap(find.text(a.title));
      await settle(tester);
      expect(find.text(b.title), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(a.title)).dy,
        lessThan(tester.getTopLeft(find.text(b.title)).dy),
      );
      // 펼쳐 둔 동안은 저절로 들어가지 않는다
      await tester.pump(const Duration(seconds: 9));
      await settle(tester);
      expect(find.text(a.title), findsOneWidget);

      // 첫 카드의 X — 그 카드만 닫히고 남은 한 장은 '+1' 없이
      await tester.tap(find.byTooltip('안내 닫기').first);
      await settle(tester);
      expect(find.text(a.title), findsNothing);
      expect(find.text(b.title), findsOneWidget);
      expect(find.text('+1'), findsNothing);

      // 접힌 뒤 손대지 않으면 8초 뒤 남은 카드도 들어간다
      await tester.pump(const Duration(seconds: 9));
      await settle(tester);
      expect(find.text(b.title), findsNothing);

      // 다시 열면 X로 닫은 안내는 안 뜨고, 8초에 들어간 안내만 다시 뜬다
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
      await tester.pumpWidget(host());
      await settle(tester);
      expect(find.text(a.title), findsNothing);
      expect(find.text(b.title), findsOneWidget);

      // 하단 탭에서 가려지면 걷는다
      await tester.pumpWidget(host(tabVisible: false));
      await settle(tester);
      expect(find.text(b.title), findsNothing);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('옆으로 밀면 더미가 통째로 닫히고 다시 띄우지 않는다', (tester) async {
      await tester.pumpWidget(host());
      await settle(tester);
      await tester.drag(find.text(a.title), const Offset(500, 0));
      await settle(tester);
      expect(find.text(a.title), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
      await tester.pumpWidget(host());
      await settle(tester);
      expect(find.text(a.title), findsNothing);
      expect(find.text(b.title), findsNothing);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('visible이 false면 띄우지 않는다', (tester) async {
      await tester.pumpWidget(host(visible: false));
      await settle(tester);
      expect(find.text(a.title), findsNothing);
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('직종 시트', () {
    testWidgets('칩을 누르면 바로 걸리고, 전체는 모두 푼다', (tester) async {
      List<String>? last;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showRoleFilterSheet(
                context,
                roles: const ['CAREGIVER', 'OFFICE'],
                selected: const [],
                onChanged: (v) => last = v,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.text('직종으로 보기'), findsOneWidget);
      await tester.tap(find.text('요양보호사'));
      await tester.pump();
      expect(last, ['caregiver']);
      await tester.tap(find.text('전체'));
      await tester.pump();
      expect(last, isEmpty);
      expect(roleFilterButtonLabel(const []), '직종 전체');
      expect(roleFilterButtonLabel(const ['caregiver', 'office']), '요양보호사 외 1');
    });
  });

  testWidgets('하단 탭 보임 신호 — 묶음 밖이면 보이는 것으로 본다', (tester) async {
    late bool seen;
    Widget probe() => Builder(
      builder: (context) {
        seen = MainTabVisibility.of(context);
        return const SizedBox();
      },
    );
    await tester.pumpWidget(probe());
    expect(seen, isTrue);
    await tester.pumpWidget(MainTabVisibility(visible: false, child: probe()));
    expect(seen, isFalse);
  });
}
