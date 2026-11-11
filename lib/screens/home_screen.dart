import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../providers/work_task_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/admin_utils.dart';
import '../utils/permissions.dart';
import '../utils/daily_greeting.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_list_entrance.dart';
import '../widgets/common/app_refresh.dart';
import '../widgets/common/app_skeleton.dart';
import '../widgets/common/app_sheet_frame.dart';
import '../widgets/common/app_tag.dart';
import '../widgets/common/notification_bell.dart';
import '../widgets/seed/seed_section_header.dart';
import '../widgets/today_schedule_dialog.dart';
import 'admin_notice_management_screen.dart';
import 'approval_hub_screen.dart';
import 'approval_detail_screen.dart';
import 'main_screen.dart' show MainTabs;
import 'notice_detail_screen.dart';
import 'notice_list_screen.dart';
import 'work_task_list_screen.dart';
import '../widgets/work_task/work_task_row.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;

  /// 한 번이라도 다 받았는지 — 첫 불러오기만 카드 뼈대를 보이고,
  /// 당겨서 새로고침 때는 예전처럼 가운데 동그라미를 둔다.
  bool _hasLoadedOnce = false;

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
    final canManageNotice = PermissionUtils.has(
      user,
      AppPermission.noticeManage,
    );
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
        // 업무진행도 칸 — 기관 전체가 같은 목록을 본다
        context.read<WorkTaskProvider>().load(),
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
        setState(() {
          _isLoading = false;
          _hasLoadedOnce = true;
        });
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
    final todaySchedules = context.read<ScheduleProvider>().getSchedulesForDate(
      now,
    );
    if (todaySchedules.isEmpty) return;

    await prefs.setString('last_today_schedule_popup_date', todayKey);
    if (!mounted) return;

    // B안: 가운데 창 대신 아래에서 올라오는 시트(엄지 닿는 곳)
    showAppSheet<void>(
      context,
      builder: (_) => TodayScheduleDialog(
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
    final dateLabel =
        '${now.month}월 ${now.day}일 (${weekdays[now.weekday - 1]})';

    return _SectionCard(
      header: SeedSectionHeader(title: '오늘', subtitle: dateLabel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (todaySchedules.isEmpty)
            Text(
              '오늘 예정된 일정이 없습니다.',
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            )
          else
            ...todaySchedules
                .take(2)
                .map(
                  // 누르면 일정 탭으로 넘어가 월간일정의 오늘을 펴고 이 일정을 강조한다
                  (schedule) => InkWell(
                    borderRadius: BorderRadius.circular(AppBorderRadius.control),
                    onTap: () {
                      context.read<ScheduleProvider>().requestFocus(
                        scheduleId: schedule.id,
                        date: now,
                      );
                      widget.onNavigateToTab?.call(MainTabs.calendar);
                    },
                    // B안: 줄 사이는 선 없이 줄 높이(48 이상)로 나눈다
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppSpacing.minTouchTarget,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: AppSpacing.space2,
                            height: AppSpacing.space2,
                            decoration: BoxDecoration(
                              color: scheduleDisplayColor(schedule),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.space2_5),
                          // 시각 칸은 최소 폭만 잡는다 — 글자가 커져도 숫자가 둘로 갈라지지 않게
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: AppSpacing.space12,
                            ),
                            child: Text(
                              schedule.timeText,
                              maxLines: 1,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppSemanticColors.textSecondary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
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
                                color: AppSemanticColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          if (todaySchedules.length > 2)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.space1),
              child: Text(
                '외 ${todaySchedules.length - 2}건',
                style: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.textTertiary,
                ),
              ),
            ),
          // B안: 구분선 대신 간격으로 일정과 휴무자를 나눈다
          const SizedBox(height: AppSpacing.space4),
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
        MaterialPageRoute(
          builder: (_) => const ApprovalHubScreen(initialTab: 1),
        ),
      );
      return;
    }
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(MainTabs.approval);
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ApprovalHubScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppSemanticColors.backgroundCanvas,
        body: Center(
          child: CircularProgressIndicator(
            color: AppSemanticColors.interactivePrimaryDefault,
          ),
        ),
      );
    }

    // 홈의 공지/결재 칸은 세부 권한을 따른다(관리자는 전부 true).
    final canManageNotice = PermissionUtils.has(
      user,
      AppPermission.noticeManage,
    );
    final canManageApprovals = PermissionUtils.has(
      user,
      AppPermission.approvalManage,
    );
    final approvalProvider = context.watch<ApprovalProvider>();
    final noticeProvider = context.watch<NoticeProvider>();
    final vacationProvider = context.watch<VacationProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final workTaskProvider = context.watch<WorkTaskProvider>();

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
      backgroundColor: AppSemanticColors.backgroundCanvas,
      body: AppRefreshIndicator(
        onRefresh: _loadDashboardData,
        // 카드 네 장이 처음 한 번만 차례로 떠오른다 — 이 감싸개가 불러오기 분기 바깥에 있어
        // 당겨서 새로고침 뒤 카드가 다시 그려져도 또 떠오르지 않는다.
        child: AppListEntrance(
        // D1: 카드는 내용 크기만큼만 차지한다 — 내용이 비어 있다고
        // 빈 화면을 억지로 나눠 갖지 않는다. 넘칠 때만 스크롤된다.
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 인사말 머리줄 — 다른 화면 상단 바와 같은 틸 바탕 + 진한 틸 하단선.
              // 상태표시줄 뒤까지 칠하려고 SafeArea 바깥에서 색을 깐다.
              // AppBar가 아니라 상태표시줄 아이콘 밝기를 직접 정한다 — 진한 틸 위라 흰 아이콘.
              AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle.light,
                // B안(2026-11-12): 다른 탭 첫 화면과 같은 높이 56 틸 바, 아래 선 없음.
                // 인사말은 제목 자리(왼쪽 20/w700), 하루 문구는 바 아래 회색 바탕 위로 내렸다.
                child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppSemanticColors.headerBackground,
                ),
                child: SafeArea(
                bottom: false,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSpacing.toolbarHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.space5,
                      right: AppSpacing.space1,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${user.name}님, 안녕하세요',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.appBarTitleLarge.copyWith(
                              color: AppSemanticColors.headerForeground,
                            ),
                          ),
                        ),
                        // 진한 틸 머리줄 위 — 흰 상자 대신 투명 바탕 + 흰 종
                        const NotificationBell(iconColor: AppSemanticColors.headerForeground),
                      ],
                    ),
                  ),
                ),
              ),
              ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space5,
                  AppSpacing.space4,
                  AppSpacing.space5,
                  AppSpacing.space1,
                ),
                child: Text(
                  getDailyGreeting(),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textSecondary,
                  ),
                ),
              ),
              if (_isLoading && !_hasLoadedOnce)
                // 첫 불러오기 — 아래 카드 네 칸과 같은 자리·여백의 뼈대
                const _HomeCardsSkeleton()
              else if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.space16,
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppSemanticColors.interactivePrimaryDefault,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space4,
                    AppSpacing.space2,
                    AppSpacing.space4,
                    AppSpacing.space4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 홈은 네 칸 — 공지사항(2건) · 전자결재(2건) · 업무진행도(3건) · 오늘(일정+휴무자).
                      // 빠른작업·지표·커뮤니티 배너는 각 탭으로 걷어냈다 (2026-08 개편).
                      // 업무진행도는 원장 요청(2026-10-22)으로 웹 대시보드 오른쪽 패널과 같이 늘 보이게 했다.
                      AppListEntranceItem(
                        index: 0,
                        child: _SectionCard(
                        header: SeedSectionHeader(
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (recentNotices.isEmpty)
                              const _EmptySectionState(
                                icon: Icons.campaign_outlined,
                                title: '등록된 공지사항이 없습니다',
                                subtitle: '새 공지가 올라오면 이곳에 표시됩니다.',
                              )
                            else
                              Column(
                                children: [
                                  // B안: 줄 사이 선 없이 줄 높이로만 나눈다
                                  for (final entry
                                      in recentNotices.asMap().entries) ...[
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
                      ),
                      const SizedBox(height: AppSpacing.space3),

                      AppListEntranceItem(
                        index: 1,
                        child: _SectionCard(
                        header: SeedSectionHeader(
                          // 내 차례인 문서가 있으면 제목 옆 숫자로 바로 드러낸다
                          // (배지·부제 강조 — 별도 블록을 새로 만들지 않는다).
                          // B안: 예전 '전자결재 (n)'의 숫자를 제목 옆 옅은 틸 알약으로.
                          title: '전자결재',
                          count: myTurnApprovals > 0 ? myTurnApprovals : null,
                          subtitle: myTurnApprovals > 0
                              ? '지금 내가 처리할 결재 $myTurnApprovals건'
                              : (canManageApprovals
                                    ? '승인이 필요한 문서'
                                    : '내 결재 진행 상황'),
                          actionLabel: '전체보기',
                          onAction: () =>
                              _openApproval(hasMyTurn: myTurnApprovals > 0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                      ),
                      ),
                      const SizedBox(height: AppSpacing.space3),

                      AppListEntranceItem(
                        index: 2,
                        child: _buildWorkTaskSection(
                          workTaskProvider,
                          user.chatUserId,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space3),

                      // 오늘 — 오늘의 일정과 휴무자 요약
                      AppListEntranceItem(
                        index: 3,
                        child: _buildTodayBriefing(
                          scheduleProvider,
                          vacationProvider,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  /// 업무진행도 칸 — 진행 중인 업무 세 건(서버가 정한 급한 순). 누르면 그 업무 창까지 연다.
  Widget _buildWorkTaskSection(WorkTaskProvider provider, String meId) {
    final inProgress = provider.inProgress;
    final mine = provider.myInProgressCount(meId);
    final today = DateTime.now();

    void openList([int? taskId]) => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkTaskListScreen(openTaskId: taskId),
      ),
    );

    return _SectionCard(
      header: SeedSectionHeader(
        // B안: 예전 '업무진행도 (n)'의 숫자를 제목 옆 옅은 틸 알약으로.
        title: '업무진행도',
        count: mine > 0 ? mine : null,
        subtitle: mine > 0
            ? '내가 맡은 업무 $mine건'
            : '진행 중인 업무 ${inProgress.length}건',
        actionLabel: '전체보기',
        onAction: openList,
      ),
      child: provider.status == WorkTaskLoadStatus.error && provider.tasks.isEmpty
          ? const _EmptySectionState(
              icon: Icons.cloud_off_outlined,
              title: '업무를 불러오지 못했습니다',
              subtitle: '아래로 당겨 다시 받아 주세요.',
            )
          : inProgress.isEmpty
          ? const _EmptySectionState(
              icon: Icons.checklist_rounded,
              title: '진행 중인 업무가 없습니다',
              subtitle: '전체보기에서 담당자·기한을 정해 업무를 올릴 수 있습니다.',
            )
          : Column(
              children: [
                // B안: 줄 사이 선 없이 줄 여백으로만 나눈다
                for (final entry in inProgress.take(3).toList().asMap().entries) ...[
                  WorkTaskRow(
                    task: entry.value,
                    today: today,
                    onTap: () => openList(entry.value.id),
                  ),
                ],
              ],
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
      final aMyTurn = approvalProvider.isMyTurn(a, myId: myId, isAdmin: isAdmin)
          ? 0
          : 1;
      final bMyTurn = approvalProvider.isMyTurn(b, myId: myId, isAdmin: isAdmin)
          ? 0
          : 1;
      if (aMyTurn != bMyTurn) return aMyTurn - bMyTurn;
      final aPending = a.status == ApprovalStatus.pending ? 0 : 1;
      final bPending = b.status == ApprovalStatus.pending ? 0 : 1;
      if (aPending != bPending) return aPending - bPending;
      return b.createdAt.compareTo(a.createdAt);
    });
    return source.take(2).toList();
  }
}

/// 홈 첫 불러오기 뼈대 — 아래 네 칸(공지사항·전자결재·업무진행도·오늘)과 같은 자리·여백의
/// 흰 카드 안에 제목·부제·줄 모양. 카드 사이 간격도 실제와 같아 내용이 뜰 때 덜 튄다.
class _HomeCardsSkeleton extends StatelessWidget {
  const _HomeCardsSkeleton();

  /// 칸마다 줄 수 — 공지 2건 · 결재 2건 · 업무 3건 · 오늘 2줄
  static const List<int> _rows = [2, 2, 3, 2];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        AppSpacing.space2,
        AppSpacing.space4,
        AppSpacing.space4,
      ),
      child: AppSkeleton(
        // 흰 카드 안의 뼈는 한 단계 옅은 색
        baseColor: AppSemanticColors.skeletonBaseOnCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _rows.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.space3),
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.cardPadding,
                  AppSpacing.cardPadding,
                  AppSpacing.cardPadding,
                  AppSpacing.space4,
                ),
                decoration: BoxDecoration(
                  color: AppSemanticColors.surfaceCard,
                  borderRadius: BorderRadius.circular(AppBorderRadius.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSkeletonLine(
                      widthFactor: 0.34,
                      height: AppSpacing.space5,
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    const AppSkeletonLine(
                      widthFactor: 0.52,
                      height: AppSpacing.space3_5,
                    ),
                    const SizedBox(height: AppSpacing.space3),
                    for (var r = 0; r < _rows[i]; r++)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: AppSpacing.space4,
                        ),
                        child: AppSkeletonLine(
                          widthFactor: 0.92,
                          height: AppSpacing.space4,
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
}

/// 홈 칸 하나 — B안(2026-11-12): 회색 바탕 위 테두리 없는 흰 카드(모서리 20, 안쪽 여백 20).
/// 예전의 연한 틸 머리띠·아래 선을 없애고 카드 안 맨 위에 제목 글자만 둔다.
/// 카드 안에는 또 다른 테두리 상자를 두지 않는다(카드 중첩 금지).
class _SectionCard extends StatelessWidget {
  /// 카드 안 맨 위 제목줄 — [SeedSectionHeader]
  final Widget header;
  final Widget child;

  const _SectionCard({required this.header, required this.child});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.cardPadding,
        AppSpacing.cardPadding,
        AppSpacing.cardPadding,
        AppSpacing.space4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: AppSpacing.space3),
          child,
        ],
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

  @override
  Widget build(BuildContext context) {
    // 선 없는 목록 줄 — 테두리·구분선 대신 줄 높이(60 이상)로 줄을 나눈다.
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.control),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.listRowMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
            child: Row(
              children: [
                if (notice.isPinned) ...[
                  const AppTag(label: '고정', icon: Icons.push_pin),
                  const SizedBox(width: AppSpacing.space2_5),
                ],
                Expanded(
                  child: Text(
                    notice.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppSemanticColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.space2),
                Text(
                  _formatDate(notice.createdAt),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
                // 탭 가능함을 알리는 chevron — ripple만으로는 눈에 잘 안 띈다.
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppSemanticColors.iconSubtle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 홈 전자결재 칸의 한 줄 — 상태 꼬리표 + 제목 + 기안자·날짜.
/// _NoticePreviewTile과 같은 선 없는 목록 줄 문법을 쓴다.
class _ApprovalPreviewTile extends StatelessWidget {
  final ApprovalRequest approval;
  final VoidCallback onTap;

  const _ApprovalPreviewTile({required this.approval, required this.onTap});

  String _formatDate(DateTime date) {
    return '${date.month}월 ${date.day}일';
  }

  (String, AppTagTone) get _statusInfo {
    switch (approval.status) {
      case ApprovalStatus.draft:
        return ('임시저장', AppTagTone.neutral);
      case ApprovalStatus.pending:
        return ('대기', AppTagTone.warning);
      case ApprovalStatus.approved:
        return ('승인', AppTagTone.success);
      case ApprovalStatus.rejected:
        return ('반려', AppTagTone.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusTone) = _statusInfo;
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.control),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.listRowMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2_5),
            child: Row(
              children: [
                AppTag(label: statusLabel, tone: statusTone),
                const SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        approval.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppSemanticColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space0_5),
                      Text(
                        '${approval.requesterName} · ${_formatDate(approval.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppSemanticColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.space2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppSemanticColors.iconSubtle,
                ),
              ],
            ),
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
    // 카드 안의 작은 빈 상태 — AppEmptyState와 같은 문법(옅은 틸 원 + 틸 아이콘)을
    // 카드 크기에 맞게 줄였다. AppEmptyState는 자체 스크롤이 있어 홈 스크롤 안에 넣지 않는다.
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space2,
          vertical: AppSpacing.space4,
        ),
        child: Column(
          children: [
            Container(
              width: AppSpacing.iconCircle,
              height: AppSpacing.iconCircle,
              decoration: const BoxDecoration(
                color: AppSemanticColors.brandWeak,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: AppSemanticColors.brandDefault),
            ),
            const SizedBox(height: AppSpacing.space3),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium.copyWith(
                color: AppSemanticColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.space1),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
