import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/vacation_request.dart';
import 'package:frontend_app/providers/auth_provider.dart';
import 'package:frontend_app/providers/vacation_provider.dart';
import 'package:frontend_app/screens/my_vacation_screen.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/theme/app_theme.dart';
import 'package:frontend_app/widgets/common/app_sheet_frame.dart';
import 'package:provider/provider.dart';

/// 묶음 ③ 내 휴무 B안(2026-11-12) — 회색 바탕 위 흰 카드(신청 현황·상태별), 구분선 없음,
/// 삭제 확인은 아래 시트. 좁은 폰에서 글자를 1.6배로 키워도 넘치지 않아야 한다.
class _FakeVacation extends VacationProvider {
  _FakeVacation(this._requests);

  final List<VacationRequest> _requests;

  @override
  List<VacationRequest> get vacationRequests => _requests;

  @override
  bool get isLoading => false;

  @override
  String get errorMessage => '';

  @override
  Future<void> loadMyVacationRequests(
    String userId, {
    String? companyId,
    String? userName,
  }) async {}

  @override
  Future<void> loadPlanningSettings({
    String? companyId,
    bool forceReload = false,
  }) async {}
}

List<VacationRequest> _requests() => [
  VacationRequest(
    id: '1',
    userId: '12',
    userName: '김민지',
    role: 'caregiver',
    date: DateTime(2026, 11, 28),
    reason: '가족 행사로 지방에 다녀와야 해서 하루 쉬려고 합니다',
    createdAt: DateTime(2026, 11, 10, 9),
  ),
  VacationRequest(
    id: '2',
    userId: '12',
    userName: '김민지',
    role: 'caregiver',
    date: DateTime(2026, 11, 15),
    status: VacationStatus.approved,
    duration: VacationDuration.halfDayAm,
    createdAt: DateTime(2026, 11, 9, 9),
  ),
  VacationRequest(
    id: '3',
    userId: '12',
    userName: '김민지',
    role: 'caregiver',
    date: DateTime(2026, 11, 21),
    status: VacationStatus.rejected,
    type: VacationType.mandatory,
    rejectionReason: '그날은 최소 근무 인원이 모자랍니다',
    createdAt: DateTime(2026, 11, 8, 9),
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required double textScale,
}) async {
  tester.view.physicalSize = Size(width * 3, 1400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<VacationProvider>(
          create: (_) => _FakeVacation(_requests()),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.withAppChrome(ThemeData()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const MyVacationScreen(),
      ),
    ),
  );
  // 목록 등장 연출(500ms)이 끝날 때까지 — 첫 틱에서 시작하므로 한 번 더 넘긴다
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      testWidgets('내 휴무 — 폭 $width · 글자 $scale배, 넘치지 않는다', (tester) async {
        await _pump(tester, width: width, textScale: scale);
        expect(tester.takeException(), isNull);

        // 회색 바탕 + 상태별 카드 제목·문구 그대로
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.backgroundColor, AppSemanticColors.backgroundCanvas);
        expect(find.text('내 휴무'), findsOneWidget);
        expect(find.text('신청 현황'), findsOneWidget);
        expect(find.text('대기 중 (1)'), findsOneWidget);
        expect(find.text('승인됨 (1)'), findsOneWidget);
        expect(find.text('거절됨 (1)'), findsOneWidget);
        expect(find.text('거절 사유'), findsOneWidget);
        // 구분선으로 나누지 않는다
        expect(find.byType(Divider), findsNothing);
        expect(find.byType(VerticalDivider), findsNothing);
      });
    }
  }

  testWidgets('신청 삭제는 아래 시트로 묻고 취소하면 닫힌다', (tester) async {
    await _pump(tester, width: 390, textScale: 1.0);

    await tester.tap(find.byTooltip('신청 삭제'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AppSheetFrame), findsOneWidget);
    expect(find.text('휴무 신청 삭제'), findsOneWidget);
    expect(find.text('11월 28일 휴무 신청을 삭제하시겠습니까?'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('휴무 신청 삭제'), findsNothing);
  });
}
