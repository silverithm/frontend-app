import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'admin_vacation_management_screen.dart';
import 'admin_approval_management_screen.dart';
import 'admin_approval_template_screen.dart';
import 'admin_user_management_screen.dart';

class AdminUnifiedApprovalScreen extends StatefulWidget {
  final bool showAppBar;
  const AdminUnifiedApprovalScreen({super.key, this.showAppBar = true});

  @override
  State<AdminUnifiedApprovalScreen> createState() =>
      _AdminUnifiedApprovalScreenState();
}

class _AdminUnifiedApprovalScreenState extends State<AdminUnifiedApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showAppBar) {
      return _buildEmbeddedView();
    }

    // 슬림 상단: 타이틀 1개(AppBar) + 탭바만. 아이콘 배지·서브텍스트·ADMIN 배지로
    // 이중 강조하지 않는다 (Seed 레이아웃 원칙 — 중복 레이어 금지).
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: Text('승인 관리', style: AppTypography.heading5),
        backgroundColor: AppSemanticColors.backgroundPrimary,
        elevation: 0,
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
                Tab(text: '휴무 승인'),
                Tab(text: '결재 승인'),
                Tab(text: '가입 승인'),
                Tab(text: '양식 관리'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // 휴무 승인 탭 - 기존 화면의 body 부분만 사용
          _VacationManagementTab(),
          // 결재 승인 탭
          AdminApprovalManagementScreen(),
          // 가입 승인 탭 - AdminUserManagementScreen의 승인 대기 목록 재사용
          AdminPendingUsersTab(),
          // 양식 관리 탭
          AdminApprovalTemplateScreen(),
        ],
      ),
    );
  }

  Widget _buildEmbeddedView() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppSemanticColors.backgroundPrimary,
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
            indicatorWeight: 3,
            labelStyle: AppTypography.labelMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: AppTypography.labelMedium,
            dividerColor: AppColors.transparent,
            tabs: const [
              Tab(text: '휴무 승인'),
              Tab(text: '결재 승인'),
              Tab(text: '가입 승인'),
              Tab(text: '양식 관리'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _VacationManagementTab(),
              AdminApprovalManagementScreen(),
              AdminPendingUsersTab(),
              AdminApprovalTemplateScreen(),
            ],
          ),
        ),
      ],
    );
  }
}

// 휴무 관리 탭 - AdminVacationManagementScreen의 body만 추출
class _VacationManagementTab extends StatefulWidget {
  const _VacationManagementTab();

  @override
  State<_VacationManagementTab> createState() => _VacationManagementTabState();
}

class _VacationManagementTabState extends State<_VacationManagementTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // AdminVacationManagementScreen의 내용을 재사용하기 위해
    // 해당 화면의 body만 렌더링 (AppBar 제외)
    return const _VacationManagementContent();
  }
}

// AdminVacationManagementScreen의 body 내용만 포함하는 위젯
class _VacationManagementContent extends StatelessWidget {
  const _VacationManagementContent();

  @override
  Widget build(BuildContext context) {
    // AdminVacationManagementScreen을 직접 사용하되
    // Scaffold로 감싸지 않고 body 내용만 표시
    // 실제로는 AdminVacationManagementScreen을 Navigator.push 없이
    // 직접 삽입하면 AppBar가 중복되므로
    // body 내용만 추출하여 사용해야 함
    //
    return const AdminVacationManagementScreen(showAppBar: false);
  }
}
