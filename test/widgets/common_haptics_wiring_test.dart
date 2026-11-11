import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/widgets/common/app_button.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:frontend_app/theme/app_theme.dart';
import 'package:frontend_app/utils/app_haptics.dart';
import 'package:frontend_app/widgets/common/app_action_sheet.dart';
import 'package:frontend_app/widgets/common/app_card.dart';
import 'package:frontend_app/widgets/common/app_dialog.dart';
import 'package:frontend_app/widgets/common/app_snackbar.dart';
import 'package:frontend_app/widgets/seed/seed_button.dart';

/// 공통 대화상자·시트·알림·버튼이 뜻에 맞는 햅틱을 울리는지.
/// 삭제 확인 = warning, 실패 알림 = error, 성공 알림 = success, 버튼 = tap, 시트 항목 = selection.
void main() {
  final heard = <AppHapticKind>[];

  setUp(() {
    heard.clear();
    AppHaptics.enabled.value = true;
    AppHaptics.debugPerformOverride = (kind) async => heard.add(kind);
  });

  tearDown(() {
    AppHaptics.debugPerformOverride = null;
    AppHaptics.enabled.value = true;
  });

  Future<BuildContext> pumpHost(WidgetTester tester, {Widget? body}) async {
    late BuildContext captured;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.withAppChrome(ThemeData()),
      home: Scaffold(
        body: Builder(builder: (context) {
          captured = context;
          return Center(child: body ?? const SizedBox());
        }),
      ),
    ));
    return captured;
  }

  group('AppDialog', () {
    testWidgets('삭제(critical) 확인 창은 뜰 때 warning', (tester) async {
      final context = await pumpHost(tester);
      AppDialog.showConfirm(
        context,
        title: '공지 삭제',
        message: '삭제할까요?',
        confirmText: '삭제',
        confirmVariant: SeedButtonVariant.critical,
      );
      await tester.pumpAndSettle();
      expect(heard, [AppHapticKind.warning]);
    });

    testWidgets('보통 확인 창은 울리지 않고, 넘기면 그 뜻으로 울린다', (tester) async {
      final context = await pumpHost(tester);
      AppDialog.showConfirm(context, title: '로그아웃', message: '할까요?');
      await tester.pumpAndSettle();
      expect(heard, isEmpty);
      Navigator.of(context).pop();
      await tester.pumpAndSettle();

      AppDialog.showConfirm(
        context,
        title: '일괄 거절',
        message: '거절할까요?',
        confirmText: '거절',
        haptic: AppHapticKind.warning,
      );
      await tester.pumpAndSettle();
      expect(heard, [AppHapticKind.warning]);
    });

    testWidgets('반려 사유 입력 창에 warning을 넘기면 뜰 때 울린다', (tester) async {
      final context = await pumpHost(tester);
      AppDialog.showInput(
        context,
        title: '반려 사유',
        confirmText: '반려',
        haptic: AppHapticKind.warning,
      );
      await tester.pumpAndSettle();
      expect(heard, [AppHapticKind.warning]);
    });

    testWidgets('확인 창 단추를 누르면 tap', (tester) async {
      final context = await pumpHost(tester);
      final result = AppDialog.showConfirm(context, title: '저장', message: '할까요?');
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(heard, [AppHapticKind.tap]);
    });
  });

  group('AppSnackBar', () {
    final cases = <String, (void Function(BuildContext), List<AppHapticKind>)>{
      '성공 → success': (
        (c) => AppSnackBar.showSuccess(c, message: '저장했습니다'),
        [AppHapticKind.success],
      ),
      '실패 → error': (
        (c) => AppSnackBar.showError(c, message: '저장하지 못했습니다'),
        [AppHapticKind.error],
      ),
      '주의 → 없음': (
        (c) => AppSnackBar.showWarning(c, message: '제목을 입력해주세요'),
        <AppHapticKind>[],
      ),
      '안내 → 없음': (
        (c) => AppSnackBar.showInfo(c, message: '복사했습니다'),
        <AppHapticKind>[],
      ),
      'haptic: false → 없음': (
        (c) => AppSnackBar.showError(c, message: '실패', haptic: false),
        <AppHapticKind>[],
      ),
      'show(type: error) → error': (
        (c) => AppSnackBar.show(c, message: '실패', type: AppStatusType.error),
        [AppHapticKind.error],
      ),
    };

    for (final entry in cases.entries) {
      testWidgets(entry.key, (tester) async {
        final context = await pumpHost(tester);
        entry.value.$1(context);
        await tester.pump();
        expect(heard, entry.value.$2);
      });
    }
  });

  group('showAppActionSheet', () {
    testWidgets('항목을 고르면 selection, 위험 항목은 울리지 않는다(뒤이은 확인 창이 울린다)',
        (tester) async {
      final context = await pumpHost(tester);
      var picked = '';
      Future<void> open() => showAppActionSheet(context, actions: [
            AppSheetAction(
              icon: Icons.edit,
              label: '수정',
              onSelected: () => picked = '수정',
            ),
            AppSheetAction(
              icon: Icons.delete,
              label: '삭제',
              isDestructive: true,
              onSelected: () => picked = '삭제',
            ),
          ]);

      open();
      await tester.pumpAndSettle();
      expect(heard, isEmpty);
      await tester.tap(find.text('수정'));
      await tester.pumpAndSettle();
      expect(picked, '수정');
      expect(heard, [AppHapticKind.selection]);

      heard.clear();
      open();
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      expect(picked, '삭제');
      expect(heard, isEmpty);
    });

    testWidgets('길게 눌러 여는 메뉴는 impact를 넘기면 뜰 때 울린다', (tester) async {
      final context = await pumpHost(tester);
      showAppActionSheet(
        context,
        haptic: AppHapticKind.impact,
        actions: [
          AppSheetAction(icon: Icons.copy, label: '복사', onSelected: () {}),
        ],
      );
      await tester.pumpAndSettle();
      expect(heard, [AppHapticKind.impact]);
    });
  });

  testWidgets('AppButton(shadcn 감싼 버튼)도 누르면 tap', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(shadcn.ShadcnApp(
      home: Center(
        child: AppButton(text: '보내기', onPressed: () => pressed++),
      ),
    ));
    await tester.tap(find.text('보내기'));
    await tester.pumpAndSettle();
    expect(pressed, 1);
    expect(heard, [AppHapticKind.tap]);
  });

  group('SeedButton', () {
    testWidgets('누르면 tap 햅틱과 함께 onPressed', (tester) async {
      var pressed = 0;
      await pumpHost(tester,
          body: SeedButton(label: '신청', onPressed: () => pressed++));
      await tester.tap(find.text('신청'));
      await tester.pumpAndSettle();
      expect(pressed, 1);
      expect(heard, [AppHapticKind.tap]);
    });

    testWidgets('haptic: null·비활성·불러오는 중이면 울리지 않는다', (tester) async {
      var pressed = 0;
      await pumpHost(tester,
          body: SeedButton(
              label: '조용히', haptic: null, onPressed: () => pressed++));
      await tester.tap(find.text('조용히'));
      await tester.pumpAndSettle();
      expect(pressed, 1);
      expect(heard, isEmpty);

      await pumpHost(tester,
          body: SeedButton(
              label: '막힘', isDisabled: true, onPressed: () => pressed++));
      await tester.tap(find.text('막힘'));
      await tester.pumpAndSettle();
      expect(pressed, 1);
      expect(heard, isEmpty);

      await pumpHost(tester,
          body: SeedButton(
              label: '저장', isLoading: true, onPressed: () => pressed++));
      await tester.tap(find.byType(SeedButton));
      await tester.pump();
      expect(pressed, 1);
      expect(heard, isEmpty);
    });
  });
}
