import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'admin_vacation_management_screen.dart';
import 'admin_approval_management_screen.dart';
import 'admin_approval_template_screen.dart';

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
    _tabController = TabController(length: 3, vsync: this);
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

    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: Text(
          '승인 관리',
          style: AppTypography.heading6.copyWith(
            color: AppSemanticColors.textInverse,
          ),
        ),
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        foregroundColor: AppSemanticColors.textInverse,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(130),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.textInverse.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.fact_check,
                        color: AppSemanticColors.textInverse,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '승인 요청 관리',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppSemanticColors.textInverse
                                  .withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.textInverse.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'ADMIN',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppSemanticColors.textInverse
                              .withValues(alpha: 0.9),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppSemanticColors.textInverse.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppSemanticColors.textInverse,
                  unselectedLabelColor:
                      AppSemanticColors.textInverse.withValues(alpha: 0.6),
                  indicatorColor: AppSemanticColors.textInverse,
                  indicatorWeight: 3,
                  labelStyle: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: AppTypography.labelMedium,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.event_note, size: 20),
                      text: '휴무 승인',
                    ),
                    Tab(
                      icon: Icon(Icons.assignment, size: 20),
                      text: '결재 승인',
                    ),
                    Tab(
                      icon: Icon(Icons.description, size: 20),
                      text: '양식 관리',
                    ),
                  ],
                ),
              ),
            ],
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
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(
                icon: Icon(Icons.event_note, size: 20),
                text: '휴무 승인',
              ),
              Tab(
                icon: Icon(Icons.assignment, size: 20),
                text: '결재 승인',
              ),
              Tab(
                icon: Icon(Icons.description, size: 20),
                text: '양식 관리',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _VacationManagementTab(),
              AdminApprovalManagementScreen(),
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
