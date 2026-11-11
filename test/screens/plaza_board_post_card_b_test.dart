import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/screens/plaza_screen.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/theme/app_spacing.dart';
import 'package:frontend_app/theme/app_theme.dart';

/// 커뮤니티 게시판 글 카드 — 아랫줄(작성자·날짜 + 조회·좋아요·댓글 수)이 좁은 폰·큰 글자에서
/// 넘치지 않아야 한다. 이름이 길면 이름 쪽이 줄임표로 줄고 숫자 묶음은 오른쪽 끝에 남는다.
Map<String, dynamic> _post({
  String author = '햇살주간보호센터 요양보호사 김민지 선생님',
  Object? views = 12345,
  Object? likes = 999,
  Object? comments = 88,
}) => {
  'id': 7,
  'board': 'free',
  'isPinned': true,
  'hasAccepted': true,
  'title': '어르신 낙상 예방 체조 순서를 정리해 봤어요 — 아침 프로그램 시간에 쓰기 좋아요',
  'preview': '<p>매일 아침 10분이면 충분해요. 의자에 앉아서 하는 동작 위주로 골랐습니다.</p>',
  'displayAuthor': author,
  'createdAt': '2026-11-12T09:30:00',
  'viewCount': views,
  'likeCount': likes,
  'commentCount': comments,
};

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required double textScale,
  required Map<String, dynamic> post,
}) async {
  tester.view.physicalSize = Size(width * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.withAppChrome(ThemeData()),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        backgroundColor: AppSemanticColors.backgroundCanvas,
        body: ListView(
          // 게시판 탭 목록과 같은 좌우 16
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenGutter,
            vertical: AppSpacing.space2,
          ),
          children: [PlazaBoardPostCard(post: post, onTap: () {})],
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      testWidgets('게시판 글 카드 — 폭 $width · 글자 $scale배, 긴 이름·큰 수에서 넘치지 않는다', (
        tester,
      ) async {
        await _pump(tester, width: width, textScale: scale, post: _post());
        expect(tester.takeException(), isNull);
        // 글자는 그대로 — 숫자 묶음은 모두 보인다
        expect(find.text('12345'), findsOneWidget);
        expect(find.text('999'), findsOneWidget);
        expect(find.text('88'), findsOneWidget);
        expect(find.text('햇살주간보호센터 요양보호사 김민지 선생님 · 11.12'), findsOneWidget);
      });
    }
  }

  testWidgets('게시판 글 카드 — 수가 비어 있으면 0으로', (tester) async {
    await _pump(
      tester,
      width: 320,
      textScale: 1.3,
      post: _post(author: '익명', views: null, likes: null, comments: null),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('0'), findsNWidgets(3));
  });
}
