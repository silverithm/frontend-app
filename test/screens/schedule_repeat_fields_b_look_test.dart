import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/theme/app_theme.dart';
import 'package:frontend_app/utils/schedule_repeat.dart';
import 'package:frontend_app/widgets/schedule/schedule_repeat_fields.dart';

/// 일정 등록 시트의 '반복' 칸 B안(2026-11-12) — 요일 동그라미 7개를 44로 못 박아
/// 좁은 폰(320, 시트 안 280)에서 넘쳤다. 이제 폭에 맞춰 지름을 정하고, 글자를 키우면
/// 동그라미 안에서 맞춰 줄인다.
void main() {
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      testWidgets('매주 요일 고르기 — 폭 $width · 글자 $scale배 넘치지 않는다', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width * 3, 900 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        var rule = ScheduleRepeatRule(
          kind: ScheduleRepeatKind.weekly,
          until: DateTime(2026, 12, 31),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.withAppChrome(ThemeData()),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => SingleChildScrollView(
                  // 일정 등록 시트 본문 여백(좌우 20)과 같게
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ScheduleRepeatFields(
                    startDate: DateTime(2026, 11, 12),
                    value: rule,
                    onChanged: (next) => setState(() => rule = next),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        for (final day in ['월', '화', '수', '목', '금', '토', '일']) {
          expect(find.text(day), findsOneWidget);
        }
        expect(find.text('반복 끝나는 날'), findsOneWidget);

        // 요일을 눌러 고를 수 있다(시작일 목요일 + 월요일)
        await tester.tap(find.bySemanticsLabel('월요일'));
        await tester.pump();
        expect(rule.weekdays, contains(DateTime.monday));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
