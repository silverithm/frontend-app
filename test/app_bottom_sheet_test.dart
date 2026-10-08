import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/theme/app_spacing.dart';
import 'package:frontend_app/widgets/common/app_dialog.dart';

Future<void> _open(WidgetTester tester, {String? title}) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => AppBottomSheet.show<void>(
            context,
            title: title,
            child: const SizedBox(height: 80, child: Text('본문')),
          ),
          child: const Text('열기'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('title을 주면 연한 틸 제목 띠와 아래 선, 손잡이가 그려진다', (tester) async {
    await _open(tester, title: '대화 검색');
    expect(find.text('대화 검색'), findsOneWidget);
    final strip = tester.widget<Container>(find
        .ancestor(of: find.text('대화 검색'), matching: find.byType(Container))
        .first);
    final deco = strip.decoration as BoxDecoration;
    expect(deco.color, AppSemanticColors.subheaderBackground);
    expect((deco.border as Border).bottom.color,
        AppSemanticColors.subheaderBorder);
    final handle = tester.getSize(find.byWidgetPredicate((w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).color ==
            AppSemanticColors.subheaderBorder &&
        (w.decoration as BoxDecoration).border == null));
    expect(handle, const Size(36, 4));
  });

  testWidgets('title이 없으면 띠 없이 손잡이만, 모서리는 16', (tester) async {
    await _open(tester);
    expect(find.text('본문'), findsOneWidget);
    final sheet = tester.widget<Container>(find
        .ancestor(of: find.text('본문'), matching: find.byType(Container))
        .last);
    expect(
        (sheet.decoration as BoxDecoration).borderRadius,
        const BorderRadius.vertical(top: Radius.circular(AppBorderRadius.xl2)));
  });
}
