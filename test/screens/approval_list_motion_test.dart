import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/approval.dart';
import 'package:frontend_app/providers/approval_provider.dart';
import 'package:frontend_app/providers/auth_provider.dart';
import 'package:frontend_app/screens/approval_list_screen.dart';
import 'package:frontend_app/widgets/approval/approval_card.dart';
import 'package:frontend_app/widgets/common/app_count_up.dart';
import 'package:frontend_app/widgets/common/app_list_entrance.dart';
import 'package:frontend_app/widgets/common/app_skeleton.dart';
import 'package:provider/provider.dart';

/// 결재 신청 목록(4단계 반응) — 첫 불러오기는 뼈대, 결재 현황 숫자는 세어 올라가고,
/// 결재 카드는 처음 한 번만 떠오른다. 이미 받은 목록을 다시 받을 때는 예전 동그라미 그대로.
class _FakeApprovalProvider extends ApprovalProvider {
  bool loading = false;
  List<ApprovalRequest> mine = [];

  @override
  bool get isLoading => loading;

  @override
  List<ApprovalRequest> get myApprovalRequests => mine;

  @override
  String get errorMessage => '';

  void set({bool? isLoading, List<ApprovalRequest>? requests}) {
    if (isLoading != null) loading = isLoading;
    if (requests != null) mine = requests;
    notifyListeners();
  }
}

ApprovalRequest _approval(int id, String status) => ApprovalRequest.fromJson({
      'id': id,
      'templateId': 1,
      'templateName': '지출결의서',
      'title': '보수교육 참석 출장 신청서 $id',
      'requesterId': '7',
      'requesterName': '조은비',
      'status': status,
      'createdAt': '2026-11-07T13:00:00',
    });

List<ApprovalRequest> _requests({int pending = 12, int approved = 2, int rejected = 1}) => [
      for (var i = 0; i < pending; i++) _approval(100 + i, 'PENDING'),
      for (var i = 0; i < approved; i++) _approval(200 + i, 'APPROVED'),
      for (var i = 0; i < rejected; i++) _approval(300 + i, 'REJECTED'),
    ];

void main() {
  late _FakeApprovalProvider approvals;

  setUp(() => approvals = _FakeApprovalProvider());

  Future<void> pumpScreen(
    WidgetTester tester, {
    double textScale = 1.0,
    bool reduceMotion = false,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<ApprovalProvider>.value(value: approvals),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: const ApprovalListScreen(showAppBar: false),
      ),
    ));
  }

  String countText(WidgetTester tester, int i) => tester
      .widget<Text>(find
          .descendant(of: find.byType(AppCountUp), matching: find.byType(Text))
          .at(i))
      .data!;

  for (final scale in [1.0, 1.3]) {
    testWidgets('첫 불러오기는 뼈대(동그라미 없음) — 폭 320·글자 $scale배에서 넘치지 않는다',
        (tester) async {
      approvals.set(isLoading: true);
      await pumpScreen(tester, textScale: scale, size: const Size(320, 640));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.byType(AppSkeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  }

  testWidgets('목록이 오면 결재 현황 숫자가 0에서 세어 올라가 그대로 멈춘다', (tester) async {
    approvals.set(isLoading: true);
    await pumpScreen(tester);
    approvals.set(isLoading: false, requests: _requests());
    await tester.pump();
    // 진행중·승인·반려 세 칸 — 처음엔 0
    expect(find.byType(AppCountUp), findsNWidgets(3));
    expect(countText(tester, 0), '0');
    await tester.pumpAndSettle();
    expect(countText(tester, 0), '12');
    expect(countText(tester, 1), '2');
    expect(countText(tester, 2), '1');
    expect(find.byType(AppSkeleton), findsNothing);
  });

  testWidgets('결재 카드는 떠오르는 줄로 감싸고 다 뜨면 모두 보인다', (tester) async {
    approvals.set(requests: _requests(pending: 3));
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    expect(find.byType(AppListEntrance), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(ApprovalCard).first,
        matching: find.byType(AppListEntranceItem),
      ),
      findsOneWidget,
    );
    expect(find.text('보수교육 참석 출장 신청서 100'), findsOneWidget);
  });

  testWidgets('다시 받는 중에는 예전 동그라미, 다시 그려져도 숫자를 0부터 세지 않는다', (tester) async {
    approvals.set(requests: _requests());
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    approvals.set(isLoading: true);
    await tester.pump();
    expect(find.byType(AppSkeleton), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('데이터를 불러오는 중...'), findsOneWidget);

    approvals.set(isLoading: false);
    await tester.pump();
    expect(countText(tester, 0), '12');
    await tester.pumpAndSettle();
  });

  testWidgets('동작 줄이기면 숫자를 세지 않고 바로 보인다', (tester) async {
    approvals.set(requests: _requests());
    await pumpScreen(tester, reduceMotion: true);
    await tester.pump();
    expect(countText(tester, 0), '12');
    await tester.pumpAndSettle();
  });
}
