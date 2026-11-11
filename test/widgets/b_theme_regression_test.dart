// B안 테마를 앱 전체에 건 뒤 캡처에서 잡힌 두 가지를 못 박는다 (2026-11-12).
//
// 1) 글꼴 — ListTile 제목·FAB 글자·대화상자 제목처럼 테마가 글자 모양을 통째로 건네는 자리는
//    DefaultTextStyle을 물려받지 않는다. 토큰에 서체가 없으면 그 자리만 기기 기본 서체로 그려져
//    글꼴이 섞인다(2026-09-08 제보 "폰트가 제각각"과 같은 증상).
// 2) 칸 안의 칸 — 테마가 상태별 테두리를 걸면 `border: InputBorder.none`인 칸에도 테두리가 생긴다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/theme/app_theme.dart';
import 'package:frontend_app/theme/app_typography.dart';
import 'package:frontend_app/widgets/seed/seed_text_field.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.withAppChrome(ThemeData()),
      home: Scaffold(body: child),
    );

String? _familyOf(WidgetTester tester, String text) {
  final rich = tester.widget<RichText>(
    find.descendant(of: find.text(text), matching: find.byType(RichText)),
  );
  return rich.text.style?.fontFamily;
}

void main() {
  test('글자 토큰은 모두 앱 서체를 직접 가진다', () {
    const tokens = <TextStyle>[
      AppTypography.heading1,
      AppTypography.heading2,
      AppTypography.heading3,
      AppTypography.heading4,
      AppTypography.heading5,
      AppTypography.heading6,
      AppTypography.appBarTitle,
      AppTypography.appBarTitleLarge,
      AppTypography.titleMedium,
      AppTypography.titleSmall,
      AppTypography.labelStrong,
      AppTypography.bodyLarge,
      AppTypography.bodyMedium,
      AppTypography.bodySmall,
      AppTypography.labelLarge,
      AppTypography.labelMedium,
      AppTypography.labelSmall,
      AppTypography.buttonLarge,
      AppTypography.buttonMedium,
      AppTypography.buttonSmall,
      AppTypography.caption,
      AppTypography.overline,
    ];
    for (final token in tokens) {
      expect(token.fontFamily, AppTypography.fontFamilySans);
    }
  });

  testWidgets('ListTile 제목·부제와 FAB 글자도 앱 서체로 그려진다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.withAppChrome(ThemeData()),
      home: Scaffold(
        body: const ListTile(title: Text('푸시 알림 받기'), subtitle: Text('휴대폰으로 받습니다')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {},
          label: const Text('업무 등록'),
        ),
      ),
    ));
    expect(_familyOf(tester, '푸시 알림 받기'), AppTypography.fontFamilySans);
    expect(_familyOf(tester, '휴대폰으로 받습니다'), AppTypography.fontFamilySans);
    expect(_familyOf(tester, '업무 등록'), AppTypography.fontFamilySans);
  });

  testWidgets('SeedTextField 안쪽 칸에는 테마 테두리·여백이 다시 붙지 않는다', (tester) async {
    await tester.pumpWidget(_app(const SeedTextField(label: '채팅방 이름', placeholder: '입력하세요')));
    final decorator = tester.widget<InputDecorator>(find.byType(InputDecorator));
    final decoration = decorator.decoration;
    expect(decoration.enabledBorder, InputBorder.none);
    expect(decoration.focusedBorder, InputBorder.none);
    expect(decoration.contentPadding, EdgeInsets.zero);
    expect(decoration.filled, isFalse);
  });

  testWidgets('화면이 테두리를 뺀 맨 TextField는 어느 상태에서도 테두리가 없다', (tester) async {
    await tester.pumpWidget(_app(const TextField(
      decoration: InputDecoration(border: InputBorder.none, hintText: '메시지를 입력하세요'),
    )));
    final decoration = tester.widget<InputDecorator>(find.byType(InputDecorator)).decoration;
    expect(decoration.enabledBorder, isNull);
    expect(decoration.focusedBorder, isNull);
    expect(decoration.border, InputBorder.none);
  });
}
