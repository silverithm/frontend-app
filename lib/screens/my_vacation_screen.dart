import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vacation_provider.dart';
import '../providers/auth_provider.dart';
import '../models/vacation_request.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_section_header.dart';
import '../widgets/vacation_planning_banner.dart';
import 'dart:math' as math;

class MyVacationScreen extends StatefulWidget {
  final bool showAppBar;

  const MyVacationScreen({super.key, this.showAppBar = true});

  @override
  State<MyVacationScreen> createState() => _MyVacationScreenState();
}

class _MyVacationScreenState extends State<MyVacationScreen>
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

    // 화면이 다시 포커스를 받을 때마다 데이터 새로고침
    if (_hasLoadedInitialData) {
      _refreshData();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 앱이 포그라운드로 돌아올 때 데이터 새로고침
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  void _loadInitialData() {
    final authProvider = context.read<AuthProvider>();
    final vacationProvider = context.read<VacationProvider>();

    if (authProvider.currentUser != null) {
      final companyId = authProvider.currentUser!.company?.id ?? '1';
      vacationProvider.loadMyVacationRequests(
        authProvider.currentUser!.id,
        companyId: companyId,
        userName: authProvider.currentUser!.name,
      );
      // 휴무 달력 탭을 거치지 않고 바로 "내 휴무"로 들어올 수도 있어 마감일 설정을 여기서도 로드한다
      vacationProvider.loadPlanningSettings(companyId: companyId);
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
    final vacationProvider = context.read<VacationProvider>();

    if (authProvider.currentUser != null) {
      await vacationProvider.loadMyVacationRequests(
        authProvider.currentUser!.id,
        companyId: authProvider.currentUser!.company?.id ?? '1',
        userName: authProvider.currentUser!.name,
      );
    }
  }

  void _showDeleteDialog(VacationRequest request) {
    bool isDeleting = false;

    AppDialog.showCustom<void>(
      context,
      barrierColor: AppColors.black.withValues(alpha: 0.5),
      child: StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(AppSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.space2),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.statusErrorBackground,
                      borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: AppSemanticColors.statusErrorIcon,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: Text(
                      '휴무 신청 삭제',
                      style: AppTypography.heading6.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space4),
              Container(
                padding: const EdgeInsets.all(AppSpacing.space4),
                decoration: BoxDecoration(
                  color: AppSemanticColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                ),
                child: Text(
                  '${request.date.month}월 ${request.date.day}일 휴무 신청을 삭제하시겠습니까?',
                  style: AppTypography.bodyLarge,
                ),
              ),
              if (request.status == VacationStatus.approved) ...[
                const SizedBox(height: AppSpacing.space3),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space3),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.statusWarningBackground,
                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    border: Border.all(
                      color: AppSemanticColors.statusWarningBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: AppSemanticColors.statusWarningIcon,
                      ),
                      const SizedBox(width: AppSpacing.space2),
                      Expanded(
                        child: Text(
                          '승인된 휴무는 삭제 시 관리자에게 문의가 필요할 수 있습니다.',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppSemanticColors.statusWarningText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.space6),
              Row(
                children: [
                  Expanded(
                    child: SeedButton(
                      label: '취소',
                      variant: SeedButtonVariant.neutralOutline,
                      onPressed: isDeleting
                          ? null
                          : () => Navigator.pop(context),
                      isDisabled: isDeleting,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: SeedButton(
                      label: '삭제',
                      variant: SeedButtonVariant.critical,
                      isLoading: isDeleting,
                      isDisabled: isDeleting,
                      onPressed: () async {
                        setState(() {
                          isDeleting = true;
                        });

                        final authProvider = context.read<AuthProvider>();
                        final vacationProvider = context
                            .read<VacationProvider>();
                        final user = authProvider.currentUser;

                        bool success = false;

                        // 관리자인 경우 관리자용 API 사용
                        if (user?.role == 'ADMIN') {
                          success = await vacationProvider
                              .deleteVacationByAdmin(vacationId: request.id);
                        } else {
                          // 직원인 경우 기존 API 사용
                          success = await vacationProvider
                              .deleteMyVacationRequest(
                                vacationId: request.id,
                                userName: user?.name ?? '',
                                userId: user?.id ?? '',
                                password: '', // 빈 비밀번호로 전송
                              );
                        }

                        setState(() {
                          isDeleting = false;
                        });

                        if (success && mounted) {
                          Navigator.pop(context);
                          // 삭제 성공 후 데이터 새로고침
                          await _refreshData();
                          if (mounted) {
                            AppSnackBar.showSuccess(context,
                                message: '휴무 신청이 삭제되었습니다');
                          }
                        } else if (mounted) {
                          Navigator.pop(context);
                          // 에러 메시지는 VacationProvider에서 처리됨
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    final weekday = weekdays[date.weekday % 7];
    return '${date.year}년 ${date.month}월 ${date.day}일 ($weekday)';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: widget.showAppBar
          ? AppBar(
              title: Text('내 휴무', style: AppTypography.heading5),
              backgroundColor: AppSemanticColors.backgroundPrimary,
              elevation: 0,
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 다음 신청 시 참고할 마감일·"다음 달만 받기" 안내 — 신청 내역만 보고는 알 수 없던 컨텍스트
            SliverToBoxAdapter(
              child: Consumer<VacationProvider>(
                builder: (context, vacationProvider, child) {
                  final now = DateTime.now();
                  final month = vacationProvider.isNextMonthOnly
                      ? vacationProvider.nextMonthOnlyMonth
                      : DateTime(now.year, now.month);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.space4,
                      AppSpacing.space3,
                      AppSpacing.space4,
                      0,
                    ),
                    child: VacationPlanningBanner(
                      nextMonthOnly: vacationProvider.isNextMonthOnly,
                      allowedMonth: vacationProvider.isNextMonthOnly
                          ? vacationProvider.nextMonthOnlyMonth
                          : null,
                      deadline: vacationProvider.deadlineForMonth(month),
                      deadlinePassed: vacationProvider.isDeadlinePassedForMonth(
                        month,
                      ),
                    ),
                  );
                },
              ),
            ),
            Consumer<VacationProvider>(
              builder: (context, vacationProvider, child) {
                if (vacationProvider.isLoading) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.space5),
                            decoration: BoxDecoration(
                              color: AppSemanticColors.surfaceDefault,
                              borderRadius: BorderRadius.circular(
                                AppBorderRadius.xl2,
                              ),
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
                          const SizedBox(height: AppSpacing.space4),
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

                if (vacationProvider.errorMessage.isNotEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          margin: const EdgeInsets.all(AppSpacing.space8),
                          padding: const EdgeInsets.all(AppSpacing.space6),
                          decoration: BoxDecoration(
                            color: AppSemanticColors.surfaceDefault,
                            borderRadius: BorderRadius.circular(
                              AppBorderRadius.xl2,
                            ),
                            border: Border.all(
                              color: AppSemanticColors.statusErrorBorder,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(
                                  AppSpacing.space4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      AppSemanticColors.statusErrorBackground,
                                  borderRadius: BorderRadius.circular(
                                    AppBorderRadius.xl2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: AppSemanticColors.statusErrorIcon,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.space4),
                              Text(
                                vacationProvider.errorMessage,
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppSemanticColors.statusErrorText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.space5),
                              SeedButton(
                                label: '다시 시도',
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

                final requests = vacationProvider.vacationRequests;

                if (requests.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Container(
                            margin: const EdgeInsets.all(AppSpacing.space8),
                            padding: const EdgeInsets.all(AppSpacing.space8),
                            decoration: BoxDecoration(
                              color: AppSemanticColors.surfaceDefault,
                              borderRadius: BorderRadius.circular(
                                AppBorderRadius.xl3,
                              ),
                              border: Border.all(
                                color: AppSemanticColors.borderDefault,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(
                                    AppSpacing.space5,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        AppSemanticColors.backgroundSecondary,
                                    borderRadius: BorderRadius.circular(
                                      AppBorderRadius.xl2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.event_available,
                                    size: 64,
                                    color: AppSemanticColors.textTertiary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.space6),
                                Text(
                                  '아직 휴무 신청 내역이 없어요',
                                  style: AppTypography.heading6.copyWith(
                                    color: AppSemanticColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.space2),
                                Text(
                                  '달력에서 날짜를 선택하여\n휴무를 신청해보세요',
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
                    ),
                  );
                }

                // 상태별로 그룹화
                final pendingRequests = requests
                    .where((r) => r.status == VacationStatus.pending)
                    .toList();
                final approvedRequests = requests
                    .where((r) => r.status == VacationStatus.approved)
                    .toList();
                final rejectedRequests = requests
                    .where((r) => r.status == VacationStatus.rejected)
                    .toList();

                return SliverList(
                  delegate: SliverChildListDelegate([
                    // one-surface 원칙: 신청현황 요약 + 상태별 섹션 + 신청 카드들을
                    // 흰 카드 여러 개로 쪼개지 않고 하나의 표면 위에서 Divider로만 구분한다.
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        margin: const EdgeInsets.all(AppSpacing.space4),
                        decoration: BoxDecoration(
                          color: AppSemanticColors.surfaceDefault,
                          borderRadius: BorderRadius.circular(
                            AppBorderRadius.xl2,
                          ),
                          border: Border.all(
                            color: AppSemanticColors.borderDefault,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.space5),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(
                                          AppSpacing.space3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppSemanticColors
                                              .backgroundTertiary,
                                          borderRadius: BorderRadius.circular(
                                            AppBorderRadius.xl2,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.analytics,
                                          color:
                                              AppSemanticColors.textSecondary,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.space3),
                                      Text(
                                        '신청 현황',
                                        style: AppTypography.heading6
                                            .copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppSemanticColors
                                                  .textPrimary,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.space4),
                                  // 내부는 구분선으로만 나눈다 (카드 중첩 금지)
                                  IntrinsicHeight(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _buildStatusCard(
                                            '대기',
                                            pendingRequests.length,
                                            AppSemanticColors
                                                .statusWarningText,
                                            Icons.schedule,
                                          ),
                                        ),
                                        VerticalDivider(
                                          width: AppSpacing.space4,
                                          thickness: 1,
                                          color:
                                              AppSemanticColors.borderSubtle,
                                        ),
                                        Expanded(
                                          child: _buildStatusCard(
                                            '승인',
                                            approvedRequests.length,
                                            AppSemanticColors
                                                .statusSuccessText,
                                            Icons.check_circle,
                                          ),
                                        ),
                                        VerticalDivider(
                                          width: AppSpacing.space4,
                                          thickness: 1,
                                          color:
                                              AppSemanticColors.borderSubtle,
                                        ),
                                        Expanded(
                                          child: _buildStatusCard(
                                            '거절',
                                            rejectedRequests.length,
                                            AppSemanticColors.statusErrorText,
                                            Icons.cancel,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 신청 목록 — 상태 그룹마다 Divider로만 구분(각 그룹의 헤더/카드는
                            // 개별 흰 카드로 다시 감싸지 않고 같은 표면 위에 이어 붙인다)
                            if (pendingRequests.isNotEmpty)
                              ..._buildRequestGroup(
                                title: '대기 중',
                                requests: pendingRequests,
                                headerColor:
                                    AppSemanticColors.statusWarningIcon,
                                headerIcon: Icons.schedule,
                                baseDelayIndex: 0,
                              ),

                            if (approvedRequests.isNotEmpty)
                              ..._buildRequestGroup(
                                title: '승인됨',
                                requests: approvedRequests,
                                headerColor:
                                    AppSemanticColors.statusSuccessIcon,
                                headerIcon: Icons.check_circle,
                                baseDelayIndex: pendingRequests.length,
                              ),

                            if (rejectedRequests.isNotEmpty)
                              ..._buildRequestGroup(
                                title: '거절됨',
                                requests: rejectedRequests,
                                headerColor: AppSemanticColors.statusErrorIcon,
                                headerIcon: Icons.cancel,
                                baseDelayIndex:
                                    pendingRequests.length +
                                    approvedRequests.length,
                              ),

                            const SizedBox(height: AppSpacing.space2),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.space20), // 바텀 패딩
                  ]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String label, int count, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: AppSpacing.space1),
        Text(
          count.toString(),
          style: AppTypography.heading4.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // one-surface 원칙: 섹션헤더는 독립된 흰 카드가 아니라 목록 안의 플랫한 라벨이어야 한다
  // (신청현황 요약 카드·신청 카드들과 나란히 흰 박스가 반복되던 것을 정리).
  // 텍스트 부분은 공용 SeedSectionHeader로 통일하고, 상태별 색상 아이콘만 앞에 붙인다
  // (SeedSectionHeader는 아이콘/컬러 파라미터를 지원하지 않으므로).
  Widget _buildSectionHeader(
    String title,
    int count,
    Color color,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        AppSpacing.space2,
        AppSpacing.space4,
        AppSpacing.space2,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: AppSpacing.space5),
          const SizedBox(width: AppSpacing.space2),
          Expanded(child: SeedSectionHeader(title: '$title ($count)')),
        ],
      ),
    );
  }

  // 상태 그룹(대기/승인/거절) 하나를 [Divider, 섹션헤더, 카드…]로 구성해
  // 신청현황 요약과 같은 표면 위에 이어붙일 수 있게 한다 (카드 중첩 금지).
  List<Widget> _buildRequestGroup({
    required String title,
    required List<VacationRequest> requests,
    required Color headerColor,
    required IconData headerIcon,
    required int baseDelayIndex,
  }) {
    final children = <Widget>[
      Divider(height: 1, thickness: 1, color: AppSemanticColors.borderSubtle),
      SlideTransition(
        position: _slideAnimation,
        child: _buildSectionHeader(
          title,
          requests.length,
          headerColor,
          headerIcon,
        ),
      ),
    ];

    for (var i = 0; i < requests.length; i++) {
      final request = requests[i];
      final delay = (baseDelayIndex + i) * 0.1;

      children.add(
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: _animationController,
                curve: Interval(delay, delay + 0.3, curve: Curves.easeOutBack),
              ),
            );

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.3, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: _buildRequestCard(request),
              ),
            );
          },
        ),
      );

      if (i != requests.length - 1) {
        children.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: AppSpacing.space5,
            endIndent: AppSpacing.space5,
            color: AppSemanticColors.borderSubtle,
          ),
        );
      }
    }

    return children;
  }

  // one-surface 원칙: 바깥의 흰 카드 wrapper(Container 배경/보더/margin)는 제거하고
  // 내용(Padding 이하)만 유지 — 상위 표면 위에 이어 붙는 한 섹션으로 렌더링된다.
  Widget _buildRequestCard(VacationRequest request) {
    final canDelete =
        request.status == VacationStatus.pending; // 대기 중인 상태에서만 삭제 가능

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.space2),
                            decoration: BoxDecoration(
                              color: _getStatusColor(request.status),
                              borderRadius: BorderRadius.circular(
                                AppBorderRadius.lg,
                              ),
                            ),
                            child: Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: _getStatusTextColor(request.status),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.space2),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatDate(request.date),
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppSemanticColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.space2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.space3,
                                        vertical: AppSpacing.space1_5,
                                      ),
                                      decoration: BoxDecoration(
                                        // 배경은 전용 배경 토큰, 텍스트는 전용 텍스트 토큰으로 역할 분리
                                        // (이전엔 텍스트전용 토큰을 배경 채우기로 잘못 사용했음)
                                        color: _getStatusColor(request.status),
                                        borderRadius: BorderRadius.circular(
                                          AppBorderRadius.full,
                                        ),
                                      ),
                                      child: Text(
                                        request.statusText,
                                        style: AppTypography.labelSmall
                                            .copyWith(
                                              color: _getStatusTextColor(
                                                request.status,
                                              ),
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.space2),
                                    if (request.duration !=
                                        VacationDuration.unused)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.space2,
                                          vertical: AppSpacing.space1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppSemanticColors
                                              .interactivePrimaryDefault,
                                          borderRadius: BorderRadius.circular(
                                            AppBorderRadius.full,
                                          ),
                                        ),
                                        child: Text(
                                          request.durationText,
                                          style: AppTypography.labelSmall
                                              .copyWith(
                                                color: AppSemanticColors
                                                    .textInverse,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                    if (request.type ==
                                        VacationType.mandatory) ...[
                                      const SizedBox(width: AppSpacing.space2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.space3,
                                          vertical: AppSpacing.space1_5,
                                        ),
                                        decoration: BoxDecoration(
                                          // 아이콘전용 토큰을 배경 채우기로 쓰던 오용을 정정 —
                                          // 배경은 statusWarningBackground, 텍스트/아이콘은 statusWarningText
                                          color: AppSemanticColors
                                              .statusWarningBackground,
                                          borderRadius: BorderRadius.circular(
                                            AppBorderRadius.full,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: AppSpacing.space3_5,
                                              height: AppSpacing.space3_5,
                                              child: CustomPaint(
                                                painter: StarPainter(
                                                  color: AppSemanticColors
                                                      .statusWarningText,
                                                ),
                                                size: Size(
                                                  AppSpacing.space3_5,
                                                  AppSpacing.space3_5,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.space1,
                                            ),
                                            Text(
                                              '필수',
                                              style: AppTypography.labelSmall
                                                  .copyWith(
                                                    color: AppSemanticColors
                                                        .statusWarningText,
                                                    fontWeight: FontWeight.bold,
                                                  ),
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
                        ],
                      ),
                    ],
                  ),
                ),
                if (canDelete)
                  Container(
                    decoration: BoxDecoration(
                      color: AppSemanticColors.statusErrorBackground,
                      borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                    ),
                    child: IconButton(
                      onPressed: () => _showDeleteDialog(request),
                      icon: Icon(
                        Icons.delete_outlined,
                        color: AppSemanticColors.statusErrorIcon,
                      ),
                      tooltip: request.status == VacationStatus.pending
                          ? '신청 삭제'
                          : '휴무 삭제',
                    ),
                  ),
              ],
            ),

            if (request.reason != null && request.reason!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.space4),
              Container(
                padding: const EdgeInsets.all(AppSpacing.space3),
                decoration: BoxDecoration(
                  color: AppSemanticColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  border: Border.all(
                    color: AppSemanticColors.borderSubtle,
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.note_outlined,
                      size: 16,
                      color: AppSemanticColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    Expanded(
                      child: Text(
                        request.reason!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppSemanticColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (request.rejectionReason != null &&
                request.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.space4),
              Container(
                padding: const EdgeInsets.all(AppSpacing.space3),
                decoration: BoxDecoration(
                  color: AppSemanticColors.statusErrorBackground,
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  border: Border.all(
                    color: AppSemanticColors.statusErrorBorder,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: AppSemanticColors.statusErrorIcon,
                        ),
                        const SizedBox(width: AppSpacing.space2),
                        Text(
                          '거절 사유',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppSemanticColors.statusErrorText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space1),
                    Text(
                      request.rejectionReason!,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppSemanticColors.statusErrorText,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.space3),
            Container(
              padding: const EdgeInsets.all(AppSpacing.space2),
              decoration: BoxDecoration(
                color: AppSemanticColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              ),
              child: Text(
                '신청일: ${_formatDateTime(request.createdAt)}',
                style: AppTypography.labelSmall.copyWith(
                  color: AppSemanticColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
  }

  Color _getStatusColor(VacationStatus status) {
    switch (status) {
      case VacationStatus.approved:
        return AppSemanticColors.statusSuccessBackground;
      case VacationStatus.rejected:
        return AppSemanticColors.statusErrorBackground;
      case VacationStatus.pending:
        return AppSemanticColors.statusWarningBackground;
    }
  }

  Color _getStatusTextColor(VacationStatus status) {
    switch (status) {
      case VacationStatus.approved:
        return AppSemanticColors.statusSuccessText;
      case VacationStatus.rejected:
        return AppSemanticColors.statusErrorText;
      case VacationStatus.pending:
        return AppSemanticColors.statusWarningText;
    }
  }
}

// 별표 그리기를 위한 CustomPainter
class StarPainter extends CustomPainter {
  final Color color;

  StarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.4;

    for (int i = 0; i < 10; i++) {
      // -90도부터 시작하여 별표가 위를 향하도록 수정
      final angle = ((i * 36) - 90) * (3.14159 / 180);
      final radius = i % 2 == 0 ? outerRadius : innerRadius;
      final x = centerX + radius * math.cos(angle);
      final y = centerY + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
