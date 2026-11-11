import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/approval.dart';
import 'package:frontend_app/providers/approval_provider.dart';
import 'package:frontend_app/providers/auth_provider.dart';
import 'package:frontend_app/screens/approval_detail_loader_screen.dart';
import 'package:frontend_app/screens/approval_detail_screen.dart';
import 'package:frontend_app/widgets/approval/approval_skeletons.dart';
import 'package:frontend_app/widgets/approval/official_document_view.dart';
import 'package:frontend_app/widgets/common/app_skeleton.dart';
import 'package:provider/provider.dart';

/// 결재 상세 — 양식을 받기 전 공문 자리는 동그라미가 아니라 공문 한 장 모양 뼈대.
/// 알림에서 번호만 받아 여는 불러오기 화면도 상태 카드·공문 카드 모양 뼈대.
class _FakeApprovalProvider extends ApprovalProvider {
  _FakeApprovalProvider([this.pending]);

  /// 주면 상세 조회가 이 값이 끝날 때까지 기다린다(불러오는 중을 붙잡아 둔다).
  final Completer<ApprovalRequest?>? pending;

  @override
  Future<ApprovalRequest?> loadApprovalDetail({required int approvalId}) async =>
      pending == null ? null : await pending!.future;
}

void main() {
  for (final scale in [1.0, 1.3]) {
    testWidgets('양식을 받기 전 공문 자리는 뼈대, 받은 뒤 공문 — 폭 320·글자 $scale배', (tester) async {
      tester.view.physicalSize = const Size(960, 1920);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final approval = ApprovalRequest.fromJson({
        'id': 1,
        // 양식 번호가 없으면 첫 장 다음에 바로 공문을 그린다(네트워크 없이 두 상태를 본다)
        'templateId': 0,
        'templateName': '지출결의서',
        'title': '보수교육 참석 출장 신청서',
        'requesterId': '7',
        'requesterName': '조은비',
        'status': 'APPROVED',
        'createdAt': '2026-11-07T13:00:00',
      });

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ChangeNotifierProvider<ApprovalProvider>(
            create: (_) => _FakeApprovalProvider(),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: ApprovalDetailScreen(approval: approval),
        ),
      ));

      // 첫 장 — 양식 조회가 끝나기 전
      expect(find.byType(AppSkeleton), findsOneWidget);
      expect(find.byType(OfficialDocumentView), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();
      expect(find.byType(AppSkeleton), findsNothing);
      expect(find.byType(OfficialDocumentView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 1.3]) {
    testWidgets('번호로 여는 결재 상세 — 불러오는 동안 상태 카드·공문 카드 뼈대(글자 $scale배)',
        (tester) async {
      tester.view.physicalSize = const Size(960, 1920);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final pending = Completer<ApprovalRequest?>();

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ChangeNotifierProvider<ApprovalProvider>(
            create: (_) => _FakeApprovalProvider(pending),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const ApprovalDetailLoaderScreen(approvalId: 77),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.byType(ApprovalDetailSkeleton), findsOneWidget);
      expect(find.byType(AppSkeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('결재 상세'), findsOneWidget);

      // 못 찾으면 예전 그대로 빈 화면 안내
      pending.complete(null);
      await tester.pumpAndSettle();
      expect(find.byType(AppSkeleton), findsNothing);
      expect(find.text('결재 문서를 불러오지 못했습니다'), findsOneWidget);
    });
  }
}
