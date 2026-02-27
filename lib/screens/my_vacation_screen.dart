import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../providers/vacation_provider.dart';
import '../providers/auth_provider.dart';
import '../models/vacation_request.dart';
import '../widgets/common/notification_bell.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
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
      vacationProvider.loadMyVacationRequests(
        authProvider.currentUser!.id,
        companyId: authProvider.currentUser!.company?.id ?? '1',
        userName: authProvider.currentUser!.name,
      );
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

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => shadcn.AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppSemanticColors.statusErrorBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: AppSemanticColors.statusErrorIcon,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '휴무 신청 삭제',
                style: AppTypography.heading6.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppSemanticColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${request.date.month}월 ${request.date.day}일 휴무 신청을 삭제하시겠습니까?',
                  style: AppTypography.bodyLarge,
                ),
              ),
              if (request.status == VacationStatus.approved) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.statusWarningBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppSemanticColors.statusWarningBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: AppSemanticColors.statusWarningIcon),
                      const SizedBox(width: 8),
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
            ],
          ),
          actions: [
            shadcn.OutlineButton(
              onPressed: isDeleting ? null : () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            shadcn.DestructiveButton(
              onPressed: isDeleting
                  ? null
                  : () async {
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('휴무 신청이 삭제되었습니다'),
                            backgroundColor: AppSemanticColors.statusSuccessIcon,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      } else if (mounted) {
                        Navigator.pop(context);
                        // 에러 메시지는 VacationProvider에서 처리됨
                      }
                    },
              child: isDeleting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppSemanticColors.textInverse),
                      ),
                    )
                  : const Text('삭제'),
            ),
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
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(
                '내 휴무',
                style: AppTypography.heading6.copyWith(
                  color: AppSemanticColors.textPrimary,
                ),
              ),
              backgroundColor: AppSemanticColors.backgroundPrimary,
              elevation: 0,
              centerTitle: true,
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: AppSpacing.space4),
                  child: const NotificationBell(),
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            Consumer<VacationProvider>(
              builder: (context, vacationProvider, child) {
                if (vacationProvider.isLoading) {
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

                if (vacationProvider.errorMessage.isNotEmpty) {
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
                                vacationProvider.errorMessage,
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

                final requests = vacationProvider.vacationRequests;

                if (requests.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Container(
                            margin: const EdgeInsets.all(32),
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: AppSemanticColors.surfaceDefault,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppSemanticColors.borderDefault,
                                width: 1,
                              ),
                            ),
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
                                    Icons.event_available,
                                    size: 64,
                                    color: AppSemanticColors.textTertiary,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  '휴무 신청 내역이 없습니다',
                                  style: AppTypography.heading6.copyWith(
                                    color: AppSemanticColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
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
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppSemanticColors.surfaceDefault,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppSemanticColors.borderDefault,
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppSemanticColors.backgroundTertiary,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.analytics,
                                      color: AppSemanticColors.textSecondary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '신청 현황',
                                    style: AppTypography.heading6.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppSemanticColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
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
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildStatusCard(
                                      '승인',
                                      approvedRequests.length,
                                      AppSemanticColors.statusSuccessIcon,
                                      Icons.check_circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
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

                    const SizedBox(height: 8),

                    // 신청 목록
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
                                child: _buildRequestCard(entry.value),
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
                                child: _buildRequestCard(entry.value),
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
                            final delay =
                                (pendingRequests.length +
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
                                child: _buildRequestCard(entry.value),
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
    );
  }

  Widget _buildStatusCard(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppSemanticColors.borderDefault, width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
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
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    int count,
    Color color,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppSemanticColors.borderDefault, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppSemanticColors.textInverse, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            '$title ($count)',
            style: AppTypography.heading6.copyWith(
              fontWeight: FontWeight.bold,
              color: AppSemanticColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(VacationRequest request) {
    final canCancel = request.status == VacationStatus.pending;
    final canDelete = request.status == VacationStatus.pending; // 대기 중인 상태에서만 삭제 가능

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppSemanticColors.borderDefault,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getStatusTextColor(
                                request.status,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: _getStatusTextColor(request.status),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusTextColor(request.status),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        request.statusText,
                                        style: AppTypography.labelSmall.copyWith(
                                          color: AppSemanticColors.textInverse,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (request.duration !=
                                        VacationDuration.unused)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppSemanticColors.interactiveSecondaryDefault,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          request.durationText,
                                          style: AppTypography.labelSmall.copyWith(
                                            color: AppSemanticColors.textInverse,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    if (request.type ==
                                        VacationType.mandatory) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppSemanticColors.statusWarningIcon,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CustomPaint(
                                                painter: StarPainter(
                                                  color: AppSemanticColors.textInverse,
                                                ),
                                                size: const Size(14, 14),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '필수',
                                              style: AppTypography.labelSmall.copyWith(
                                                color: AppSemanticColors.textInverse,
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
                      borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppSemanticColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppSemanticColors.borderSubtle, width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.note_outlined,
                      size: 16,
                      color: AppSemanticColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppSemanticColors.statusErrorBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppSemanticColors.statusErrorBorder, width: 1),
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
                        const SizedBox(width: 8),
                        Text(
                          '거절 사유',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppSemanticColors.statusErrorText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
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

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppSemanticColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(8),
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
