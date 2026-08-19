import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/html_utils.dart';
import '../models/notice.dart';
import '../models/schedule.dart';
import '../models/schedule_colors.dart';
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
import '../utils/daily_greeting.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/notification_bell.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_callout.dart';
import '../widgets/today_schedule_dialog.dart';
import 'admin_notice_management_screen.dart';
import 'admin_unified_approval_screen.dart';
import 'admin_user_management_screen.dart';
import 'approval_list_screen.dart';
import 'calendar_screen.dart';
import 'main_screen.dart' show MainTabs;
import 'my_vacation_screen.dart';
import 'notice_detail_screen.dart';
import 'notice_list_screen.dart';
import 'plaza_screen.dart';
import '../widgets/vacation_request_dialog.dart';
import 'approval_form_screen.dart';

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
        _maybeShowTodaySchedulePopup();
      }
    }
  }

  /// 접속 시 오늘 일정 알림 — 하루 1회만 띄운다.
  Future<void> _maybeShowTodaySchedulePopup() async {
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('last_today_schedule_popup_date') == todayKey) return;

    if (!mounted) return;
    final todaySchedules =
        context.read<ScheduleProvider>().getSchedulesForDate(now);
    if (todaySchedules.isEmpty) return;

    await prefs.setString('last_today_schedule_popup_date', todayKey);
    if (!mounted) return;

    AppDialog.showCustom(
      context,
      child: TodayScheduleDialog(
        schedules: todaySchedules,
        onViewSchedule: () => widget.onNavigateToTab?.call(MainTabs.calendar),
      ),
    );
  }

  /// 오늘 브리핑 — 오늘 일정 목록과 오늘 휴무자 요약
  Widget _buildTodayBriefing(
    ScheduleProvider scheduleProvider,
    VacationProvider vacationProvider,
  ) {
    final now = DateTime.now();
    final todaySchedules = scheduleProvider.getSchedulesForDate(now);
    final todayKey = DateTime(now.year, now.month, now.day);
    final todayVacationers = (vacationProvider.calendarData[todayKey] ?? [])
        .where((v) => v.status == VacationStatus.approved)
        .toList();

    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final dateLabel = '${now.month}월 ${now.day}일 (${weekdays[now.weekday - 1]})';

    return _SectionCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space5,
        AppSpacing.space3,
        AppSpacing.space5,
        AppSpacing.space5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: '오늘', subtitle: dateLabel),
          const SizedBox(height: AppSpacing.space3),
          if (todaySchedules.isEmpty)
            Text(
              '오늘 예정된 일정이 없습니다.',
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            )
          else
            ...todaySchedules.take(3).map(
              (schedule) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.space2),
                child: Row(
                  children: [
                    Container(
                      width: AppSpacing.space1_5,
                      height: AppSpacing.space1_5,
                      decoration: BoxDecoration(
                        color: scheduleDisplayColor(schedule),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    SizedBox(
                      width: AppSpacing.space10,
                      child: Text(
                        schedule.timeText,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppSemanticColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    Expanded(
                      child: Text(
                        schedule.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: AppTypography.fontWeightMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (todaySchedules.length > 3)
            Text(
              '외 ${todaySchedules.length - 3}건',
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            ),
          const SizedBox(height: AppSpacing.space2),
          Divider(height: 1, color: AppSemanticColors.borderSubtle),
          const SizedBox(height: AppSpacing.space3),
          Row(
            children: [
              Icon(
                Icons.beach_access_outlined,
                size: AppSpacing.space4,
                color: AppSemanticColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.space2),
              Expanded(
                child: Text(
                  todayVacationers.isEmpty
                      ? '오늘 휴무자가 없습니다.'
                      : '오늘 휴무 ${todayVacationers.length}명 · ${todayVacationers.take(3).map((v) => v.userName).join(', ')}${todayVacationers.length > 3 ? ' 외 ${todayVacationers.length - 3}명' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 홈에서 바로 휴무 신청 — 오늘 날짜 기본값
  void _openVacationRequest() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => VacationRequestDialog(
        selectedDate: DateTime.now(),
        onRequestSubmitted: _loadDashboardData,
      ),
    );
  }

  /// 홈에서 바로 결재 작성 화면으로
  void _openApprovalForm() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ApprovalFormScreen()))
        .then((_) => _loadDashboardData());
  }

  void _openApproval() {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(MainTabs.approval);
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
      widget.onNavigateToTab!(MainTabs.calendar);
      return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CalendarScreen()));
  }

  void _openMemberManagement() {
    // 회원관리는 하단 탭에서 빠졌으므로 항상 화면을 push한다 (전체 탭에서도 진입 가능)
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
              // 플랫한 표면 헤더 — 스크롤 본문과 같은 backgroundPrimary를 써서
              // 이질적인 대면적 브랜드 블록 없이 콘텐츠와 자연스럽게 이어지도록 한다.
              // 브랜드 색은 오늘의 한마디 카드(소면적)에만 강조로 사용한다.
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space5,
                    AppSpacing.space4,
                    AppSpacing.space5,
                    AppSpacing.space4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${user.name}님, 안녕하세요',
                              style: AppTypography.heading6.copyWith(
                                color: AppSemanticColors.textPrimary,
                                fontWeight: AppTypography.fontWeightBold,
                              ),
                            ),
                          ),
                          const NotificationBell(),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.space3),
                      SeedCallout(
                        variant: SeedCalloutVariant.brand,
                        icon: Icons.format_quote_outlined,
                        title: getDailyGreeting(),
                      ),
                    ],
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
                    // 오늘 브리핑 — 오늘 일정과 휴무 현황을 가장 먼저 보여준다
                    _buildTodayBriefing(scheduleProvider, vacationProvider),
                    const SizedBox(height: AppSpacing.space4),

                    // 빠른 작업 — 자주 쓰는 액션 바로가기. 다른 섹션과 동일하게
                    // _SectionCard/_SectionHeader로 감싸 리듬을 맞춘다.
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
                            title: '빠른 작업',
                            subtitle: '자주 쓰는 기능 바로가기',
                          ),
                          const SizedBox(height: AppSpacing.space4),
                          Row(
                            children: [
                              Expanded(
                                child: _QuickActionButton(
                                  icon: Icons.beach_access_outlined,
                                  label: '휴무 신청',
                                  onTap: _openVacationRequest,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.space3),
                              Expanded(
                                child: _QuickActionButton(
                                  icon: Icons.edit_note_outlined,
                                  label: isAdmin ? '결재 승인' : '결재 작성',
                                  // 직원은 작성 화면을 바로 연다 (탭 전환만 하는 버튼은 빠른작업이 아니다)
                                  onTap:
                                      isAdmin ? _openApproval : _openApprovalForm,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.space3),
                              Expanded(
                                child: _QuickActionButton(
                                  icon: Icons.campaign_outlined,
                                  label: '공지 보기',
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => isAdmin
                                          ? const AdminNoticeManagementScreen()
                                          : const NoticeListScreen(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space4),

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

                    // 케어브이 커뮤니티 진입
                    _SectionCard(
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PlazaScreen()),
                        ),
                        borderRadius: BorderRadius.circular(AppSpacing.space3),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.space3),
                              decoration: BoxDecoration(
                                color: AppSemanticColors.interactivePrimaryDefault
                                    .withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.space3),
                              ),
                              child: Icon(
                                Icons.forum_outlined,
                                color: AppSemanticColors.interactivePrimaryDefault,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.space3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('케어브이 커뮤니티',
                                      style: AppTypography.bodyLarge.copyWith(
                                        color: AppSemanticColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      )),
                                  Text('요양 소식 · 게시판 · 자료실',
                                      style: AppTypography.caption.copyWith(
                                        color: AppSemanticColors.textTertiary,
                                      )),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: AppSemanticColors.textSecondary),
                          ],
                        ),
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
                            Column(
                              children: [
                                for (final entry
                                    in recentNotices.asMap().entries) ...[
                                  if (entry.key > 0)
                                    Divider(
                                      height: 1,
                                      color: AppSemanticColors.borderSubtle,
                                    ),
                                  _NoticePreviewTile(
                                    notice: entry.value,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => NoticeDetailScreen(
                                          noticeId: entry.value.id,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
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
                            Column(
                              children: [
                                for (final entry in monthlyPreviewSchedules
                                    .asMap()
                                    .entries) ...[
                                  if (entry.key > 0)
                                    Divider(
                                      height: 1,
                                      color: AppSemanticColors.borderSubtle,
                                    ),
                                  _SchedulePreviewTile(
                                    schedule: entry.value,
                                    onTap: _openWorkAdjustment,
                                  ),
                                ],
                              ],
                            ),
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
          onTap: _openApproval,
        ),
        _DashboardMetric(
          icon: Icons.people_outline_rounded,
          label: '회원관리',
          caption: '승인 요청',
          count: adminProvider.pendingUsers.length,
          onTap: _openMemberManagement,
        ),
        _DashboardMetric(
          icon: Icons.campaign_outlined,
          label: '공지사항',
          caption: '등록 공지',
          count: noticeProvider.notices.length,
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
        onTap: _openApproval,
      ),
      _DashboardMetric(
        icon: Icons.campaign_outlined,
        label: '공지사항',
        caption: '읽지 않음',
        count: noticeProvider.unreadNoticeCount,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NoticeListScreen())),
      ),
      _DashboardMetric(
        icon: Icons.calendar_today_outlined,
        label: '내 휴무',
        caption: '승인 대기',
        count: pendingVacationCount,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const MyVacationScreen())),
      ),
      _DashboardMetric(
        icon: Icons.schedule_outlined,
        label: '근무조정',
        caption: '이번 달 일정',
        count: currentMonthSchedules.length,
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
  final VoidCallback onTap;

  // 아이콘 색은 항목마다 두지 않는다. 여기 색은 상태를 뜻하는 것이 아니라
  // 그냥 메뉴 구분이었는데, 초록·노랑·회색이 섞이니 경고처럼 읽혔다.
  const _DashboardMetric({
    required this.icon,
    required this.label,
    required this.caption,
    required this.count,
    required this.onTap,
  });
}

/// 평평한 흰 표면 — Seed 레이아웃 원칙(카드 중첩 금지)에 따라 자체 보더 1px +
/// xl2(16) 라운드만 사용하고, 내부에는 또 다른 보더/그림자 카드를 두지 않는다.
class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.space5),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppSemanticColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
        border: Border.all(color: AppSemanticColors.borderSubtle, width: 1),
      ),
      child: child,
    );
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
          SeedButton(
            label: actionLabel!,
            onPressed: onAction,
            variant: SeedButtonVariant.neutralWeak,
            size: SeedButtonSize.xsmall,
          ),
      ],
    );
  }
}

