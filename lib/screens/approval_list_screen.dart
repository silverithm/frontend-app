import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../providers/approval_provider.dart';
import '../providers/auth_provider.dart';
import '../models/approval.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';
import '../widgets/approval/approval_card.dart';
import '../widgets/approval/approval_status_badge.dart';
import 'approval_detail_screen.dart';
import 'approval_form_screen.dart';

class ApprovalListScreen extends StatefulWidget {
  final bool showAppBar;

  const ApprovalListScreen({super.key, this.showAppBar = true});

  @override
  State<ApprovalListScreen> createState() => _ApprovalListScreenState();
}

class _ApprovalListScreenState extends State<ApprovalListScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _hasLoadedInitialData = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animationController = AnimationController(
      duration: AppTransitions.slowest,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutBack,
          ),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      _animationController.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_hasLoadedInitialData) {
      _refreshData();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  void _loadInitialData() {
    final authProvider = context.read<AuthProvider>();
    final approvalProvider = context.read<ApprovalProvider>();

    if (authProvider.currentUser != null) {
      final requesterId = authProvider.currentUser!.id;
      approvalProvider.loadMyApprovalRequests(requesterId: requesterId);
      _hasLoadedInitialData = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    final authProvider = context.read<AuthProvider>();
    final approvalProvider = context.read<ApprovalProvider>();

    if (authProvider.currentUser != null) {
      final requesterId = authProvider.currentUser!.id;
      await approvalProvider.loadMyApprovalRequests(requesterId: requesterId);
    }
  }

  void _navigateToForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ApprovalFormScreen()),
    );

    if (result == true) {
      _refreshData();
    }
  }

  void _navigateToDetail(ApprovalRequest approval) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApprovalDetailScreen(approval: approval),
      ),
    );

    if (result == true) {
      _refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(
                '결재',
                style: AppTypography.heading6.copyWith(
                  color: AppSemanticColors.textPrimary,
                ),
              ),
              backgroundColor: AppSemanticColors.backgroundPrimary,
              elevation: 0,
              centerTitle: true,
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            Consumer<ApprovalProvider>(
              builder: (context, approvalProvider, child) {
                if (approvalProvider.isLoading) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppSemanticColors.surfaceDefault,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppSemanticColors.borderDefault,
                                width: 1,
                              ),
                            ),
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppSemanticColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '데이터를 불러오는 중...',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppSemanticColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (approvalProvider.errorMessage.isNotEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          margin: const EdgeInsets.all(32),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppSemanticColors.surfaceDefault,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppSemanticColors.statusErrorBorder,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppSemanticColors.statusErrorBackground,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: AppSemanticColors.statusErrorIcon,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                approvalProvider.errorMessage,
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppSemanticColors.statusErrorText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 20),
                              shadcn.PrimaryButton(
                                onPressed: _refreshData,
                                leading: const Icon(Icons.refresh),
                                child: const Text('다시 시도'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final requests = approvalProvider.myApprovalRequests;

                if (requests.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppSemanticColors.backgroundSecondary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  Icons.assignment_outlined,
                                  size: 64,
                                  color: AppSemanticColors.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                '결재 요청 내역이 없습니다',
                                style: AppTypography.heading6.copyWith(
                                  color: AppSemanticColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '우측 하단 버튼을 눌러\n새 결재를 요청해보세요',
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppSemanticColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                // 상태별로 그룹화
                final pendingRequests = requests
                    .where((r) => r.status == ApprovalStatus.pending)
                    .toList();
                final approvedRequests = requests
                    .where((r) => r.status == ApprovalStatus.approved)
                    .toList();
                final rejectedRequests = requests
                    .where((r) => r.status == ApprovalStatus.rejected)
                    .toList();

                return SliverList(
                  delegate: SliverChildListDelegate([
                    // 결재 현황 요약 - 깔끔한 디자인
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppSemanticColors.surfaceDefault,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppSemanticColors.borderDefault,
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '결재 현황',
                                style: AppTypography.labelLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppSemanticColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatusCard(
                                      '대기',
                                      pendingRequests.length,
                                      AppSemanticColors.statusWarningIcon,
                                      Icons.schedule,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildStatusCard(
                                      '승인',
                                      approvedRequests.length,
                                      AppSemanticColors.statusSuccessIcon,
                                      Icons.check_circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildStatusCard(
                                      '거절',
                                      rejectedRequests.length,
                                      AppSemanticColors.statusErrorIcon,
                                      Icons.cancel,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 결재 목록
                    if (pendingRequests.isNotEmpty) ...[
                      SlideTransition(
                        position: _slideAnimation,
                        child: _buildSectionHeader(
                          '대기 중',
                          pendingRequests.length,
                          AppSemanticColors.statusWarningIcon,
                          Icons.schedule,
                        ),
                      ),
                      ...pendingRequests.asMap().entries.map(
                        (entry) => AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            final delay = entry.key * 0.1;
                            final animation =
                                Tween<double>(begin: 0.0, end: 1.0).animate(
                              CurvedAnimation(
                                parent: _animationController,
                                curve: Interval(
                                  delay,
                                  delay + 0.3,
                                  curve: Curves.easeOutBack,
                                ),
                              ),
                            );

                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.3, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.space4,
                                  ),
                                  child: ApprovalCard(
                                    approval: entry.value,
                                    onTap: () => _navigateToDetail(entry.value),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (approvedRequests.isNotEmpty) ...[
                      SlideTransition(
                        position: _slideAnimation,
                        child: _buildSectionHeader(
                          '승인됨',
                          approvedRequests.length,
                          AppSemanticColors.statusSuccessIcon,
                          Icons.check_circle,
                        ),
                      ),
                      ...approvedRequests.asMap().entries.map(
                        (entry) => AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            final delay =
                                (pendingRequests.length + entry.key) * 0.1;
                            final animation =
                                Tween<double>(begin: 0.0, end: 1.0).animate(
                              CurvedAnimation(
                                parent: _animationController,
                                curve: Interval(
                                  delay,
                                  delay + 0.3,
                                  curve: Curves.easeOutBack,
                                ),
                              ),
                            );

                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.3, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.space4,
                                  ),
                                  child: ApprovalCard(
                                    approval: entry.value,
                                    onTap: () => _navigateToDetail(entry.value),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (rejectedRequests.isNotEmpty) ...[
                      SlideTransition(
                        position: _slideAnimation,
                        child: _buildSectionHeader(
                          '거절됨',
                          rejectedRequests.length,
                          AppSemanticColors.statusErrorIcon,
                          Icons.cancel,
                        ),
                      ),
                      ...rejectedRequests.asMap().entries.map(
                        (entry) => AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            final delay = (pendingRequests.length +
                                    approvedRequests.length +
                                    entry.key) *
                                0.1;
                            final animation =
                                Tween<double>(begin: 0.0, end: 1.0).animate(
                              CurvedAnimation(
                                parent: _animationController,
                                curve: Interval(
                                  delay,
                                  delay + 0.3,
                                  curve: Curves.easeOutBack,
                                ),
                              ),
                            );

                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.3, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.space4,
                                  ),
                                  child: ApprovalCard(
                                    approval: entry.value,
                                    onTap: () => _navigateToDetail(entry.value),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 100), // 바텀 패딩
                  ]),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          color: AppSemanticColors.interactivePrimaryDefault,
          borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
        ),
        child: FloatingActionButton.extended(
          heroTag: 'approval_list_fab',
          onPressed: _navigateToForm,
          backgroundColor: AppColors.transparent,
          elevation: 0,
          icon: Icon(
            Icons.add,
            color: AppSemanticColors.textInverse,
          ),
          label: Text(
            '결재 요청',
            style: AppTypography.labelLarge.copyWith(
              color: AppSemanticColors.textInverse,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppSemanticColors.borderDefault, width: 1),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: AppTypography.heading4.copyWith(
              fontWeight: FontWeight.w600,
              color: AppSemanticColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          // 상태 태그
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    int count,
    Color color,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: AppTypography.labelLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: AppSemanticColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          // 카운트 태그
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              count.toString(),
              style: AppTypography.labelSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
