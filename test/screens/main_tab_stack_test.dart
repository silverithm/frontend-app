import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/screens/main_screen.dart';

/// 하단 탭 겹쳐 바뀜(fade-through) — 새로 보이는 탭이 200ms로 옅게 나타나고,
/// 처음 뜰 때·'동작 줄이기'면 바로 보이며, 탭 화면 상태는 IndexedStack이 그대로 살려 둔다.
void main() {
  Widget host(int index, {bool reduceMotion = false}) => MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: MainTabStack(
            index: index,
            children: const [
              _CounterTab(name: '홈'),
              _CounterTab(name: '채팅'),
              _CounterTab(name: '전체'),
            ],
          ),
        ),
      );

  double opacityOf(WidgetTester tester) =>
      tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value;

  testWidgets('앱이 처음 뜰 때는 투명하지 않다(연출 없이 바로 1)', (tester) async {
    await tester.pumpWidget(host(0));
    expect(opacityOf(tester), 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text('홈 0'), findsOneWidget);
  });

  testWidgets('탭을 바꾸면 새 탭이 옅게 나타나 200ms 안에 1이 된다', (tester) async {
    await tester.pumpWidget(host(0));
    await tester.pumpWidget(host(1));
    // 바꾼 그 순간은 투명에서 시작한다
    expect(opacityOf(tester), 0);
    await tester.pump(const Duration(milliseconds: 60));
    final mid = opacityOf(tester);
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));
    await tester.pumpAndSettle();
    expect(opacityOf(tester), 1);
    // 200ms를 넘겨 계속 그리지 않는다
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('옅게 나타나는 동안에도 화면 낭독기는 새 탭 내용을 읽는다', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(0));
    await tester.pumpWidget(host(2));
    expect(opacityOf(tester), 0);
    expect(find.bySemanticsLabel('전체 0'), findsOneWidget);
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets('동작 줄이기면 연출 없이 바로 1', (tester) async {
    await tester.pumpWidget(host(0, reduceMotion: true));
    await tester.pumpWidget(host(1, reduceMotion: true));
    expect(opacityOf(tester), 1);
    // 탭이 바뀐 그 한 장만 그리고, 옅어지는 연출은 돌지 않는다
    await tester.pump();
    expect(opacityOf(tester), 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('탭을 오가도 각 탭 화면의 상태가 그대로다', (tester) async {
    await tester.pumpWidget(host(0));
    await tester.tap(find.text('홈 0'));
    await tester.pump();
    await tester.tap(find.text('홈 1'));
    await tester.pump();
    expect(find.text('홈 2'), findsOneWidget);

    await tester.pumpWidget(host(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('채팅 0'));
    await tester.pump();

    await tester.pumpWidget(host(0));
    await tester.pumpAndSettle();
    expect(find.text('홈 2'), findsOneWidget);

    await tester.pumpWidget(host(1));
    await tester.pumpAndSettle();
    expect(find.text('채팅 1'), findsOneWidget);
  });
}

class _CounterTab extends StatefulWidget {
  const _CounterTab({required this.name});

  final String name;

  @override
  State<_CounterTab> createState() => _CounterTabState();
}

class _CounterTabState extends State<_CounterTab> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _count++),
      child: Center(child: Text('${widget.name} $_count')),
    );
  }
}
