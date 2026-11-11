import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/widgets/common/app_sheet_frame.dart';
import 'package:frontend_app/widgets/seed/seed_button.dart';
import 'package:frontend_app/widgets/update_dialog.dart';

/// 시트 단추 줄 — 평소엔 취소 1 : 확인 1.7 그대로, 취소 글자가 제 몫에 한 줄로 안 들어갈 때만
/// 그만큼 넓어진다(많아도 절반). 좁은 업데이트 창에서 글자 1.3배일 때 '나중에'가
/// '나중 / 에'로 쪼개지던 것(2026-11-12 글자 1.3배 점검).
Widget _host({required double width, required double scale, required Widget child}) {
  return MaterialApp(
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: c!,
    ),
    home: Scaffold(
      body: Center(child: SizedBox(width: width, child: child)),
    ),
  );
}

Widget _actions(String cancel, String confirm) => AppSheetActions(
      cancel: SeedButton(
        label: cancel,
        variant: SeedButtonVariant.neutralWeak,
        size: SeedButtonSize.large,
        onPressed: () {},
      ),
      confirm: SeedButton(
        label: confirm,
        size: SeedButtonSize.large,
        onPressed: () {},
      ),
    );

Size _button(WidgetTester tester, String label) => tester.getSize(
      find.ancestor(of: find.text(label), matching: find.byType(SeedButton)),
    );

void main() {
  testWidgets('글자가 들어가면 예전과 같은 1 : 1.7', (tester) async {
    await tester.pumpWidget(
      _host(width: 350, scale: 1.0, child: _actions('취소', '확인')),
    );
    expect(tester.takeException(), isNull);
    final room = 350 - 8.0;
    expect(_button(tester, '취소').width, moreOrLessEquals(room * 10 / 27));
    expect(_button(tester, '확인').width, moreOrLessEquals(room * 17 / 27));
    expect(_button(tester, '취소').height, _button(tester, '확인').height);
  });

  for (final scale in [1.3, 1.6]) {
    testWidgets('좁은 폭·글자 $scale배 — 취소 글자가 한 줄, 그만큼만 넓어진다', (tester) async {
      // 업데이트 창 안쪽 폭(390 - 바깥 40×2 - 안 24×2)
      await tester.pumpWidget(
        _host(width: 262, scale: scale, child: _actions('나중에', '업데이트')),
      );
      expect(tester.takeException(), isNull);
      final room = 262 - 8.0;
      final later = _button(tester, '나중에');
      expect(later.width, greaterThan(room * 10 / 27));
      expect(later.width, lessThanOrEqualTo(room / 2));
      // 한 줄 — 두 줄이면 글자 높이가 글자 크기(16)의 두 배를 넘는다.
      // (테스트 글꼴은 글자 폭이 실제보다 넓어 1.6배에서는 '업데이트'가 대신 넘어갈 수 있다 —
      // 둘을 합친 폭이 줄보다 넓을 때뿐이고, 그때는 어떻게 나눠도 한쪽은 두 줄이다)
      expect(
        tester.getSize(find.text('나중에')).height,
        lessThan(16 * scale * 2),
      );
      // 두 단추가 남은 폭을 다 쓴다
      expect(
        later.width + 8 + _button(tester, '업데이트').width,
        moreOrLessEquals(262),
      );
    });
  }

  testWidgets('취소가 아무리 길어도 절반을 넘지 않는다', (tester) async {
    await tester.pumpWidget(
      _host(
        width: 262,
        scale: 1.6,
        child: _actions('다음에 다시 알려 주세요', '업데이트'),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      _button(tester, '다음에 다시 알려 주세요').width,
      moreOrLessEquals((262 - 8) / 2),
    );
  });

  testWidgets('취소가 없으면 확인 하나가 꽉 찬다', (tester) async {
    await tester.pumpWidget(
      _host(
        width: 262,
        scale: 1.0,
        child: AppSheetActions(
          confirm: SeedButton(
            label: '업데이트',
            size: SeedButtonSize.large,
            onPressed: () {},
          ),
        ),
      ),
    );
    expect(_button(tester, '업데이트').width, 262);
  });

  testWidgets('업데이트 창 — 폭 390·글자 1.3배에서 나중에가 한 줄', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: c!,
        ),
        home: const Scaffold(
          body: UpdateDialog(
            currentVersion: '1.19.7',
            latestVersion: '1.20.0',
            updateMessage: '새 버전이 나왔어요.',
            forceUpdate: false,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.text('나중에')).height, lessThan(16 * 1.3 * 2));
    expect(
      tester.getSize(find.text('업데이트').last).height,
      lessThan(16 * 1.3 * 2),
    );
  });
}
