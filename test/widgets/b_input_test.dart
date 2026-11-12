import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/widgets/common/app_input.dart';
import 'package:frontend_app/widgets/seed/seed_text_field.dart';

/// B안 입력칸 — 회색으로 채운 칸, 평소 테두리 없음, 포커스 틸 2px, 높이 48, 라벨 14/w600.
void main() {
  Widget host(Widget child, {double textScale = 1.0}) => MaterialApp(
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: c!,
        ),
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      );

  AnimatedContainer box(WidgetTester tester) => tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(SeedTextField),
          matching: find.byType(AnimatedContainer),
        ),
      );

  testWidgets('SeedTextField: 채운 칸·테두리 투명·높이 48, 포커스면 틸', (tester) async {
    await tester.pumpWidget(host(const Column(children: [
      SeedTextField(label: '반려 사유', placeholder: '예: 해당 주 근무 인원 부족'),
    ])));
    expect((box(tester).decoration as BoxDecoration).color, AppSemanticColors.fillDefault);
    final idle = (box(tester).foregroundDecoration as BoxDecoration).border as Border;
    expect(idle.top.color, AppColors.transparent);
    expect(
      tester.getSize(find.descendant(
        of: find.byType(SeedTextField),
        matching: find.byType(AnimatedContainer),
      )).height,
      48,
    );
    final label = tester.widget<Text>(find.text('반려 사유'));
    expect(label.style!.fontSize, 14);
    expect(label.style!.color, AppSemanticColors.textPrimary);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    final focused = (box(tester).foregroundDecoration as BoxDecoration).border as Border;
    expect(focused.top.color, AppSemanticColors.borderFocus);
    expect(focused.top.width, 2);
  });

  testWidgets('틀리면 빨강 테두리 + 14 안내, 뒤 아이콘은 48 칸', (tester) async {
    await tester.pumpWidget(host(Column(children: [
      SeedTextField(
        label: '비밀번호',
        errorText: '8자 이상 입력해주세요',
        obscureText: true,
        enableObscureToggle: true,
        suffixIcon: Icons.search,
        onSuffixIconTap: () {},
      ),
    ])));
    final border = (box(tester).foregroundDecoration as BoxDecoration).border as Border;
    expect(border.top.color, AppSemanticColors.statusErrorText);
    expect(tester.widget<Text>(find.text('8자 이상 입력해주세요')).style!.fontSize, 14);
    final eye = find.ancestor(
      of: find.byIcon(Icons.visibility_off_outlined),
      matching: find.byType(SizedBox),
    ).first;
    expect(tester.getSize(eye), const Size(48, 48));
  });

  testWidgets('AppInput: 채운 칸, 평소 테두리 없음', (tester) async {
    await tester.pumpWidget(host(const AppPasswordInput(label: '비밀번호')));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration!.filled, isTrue);
    expect(field.decoration!.fillColor, AppSemanticColors.fillDefault);
    expect(field.decoration!.enabledBorder!.borderSide, BorderSide.none);
    expect(tester.widget<Text>(find.text('비밀번호')).style!.fontSize, 14);
  });

  testWidgets('글자 1.6배에서도 넘치지 않는다', (tester) async {
    await tester.pumpWidget(host(
      const Column(children: [
        SeedTextField(label: '사유 (선택)', placeholder: '예: 가족 행사', maxLines: 3),
        SeedTextField(label: '이름', placeholder: '이름', size: SeedTextFieldSize.large),
      ]),
      textScale: 1.6,
    ));
    expect(tester.takeException(), isNull);
  });
}
