import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'admin_approval_management_screen.dart';
import 'approval_list_screen.dart';

/// 전자결재 탭 — 결재 신청 / 결재 관리 두 화면만 (2026-08 개편).
///
/// 관리자·직원 모두 같은 구조를 쓴다. '결재 관리'는 서버(GET /v1/approvals)가
/// 열람 권한(관리자·기안자·결재선 참여자·열람 대상)으로 목록을 걸러주므로,
/// 관리자가 아니어도 결재선에 오른 문서를 여기서 보고 내 차례면 승인한다.
/// 예전 승인함의 휴무 승인·가입 승인·양식 관리는 각자 자리(일정 탭 근무조정,
/// 전체 탭 회원관리·기관 관리)로 옮겼다.
class ApprovalHubScreen extends StatefulWidget {
  /// 시작 탭 인덱스 — 0: 결재 신청, 1: 결재 관리.
  /// 결재 도착 알림은 관리 탭으로 바로 연다.
  final int initialTab;

  const ApprovalHubScreen({super.key, this.initialTab = 0});

  @override
  State<ApprovalHubScreen> createState() => _ApprovalHubScreenState();
}

class _ApprovalHubScreenState extends State<ApprovalHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: Text('전자결재', style: AppTypography.heading5),
        backgroundColor: AppSemanticColors.backgroundPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppSemanticColors.borderDefault,
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppSemanticColors.interactivePrimaryDefault,
              unselectedLabelColor: AppSemanticColors.textTertiary,
              indicatorColor: AppSemanticColors.interactivePrimaryDefault,
              indicatorWeight: 2,
              labelStyle: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: AppTypography.labelMedium,
              dividerColor: AppColors.transparent,
              tabs: const [
                Tab(text: '결재 신청'),
                Tab(text: '결재 관리'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // 결재 신청 — 내가 기안한 문서 목록 + 작성 FAB
          ApprovalListScreen(showAppBar: false),
          // 결재 관리 — 열람 범위 문서함 (내 차례 승인 / 관리자 직권·일괄)
          AdminApprovalManagementScreen(),
        ],
      ),
    );
  }
}
