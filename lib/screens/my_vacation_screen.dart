import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vacation_provider.dart';
import '../providers/auth_provider.dart';
import '../models/vacation_request.dart';
import '../theme/app_colors.dart';
import '../theme/app_lines.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_count_up.dart';
import '../widgets/common/app_empty_state.dart';
import '../widgets/common/app_refresh.dart';
import '../widgets/common/app_sheet_frame.dart';
import '../widgets/common/carev_app_bar.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/common/app_tag.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_section_header.dart';
import '../widgets/vacation_planning_banner.dart';

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

  /// 삭제 확인 — B안: 가운데 창 대신 아래 시트(경고 아이콘 + 제목 18 + 큰 단추 취소 1 : 삭제 1.7)
  void _showDeleteDialog(VacationRequest request) {
    bool isDeleting = false;

    showAppSheet<void>(
      context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) => AppSheetFrame(
          warning: true,
          title: '휴무 신청 삭제',
          message:
              '${request.date.month}월 ${request.date.day}일 휴무 신청을 삭제하시겠습니까?',
          actions: AppSheetActions(
            cancel: SeedButton(
              label: '취소',
              variant: SeedButtonVariant.neutralWeak,
              size: SeedButtonSize.large,
              onPressed: isDeleting ? null : () => Navigator.pop(context),
              isDisabled: isDeleting,
            ),
            confirm: SeedButton(
              label: '삭제',
              variant: SeedButtonVariant.critical,
              size: SeedButtonSize.large,
              isLoading: isDeleting,
              isDisabled: isDeleting,
              onPressed: () async {
                setState(() {
                  isDeleting = true;
                });

                final authProvider = context.read<AuthProvider>();
                final vacationProvider = context.read<VacationProvider>();
                final user = authProvider.currentUser;

                bool success = false;

                // 관리자인 경우 관리자용 API 사용
                if (user?.role == 'ADMIN') {
                  success = await vacationProvider.deleteVacationByAdmin(
                    vacationId: request.id,
                  );
                } else {
                  // 직원인 경우 기존 API 사용
                  success = await vacationProvider.deleteMyVacationRequest(
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
          children: [
            if (request.status == VacationStatus.approved) ...[
              const SizedBox(height: AppSpacing.space4),
              // B안 안내 상자: 테두리 없이 옅은 노랑, 모서리 12
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space4,
                  vertical: AppSpacing.space3,
                ),
                decoration: BoxDecoration(
                  color: AppSemanticColors.statusWarningBackground,
                  borderRadius: BorderRadius.circular(AppBorderRadius.control),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: AppSemanticColors.statusWarningIcon,
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    Expanded(
                      child: Text(
                        '승인된 휴무는 삭제 시 관리자에게 문의가 필요할 수 있습니다.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppSemanticColors.statusWarningText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
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
    // B안: 회색 바탕 위 흰 카드, 안쪽 화면 공통 상단 바(가운데 18, 꺾쇠 뒤로)
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundCanvas,
      appBar: widget.showAppBar ? const CareVAppBar(title: '내 휴무') : null,
      body: AppRefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 다음 신청 시 참고할 마감일·"다음 달만 받기" 안내 — 신청 내역만 보고는 알 수 없던 컨텍스트
            SliverToBoxAdapter(
              child: Consumer<VacationProvider>(
                builder: (context, vacationProvider, child) {
                  // 이 화면 배너는 '다가오는 마감' 안내가 목적 —
                  // 항상 다음 달 휴무분(마감일은 이번 달에 위치)을 보여준다
                  final now = DateTime.now();
                  final month = DateTime(now.year, now.month + 1);
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
                      deadline: vacationProvider.deadlineForTargetMonth(month),
                      deadlineTargetMonth: month,
                      deadlinePassed: vacationProvider
                          .isDeadlinePassedForTargetMonth(month),
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
                              color: AppSemanticColors.surfaceCard,
                              borderRadius: BorderRadius.circular(
                                AppBorderRadius.card,
                              ),
                              border: AppLines.cardBorder,
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

                if (vacationProvider.errorMessage.isNotEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        // B안: 테두리 없는 흰 카드, 경고 아이콘은 옅은 빨강 동그라미
                        child: Container(
                          margin: const EdgeInsets.all(AppSpacing.space8),
                          padding: const EdgeInsets.all(AppSpacing.space6),
                          decoration: BoxDecoration(
                            color: AppSemanticColors.surfaceCard,
                            borderRadius: BorderRadius.circular(
                              AppBorderRadius.card,
                            ),
                            border: AppLines.cardBorder,
                          ),
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
                                vacationProvider.errorMessage,
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppSemanticColors.statusErrorText,
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
                          child: const AppEmptyState(
                            icon: Icons.event_available,
                            title: '아직 휴무 신청 내역이 없어요',
                            description: '달력에서 날짜를 선택하여\n휴무를 신청해보세요',
                            topSpacing: AppSpacing.space8,
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

                // B안: 한 표면을 구분선으로 나누던 것을 회색 바탕 위 흰 카드 여러 장으로 —
                // 신청 현황 카드 하나 + 상태(대기·승인·거절)마다 카드 하나, 카드 사이는 간격 10.
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space4,
                    AppSpacing.cardGap,
                    AppSpacing.space4,
                    AppSpacing.space20, // 바텀 패딩
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildCard(
                          children: [
                            const SeedSectionHeader(title: '신청 현황'),
                            const SizedBox(height: AppSpacing.space4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildStatusCard(
                                    '대기',
                                    pendingRequests.length,
                                    AppSemanticColors.statusWarningText,
                                    Icons.schedule,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.space3),
                                Expanded(
                                  child: _buildStatusCard(
                                    '승인',
                                    approvedRequests.length,
                                    AppSemanticColors.statusSuccessText,
                                    Icons.check_circle,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.space3),
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
                          ],
                        ),
                      ),

                      if (pendingRequests.isNotEmpty)
                        _buildRequestGroup(
                          title: '대기 중',
                          requests: pendingRequests,
                          headerColor: AppSemanticColors.statusWarningIcon,
                          headerIcon: Icons.schedule,
                          baseDelayIndex: 0,
                        ),

                      if (approvedRequests.isNotEmpty)
                        _buildRequestGroup(
                          title: '승인됨',
                          requests: approvedRequests,
                          headerColor: AppSemanticColors.statusSuccessIcon,
                          headerIcon: Icons.check_circle,
                          baseDelayIndex: pendingRequests.length,
                        ),

                      if (rejectedRequests.isNotEmpty)
                        _buildRequestGroup(
                          title: '거절됨',
                          requests: rejectedRequests,
                          headerColor: AppSemanticColors.statusErrorIcon,
                          headerIcon: Icons.cancel,
                          baseDelayIndex:
                              pendingRequests.length + approvedRequests.length,
                        ),
                    ]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// B안 카드 — 흰 바탕, 테두리 없음, 모서리 16, 안쪽 16
  Widget _buildCard({
    required List<Widget> children,
    EdgeInsetsGeometry margin = EdgeInsets.zero,
  }) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppBorderRadius.card),
        border: AppLines.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildStatusCard(String label, int count, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: AppSpacing.space1),
        // 큰 숫자는 0에서 세어 올라간다(글자는 그대로 count)
        AppCountUp(
          value: count,
          style: AppTypography.heading4.copyWith(
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: color,
          ),
        ),
      ],
    );
  }

  // 카드 맨 위 제목 — 공용 SeedSectionHeader(16/w700) 앞에 상태 색 아이콘만 붙인다
  // (SeedSectionHeader는 아이콘/컬러 파라미터를 지원하지 않으므로).
  Widget _buildSectionHeader(
    String title,
    int count,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: AppSpacing.space6),
        const SizedBox(width: AppSpacing.space2),
        Expanded(child: SeedSectionHeader(title: '$title ($count)')),
      ],
    );
  }

  // 상태 그룹(대기/승인/거절) 하나 — B안: 흰 카드 하나에 [제목, 신청…]. 신청 사이는 구분선 대신 간격.
  Widget _buildRequestGroup({
    required String title,
    required List<VacationRequest> requests,
    required Color headerColor,
    required IconData headerIcon,
    required int baseDelayIndex,
  }) {
    final children = <Widget>[
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
      // 등장 시차 — 끝(delay + 0.3)이 1을 넘지 않게 묶는다(신청이 8건을 넘으면 Interval이 깨졌다)
      final delay = ((baseDelayIndex + i) * 0.1).clamp(0.0, 0.7).toDouble();

      if (i > 0) {
        // 신청 사이는 선으로 나눈다
        children.addAll(const [
          SizedBox(height: AppSpacing.space3),
          AppRowDivider(),
          SizedBox(height: AppSpacing.space3),
        ]);
      } else {
        children.add(const SizedBox(height: AppSpacing.space4));
      }
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
    }

    return _buildCard(
      margin: const EdgeInsets.only(top: AppSpacing.cardGap),
      children: children,
    );
  }

  // 신청 한 건 — 상태 그룹 카드 안에 이어 붙는다(여백은 카드가 준다)
  Widget _buildRequestCard(VacationRequest request) {
    final canDelete =
        request.status == VacationStatus.pending; // 대기 중인 상태에서만 삭제 가능

    return Padding(
      padding: EdgeInsets.zero,
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
                          // B안 둥근 아이콘 — 바탕은 상태 색(옅게) 그대로
                          Container(
                            width: AppSpacing.iconCircle,
                            height: AppSpacing.iconCircle,
                            decoration: BoxDecoration(
                              color: _getStatusColor(request.status),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.calendar_today,
                              size: 20,
                              color: _getStatusTextColor(request.status),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.space3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatDate(request.date),
                                  style: AppTypography.titleMedium.copyWith(
                                    color: AppSemanticColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.space2),
                                // 상태만 색(옅은 꼬리표), 연차·반차·필수 같은 분류는 회색 — 웹과 같은 규칙
                                Wrap(
                                  spacing: AppSpacing.space2,
                                  runSpacing: AppSpacing.space1,
                                  children: [
                                    AppTag(
                                      label: request.statusText,
                                      tone: _statusTone(request.status),
                                    ),
                                    if (request.duration !=
                                        VacationDuration.unused)
                                      AppTag(label: request.durationText),
                                    if (request.type == VacationType.mandatory)
                                      const AppTag(label: '필수'),
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
                    decoration: const BoxDecoration(
                      color: AppSemanticColors.statusErrorBackground,
                      shape: BoxShape.circle,
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
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.space3),
                decoration: BoxDecoration(
                  color: AppSemanticColors.fillDefault,
                  borderRadius: BorderRadius.circular(AppBorderRadius.control),
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
              // B안: 테두리 없이 옅은 빨강 칸
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.space3),
                decoration: BoxDecoration(
                  color: AppSemanticColors.statusErrorBackground,
                  borderRadius: BorderRadius.circular(AppBorderRadius.control),
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
                          style: AppTypography.titleSmall.copyWith(
                            color: AppSemanticColors.statusErrorText,
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

            const SizedBox(height: AppSpacing.space2),
            Text(
              '신청일 ${_formatDateTime(request.createdAt)}',
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            ),
          ],
        ),
      );
  }

  AppTagTone _statusTone(VacationStatus status) {
    switch (status) {
      case VacationStatus.approved:
        return AppTagTone.success;
      case VacationStatus.rejected:
        return AppTagTone.error;
      case VacationStatus.pending:
        return AppTagTone.warning;
    }
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
