import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/approval.dart';
import '../models/notice.dart';
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
import '../utils/permissions.dart';
import '../utils/daily_greeting.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/notification_bell.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/today_schedule_dialog.dart';
import 'admin_notice_management_screen.dart';
import 'approval_hub_screen.dart';
import 'approval_detail_screen.dart';
import 'main_screen.dart' show MainTabs;
import 'notice_detail_screen.dart';
import 'notice_list_screen.dart';

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
    // 공지 전체(미게시 포함)·회원 목록은 해당 권한이 있어야 의미가 있다.
    // 관리자는 PermissionUtils가 전부 true라 기존과 동일하게 동작한다.
    final canManageNotice =
        PermissionUtils.has(user, AppPermission.noticeManage);
    final companyId = user.company?.id ?? '1';

    try {
      final futures = <Future<void>>[
        context.read<ScheduleProvider>().loadCalendarData(
          DateTime.now(),
          companyId: companyId,
        ),
        // 관리자·직원 모두 결재함(열람 범위 문서)을 받아둔다 — 홈 "전자결재" 칸에서
        // "내 차례" 문서를 우선 보여주는 데 쓴다(직원은 아래에서 내가 기안한 문서도
        // 별도로 받아 두 목록을 합친다).
        context.read<ApprovalProvider>().loadApprovalRequests(
          companyId: companyId,
          refresh: true,
        ),
      ];

      if (isAdmin) {
        futures.addAll([
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
          // 공지 관리 권한을 위임받은 직원은 관리자와 같은 목록(미게시 포함)을 본다.
          if (canManageNotice)
            context.read<NoticeProvider>().loadNotices(
              companyId: companyId,
              refresh: true,
            )
          else
            context.read<NoticeProvider>().loadPublishedNotices(
              companyId: companyId,
              refresh: true,
            ),
        ]);
      }

      await Future.wait(futures);

      if (!mounted) return;

      context.read<NotificationProvider>().loadNotifications(
        user.id,
        alsoUserId: user.chatUserId,
      );
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
        AppSpacing.space3,
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
            ...todaySchedules.take(2).map(
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
          if (todaySchedules.length > 2)
            Text(
              '외 ${todaySchedules.length - 2}건',
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            ),
          // 카드가 화면 비율대로 늘어나므로 남는 공간은 여기서 흡수하고
          // 휴무자 줄은 카드 바닥에 앵커한다
          const Spacer(),
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

  /// 전자결재 칸 "전체보기" — 지금 내 차례인 문서가 있으면 결재관리(받은 결재) 탭으로
  /// 바로 연다. 없으면 기존처럼 하단 탭 전환 또는 기본 탭(결재 신청)으로 이동한다.
  void _openApproval({required bool hasMyTurn}) {
    if (hasMyTurn) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ApprovalHubScreen(initialTab: 1)),
      );
      return;
    }
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(MainTabs.approval);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ApprovalHubScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppSemanticColors.backgroundPrimary,
        body: Center(
          child: CircularProgressIndicator(
            color: AppSemanticColors.interactivePrimaryDefault,
          ),
        ),
      );
    }

    // 홈의 공지/결재 칸은 세부 권한을 따른다(관리자는 전부 true).
    final canManageNotice =
        PermissionUtils.has(user, AppPermission.noticeManage);
    final canManageApprovals =
        PermissionUtils.has(user, AppPermission.approvalManage);
    final approvalProvider = context.watch<ApprovalProvider>();
    final noticeProvider = context.watch<NoticeProvider>();
    final vacationProvider = context.watch<VacationProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();

    // 지금 내 차례인 결재 건수 — 기존 "전자결재" 칸 안에서 강조하는 데 쓴다
    // (새 영역을 만들지 않는다 — 알림을 놓치면 메뉴 깊숙이 숨어 안 보이던 것을
    // 홈의 전자결재 칸에서 바로 드러낸다).
    final myTurnApprovals = approvalProvider.myTurnCount(
      myId: user.id,
      isAdmin: canManageApprovals,
    );

    final recentNotices = _getRecentNotices(
      isAdmin: canManageNotice,
      noticeProvider: noticeProvider,
    );
    final recentApprovals = _getRecentApprovals(
      isAdmin: canManageApprovals,
      myId: user.id,
      approvalProvider: approvalProvider,
    );

    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: AppSemanticColors.interactivePrimaryDefault,
        // 세 칸이 내용과 무관하게 화면을 비율대로 꽉 채운다 — 내용이 비어도
        // 카드가 화면을 나눠 갖고, 내용이 넘치는 작은 화면에서만 스크롤된다.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
            SafeArea(
              // 플랫한 표면 헤더 — 본문과 같은 backgroundPrimary를 써서
              // 이질적인 대면적 브랜드 블록 없이 콘텐츠와 자연스럽게 이어지도록 한다.
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space5,
                    AppSpacing.space2,
                    AppSpacing.space5,
                    AppSpacing.space2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${user.name}님, 안녕하세요',
                                  style: AppTypography.heading5.copyWith(
                                    color: AppSemanticColors.textPrimary,
                                    fontWeight: AppTypography.fontWeightBold,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.space1),
                                Text(
                                  getDailyGreeting(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppSemanticColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const NotificationBell(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (_isLoading)
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppSemanticColors.interactivePrimaryDefault,
                  ),
                ),
              )
            else
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space4,
                    AppSpacing.space2,
                    AppSpacing.space4,
                    AppSpacing.space4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    // 홈은 세 칸만 — 공지사항(2건) · 전자결재(2건) · 오늘(일정+휴무자).
                    // 빠른작업·지표·커뮤니티 배너는 각 탭으로 걷어냈다 (2026-08 개편).
                    Expanded(child: _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                            title: '공지사항',
                            subtitle: '최근 공지',
                            actionLabel: '전체보기',
                            onAction: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => canManageNotice
                                    ? const AdminNoticeManagementScreen()
                                    : const NoticeListScreen(),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space3),
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
                    )),
                    const SizedBox(height: AppSpacing.space3),

                    Expanded(child: _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                            // 내 차례인 문서가 있으면 제목 옆 숫자로 바로 드러낸다
                            // (배지·부제 강조 — 별도 블록을 새로 만들지 않는다).
                            title: myTurnApprovals > 0
                                ? '전자결재 ($myTurnApprovals)'
                                : '전자결재',
                            subtitle: myTurnApprovals > 0
                                ? '지금 내가 처리할 결재 $myTurnApprovals건'
                                : (canManageApprovals
                                    ? '승인이 필요한 문서'
                                    : '내 결재 진행 상황'),
                            actionLabel: '전체보기',
                            onAction: () => _openApproval(hasMyTurn: myTurnApprovals > 0),
                          ),
                          const SizedBox(height: AppSpacing.space3),
                          if (recentApprovals.isEmpty)
                            _EmptySectionState(
                              icon: Icons.fact_check_outlined,
                              title: canManageApprovals
                                  ? '승인 대기 문서가 없습니다'
                                  : '진행 중인 결재가 없습니다',
                              subtitle: '새 결재가 생기면 이곳에 표시됩니다.',
                            )
                          else
                            Column(
                              children: [
                                for (final entry
                                    in recentApprovals.asMap().entries) ...[
                                  if (entry.key > 0)
                                    Divider(
                                      height: 1,
                                      color: AppSemanticColors.borderSubtle,
                                    ),
                                  _ApprovalPreviewTile(
                                    approval: entry.value,
                                    // 미리보기에서 바로 그 문서의 공문 상세로
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ApprovalDetailScreen(
                                          approval: entry.value,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    )),
                    const SizedBox(height: AppSpacing.space3),

                    // 오늘 — 오늘의 일정과 휴무자 요약
                    Expanded(
                      child: _buildTodayBriefing(
                        scheduleProvider,
                        vacationProvider,
                      ),
                    ),
                  ]),
                ),
              ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

    // 홈은 두 줄만 — 나머지는 전체보기로
    return notices.take(2).toList();
  }

  /// 홈 전자결재 칸의 두 건 — 내 차례인 문서를 최우선, 그다음 대기 문서, 그다음 최신순.
  /// 관리자는 회사 결재함 기준, 직원은 "내가 기안한 문서"에 "내 차례인 문서"(결재함에서)를
  /// 합쳐서 본다 — 내가 기안한 것만 보이면 정작 내가 서명해야 할 문서를 놓친다.
  List<ApprovalRequest> _getRecentApprovals({
    required bool isAdmin,
    required String? myId,
    required ApprovalProvider approvalProvider,
  }) {
    final List<ApprovalRequest> source;
    if (isAdmin) {
      source = List<ApprovalRequest>.from(approvalProvider.approvalRequests);
    } else {
      final merged = <int, ApprovalRequest>{};
      // 내 차례인 문서를 먼저 넣어 우선순위를 보장한다
      for (final r in approvalProvider.approvalRequests) {
        if (approvalProvider.isMyTurn(r, myId: myId, isAdmin: isAdmin)) {
          merged[r.id] = r;
        }
      }
      for (final r in approvalProvider.myApprovalRequests) {
        merged.putIfAbsent(r.id, () => r);
      }
      source = merged.values.toList();
    }

    source.sort((a, b) {
      final aMyTurn = approvalProvider.isMyTurn(a, myId: myId, isAdmin: isAdmin) ? 0 : 1;
      final bMyTurn = approvalProvider.isMyTurn(b, myId: myId, isAdmin: isAdmin) ? 0 : 1;
      if (aMyTurn != bMyTurn) return aMyTurn - bMyTurn;
      final aPending = a.status == ApprovalStatus.pending ? 0 : 1;
      final bPending = b.status == ApprovalStatus.pending ? 0 : 1;
      if (aPending != bPending) return aPending - bPending;
      return b.createdAt.compareTo(a.createdAt);
    });
    return source.take(2).toList();
  }
}

