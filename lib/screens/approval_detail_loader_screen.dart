import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/approval.dart';
import '../providers/approval_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/common/app_empty_state.dart';
import '../widgets/common/app_loading.dart';
import '../widgets/common/carev_app_bar.dart';
import 'approval_detail_screen.dart';
import 'approval_hub_screen.dart';

/// 결재 문서 번호만 들고 온 경우(알림) — 문서를 받아 결재 상세를 연다.
///
/// 결재 알림을 누르면 결재함 목록이 열려 그 문서를 다시 찾아야 했다(2026-10-22 "전자결재도
/// 알림을 누르면 그 문서로 가야"). 상세 화면은 목록에서 받은 문서를 들고 시작하는데 알림에는
/// 번호뿐이라, 받기 전까지는 빈 문서에 승인·반려 단추가 보일 수 있다. 그래서 문서를 받은 뒤에 연다.
class ApprovalDetailLoaderScreen extends StatefulWidget {
  final int approvalId;

  const ApprovalDetailLoaderScreen({super.key, required this.approvalId});

  @override
  State<ApprovalDetailLoaderScreen> createState() =>
      _ApprovalDetailLoaderScreenState();
}

class _ApprovalDetailLoaderScreenState
    extends State<ApprovalDetailLoaderScreen> {
  ApprovalRequest? _approval;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final provider = context.read<ApprovalProvider>();
    final approval = await provider.loadApprovalDetail(
      approvalId: widget.approvalId,
    );
    if (!mounted) return;
    setState(() {
      _approval = approval;
      _error = approval == null
          ? (provider.errorMessage == ApprovalProvider.goneDocumentMessage
                ? ApprovalProvider.goneDocumentMessage
                : '결재 문서를 불러오지 못했습니다')
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final approval = _approval;
    if (approval != null) return ApprovalDetailScreen(approval: approval);

    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: const CareVAppBar(title: '결재 상세', centerTitle: true),
      body: _error == null
          ? const Center(child: AppLoading())
          : AppEmptyState(
              icon: Icons.fact_check_outlined,
              title: _error!,
              description: '결재함에서 지금 문서를 확인해 주세요.',
              actionLabel: '결재함 열기',
              onAction: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const ApprovalHubScreen(initialTab: 1),
                ),
              ),
            ),
    );
  }
}
