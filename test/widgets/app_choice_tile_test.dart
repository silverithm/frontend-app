import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/widgets/common/app_choice_tile.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 120, child: child))));

  testWidgets('선택 타일은 brandWeak 바탕과 틸 1.5px 테두리 — 의미 색을 줘도 테두리는 틸', (tester) async {
    await tester.pumpWidget(wrap(AppChoiceTile(
      label: '긴급',
      icon: Icons.priority_high,
      selected: true,
      accentColor: AppSemanticColors.statusErrorIcon,
      onTap: () {},
    )));
    final box = tester.widget<Container>(find.descendant(
      of: find.byType(AppChoiceTile),
      matching: find.byType(Container),
    ).first);
    final deco = box.decoration as BoxDecoration;
    expect(deco.color, AppSemanticColors.brandWeak);
    final border = deco.border as Border;
    expect(border.top.color, AppSemanticColors.interactivePrimaryDefault);
    expect(border.top.width, 1.5);
  });

  testWidgets('선택 전후로 라벨 굵기가 같다', (tester) async {
    Future<FontWeight?> weight(bool selected) async {
      await tester.pumpWidget(wrap(AppChoiceTile(
        label: '일반',
        icon: Icons.info_outline,
        selected: selected,
        onTap: () {},
      )));
      return tester.widget<Text>(find.text('일반')).style?.fontWeight;
    }
    expect(await weight(true), await weight(false));
  });

  testWidgets('탭하면 onTap이 불린다', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(wrap(AppChoiceTile(
      label: '낮음',
      icon: Icons.arrow_downward,
      selected: false,
      onTap: () => tapped++,
    )));
    await tester.tap(find.text('낮음'));
    expect(tapped, 1);
  });
}
