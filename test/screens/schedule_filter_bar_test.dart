import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/theme/app_theme.dart';
import 'package:frontend_app/widgets/schedule/schedule_filter_bar.dart';
import 'package:frontend_app/widgets/seed/seed_chip.dart';

/// 월간일정 '일정 필터' 칩 줄 — 담당자를 고르면 칩이 '일정 필터 · 김민지'로 길어져
/// 오른쪽으로 21px 넘쳤다(2단계 뒤, 2026-11-12). 달력 카드 안(폭 390 → 358)과 좁은 폰에서
/// 글자를 1.6배로 키워도 넘치지 않아야 하고, 완료 수는 자리가 모자라면 다음 줄로 내려간다.
void main() {
  // 화면 폭 → 달력 카드 안쪽 폭(화면 좌우 여백 16씩)
  for (final screenWidth in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      for (final label in ['일정 필터', '일정 필터 · 김민지', '일정 필터 · 남궁민수경']) {
        testWidgets('폭 $screenWidth · 글자 $scale배 · "$label" — 넘치지 않는다', (
          tester,
        ) async {
          tester.view.physicalSize = Size(screenWidth * 3, 600 * 3);
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);

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
                body: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      ScheduleFilterBar(
                        label: label,
                        filtered: label != '일정 필터',
                        onTap: () {},
                        done: 1,
                        total: 7,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.text(label), findsOneWidget);
          expect(find.text('완료 1/7'), findsOneWidget);
          expect(
            tester.widget<SeedChip>(find.byType(SeedChip)).selected,
            label != '일정 필터',
          );
        });
      }
    }
  }

  testWidgets('이번 달 일정이 없으면 완료 수를 그리지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleFilterBar(
            label: '일정 필터',
            filtered: false,
            onTap: () {},
            done: 0,
            total: 0,
            showProgress: false,
          ),
        ),
      ),
    );
    expect(find.textContaining('완료'), findsNothing);
  });
}