/// 평평한 흰 표면 — Seed 레이아웃 원칙(카드 중첩 금지)에 따라 자체 보더 1px +
/// xl2(16) 라운드만 사용하고, 내부에는 또 다른 보더/그림자 카드를 두지 않는다.
class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SectionCard({
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.space5,
      vertical: AppSpacing.space3,
    ),
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

class _NoticePreviewTile extends StatelessWidget {
  final Notice notice;
  final VoidCallback onTap;

  const _NoticePreviewTile({required this.notice, required this.onTap});

  String _formatDate(DateTime date) {
    return '${date.month}월 ${date.day}일';
  }

  @override
  Widget build(BuildContext context) {
    // 구분선 리스트 아이템 — 개별 보더 카드 대신 패딩만으로 아이템을 구분한다.
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
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
            ],
          ),
        ),
      ),
    );
  }
}

/// 홈 전자결재 칸의 한 줄 — 상태 점 + 제목 + 기안자·날짜.
/// _NoticePreviewTile과 같은 구분선 리스트 문법을 쓴다.
class _ApprovalPreviewTile extends StatelessWidget {
  final ApprovalRequest approval;
  final VoidCallback onTap;

  const _ApprovalPreviewTile({required this.approval, required this.onTap});

  String _formatDate(DateTime date) {
    return '${date.month}월 ${date.day}일';
  }

  (String, Color) get _statusInfo {
    switch (approval.status) {
      case ApprovalStatus.draft:
        return ('임시저장', AppSemanticColors.textTertiary);
      case ApprovalStatus.pending:
        return ('대기', AppSemanticColors.statusWarningIcon);
      case ApprovalStatus.approved:
        return ('승인', AppSemanticColors.statusSuccessIcon);
      case ApprovalStatus.rejected:
        return ('반려', AppSemanticColors.statusErrorIcon);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = _statusInfo;
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space2,
                  vertical: AppSpacing.space1,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppBorderRadius.full),
                ),
                child: Text(
                  statusLabel,
                  style: AppTypography.labelSmall.copyWith(
                    color: statusColor,
                    fontWeight: AppTypography.fontWeightSemibold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      approval.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppSemanticColors.textPrimary,
                        fontWeight: AppTypography.fontWeightSemibold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space1),
                    Text(
                      '${approval.requesterName} · ${_formatDate(approval.createdAt)}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppSemanticColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
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
