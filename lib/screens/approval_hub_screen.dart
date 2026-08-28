import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/approval_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/admin_utils.dart';
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
        // 탭 루트에선 canPop=false라 자동으로 안 뜨고,
        // 알림에서 push로 열리면 뒤로가기가 생긴다
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
            child: Consumer2<ApprovalProvider, AuthProvider>(
              builder: (context, approvalProvider, authProvider, child) {
                final currentUser = authProvider.currentUser;
                final isAdmin = AdminUtils.hasAdminPermission(currentUser);
                // 지금 내가 처리할 차례인 결재 건수 — 관리자·직원 모두 "내가" 처리할
                // 건수만 센다(결재선에서 내가 현재 단계인 문서, 결재선 없는 legacy는
                // 관리자만 처리 가능하므로 그때만). 회사 전체 대기 건수가 아니다.
                final myTurnCount = approvalProvider.myTurnCount(
                  myId: currentUser?.id,
                  isAdmin: isAdmin,
                );

                return TabBar(
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
                  tabs: [
                    const Tab(text: '결재 신청'),
                    Tab(
                      child: _TabLabelWithBadge(
                        label: '결재 관리',
                        count: myTurnCount,
                      ),
                    ),
                  ],
                );
              },
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

/// 탭 라벨 + 카카오톡 안읽음처럼 눈에 띄는 빨간 원형 배지.
/// count가 0이면 배지를 아예 그리지 않는다. 두 자리를 넘으면 "99+"로 자른다.
class _TabLabelWithBadge extends StatelessWidget {
  final String label;
  final int count;

  const _TabLabelWithBadge({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    // 배지가 라벨 오른쪽 위로 겹쳐 나가므로 자리를 미리 비워둔다.
    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 스타일은 지정하지 않는다 — TabBar가 선택 상태에 따라
          // labelColor/labelStyle을 DefaultTextStyle로 내려준다.
          Text(label),
          if (count > 0)
            Positioned(
              top: -6,
              right: -10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  // 앱 토큰 중 error 계열(red600) — 눈에 띄는 경고색으로 새로 만들지 않고 기존 토큰 사용
                  color: AppSemanticColors.statusErrorIcon,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppSemanticColors.backgroundPrimary,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