/// 대시보드 지표 타일 — 카드 중첩 금지 원칙에 따라 틴트 배경+보더 카드를
/// 두지 않고, 아이콘 칩(작은 원형 배지) + 숫자 + 라벨로만 구성한 평평한
/// 콘텐츠 블록. 바깥 _SectionCard가 이미 표면을 제공하므로 여기서는
/// 보더/그림자를 추가하지 않는다.
class _DashboardMetricCard extends StatelessWidget {
  final _DashboardMetric metric;

  const _DashboardMetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: metric.onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.space1,
            horizontal: AppSpacing.space2,
          ),
          // 칸은 화면 절반인데 내용이 왼쪽에 붙어 있어 오른쪽이 통째로 비어 보였다.
          // 가로·세로 모두 칸 한가운데에 둔다.
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: AppSpacing.space9,
                height: AppSpacing.space9,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppSemanticColors.brandWeak,
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                ),
                child: Icon(
                  metric.icon,
                  color: AppSemanticColors.brandDefault,
                  size: 20,
                ),
              ),
              const SizedBox(height: AppSpacing.space3),
              Text(
                metric.count.toString(),
                textAlign: TextAlign.center,
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
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppSemanticColors.textPrimary,
                  fontWeight: AppTypography.fontWeightSemibold,
                ),
              ),
              const SizedBox(height: AppSpacing.space0_5),
              Text(
                metric.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
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
    // 서식 공지만 태그를 걷어낸다 — 평문 공지의 '<중요>' 같은 표기는 그대로 둔다
    final plain =
        containsHtmlTags(content) ? stripHtmlToPlainText(content) : content;
    final normalized = plain.replaceAll('\n', ' ').trim();
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
    // 구분선 리스트 아이템 — 개별 보더 카드 대신 패딩만으로 아이템을 구분한다.
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
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
                  // 탭 가능함을 알리는 chevron — ripple만으로는 눈에 잘 안 띈다.
                  Icon(
                    Icons.chevron_right,
                    size: AppSpacing.space4,
                    color: AppSemanticColors.textTertiary,
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
  final VoidCallback onTap;

  const _SchedulePreviewTile({required this.schedule, required this.onTap});

  String _formatDate(DateTime date) {
    return '${date.month}.${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    // 구분선 리스트 아이템 — 개별 보더 카드 대신 패딩만으로 아이템을 구분한다.
    // _NoticePreviewTile과 동일하게 InkWell로 감싸 탭 가능함을 동일하게 보여준다.
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppSpacing.space12,
                height: AppSpacing.space12,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppSemanticColors.interactivePrimaryDefault
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
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
                            if (schedule.timeText.isNotEmpty)
                              schedule.timeText,
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
              // 탭 가능함을 알리는 chevron — _NoticePreviewTile과 동일한 신호.
              Icon(
                Icons.chevron_right,
                size: AppSpacing.space4,
                color: AppSemanticColors.textTertiary,
              ),
            ],
          ),
        ),
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
    // 카드 중첩 금지 — 별도 보더/배경 없이 여백만으로 구분되는 콘텐츠 블록.
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space6,
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
      ),
    );
  }
}

/// 빠른 작업 버튼 — _SectionCard 안에 놓이므로 라운드를 카드와 동일한
/// xl2(16)로 맞춘다(§1 기본 r2 대신). pressed 시 배경 전환 + scale 0.97.
class _QuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
          decoration: BoxDecoration(
            color: _pressed
                ? AppSemanticColors.surfaceActive
                : AppSemanticColors.surfaceDefault,
            border: Border.all(color: AppSemanticColors.borderSubtle),
            borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
          ),
          child: Column(
            children: [
              Icon(widget.icon, size: 22, color: AppSemanticColors.brandPressed),
              const SizedBox(height: AppSpacing.space1),
              Text(
                widget.label,
                style: AppTypography.labelMedium.copyWith(
                  color: AppSemanticColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
