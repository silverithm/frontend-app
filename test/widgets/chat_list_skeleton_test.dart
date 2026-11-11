import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/widgets/chat/chat_list_skeleton.dart';
import 'package:frontend_app/widgets/chat/chat_messages_skeleton.dart';
import 'package:frontend_app/widgets/common/app_skeleton.dart';

/// 채팅 목록·채팅방 첫 불러오기 뼈대 — 스피너 대신 흰 카드 안 줄·말풍선 모양, 화면 낭독기는 "불러오는 중" 하나.
void main() {
  Widget host(Widget child, {double textScale = 1.0}) => MaterialApp(
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: c!,
        ),
        home: Scaffold(body: child),
      );

  for (final scale in [1.0, 1.3]) {
    testWidgets('방 목록 뼈대 — 글자 $scale배, 작은 폰에서도 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(960, 1600); // 320×533
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(const ChatListSkeleton(), textScale: scale));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.byType(AppSkeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(AppSkeletonCircle), findsNWidgets(6));
    });
  }

  testWidgets('직원 목록 뼈대 — 나 카드 1줄 + 직원 카드 6줄', (tester) async {
    await tester.pumpWidget(host(const ChatListSkeleton(
      groups: [1, 6],
      avatarSize: 40,
      groupLabel: true,
    )));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byType(AppSkeletonCircle), findsNWidgets(7));
    expect(tester.getSize(find.byType(AppSkeletonCircle).first).width, 40);
  });

  testWidgets('화면 낭독기는 "불러오는 중" 하나만 읽는다', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(const ChatListSkeleton()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.bySemanticsLabel('불러오는 중'), findsOneWidget);
    semantics.dispose();
  });

  for (final width in [960.0, 1170.0]) {
    testWidgets('채팅방 말풍선 뼈대 — 폭 ${width ~/ 3}에서 넘치지 않고 왼쪽·오른쪽 말풍선이 섞인다',
        (tester) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(const ChatMessagesSkeleton(), textScale: 1.3));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.byType(AppSkeleton), findsOneWidget);
      // 남의 말풍선 묶음 첫 줄마다 아바타 동그라미
      expect(find.byType(AppSkeletonCircle), findsNWidgets(3));
      final screenWidth = width / 3;
      final boxes = find.byType(AppSkeletonBox);
      final rights = boxes
          .evaluate()
          .where((e) => tester.getTopRight(find.byWidget(e.widget)).dx > screenWidth - 20)
          .length;
      expect(rights, greaterThan(0));
      expect(rights, lessThan(boxes.evaluate().length));
    });
  }
}
