import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../models/notice.dart';
import '../models/schedule.dart';
import '../models/vacation_request.dart';
import '../providers/admin_provider.dart';
import '../providers/approval_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notice_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/vacation_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/admin_utils.dart';
import '../widgets/common/notification_bell.dart';
import 'admin_notice_management_screen.dart';
import 'admin_unified_approval_screen.dart';
import 'admin_user_management_screen.dart';
import 'approval_list_screen.dart';
import 'calendar_screen.dart';
import 'my_vacation_screen.dart';
import 'notice_detail_screen.dart';
import 'notice_list_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    final isAdmin = AdminUtils.canAccessAdminPages(user);
    final companyId = user.company?.id ?? '1';

    try {
      final futures = <Future<void>>[
        context.read<ScheduleProvider>().loadCalendarData(
          DateTime.now(),
          companyId: companyId,
        ),
      ];

      if (isAdmin) {
        futures.addAll([
          context.read<ApprovalProvider>().loadApprovalRequests(
            companyId: companyId,
            refresh: true,
          ),
          context.read<NoticeProvider>().loadNotices(
            companyId: companyId,
            refresh: true,
          ),
          context.read<AdminProvider>().loadPendingUsers(companyId),
          context.read<AdminProvider>().loadCompanyMembers(companyId),
        ]);
      } else {
        futures.addAll([
          context.read<VacationProvider>().loadMyVacationRequests(
            user.id,
            companyId: companyId,
            userName: user.name,
          ),
          context.read<ApprovalProvider>().loadMyApprovalRequests(
            requesterId: user.id,
            refresh: true,
          ),
          context.read<NoticeProvider>().loadPublishedNotices(
            companyId: companyId,
            refresh: true,
          ),
        ]);
      }

      await Future.wait(futures);

      if (!mounted) return;

      context.read<NotificationProvider>().loadNotifications(user.id);
      context.read<NoticeProvider>().loadUnreadNoticeCount(
        companyId: companyId,
        userId: user.id,
      );
    } catch (e) {
      debugPrint('[HomeScreen] 대시보드 데이터 로드 에러: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openApproval() {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(2);
      return;
    }

    final isAdmin = AdminUtils.canAccessAdminPages(
      context.read<AuthProvider>().currentUser,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => isAdmin
            ? const AdminUnifiedApprovalScreen()
            : const ApprovalListScreen(),
      ),
    );
  }

  void _openWorkAdjustment() {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(3);
      return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CalendarScreen()));
  }

  void _openMemberManagement() {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(4);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminUserManagementScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppSemanticColors.backgroundPrimary,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isAdmin = AdminUtils.canAccessAdminPages(user);
    final approvalProvider = context.watch<ApprovalProvider>();
    final noticeProvider = context.watch<NoticeProvider>();
    final adminProvider = context.watch<AdminProvider>();
    final vacationProvider = context.watch<VacationProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();

    final dashboardMetrics = _buildDashboardMetrics(
      isAdmin: isAdmin,
      approvalProvider: approvalProvider,
      noticeProvider: noticeProvider,
      adminProvider: adminProvider,
      vacationProvider: vacationProvider,
      scheduleProvider: scheduleProvider,
    );
    final recentNotices = _getRecentNotices(
      isAdmin: isAdmin,
      noticeProvider: noticeProvider,
    );
    final monthlyPreviewSchedules = _getMonthlyPreviewSchedules(
      scheduleProvider,
    );

    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: AppSemanticColors.interactivePrimaryDefault,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: AppSemanticColors.interactivePrimaryDefault,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.space5,
                      AppSpacing.space4,
                      AppSpacing.space5,
                      AppSpacing.space5,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '홈',
                                style: AppTypography.heading5.copyWith(
                                  color: AppSemanticColors.textInverse,
                                  fontWeight: AppTypography.fontWeightBold,
                                ),
                              ),
                            ),
                            _ProfileActionButton(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ProfileScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.space2),

                            const NotificationBell(
                              iconColor: AppSemanticColors.textInverse,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.space4),
                        Text(
                          '${user.name}님, 반갑습니다.',
                          style: AppTypography.heading6.copyWith(
                            color: AppSemanticColors.textInverse,
                            fontWeight: AppTypography.fontWeightBold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space1),
                        Text(
                          isAdmin
                              ? '대시보드, 공지사항, 월간 일정을 한 번에 확인하세요.'
                              : '오늘 필요한 공지와 월간 일정을 먼저 확인하세요.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppSemanticColors.textInverse.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space5,
                  AppSpacing.space5,
                  AppSpacing.space5,
                  AppSpacing.space8,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _SectionCard(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.space5,
                        AppSpacing.space3,
                        AppSpacing.space5,
                        AppSpacing.space5,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionHeader(
                            title: '대시보드',
                            subtitle: '주요 업무 현황',
                          ),
                          const SizedBox(height: AppSpacing.space4),
                          GridView.builder(
                            shrinkWrap: true,
                            primary: false,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: AppSpacing.space3,
                                  mainAxisSpacing: AppSpacing.space3,
                                  mainAxisExtent: 156,
                                ),
                            itemCount: dashboardMetrics.length,
                            itemBuilder: (context, index) {
                              return _DashboardMetricCard(
                                metric: dashboardMetrics[index],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space4),
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                            title: '공지사항',
                            subtitle: '최근 공지 미리보기',
                            actionLabel: '전체보기',
                            onAction: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => isAdmin
                                    ? const AdminNoticeManagementScreen()
                                    : const NoticeListScreen(),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space4),
                          if (recentNotices.isEmpty)
                            const _EmptySectionState(
                              icon: Icons.campaign_outlined,
                              title: '등록된 공지사항이 없습니다',
                              subtitle: '새 공지가 올라오면 이곳에 표시됩니다.',
                            )
                          else
                            ...recentNotices.asMap().entries.map((entry) {
                              final notice = entry.value;
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: entry.key == recentNotices.length - 1
                                      ? 0
                                      : AppSpacing.space3,
                                ),
                                child: _NoticePreviewTile(
                                  notice: notice,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => NoticeDetailScreen(
                                        noticeId: notice.id,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space4),
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                            title: '월간 일정',
                            subtitle: '이번 달 일정 미리보기',
                            actionLabel: '전체보기',
                            onAction: _openWorkAdjustment,
                          ),
                          const SizedBox(height: AppSpacing.space4),
                          if (monthlyPreviewSchedules.isEmpty)
                            const _EmptySectionState(
                              icon: Icons.schedule_outlined,
                              title: '이번 달 등록된 일정이 없습니다',
                              subtitle: '근무조정 탭에서 일정과 휴무 달력을 확인할 수 있습니다.',
                            )
                          else
                            ...monthlyPreviewSchedules.asMap().entries.map((
                              entry,
                            ) {
                              final schedule = entry.value;
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      entry.key ==
                                          monthlyPreviewSchedules.length - 1
                                      ? 0
                                      : AppSpacing.space3,
                                ),
                                child: _SchedulePreviewTile(schedule: schedule),
                              );
                            }),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<_DashboardMetric> _buildDashboardMetrics({
    required bool isAdmin,
    required ApprovalProvider approvalProvider,
    required NoticeProvider noticeProvider,
    required AdminProvider adminProvider,
    required VacationProvider vacationProvider,
    required ScheduleProvider scheduleProvider,
  }) {
    final currentMonthSchedules = _getCurrentMonthSchedules(scheduleProvider);
    final pendingVacationCount = vacationProvider.vacationRequests
        .where((request) => request.status == VacationStatus.pending)
        .length;

    if (isAdmin) {
      return [
        _DashboardMetric(
          icon: Icons.fact_check_outlined,
          label: '전자결재',
          caption: '승인 대기',
          count: approvalProvider.pendingCount,
          color: AppSemanticColors.interactivePrimaryDefault,
          onTap: _openApproval,
        ),
        _DashboardMetric(
          icon: Icons.people_outline_rounded,
          label: '회원관리',
          caption: '승인 요청',
          count: adminProvider.pendingUsers.length,
          color: AppSemanticColors.statusSuccessIcon,
          onTap: _openMemberManagement,
        ),
        _DashboardMetric(
          icon: Icons.campaign_outlined,
          label: '공지사항',
          caption: '등록 공지',
          count: noticeProvider.notices.length,
          color: AppSemanticColors.statusWarningIcon,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AdminNoticeManagementScreen(),
            ),
          ),
        ),
        _DashboardMetric(
          icon: Icons.schedule_outlined,
          label: '근무조정',
          caption: '이번 달 일정',
          count: currentMonthSchedules.length,
          color: AppSemanticColors.textSecondary,
          onTap: _openWorkAdjustment,
        ),
      ];
    }

    return [
      _DashboardMetric(
        icon: Icons.description_outlined,
        label: '전자결재',
        caption: '진행 중',
        count: approvalProvider.myPendingCount,
        color: AppSemanticColors.interactivePrimaryDefault,
        onTap: _openApproval,
      ),
      _DashboardMetric(
        icon: Icons.campaign_outlined,
        label: '공지사항',
        caption: '읽지 않음',
        count: noticeProvider.unreadNoticeCount,
        color: AppSemanticColors.statusWarningIcon,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NoticeListScreen())),
      ),
      _DashboardMetric(
        icon: Icons.calendar_today_outlined,
        label: '내 휴무',
        caption: '승인 대기',
        count: pendingVacationCount,
        color: AppSemanticColors.statusSuccessIcon,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const MyVacationScreen())),
      ),
      _DashboardMetric(
        icon: Icons.schedule_outlined,
        label: '근무조정',
        caption: '이번 달 일정',
        count: currentMonthSchedules.length,
        color: AppSemanticColors.textSecondary,
        onTap: _openWorkAdjustment,
      ),
    ];
  }

  List<Notice> _getRecentNotices({
    required bool isAdmin,
    required NoticeProvider noticeProvider,
  }) {
    final notices = List<Notice>.from(
      isAdmin ? noticeProvider.notices : noticeProvider.publishedNotices,
    );

    notices.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    return notices.take(3).toList();
  }

  List<Schedule> _getCurrentMonthSchedules(ScheduleProvider scheduleProvider) {
    final now = DateTime.now();
    final schedules = scheduleProvider.schedules.where((schedule) {
      return schedule.startDate.year == now.year &&
          schedule.startDate.month == now.month;
    }).toList();

    schedules.sort((a, b) => a.startDate.compareTo(b.startDate));
    return schedules;
  }

  List<Schedule> _getMonthlyPreviewSchedules(
    ScheduleProvider scheduleProvider,
  ) {
    return _getCurrentMonthSchedules(scheduleProvider).take(4).toList();
  }
}

