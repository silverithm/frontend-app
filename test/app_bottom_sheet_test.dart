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
  // B안(2026-11-12): 제목 띠·아래 선 없이 제목 17/w700(글자 단계 '제목', 2026-11-14), 손잡이 40×5, 위 모서리 24.
  testWidgets('title을 주면 띠 없이 큰 제목, 손잡이 40×5', (tester) async {
    await _open(tester, title: '대화 검색');
    final title = tester.widget<Text>(find.text('대화 검색'));
    expect(title.style!.fontSize, 17);
    expect(title.style!.fontWeight, FontWeight.w700);
    // 제목 둘레에 색 띠(바탕색 있는 Container)가 없다
    final tinted = find.ancestor(
      of: find.text('대화 검색'),
      matching: find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == AppSemanticColors.subheaderBackground),
    );
    expect(tinted, findsNothing);
    final handle = tester.getSize(find.byWidgetPredicate((w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).color == AppSemanticColors.sheetHandle));
    expect(handle, const Size(40, 5));
  });

  testWidgets('title이 없으면 손잡이만, 모서리는 24', (tester) async {
    await _open(tester);
    expect(find.text('본문'), findsOneWidget);
    final sheet = tester.widget<Container>(find
        .ancestor(of: find.text('본문'), matching: find.byType(Container))
        .last);
    expect(
        (sheet.decoration as BoxDecoration).borderRadius,
        const BorderRadius.vertical(top: Radius.circular(AppBorderRadius.sheet)));
  });
}
