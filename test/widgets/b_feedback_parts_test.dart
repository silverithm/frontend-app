import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/widgets/common/app_empty_state.dart';
import 'package:frontend_app/widgets/common/app_snackbar.dart';
import 'package:frontend_app/widgets/seed/seed_button.dart';

/// B안 알림 띠·빈 화면.
void main() {
  testWidgets('알림 띠 — 짙은 반투명 바탕·흰 글자·모서리 14, 뜻은 아이콘 색으로', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        return const SizedBox.expand();
      })),
    ));
    AppSnackBar.showError(ctx, message: '저장하지 못했습니다', haptic: false);
    await tester.pump();
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.backgroundColor, AppSemanticColors.toastBackground);
    expect((bar.shape as RoundedRectangleBorder).side, BorderSide.none);
    expect(tester.widget<Text>(find.text('저장하지 못했습니다')).style!.color,
        AppSemanticColors.textInverse);
    expect(tester.widget<Icon>(find.byIcon(Icons.error_rounded)).color, AppColors.rejDot);
  });

  testWidgets('빈 화면 — 옅은 틸 원 56 + 제목 19 + 회색 보조 단추', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppEmptyState(
          icon: Icons.inbox_outlined,
          title: '아직 공지가 없어요',
          description: '새 공지가 올라오면 여기에 보여요',
          actionLabel: '새로고침',
          onAction: () => tapped++,
        ),
      ),
    ));
    expect(tester.widget<Text>(find.text('아직 공지가 없어요')).style!.fontSize, 19);
    expect(tester.widget<Icon>(find.byIcon(Icons.inbox_outlined)).color,
        AppSemanticColors.brandDefault);
    expect(tester.widget<SeedButton>(find.byType(SeedButton)).variant,
        SeedButtonVariant.neutralWeak);
    await tester.tap(find.text('새로고침'));
    expect(tapped, 1);
  });
}
