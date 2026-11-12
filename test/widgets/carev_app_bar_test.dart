import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/theme/app_theme.dart';
import 'package:frontend_app/widgets/common/carev_app_bar.dart';

/// B안 상단 바 — 탭 첫 화면은 왼쪽 20/w700, 안쪽 화면은 꺾쇠 + 가운데 18/w600, 높이 56.
void main() {
  Widget app(Widget home) => MaterialApp(
        theme: AppTheme.withAppChrome(ThemeData(platform: TargetPlatform.android)),
        home: home,
      );

  testWidgets('탭 첫 화면: 왼쪽 큰 제목, 뒤로 없음, 높이 56', (tester) async {
    await tester.pumpWidget(app(const Scaffold(
      appBar: CareVAppBar(title: '전체', isRoot: true),
    )));
    final text = tester.widget<Text>(find.text('전체'));
    expect(text.style!.fontSize, 20);
    expect(text.style!.fontWeight, FontWeight.w700);
    expect(text.style!.color, AppSemanticColors.headerForeground);
    expect(tester.getTopLeft(find.text('전체')).dx, 20);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    expect(tester.getSize(find.byType(AppBar)).height, 56);
  });

  testWidgets('안쪽 화면: 꺾쇠 뒤로 + 가운데 18/w600 + 작은 부제', (tester) async {
    await tester.pumpWidget(app(Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const Scaffold(
              appBar: CareVAppBar(title: '요양보호사 1팀', subtitle: '6명'),
            ),
          )),
          child: const Text('열기'),
        ),
      ),
    )));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.text('요양보호사 1팀'));
    expect(text.style!.fontSize, 18);
    expect(text.style!.fontWeight, FontWeight.w600);
    expect(find.text('6명'), findsOneWidget);
    final width = tester.getSize(find.byType(AppBar)).width;
    expect(tester.getCenter(find.text('요양보호사 1팀')).dx, closeTo(width / 2, 1));

    // 뒤로 단추: 꺾쇠, 48 터치, 누르면 돌아간다
    final back = find.byIcon(Icons.chevron_left_rounded);
    expect(back, findsOneWidget);
    final button = find.ancestor(of: back, matching: find.byType(IconButton));
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.text('열기'), findsOneWidget);
  });

  testWidgets('글자 크게(1.6배)에서도 제목이 넘치지 않고 말줄임', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.withAppChrome(ThemeData()),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.6)),
        child: child!,
      ),
      home: Scaffold(
        appBar: CareVAppBar(
          title: '아주 긴 제목이 들어가는 화면입니다 아주 긴 제목',
          isRoot: true,
          actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.add))],
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
  });
}
