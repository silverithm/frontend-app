import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/notice.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/widgets/common/app_card.dart';
import 'package:frontend_app/widgets/common/app_tag.dart';
import 'package:frontend_app/widgets/notice/notice_card.dart';
import 'package:frontend_app/widgets/notice/notice_priority_badge.dart';

/// 공지 카드 B안 — 테두리 없는 흰 카드, 꼬리표는 테두리 없는 알약, 글자를 키워도 넘치지 않는다.
void main() {
  Widget host(Widget child, {double textScale = 1.0}) => MaterialApp(
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: c!,
        ),
        home: Scaffold(
          backgroundColor: AppSemanticColors.backgroundCanvas,
          body: ListView(children: [child]),
        ),
      );

  Notice notice({
    bool pinned = true,
    NoticePriority priority = NoticePriority.high,
    NoticeStatus status = NoticeStatus.published,
    String author = '김관리',
  }) =>
      Notice(
        id: 1,
        title: '[필독] 안전점검의 날 안내 — 전 직원 참석 부탁드립니다',
        content: '이번 주 금요일 오전 10시에 전 직원 안전점검 교육이 있습니다.',
        priority: priority,
        status: status,
        isPinned: pinned,
        authorId: 'u1',
        authorName: author,
        companyId: 1,
        viewCount: 24,
        createdAt: DateTime.now().subtract(const Duration(hours: 16)),
        updatedAt: DateTime.now(),
      );

  testWidgets('맨 Card 대신 AppCard(테두리 없음)로 그리고 누르면 전달된다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(NoticeCard(notice: notice(), onTap: () => taps++)));
    expect(find.byType(Card), findsNothing);
    expect(find.byType(AppCard), findsOneWidget);
    expect(find.text('고정'), findsOneWidget);
    expect(find.text('긴급'), findsOneWidget);
    await tester.tap(find.textContaining('안전점검의 날'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('게시 상태 꼬리표는 AppTag — 색의 뜻 그대로(게시됨 초록·보관됨 노랑·임시저장 회색)',
      (tester) async {
    await tester.pumpWidget(host(const Column(children: [
      NoticeStatusBadge(status: NoticeStatus.published),
      NoticeStatusBadge(status: NoticeStatus.archived),
      NoticeStatusBadge(status: NoticeStatus.draft, small: true),
    ])));
    final tags = tester.widgetList<AppTag>(find.byType(AppTag)).toList();
    expect(tags.map((t) => t.label), ['게시됨', '보관됨', '임시저장']);
    expect(tags.map((t) => t.tone),
        [AppTagTone.success, AppTagTone.warning, AppTagTone.neutral]);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('폭 $width·글자 1.3배 — 꼬리표 셋·긴 작성자 이름에도 넘치지 않는다', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(
        NoticeCard(
          notice: notice(author: '햇살주간보호센터 사무국장 김관리님'),
          showStatus: true,
          onTap: () {},
        ),
        textScale: 1.3,
      ));
      expect(tester.takeException(), isNull);
    });
  }
}
