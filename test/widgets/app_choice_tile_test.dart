import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/widgets/common/app_choice_tile.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 120, child: child))));

  testWidgets('B안: 고르면 틸 바탕 + 흰 글자, 테두리 없음 — 의미 색은 고르기 전 아이콘에만', (tester) async {
    Future<BoxDecoration> deco(bool selected) async {
      await tester.pumpWidget(wrap(AppChoiceTile(
        label: '긴급',
        icon: Icons.priority_high,
        selected: selected,
        accentColor: AppSemanticColors.statusErrorIcon,
        onTap: () {},
      )));
      return tester.widget<AnimatedContainer>(find.descendant(
        of: find.byType(AppChoiceTile),
        matching: find.byType(AnimatedContainer),
      )).decoration! as BoxDecoration;
    }

    final on = await deco(true);
    expect(on.color, AppSemanticColors.brandDefault);
    expect(on.border, isNull);
    expect(tester.widget<Icon>(find.byIcon(Icons.priority_high)).color,
        AppSemanticColors.textInverse);

    final off = await deco(false);
    expect(off.color, AppSemanticColors.fillDefault);
    expect(tester.widget<Icon>(find.byIcon(Icons.priority_high)).color,
        AppSemanticColors.statusErrorIcon);
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
