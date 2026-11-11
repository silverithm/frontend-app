import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:provider/provider.dart';
import '../providers/approval_provider.dart';
import '../providers/auth_provider.dart';
import '../models/approval.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_tag.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_count_up.dart';
import '../widgets/common/app_list_entrance.dart';
import '../widgets/common/app_refresh.dart';
import '../widgets/common/app_skeleton.dart';
import '../widgets/common/app_fab.dart';
import '../widgets/common/carev_app_bar.dart';
import '../widgets/approval/approval_card.dart';
import '../widgets/seed/seed_button.dart';
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

  /// 결재 현황 숫자를 한 번 세었는지 — 새로고침 뒤 다시 그려질 때는 0부터 다시 세지 않는다.
  bool _statusCounted = false;

  /// 목록을 아래로 내리면 FAB 글자를 접는다(B안 알약 FAB).
  bool _fabCollapsed = false;

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
      backgroundColor: AppSemanticColors.backgroundCanvas,
      appBar: widget.showAppBar ? const CareVAppBar(title: '결재') : null,
      body: NotificationListener<UserScrollNotification>(
        onNotification: _onUserScroll,
        child: AppRefreshIndicator(
          onRefresh: _refreshData,
          // 현황 카드·결재 카드가 처음 한 번만 차례로 떠오른다 — 불러오기 분기 바깥에 두어
          // 새로고침 뒤 다시 그려져도 또 떠오르지 않는다.
          child: AppListEntrance(
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              Consumer<ApprovalProvider>(
                builder: (context, approvalProvider, child) {
                  if (approvalProvider.isLoading &&
                      approvalProvider.myApprovalRequests.isEmpty) {
                    // 첫 불러오기 — 결재 현황 카드 + 결재 카드 모양 뼈대
                    return const SliverToBoxAdapter(
                      child: _ApprovalListSkeleton(),
                    );
                  }

                  if (approvalProvider.isLoading) {
                    // 이미 받은 목록을 다시 받는 중 — 예전처럼 가운데 동그라미
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.space5),
                              decoration: BoxDecoration(
                                color: AppSemanticColors.surfaceCard,
                                borderRadius: BorderRadius.circular(
                                  AppBorderRadius.card,
                                ),
                              ),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppSemanticColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.space4),
                            Text(
                              '데이터를 불러오는 중...',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppSemanticColors.textSecondary,
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
                          child: AppCard(
                            margin: const EdgeInsets.all(AppSpacing.space8),
                            padding: const EdgeInsets.all(AppSpacing.space6),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(
                                    AppSpacing.space4,
                                  ),
                                  decoration: const BoxDecoration(
                                    color:
                                        AppSemanticColors.statusErrorBackground,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: AppSemanticColors.statusErrorIcon,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.space4),
                                Text(
                                  approvalProvider.errorMessage,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppSemanticColors.statusErrorText,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.space5),
                                SeedButton(
                                  label: '다시 시도',
                                  variant: SeedButtonVariant.neutralWeak,
                                  prefixIcon: Icons.refresh,
                                  onPressed: _refreshData,
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
                                // B안 빈 화면(AppEmptyState와 같은 모양) — 당겨서 새로고침이
                                // 이 목록의 스크롤에 걸리도록 위젯 대신 모양만 맞춘다.
                                Container(
                                  width: AppSpacing.space14,
                                  height: AppSpacing.space14,
                                  decoration: const BoxDecoration(
                                    color: AppSemanticColors.brandWeak,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.assignment_outlined,
                                    size: 26,
                                    color: AppSemanticColors.brandDefault,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.space3_5),
                                Text(
                                  '아직 결재 내역이 없어요',
                                  style: AppTypography.heading6.copyWith(
                                    color: AppSemanticColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.space2),
                                Text(
                                  '우측 하단 버튼을 눌러 새 결재를 작성해보세요',
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
                  final draftRequests = requests
                      .where((r) => r.status == ApprovalStatus.draft)
                      .toList();
                  final pendingRequests = requests
                      .where((r) => r.status == ApprovalStatus.pending)
                      .toList();
                  final approvedRequests = requests
                      .where((r) => r.status == ApprovalStatus.approved)
                      .toList();
                  final rejectedRequests = requests
                      .where((r) => r.status == ApprovalStatus.rejected)
                      .toList();

                  // 줄마다 차례 — 현황 카드·묶음 제목·결재 카드 순서(처음 8개만 연출)
                  var rise = 0;
                  final countStatus = !_statusCounted;
                  _statusCounted = true;

                  return SliverList(
                    delegate: SliverChildListDelegate([
                      // 결재 현황 요약 — B안: 테두리 없는 흰 카드 하나, 안은 선 대신 간격으로 나눈다
                      AppListEntranceItem(
                        index: rise++,
                        child: AppCard(
                          margin: const EdgeInsets.fromLTRB(
                            AppSpacing.screenGutter,
                            AppSpacing.space3,
                            AppSpacing.screenGutter,
                            0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  '결재 현황',
                                  style: AppTypography.heading6.copyWith(
                                    color: AppSemanticColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.space4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (draftRequests.isNotEmpty) ...[
                                    Expanded(
                                      child: _buildStatusCard(
                                        '임시저장',
                                        draftRequests.length,
                                        AppTagTone.neutral,
                                        countUp: countStatus,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.space2),
                                  ],
                                  Expanded(
                                    child: _buildStatusCard(
                                      '진행중',
                                      pendingRequests.length,
                                      AppTagTone.warning,
                                      countUp: countStatus,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.space2),
                                  Expanded(
                                    child: _buildStatusCard(
                                      '승인',
                                      approvedRequests.length,
                                      AppTagTone.success,
                                      countUp: countStatus,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.space2),
                                  Expanded(
                                    child: _buildStatusCard(
                                      '반려',
                                      rejectedRequests.length,
                                      AppTagTone.error,
                                      countUp: countStatus,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space3),

                      // 결재 목록
                      // 임시저장 — 웹에서 상신 전 저장한 문서. 승인 대기와 혼동되지 않도록 별도 섹션.
                      if (draftRequests.isNotEmpty) ...[
                        AppListEntranceItem(
                          index: rise++,
                          child: _buildSectionHeader(
                            '임시저장',
                            draftRequests.length,
                            AppTagTone.neutral,
                          ),
                        ),
                        ...draftRequests.asMap().entries.map(
                          (entry) => AppListEntranceItem(
                            index: rise++,
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
                        ),
                        const SizedBox(height: AppSpacing.space3),
                      ],

                      if (pendingRequests.isNotEmpty) ...[
                        AppListEntranceItem(
                          index: rise++,
                          child: _buildSectionHeader(
                            '진행중',
                            pendingRequests.length,
                            AppTagTone.warning,
                          ),
                        ),
                        ...pendingRequests.asMap().entries.map(
                          (entry) => AppListEntranceItem(
                            index: rise++,
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
                        ),
                        const SizedBox(height: AppSpacing.space3),
                      ],

                      if (approvedRequests.isNotEmpty) ...[
                        AppListEntranceItem(
                          index: rise++,
                          child: _buildSectionHeader(
                            '승인됨',
                            approvedRequests.length,
                            AppTagTone.success,
                          ),
                        ),
                        ...approvedRequests.asMap().entries.map(
                          (entry) => AppListEntranceItem(
                            index: rise++,
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
                        ),
                        const SizedBox(height: AppSpacing.space3),
                      ],

                      if (rejectedRequests.isNotEmpty) ...[
                        AppListEntranceItem(
                          index: rise++,
                          child: _buildSectionHeader(
                            '반려됨',
                            rejectedRequests.length,
                            AppTagTone.error,
                          ),
                        ),
                        ...rejectedRequests.asMap().entries.map(
                          (entry) => AppListEntranceItem(
                            index: rise++,
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
        ),
      ),
      // B안 알약 FAB — 아래로 내리면 글자가 접히고 위로 올리면 다시 펴진다
      floatingActionButton: AppFab(
        icon: Icons.add,
        label: '결재 요청',
        onPressed: _navigateToForm,
        collapsed: _fabCollapsed,
      ),
    );
  }

  bool _onUserScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final collapse = switch (notification.direction) {
      ScrollDirection.reverse => true,
      ScrollDirection.forward => false,
      ScrollDirection.idle => _fabCollapsed,
    };
    if (collapse != _fabCollapsed) {
      setState(() => _fabCollapsed = collapse);
    }
    return false;
  }

  Widget _buildStatusCard(
    String label,
    int count,
    AppTagTone tone, {
    bool countUp = true,
  }) {
    return Column(
      children: [
        // 큰 숫자는 0에서 세어 올라간다(처음 한 번). 글자 모양은 그대로.
        AppCountUp(
          value: count,
          animateOnFirstBuild: countUp,
          style: AppTypography.heading4.copyWith(
            color: AppSemanticColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.space1_5),
        // 상태 태그 — B안 옅은 알약(색 뜻 그대로)
        FittedBox(
          fit: BoxFit.scaleDown,
          child: AppTag(label: label, tone: tone),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, AppTagTone tone) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter + AppSpacing.space1,
        AppSpacing.space3,
        AppSpacing.screenGutter,
        AppSpacing.space2_5,
      ),
      child: Row(
        children: [
          Flexible(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleMedium.copyWith(
                  color: AppSemanticColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          // 카운트 태그 — B안 옅은 알약
          AppTag(label: count.toString(), tone: tone),
        ],
      ),
    );
  }
}

/// 결재 신청 첫 불러오기 뼈대 — 결재 현황 카드(제목 + 숫자 네 칸) + 묶음 제목 + 결재 카드 세 장.
/// 실제 목록과 같은 바깥 여백(좌우 20/16·카드 사이 12)이라 내용이 떠도 덜 튄다.
class _ApprovalListSkeleton extends StatelessWidget {
  const _ApprovalListSkeleton();

  @override
  Widget build(BuildContext context) {
    final cardDecoration = BoxDecoration(
      color: AppSemanticColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppBorderRadius.card),
    );
    return AppSkeleton(
      // 흰 카드 안의 뼈는 한 단계 옅은 색
      baseColor: AppSemanticColors.skeletonBaseOnCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.space3,
              AppSpacing.screenGutter,
              0,
            ),
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSkeletonLine(widthFactor: 0.3, height: AppSpacing.space5),
                const SizedBox(height: AppSpacing.space4),
                Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.space2),
                      const Expanded(
                        child: Column(
                          children: [
                            AppSkeletonBox(
                              width: AppSpacing.space8,
                              height: AppSpacing.space6,
                              radius: AppBorderRadius.base,
                            ),
                            SizedBox(height: AppSpacing.space1_5),
                            AppSkeletonBox(
                              width: AppSpacing.space12,
                              height: AppSpacing.space6,
                              radius: AppBorderRadius.full,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenGutter + AppSpacing.space1,
              AppSpacing.space3,
              AppSpacing.screenGutter,
              AppSpacing.space2_5,
            ),
            child: AppSkeletonLine(widthFactor: 0.2, height: AppSpacing.space4),
          ),
          for (var i = 0; i < 3; i++)
            const AppSkeletonCard(
              standalone: false,
              margin: EdgeInsets.fromLTRB(
                AppSpacing.space4,
                0,
                AppSpacing.space4,
                AppSpacing.cardGap,
              ),
            ),
        ],
      ),
    );
  }
}
