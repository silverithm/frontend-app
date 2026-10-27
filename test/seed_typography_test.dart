import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/theme/app_typography.dart';
import 'package:frontend_app/widgets/common/app_tag.dart';
import 'package:frontend_app/widgets/seed/seed_callout.dart';
import 'package:frontend_app/widgets/seed/seed_list_cell.dart';

TextStyle _styleOf(WidgetTester t, String text) =>
    t.widget<Text>(find.text(text)).style!;

void main() {
  testWidgets('SeedListCell: 제목 titleMedium, 부제 bodySmall (글자 역할 표)', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: SeedListCell(title: '제목', description: '부제')),
    ));
    expect(_styleOf(t, '제목').fontSize, AppTypography.titleMedium.fontSize);
    expect(_styleOf(t, '제목').fontWeight, FontWeight.w600);
    expect(_styleOf(t, '부제').fontSize, AppTypography.bodySmall.fontSize);
  });

  testWidgets('SeedCallout info: 제목·본문은 파랑이 아니라 중립색', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SeedCallout(
            variant: SeedCalloutVariant.info, title: '안내', description: '내용'),
      ),
    ));
    final title = _styleOf(t, '안내');
    final body = _styleOf(t, '내용');
    expect(title.fontWeight, FontWeight.w600);
    expect(body.fontSize, 12);
    expect(title.color, isNot(body.color));
  });

  test('AppTag.labelStyle 은 11 / w600', () {
    expect(AppTag.labelStyle.fontSize, 11);
    expect(AppTag.labelStyle.fontWeight, FontWeight.w600);
  });
}
