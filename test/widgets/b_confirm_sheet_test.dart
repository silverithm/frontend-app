import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/theme/app_theme.dart';
import 'package:frontend_app/utils/app_haptics.dart';
import 'package:frontend_app/widgets/common/app_dialog.dart';
import 'package:frontend_app/widgets/seed/seed_button.dart';

/// B안 확인 창 — 가운데 대화상자 대신 아래 시트 + 큰 단추. 돌려주는 값과 경고 진동은 그대로.
void main() {
  final heard = <AppHapticKind>[];
  setUp(() {
    heard.clear();
    AppHaptics.debugPerformOverride = (k) async => heard.add(k);
  });
  tearDown(() => AppHaptics.debugPerformOverride = null);

  Future<BuildContext> pumpHost(WidgetTester tester, {double textScale = 1.0}) async {
    tester.view.physicalSize = const Size(1080, 1920); // 360×640
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late BuildContext captured;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.withAppChrome(ThemeData()),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: Builder(builder: (context) {
        captured = context;
        return const SizedBox.expand();
      })),
    ));
    return captured;
  }

  testWidgets('확인 → true, 취소 → false, 바깥 → null', (tester) async {
    final context = await pumpHost(tester);
    for (final (tap, expected) in [('확인', true), ('취소', false)]) {
      final result = AppDialog.showConfirm(context, title: '저장할까요?', message: '바꾼 내용을 저장합니다.');
      await tester.pumpAndSettle();
      await tester.tap(find.text(tap));
      await tester.pumpAndSettle();
      expect(await result, expected);
    }
    final dismissed = AppDialog.showConfirm(context, title: '저장할까요?', message: '');
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(180, 40));
    await tester.pumpAndSettle();
    expect(await dismissed, isNull);
  });

  testWidgets('아래에서 올라오는 시트이고, 단추는 큰 54 · 취소는 회색', (tester) async {
    final context = await pumpHost(tester);
    AppDialog.showConfirm(context, title: '이 결재를 승인할까요?', message: '보수교육 참석 출장 신청서 · 조은비', confirmText: '승인');
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.getBottomLeft(find.byType(BottomSheet)).dy, 640);
    final title = tester.widget<Text>(find.text('이 결재를 승인할까요?'));
    expect(title.style!.fontSize, 21);
    final confirm = find.widgetWithText(SeedButton, '승인');
    expect(tester.widget<SeedButton>(confirm).size, SeedButtonSize.large);
    expect(tester.widget<SeedButton>(find.widgetWithText(SeedButton, '취소')).variant,
        SeedButtonVariant.neutralWeak);
    // 취소 1 : 확인 1.7
    final cw = tester.getSize(find.widgetWithText(SeedButton, '취소')).width;
    final ow = tester.getSize(confirm).width;
    expect(ow / cw, closeTo(1.7, 0.05));
  });

  testWidgets('삭제(critical)는 경고 아이콘 + warning 진동 + 빨간 확인', (tester) async {
    final context = await pumpHost(tester);
    AppDialog.showConfirm(
      context,
      title: '공지를 삭제할까요?',
      message: '삭제하면 되돌릴 수 없습니다.',
      confirmText: '삭제',
      confirmVariant: SeedButtonVariant.critical,
    );
    await tester.pumpAndSettle();
    expect(heard, [AppHapticKind.warning]);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(tester.widget<SeedButton>(find.widgetWithText(SeedButton, '삭제')).variant,
        SeedButtonVariant.critical);
  });

  testWidgets('반려 사유 입력 — 경고 아이콘, 입력한 글을 돌려준다', (tester) async {
    final context = await pumpHost(tester);
    final result = AppDialog.showInput(
      context,
      title: '반려 사유',
      message: '반려 사유를 입력해주세요.',
      hintText: '반려 사유를 입력하세요',
      confirmText: '반려',
      maxLines: 3,
      haptic: AppHapticKind.warning,
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    await tester.enterText(find.byType(TextField), '증빙 영수증을 붙여 다시 올려 주세요');
    await tester.tap(find.text('반려'));
    await tester.pumpAndSettle();
    expect(await result, '증빙 영수증을 붙여 다시 올려 주세요');
  });

  testWidgets('알림 창은 꽉 찬 단추 하나', (tester) async {
    final context = await pumpHost(tester);
    final result = AppDialog.showAlert(context, title: '신청할 수 없는 날짜입니다', message: '이미 휴무 인원이 가득 찼어요.');
    await tester.pumpAndSettle();
    expect(find.byType(SeedButton), findsOneWidget);
    expect(tester.getSize(find.byType(SeedButton)).width, 360 - 40);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    await result;
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('360×640 · 글자 1.6배 · 긴 글에서도 넘치지 않는다', (tester) async {
    final context = await pumpHost(tester, textScale: 1.6);
    AppDialog.showConfirm(
      context,
      title: '선택한 12개의 휴무 요청을 모두 거절하시겠습니까?',
      message: List.filled(8, '거절하면 신청한 분에게 알림이 갑니다.').join(' '),
      confirmText: '그래도 거절',
      haptic: AppHapticKind.warning,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