class _DashboardMetric {
  final IconData icon;
  final String label;
  final String caption;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _DashboardMetric({
    required this.icon,
    required this.label,
    required this.caption,
    required this.count,
    required this.color,
    required this.onTap,
  });
}

class _ProfileActionButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ProfileActionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
        child: Container(
          width: AppSpacing.space10,
          height: AppSpacing.space10,
          decoration: BoxDecoration(
            color: AppSemanticColors.textInverse.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppSemanticColors.textInverse.withValues(alpha: 0.18),
            ),
          ),
          child: const Icon(
            Icons.person_outline,
            color: AppSemanticColors.textInverse,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.space5),
  });

  @override
  Widget build(BuildContext context) {
    return shadcn.Card(padding: padding, child: child);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTypography.heading6.copyWith(
                  color: AppSemanticColors.textPrimary,
                  fontWeight: AppTypography.fontWeightBold,
                ),
              ),
              const SizedBox(height: AppSpacing.space1),
              Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: AppTypography.labelMedium.copyWith(
                color: AppSemanticColors.interactivePrimaryDefault,
                fontWeight: AppTypography.fontWeightSemibold,
              ),
            ),
          ),
      ],
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  final _DashboardMetric metric;

  const _DashboardMetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
      child: InkWell(
        onTap: metric.onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.space4),
          decoration: BoxDecoration(
            color: metric.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
            border: Border.all(color: metric.color.withValues(alpha: 0.16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppSpacing.space9,
                height: AppSpacing.space9,
                decoration: BoxDecoration(
                  color: metric.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                ),
                child: Icon(metric.icon, color: metric.color, size: 20),
              ),
              const Spacer(),
              Text(
                metric.count.toString(),
                style: AppTypography.heading5.copyWith(
                  color: AppSemanticColors.textPrimary,
                  fontWeight: AppTypography.fontWeightBold,
                ),
              ),
              const SizedBox(height: AppSpacing.space1),
              Text(
                metric.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppSemanticColors.textPrimary,
                  fontWeight: AppTypography.fontWeightSemibold,
                ),
              ),
              const SizedBox(height: AppSpacing.space1),
              Text(
                metric.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticePreviewTile extends StatelessWidget {
  final Notice notice;
  final VoidCallback onTap;

  const _NoticePreviewTile({required this.notice, required this.onTap});

  String _formatDate(DateTime date) {
    return '${date.month}월 ${date.day}일';
  }

  String _previewText(String content) {
    final normalized = content.replaceAll('\n', ' ').trim();
    if (normalized.isEmpty) {
      return '본문 미리보기가 없습니다.';
    }
    if (normalized.length <= 56) {
      return normalized;
    }
    return '${normalized.substring(0, 56)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      borderRadius: BorderRadius.circular(AppBorderRadius.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.space4),
          decoration: BoxDecoration(
            color: AppSemanticColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            border: Border.all(color: AppSemanticColors.borderDefault),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (notice.isPinned) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space2,
                        vertical: AppSpacing.space1,
                      ),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.interactivePrimaryDefault
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppBorderRadius.full,
                        ),
                      ),
                      child: Text(
                        '고정',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppSemanticColors.interactivePrimaryDefault,
                          fontWeight: AppTypography.fontWeightSemibold,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space2),
                  ],
                  Expanded(
                    child: Text(
                      notice.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppSemanticColors.textPrimary,
                        fontWeight: AppTypography.fontWeightSemibold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Text(
                    _formatDate(notice.createdAt),
                    style: AppTypography.labelSmall.copyWith(
                      color: AppSemanticColors.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space2),
              Text(
                _previewText(notice.content),
                style: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SchedulePreviewTile extends StatelessWidget {
  final Schedule schedule;

  const _SchedulePreviewTile({required this.schedule});

  String _formatDate(DateTime date) {
    return '${date.month}.${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppSemanticColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(color: AppSemanticColors.borderDefault),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSpacing.space12,
            height: AppSpacing.space12,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppSemanticColors.interactivePrimaryDefault.withValues(
                alpha: 0.12,
              ),
              borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            ),
            child: Text(
              _formatDate(schedule.startDate),
              style: AppTypography.labelMedium.copyWith(
                color: AppSemanticColors.interactivePrimaryDefault,
                fontWeight: AppTypography.fontWeightBold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textPrimary,
                    fontWeight: AppTypography.fontWeightSemibold,
                  ),
                ),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  schedule.categoryText,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textSecondary,
                  ),
                ),
                if (schedule.timeText.isNotEmpty ||
                    (schedule.location?.isNotEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.space1),
                    child: Text(
                      [
                        if (schedule.timeText.isNotEmpty) schedule.timeText,
                        if (schedule.location?.isNotEmpty ?? false)
                          schedule.location!,
                      ].join(' · '),
                      style: AppTypography.labelSmall.copyWith(
                        color: AppSemanticColors.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySectionState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptySectionState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space6,
      ),
      decoration: BoxDecoration(
        color: AppSemanticColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(color: AppSemanticColors.borderDefault),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: AppSemanticColors.textTertiary),
          const SizedBox(height: AppSpacing.space3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textPrimary,
              fontWeight: AppTypography.fontWeightSemibold,
            ),
          ),
          const SizedBox(height: AppSpacing.space1),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
