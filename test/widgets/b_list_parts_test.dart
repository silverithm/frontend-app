import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/theme/app_spacing.dart';
import 'package:frontend_app/utils/app_haptics.dart';
import 'package:frontend_app/widgets/common/app_card.dart';
import 'package:frontend_app/widgets/seed/seed_list_cell.dart';
import 'package:frontend_app/widgets/seed/seed_section_header.dart';

/// B안 카드·목록 줄·구역 머리 — 테두리 없는 흰 카드, 60 이상 줄, 둥근 틸 아이콘, 18 제목 + 링크.
void main() {
  Widget host(Widget child, {double textScale = 1.0}) => MaterialApp(
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: c!,
        ),
        home: Scaffold(
          backgroundColor: AppSemanticColors.backgroundCanvas,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      );

  testWidgets('AppCard — 흰 바탕, 테두리 없음, 모서리 16, 여백 16', (tester) async {
    await tester.pumpWidget(host(const AppCard(child: Text('내용'))));
    final box = tester.widget<DecoratedBox>(find
        .ancestor(of: find.text('내용'), matching: find.byType(DecoratedBox))
        .first);
    final deco = box.decoration as BoxDecoration;
    expect(deco.color, AppSemanticColors.surfaceCard);
    expect(deco.border, isNull);
    expect(deco.borderRadius, BorderRadius.circular(AppBorderRadius.card));
    expect(tester.getTopLeft(find.text('내용')) - tester.getTopLeft(find.byType(AppCard)),
        const Offset(16, 16));
  });

  testWidgets('누를 수 있는 카드는 tap 햅틱과 함께 전달', (tester) async {
    final heard = <AppHapticKind>[];
    AppHaptics.debugPerformOverride = (k) async => heard.add(k);
    addTearDown(() => AppHaptics.debugPerformOverride = null);
    var taps = 0;
    await tester.pumpWidget(host(AppCard(onTap: () => taps++, child: const Text('공지'))));
    await tester.tap(find.text('공지'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(heard, [AppHapticKind.tap]);
  });

  testWidgets('목록 줄 — 높이 52 이상, 둥근 틸 아이콘 40, 눌리면 옅은 회색', (tester) async {
    await tester.pumpWidget(host(SeedListSection(
      title: '내 업무',
      children: [
        SeedListCell(
          leadingIcon: Icons.checklist,
          title: '업무진행도',
          description: '담당 업무·기한·수행도를 함께 확인',
          onTap: () {},
        ),
      ],
    )));
    final row = find.byType(SeedListCell);
    expect(tester.getSize(row).height, greaterThanOrEqualTo(AppSpacing.listRowMinHeight));
    final circle = tester.widget<Container>(find
        .ancestor(of: find.byIcon(Icons.checklist), matching: find.byType(Container))
        .first);
    expect((circle.decoration as BoxDecoration).color, AppSemanticColors.brandWeak);
    expect((circle.decoration as BoxDecoration).shape, BoxShape.circle);
    expect(tester.getSize(find.byWidget(circle)), const Size(40, 40));

    // 아이콘 원은 카드 가장자리에서 20 들어온다(섹션 8 + 줄 12) — 눌림 면이 카드 모서리에 붙지 않게
    final card = find.ancestor(of: row, matching: find.byType(Container)).first;
    expect(tester.getTopLeft(find.byIcon(Icons.checklist)).dx -
            tester.getTopLeft(card).dx,
        closeTo(20 + (40 - 22) / 2, 0.5));

    final gesture = await tester.startGesture(tester.getCenter(row));
    await tester.pump(const Duration(milliseconds: 200));
    final pressed = tester.widget<AnimatedContainer>(find.descendant(
      of: row,
      matching: find.byType(AnimatedContainer),
    ));
    expect((pressed.decoration as BoxDecoration).color, AppSemanticColors.surfacePressed);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('구역 머리 — 16 제목, 숫자 알약, 링크 48 터치', (tester) async {
    var opened = 0;
    await tester.pumpWidget(host(AppCard(
      child: SeedSectionHeader(
        title: '전자결재',
        count: 0,
        subtitle: '지금 내가 처리할 결재 0건',
        actionLabel: '전체보기',
        onAction: () => opened++,
      ),
    )));
    expect(tester.widget<Text>(find.text('전자결재')).style!.fontSize, 16);
    expect(find.text('0'), findsOneWidget);
    final link = find.ancestor(of: find.text('전체보기'), matching: find.byType(GestureDetector)).first;
    expect(tester.getSize(link).height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('전체보기'));
    expect(opened, 1);
  });

  testWidgets('글자 1.6배에서도 넘치지 않는다(360 폭)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(
      Column(children: [
        AppCard(
          child: SeedSectionHeader(
            title: '업무진행도',
            count: 12,
            subtitle: '진행 중인 업무 4건',
            actionLabel: '전체보기',
            onAction: () {},
          ),
        ),
        SeedListSection(title: '소통', children: [
          SeedListCell(
            leadingIcon: Icons.campaign_outlined,
            title: '케어브이 커뮤니티 아주 긴 이름',
            description: '전국 요양기관 종사자와 정보를 나눠요',
            trailing: const Text('새 글 3'),
            onTap: () {},
          ),
        ]),
      ]),
      textScale: 1.6,
    ));
    expect(tester.takeException(), isNull);
  });
}
