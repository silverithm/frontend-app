import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/theme/app_theme.dart';

/// 화면마다 색을 지정하지 않아도 상단 바가 틸 바탕으로 그려지는지.
/// 예전엔 테마가 연결돼 있지 않아 화면마다 흰색·진한 틸을 제각각 덮어썼다.
/// B안(2026-11-12): 틸은 남기고 아래 선은 없앴다, 높이 56, 안쪽 화면 제목 17/w600.
void main() {
  testWidgets('색을 지정하지 않은 AppBar는 앱 공통 상단 바 색을 쓴다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.withAppChrome(ThemeData()),
        home: Scaffold(
          appBar: AppBar(title: const Text('공지사항')),
        ),
      ),
    );

    final material = tester.widget<Material>(
      find.descendant(of: find.byType(AppBar), matching: find.byType(Material)).first,
    );
    expect(material.color, AppSemanticColors.headerBackground);
    // B안: 아래 선 없음
    expect(material.shape, isNull);
    expect(tester.getSize(find.byType(AppBar)).height, 56);

    final title = tester.widget<DefaultTextStyle>(
      find
          .ancestor(of: find.text('공지사항'), matching: find.byType(DefaultTextStyle))
          .first,
    );
    expect(title.style.color, AppSemanticColors.headerForeground);
    expect(title.style.fontSize, 17);
    expect(title.style.fontWeight, FontWeight.w600);
  });

  testWidgets('자동으로 생기는 뒤로 단추는 꺾쇠 모양이다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.withAppChrome(ThemeData()),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => Scaffold(appBar: AppBar(title: const Text('상세'))),
              )),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
  });

  testWidgets('스크롤해도 상단 바 색과 그림자가 바뀌지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.withAppChrome(ThemeData()),
        home: Scaffold(
          appBar: AppBar(title: const Text('채팅')),
          body: ListView(
            children: [for (var i = 0; i < 50; i++) ListTile(title: Text('$i'))],
          ),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    final material = tester.widget<Material>(
      find.descendant(of: find.byType(AppBar), matching: find.byType(Material)).first,
    );
    expect(material.color, AppSemanticColors.headerBackground);
    expect(material.elevation, 0);
  });

  testWidgets('상단 바 제목은 기본으로 가운데 정렬된다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.withAppChrome(ThemeData(platform: TargetPlatform.android)),
        home: Scaffold(appBar: AppBar(title: const Text('공지사항'))),
      ),
    );
    final center = tester.getCenter(find.text('공지사항')).dx;
    expect(center, closeTo(tester.view.physicalSize.width / tester.view.devicePixelRatio / 2, 1));
  });
}
