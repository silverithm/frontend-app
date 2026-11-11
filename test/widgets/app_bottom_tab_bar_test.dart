import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/widgets/common/app_bottom_tab_bar.dart';

/// B안 하단 탭 — 흰 바탕·위 옅은 선·높이 64, 고르면 채운 아이콘 + 틸, 배지, 화면 낭독기.
void main() {
  const items = [
    AppBottomTabItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: '홈'),
    AppBottomTabItem(icon: Icons.chat_bubble_outline_rounded, selectedIcon: Icons.chat_rounded, label: '채팅', badgeCount: 3),
    AppBottomTabItem(icon: Icons.calendar_month_outlined, selectedIcon: Icons.calendar_month_rounded, label: '일정'),
    AppBottomTabItem(icon: Icons.fact_check_outlined, selectedIcon: Icons.fact_check_rounded, label: '전자결재', badgeCount: 120),
    AppBottomTabItem(icon: Icons.grid_view_outlined, selectedIcon: Icons.grid_view_rounded, label: '전체'),
  ];

  Widget host({int current = 0, ValueChanged<int>? onTap, double textScale = 1.0}) => MaterialApp(
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: c!,
        ),
        home: Scaffold(
          bottomNavigationBar: AppBottomTabBar(
            items: items,
            currentIndex: current,
            onTap: onTap ?? (_) {},
          ),
        ),
      );

  testWidgets('높이 64, 고른 탭은 채운 아이콘 + 틸, 나머지는 선 아이콘 + 회색', (tester) async {
    await tester.pumpWidget(host(current: 1));
    // 위 선은 칸 위에 겹쳐 그린다(높이에 더하지 않음)
    expect(tester.getSize(find.byType(AppBottomTabBar)).height, 64);
    expect(tester.widget<Icon>(find.byIcon(Icons.chat_rounded)).color, AppSemanticColors.brandDefault);
    expect(find.byIcon(Icons.home_rounded), findsNothing);
    expect(tester.widget<Icon>(find.byIcon(Icons.home_outlined)).color, AppSemanticColors.iconSubtle);
    final chat = tester.widget<Text>(find.text('채팅'));
    expect(chat.style!.fontWeight, FontWeight.w700);
    expect(tester.widget<Text>(find.text('홈')).style!.fontWeight, FontWeight.w500);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('누르면 그 칸 번호를 알려 준다(칸 전체가 눌린다)', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(host(onTap: taps.add));
    await tester.tap(find.text('전자결재'));
    await tester.tapAt(tester.getTopLeft(find.byType(AppBottomTabBar)) + const Offset(10, 8));
    expect(taps, [3, 0]);
  });

  testWidgets('화면 낭독기 — 고른 탭·배지 건수를 읽는다', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(current: 0));
    expect(
      tester.getSemantics(find.bySemanticsLabel('채팅, 새 소식 3건')),
      matchesSemantics(
        label: '채팅, 새 소식 3건',
        hint: '탭 2/5',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('홈')),
      matchesSemantics(
        label: '홈',
        hint: '탭 1/5',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('360 폭 · 글자 1.6배에서도 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(current: 3, textScale: 1.6));
    expect(tester.takeException(), isNull);
  });
}
