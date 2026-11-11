import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/theme/app_motion.dart';
import 'package:frontend_app/widgets/common/app_skeleton.dart';

/// 뼈대: 작은 폰(360)에서 넘치지 않고, 화면 낭독기에는 "불러오는 중" 하나만 읽히고,
/// 빛이 돌다가도 '동작 줄이기'면 멈춰 있다.
void main() {
  Widget host(Widget child, {bool reduceMotion = false}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 640),
          disableAnimations: reduceMotion,
        ),
        child: Scaffold(body: child),
      ),
    );
  }

  setUp(() {});

  testWidgets('목록·상세·카드 뼈대가 360 폭에서 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    for (final skeleton in <Widget>[
      const AppSkeletonList(),
      const AppSkeletonList(showLeading: false, itemCount: 20),
      const AppSkeletonDetail(showMedia: true),
      const AppSkeletonCard(),
    ]) {
      await tester.pumpWidget(host(skeleton));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '$skeleton');
    }
  });

  testWidgets('화면 낭독기에는 "불러오는 중"만 읽힌다', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(const AppSkeletonList()));
    expect(find.bySemanticsLabel('불러오는 중'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('빛이 돌고(다시 그림), 동작 줄이기면 멈춘다', (tester) async {
    await tester.pumpWidget(host(const AppSkeletonList()));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(AppMotion.shimmer ~/ 2);
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(host(const AppSkeletonList(), reduceMotion: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    // 멈춘 상태라 pumpAndSettle이 끝난다.
    await tester.pumpAndSettle();
  });

  testWidgets('카드 바탕·테두리를 뼈대 사이에 둬도 된다(빛은 뼈에만)', (tester) async {
    await tester.pumpWidget(host(
      AppSkeleton(
        child: Column(
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black12),
                ),
                child: const Row(
                  children: [
                    AppSkeletonCircle(),
                    SizedBox(width: 12),
                    Expanded(child: AppSkeletonLine(widthFactor: 0.5)),
                  ],
                ),
              ),
          ],
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.byType(AppSkeletonCircle), findsNWidgets(3));
  });

  testWidgets('AppSkeleton 밖에서 뼈를 써도 회색으로 그려진다', (tester) async {
    await tester.pumpWidget(host(
      const Column(
        children: [
          AppSkeletonLine(width: 120),
          AppSkeletonBox(height: 40),
          AppSkeletonCircle(size: 32),
        ],
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AppSkeletonLine)).width, 120);
    expect(tester.getSize(find.byType(AppSkeletonCircle)), const Size(32, 32));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
