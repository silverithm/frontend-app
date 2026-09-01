import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vacation_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/admin_provider.dart' hide VacationRequest;
import '../models/vacation_request.dart';
import '../models/schedule.dart';
import '../models/schedule_colors.dart';
import '../models/user.dart';
import '../utils/admin_utils.dart';
import '../widgets/vacation_calendar_widget.dart';
import '../widgets/vacation_planning_banner.dart';
import '../widgets/vacation_request_dialog.dart';
import '../widgets/admin_vacation_add_dialog.dart';
import '../services/analytics_service.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';
import '../widgets/common/app_action_sheet.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_text_field.dart';
import 'admin_vacation_limits_setting_screen.dart';
import '../providers/notice_provider.dart';
import 'dart:math' as math;
import '../widgets/common/app_snackbar.dart';

class CalendarScreen extends StatefulWidget {
  /// 일정 알림을 눌러 들어온 경우 그 일정이 있는 날로 바로 연다.
  /// 일정은 별도 상세 화면이 없고 날짜를 고르면 아래에 펼쳐지는 구조라, 날짜가 곧 목적지다.
  final DateTime? initialScheduleDate;

  /// 알림으로 들어온 경우 강조해서 보여줄 일정 id. 날짜 목록에서 눈에 띄게
  /// 테두리를 강조하고, 할 일이 있으면 체크리스트도 펼쳐 둔다.
  final int? highlightedScheduleId;

  const CalendarScreen({
    super.key,
    this.initialScheduleDate,
    this.highlightedScheduleId,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with TickerProviderStateMixin {
  DateTime _currentDate = DateTime.now();
  DateTime? _selectedDate;
  List<String> _roleFilters = [];
  late AnimationController _fabAnimationController;
  late AnimationController _filterAnimationController;
  late TabController _tabController;

  // 일정 달력용 상태
  DateTime _scheduleCurrentDate = DateTime.now();
  DateTime? _scheduleSelectedDate;
  // 할 일이 있는 일정 항목 중 체크리스트를 펼쳐 둔 것들 (별도 상세 화면이 없어 항목 확장으로 대신한다)
  final Set<int> _expandedTaskScheduleIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 알림으로 들어왔으면 일정 달력을 그 날짜에 펴 둔다
    final target = widget.initialScheduleDate;
    if (target != null) {
      _scheduleCurrentDate = DateTime(target.year, target.month);
      _scheduleSelectedDate = DateTime(target.year, target.month, target.day);
      _tabController.index = 1; // 0=휴무 달력, 1=일정 달력
    }
    // 강조할 일정에 할 일이 있다면 체크리스트를 펼쳐서 바로 보이게 한다
    final highlightId = widget.highlightedScheduleId;
    if (highlightId != null) {
      _expandedTaskScheduleIds.add(highlightId);
    }
    _fabAnimationController = AnimationController(
      duration: AppTransitions.slow,
      vsync: this,
    );
    _filterAnimationController = AnimationController(
      duration: AppTransitions.normal,
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vacationProvider = context.read<VacationProvider>();
      final scheduleProvider = context.read<ScheduleProvider>();
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.company?.id ?? '1';

      vacationProvider.loadCalendarData(_currentDate, companyId: companyId);
      scheduleProvider.loadCalendarData(
        _scheduleCurrentDate,
        companyId: companyId.toString(),
      );

      _fabAnimationController.forward();

      // Analytics 화면 조회 이벤트
      AnalyticsService().logScreenView(screenName: 'calendar_screen');
      AnalyticsService().logCalendarView(
        viewType: 'month',
        date: _currentDate.toIso8601String().split('T')[0],
      );
    });

    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fabAnimationController.dispose();
    _filterAnimationController.dispose();
    super.dispose();
  }

  void _showVacationRequestDialog() {
    final vacationProvider = context.read<VacationProvider>();
    final targetDate = _selectedDate ?? DateTime.now();

    // 기관이 "다음 달만 받기"를 켜뒀으면 눌러보기 전에 먼저 막는다 (서버도 같은 규칙으로 다시 검증)
    if (!vacationProvider.isDateAllowedForRequest(targetDate)) {
      final allowedMonth = vacationProvider.nextMonthOnlyMonth;
      AppDialog.showAlert(
        context,
        title: '신청할 수 없는 날짜입니다',
        message:
            '${allowedMonth.year}년 ${allowedMonth.month}월 휴무만 신청하실 수 있습니다.',
      );
      return;
    }

    // 날짜를 아직 안 골랐으면 오늘 날짜로 바로 신청할 수 있게 한다 (재시도 강요 금지)
    if (_selectedDate == null) {
      setState(() => _selectedDate = targetDate);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => VacationRequestDialog(
        selectedDate: _selectedDate!,
        onRequestSubmitted: () {
          final vacationProvider = context.read<VacationProvider>();
          final authProvider = context.read<AuthProvider>();
          final companyId = authProvider.currentUser?.company?.id ?? '1';
          vacationProvider.loadCalendarData(_currentDate, companyId: companyId);
        },
      ),
    );
  }

  String _formatSelectedDate(DateTime date) {
    final weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    final weekday = weekdays[date.weekday % 7];
    return '${date.month}월 ${date.day}일 ($weekday)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundSecondary,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // 앱바
            SliverAppBar(
              floating: false,
              pinned: true,
              elevation: 0,
              toolbarHeight: 0,
              backgroundColor: AppSemanticColors.interactivePrimaryDefault,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Builder(
                  builder: (context) {
                    final isAdmin = AdminUtils.canAccessAdminPages(
                      context.read<AuthProvider>().currentUser,
                    );
                    final accentColor =
                        AppSemanticColors.interactivePrimaryDefault;
                    return Container(
                      color: AppSemanticColors.interactivePrimaryDefault,
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: AppSemanticColors.textInverse,
                        indicatorWeight: 2,
                        labelColor: AppSemanticColors.textInverse,
                        unselectedLabelColor: AppSemanticColors.textInverse
                            .withValues(alpha: 0.5),
                        labelStyle: AppTypography.labelLarge.copyWith(
                          fontWeight: AppTypography.fontWeightSemibold,
                        ),
                        unselectedLabelStyle: AppTypography.labelLarge.copyWith(
                          fontWeight: FontWeight.normal,
                        ),
                        // 웹 관리자 화면과 같은 이름 — 근무조정(휴무)·월간일정(일정)
                        tabs: const [
                          Tab(text: '근무조정'),
                          Tab(text: '월간일정'),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // 휴무 달력 탭
            _buildVacationCalendar(),
            // 일정 달력 탭
            _buildScheduleCalendar(),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? _buildFab()
          : _buildScheduleFab(),
    );
  }

  /// 일정 달력 탭 빌드
  Widget _buildScheduleCalendar() {
    return Consumer<ScheduleProvider>(
      builder: (context, scheduleProvider, child) {
        print(
          '[CalendarScreen] 일정 달력 빌드 - 로딩: ${scheduleProvider.isLoading}, 일정수: ${scheduleProvider.schedules.length}, 날짜별: ${scheduleProvider.schedulesByDate.keys.toList()}',
        );
        return SingleChildScrollView(
          child: Column(
            children: [
              // 달력 위젯
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space4,
                  vertical: AppSpacing.space3,
                ),
                decoration: BoxDecoration(
                  color: AppSemanticColors.surfaceDefault,
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  border: Border.all(
                    color: AppSemanticColors.borderSubtle,
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildScheduleCalendarWidget(scheduleProvider),
              ),

              // 선택된 날짜 정보
              if (_scheduleSelectedDate != null)
                _buildScheduleDateDetail(scheduleProvider),

              // 하단 여백
              const SizedBox(height: AppSpacing.space20),
            ],
          ),
        );
      },
    );
  }

  /// 일정 달력 위젯
  Widget _buildScheduleCalendarWidget(ScheduleProvider provider) {
    return Column(
      children: [
        // 월 네비게이션 — 흰 표면 위, 하단 구분선만으로 분리
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space3,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppSemanticColors.borderSubtle,
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: '이전 달',
                onPressed: () {
                  setState(() {
                    _scheduleCurrentDate = DateTime(
                      _scheduleCurrentDate.year,
                      _scheduleCurrentDate.month - 1,
                    );
                  });
                  final authProvider = context.read<AuthProvider>();
                  final companyId =
                      authProvider.currentUser?.company?.id ?? '1';
                  provider.loadCalendarData(
                    _scheduleCurrentDate,
                    companyId: companyId.toString(),
                  );
                },
                icon: Icon(
                  Icons.chevron_left,
                  color: AppSemanticColors.textSecondary,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: AppSemanticColors.backgroundTertiary,
                  shape: const CircleBorder(),
                ),
              ),
              Text(
                '${_scheduleCurrentDate.year}년 ${_scheduleCurrentDate.month}월',
                style: AppTypography.heading6.copyWith(
                  fontWeight: AppTypography.fontWeightSemibold,
                ),
              ),
              IconButton(
                tooltip: '다음 달',
                onPressed: () {
                  setState(() {
                    _scheduleCurrentDate = DateTime(
                      _scheduleCurrentDate.year,
                      _scheduleCurrentDate.month + 1,
                    );
                  });
                  final authProvider = context.read<AuthProvider>();
                  final companyId =
                      authProvider.currentUser?.company?.id ?? '1';
                  provider.loadCalendarData(
                    _scheduleCurrentDate,
                    companyId: companyId.toString(),
                  );
                },
                icon: Icon(
                  Icons.chevron_right,
                  color: AppSemanticColors.textSecondary,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: AppSemanticColors.backgroundTertiary,
                  shape: const CircleBorder(),
                ),
              ),
            ],
          ),
        ),

        // 요일 헤더 — 같은 표면, 상하 space3 여백만
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space3,
          ),
          child: Row(
            children: ['일', '월', '화', '수', '목', '금', '토'].map((day) {
              final isSunday = day == '일';
              final isSaturday = day == '토';
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: AppTypography.labelMedium.copyWith(
                      color: isSunday
                          ? AppSemanticColors.statusErrorIcon
                          : isSaturday
                          ? AppSemanticColors.interactivePrimaryDefault
                          : AppSemanticColors.textSecondary,
                      fontWeight: AppTypography.fontWeightMedium,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // 달력 그리드
        _buildScheduleCalendarGrid(provider),

        const SizedBox(height: AppSpacing.space4),
      ],
    );
  }

  Widget _buildScheduleCalendarGrid(ScheduleProvider provider) {
    final firstDayOfMonth = DateTime(
      _scheduleCurrentDate.year,
      _scheduleCurrentDate.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _scheduleCurrentDate.year,
      _scheduleCurrentDate.month + 1,
      0,
    );
    final firstWeekday = firstDayOfMonth.weekday % 7;

    final days = <Widget>[];

    // 이전 달 빈 칸
    for (int i = 0; i < firstWeekday; i++) {
      days.add(const SizedBox());
    }

    // 현재 달의 날짜들
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(
        _scheduleCurrentDate.year,
        _scheduleCurrentDate.month,
        day,
      );
      final isSelected =
          _scheduleSelectedDate != null &&
          _scheduleSelectedDate!.year == date.year &&
          _scheduleSelectedDate!.month == date.month &&
          _scheduleSelectedDate!.day == date.day;
      final isToday =
          DateTime.now().year == date.year &&
          DateTime.now().month == date.month &&
          DateTime.now().day == date.day;
      final hasSchedule = provider.hasSchedulesOnDate(date);

      // 디버깅 (일정이 있는 날짜 확인)
      if (day == 1 || hasSchedule) {
        final dateKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        print(
          '[CalendarScreen] $day일 확인 - dateKey: $dateKey, hasSchedule: $hasSchedule',
        );
        if (day == 1) {
          print(
            '[CalendarScreen] 저장된 모든 키: ${provider.schedulesByDate.keys.toList()}',
          );
        }
      }
      final isSunday = date.weekday == 7;
      final isSaturday = date.weekday == 6;

      days.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _scheduleSelectedDate = date;
            });
          },
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppSemanticColors.interactivePrimaryDefault
                  : isToday
                  ? AppSemanticColors.interactivePrimaryDefault.withValues(
                      alpha: 0.1,
                    )
                  : null,
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              border: isToday && !isSelected
                  ? Border.all(
                      color: AppSemanticColors.interactivePrimaryDefault,
                      width: 1,
                    )
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  day.toString(),
                  style: AppTypography.bodyMedium.copyWith(
                    color: isSelected
                        ? AppSemanticColors.textInverse
                        : isSunday
                        ? AppSemanticColors.statusErrorIcon
                        : isSaturday
                        ? AppSemanticColors.interactivePrimaryDefault
                        : AppSemanticColors.textPrimary,
                    fontWeight: isToday || isSelected
                        ? AppTypography.fontWeightSemibold
                        : AppTypography.fontWeightNormal,
                  ),
                ),
                if (hasSchedule)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppSemanticColors.textInverse
                          : AppSemanticColors.statusSuccessIcon,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      childAspectRatio: 1,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
      children: days,
    );
  }

  /// 선택된 날짜의 일정 상세
  Widget _buildScheduleDateDetail(ScheduleProvider provider) {
    final schedules = provider.getSchedulesForDate(_scheduleSelectedDate!);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        AppSpacing.space2,
        AppSpacing.space4,
        AppSpacing.space4,
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppSemanticColors.surfaceDefault,
          borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
          border: Border.all(color: AppSemanticColors.borderDefault, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.space3),
                          decoration: BoxDecoration(
                            color: AppSemanticColors.backgroundTertiary,
                            borderRadius: BorderRadius.circular(
                              AppBorderRadius.xl2,
                            ),
                          ),
                          child: Icon(
                            Icons.event_note,
                            color: AppSemanticColors.textSecondary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.space3),
                        Expanded(
                          child: Text(
                            _formatSelectedDate(_scheduleSelectedDate!),
                            style: AppTypography.heading6.copyWith(
                              fontWeight: AppTypography.fontWeightBold,
                              color: AppSemanticColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '날짜 선택 해제',
                    onPressed: () {
                      setState(() {
                        _scheduleSelectedDate = null;
                      });
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(AppSpacing.space2),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: AppSemanticColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space4),

              if (schedules.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.space2,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_available,
                        color: AppSemanticColors.textTertiary,
                        size: 24,
                      ),
                      const SizedBox(width: AppSpacing.space3),
                      Text(
                        '이 날짜에는 등록된 일정이 없습니다.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppSemanticColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space3,
                        vertical: AppSpacing.space1_5,
                      ),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.statusSuccessIcon.withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppBorderRadius.full,
                        ),
                      ),
                      child: Text(
                        '일정 ${schedules.length}건',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppSemanticColors.statusSuccessIcon,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space3),
                    ...schedules.map(
                      (schedule) => _buildScheduleItem(schedule),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /**
   * 일정을 수행완료로 바꾼다.
   *
   * 서버가 담당자·관리자만 허용하므로 화면에서 미리 막지 않고 거절 사유를 그대로 보여준다 —
   * 담당자 판별에 필요한 memberId를 화면이 정확히 알기 어렵고, 잘못 막으면 할 수 있는 사람이
   * 못 하게 된다.
   */
  Future<void> _toggleScheduleCompletion(Schedule schedule) async {
    final scheduleProvider = context.read<ScheduleProvider>();
    final ok = await scheduleProvider.toggleCompletion(
      scheduleId: schedule.id,
      completed: !schedule.isCompleted,
    );

    if (!mounted) return;
    if (ok) {
      AppSnackBar.showSuccess(context,
          message: schedule.isCompleted ? '수행완료를 해제했습니다' : '수행완료로 표시했습니다');
    } else {
      AppSnackBar.showError(context,
          message: scheduleProvider.error ?? '수행완료 상태를 바꾸지 못했습니다');
    }
  }

  /**
   * 할 일(담당자 업무) 완료를 토글한다.
   *
   * 담당자 본인 또는 관리자만 가능 — 일정 수행완료 토글과 같은 이유로 화면에서 미리
   * 막지 않고 서버 거절 사유를 그대로 보여준다. 실패하면 서버 반영 전이라 상태가
   * 이미 원래대로이므로 스낵바만 띄운다.
   */
  Future<void> _toggleTaskCompletion(Schedule schedule, ScheduleTask task) async {
    final scheduleProvider = context.read<ScheduleProvider>();
    final ok = await scheduleProvider.toggleTaskCompletion(
      scheduleId: schedule.id,
      taskId: task.id,
      completed: !task.isCompleted,
    );

    if (!mounted) return;
    if (ok) {
      AppSnackBar.showSuccess(context,
          message: task.isCompleted ? '할 일 완료를 해제했습니다' : '할 일을 완료했습니다');
    } else {
      AppSnackBar.showError(context,
          message: scheduleProvider.error ?? '할 일 완료 상태를 바꾸지 못했습니다');
    }
  }

  Widget _buildScheduleItem(Schedule schedule) {
    final scheduleColor = scheduleDisplayColor(schedule);
    final authProvider = context.read<AuthProvider>();
    final currentUserEmail = authProvider.currentUser?.email;
    final isMySchedule =
        schedule.authorId != null &&
        currentUserEmail != null &&
        schedule.authorId == currentUserEmail;
    // 할 일이 등록된 일정은 일정 자체를 직접 완료 처리하지 않는다 — 담당자들이 할 일을
    // 모두 체크하면 자동으로 완료된다 (웹 월간일정·서버 규칙과 동일)
    final taskItems = schedule.tasks;
    final hasTasks = taskItems.isNotEmpty || schedule.taskTotal > 0;
    final taskDoneCount =
        taskItems.isNotEmpty ? taskItems.where((t) => t.isCompleted).length : schedule.taskCompleted;
    final taskTotalCount = taskItems.isNotEmpty ? taskItems.length : schedule.taskTotal;
    final isTaskListExpanded = _expandedTaskScheduleIds.contains(schedule.id);
    // 알림을 눌러 들어온 그 일정이면 테두리를 강조해 눈에 띄게 한다
    final isHighlighted = widget.highlightedScheduleId == schedule.id;

    return GestureDetector(
      onLongPress: isMySchedule
          ? () => _showDeleteScheduleDialog(schedule)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.space2),
        padding: const EdgeInsets.all(AppSpacing.space4),
        decoration: BoxDecoration(
          color: AppSemanticColors.surfaceDefault,
          borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
          border: Border.all(
            color: isHighlighted
                ? scheduleColor
                : scheduleColor.withValues(alpha: 0.2),
            width: isHighlighted ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheduleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppSpacing.space3),
                // 수행완료 체크 — 웹 월간일정과 같은 동작. 할 일이 있는 일정은 할 일 진행에
                // 따라 자동으로 완료되므로 수동 토글 버튼을 숨기고 상태만 보여준다
                SizedBox(
                  width: 36,
                  height: 36,
                  child: hasTasks
                      ? Center(
                          child: Icon(
                            schedule.isCompleted
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked,
                            size: 22,
                            color: schedule.isCompleted
                                ? AppSemanticColors.statusSuccessIcon
                                : AppSemanticColors.textTertiary,
                          ),
                        )
                      : IconButton(
                          onPressed: () => _toggleScheduleCompletion(schedule),
                          icon: Icon(
                            schedule.isCompleted
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked,
                            size: 22,
                            color: schedule.isCompleted
                                ? AppSemanticColors.statusSuccessIcon
                                : AppSemanticColors.textTertiary,
                          ),
                          tooltip: schedule.isCompleted ? '수행완료 해제' : '수행완료',
                          visualDensity: VisualDensity.compact,
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                        ),
                ),
                const SizedBox(width: AppSpacing.space2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              schedule.title,
                              style: AppTypography.bodyLarge.copyWith(
                                color: schedule.isCompleted
                                    ? AppSemanticColors.textTertiary
                                    : AppSemanticColors.textPrimary,
                                fontWeight: AppTypography.fontWeightSemibold,
                                // 끝난 일과 남은 일이 한눈에 갈리도록 완료는 줄을 긋는다 (웹과 같은 표시)
                                decoration: schedule.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          if (isMySchedule)
                            IconButton(
                              onPressed: () =>
                                  _showDeleteScheduleDialog(schedule),
                              icon: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: AppSemanticColors.textTertiary,
                              ),
                              tooltip: '일정 삭제',
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.space1),
                      Row(
                        children: [
                          if (schedule.timeText.isNotEmpty) ...[
                            Icon(
                              Icons.access_time,
                              size: 12,
                              color: AppSemanticColors.textTertiary,
                            ),
                            const SizedBox(width: AppSpacing.space1),
                            Text(
                              schedule.timeText,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppSemanticColors.textTertiary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.space3),
                          ],
                          if (schedule.location != null &&
                              schedule.location!.isNotEmpty) ...[
                            Icon(
                              Icons.location_on_outlined,
                              size: 12,
                              color: AppSemanticColors.textTertiary,
                            ),
                            const SizedBox(width: AppSpacing.space1),
                            Text(
                              schedule.location!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppSemanticColors.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (schedule.authorName != null &&
                          schedule.authorName!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.space1),
                          child: Text(
                            '등록: ${schedule.authorName}',
                            style: AppTypography.caption.copyWith(
                              color: AppSemanticColors.textTertiary,
                            ),
                          ),
                        ),
                      // 담당자 — 참석자와 별개로 지정된 사람 (웹 월간일정과 같은 표시)
                      if (schedule.managerName != null &&
                          schedule.managerName!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.space1),
                          child: Text(
                            '담당: ${schedule.managerName}',
                            style: AppTypography.caption.copyWith(
                              color: AppSemanticColors.brandDefault,
                              fontWeight: AppTypography.fontWeightMedium,
                            ),
                          ),
                        ),
                      // 할 일 진행도 — 누르면 아래에 체크리스트를 펼친다/접는다
                      if (hasTasks)
                        Padding(
                          padding:
                              const EdgeInsets.only(top: AppSpacing.space1_5),
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(AppBorderRadius.full),
                            onTap: () {
                              setState(() {
                                if (isTaskListExpanded) {
                                  _expandedTaskScheduleIds.remove(schedule.id);
                                } else {
                                  _expandedTaskScheduleIds.add(schedule.id);
                                }
                              });
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.space2,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        AppSemanticColors.statusInfoBackground,
                                    borderRadius: BorderRadius.circular(
                                      AppBorderRadius.full,
                                    ),
                                  ),
                                  child: Text(
                                    '할 일 $taskDoneCount/$taskTotalCount',
                                    style: AppTypography.caption.copyWith(
                                      color: AppSemanticColors.statusInfoText,
                                      fontWeight:
                                          AppTypography.fontWeightSemibold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.space1),
                                Icon(
                                  isTaskListExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 16,
                                  color: AppSemanticColors.textTertiary,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space2,
                    vertical: AppSpacing.space1,
                  ),
                  decoration: BoxDecoration(
                    color: scheduleColor,
                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  ),
                  child: Text(
                    schedule.categoryText,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppSemanticColors.textInverse,
                      fontWeight: AppTypography.fontWeightBold,
                    ),
                  ),
                ),
              ],
            ),
            // 할 일 체크리스트 — 별도 상세 화면이 없어 항목을 눌러 이 자리에서 편다
            if (hasTasks && isTaskListExpanded) ...[
              const SizedBox(height: AppSpacing.space3),
              Container(height: 1, color: AppSemanticColors.borderSubtle),
              const SizedBox(height: AppSpacing.space3),
              if (taskItems.isEmpty)
                Text(
                  '할 일 목록을 불러오지 못했습니다',
                  style: AppTypography.caption.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                )
              else
                ...taskItems.map(
                  (task) => _buildScheduleTaskItem(schedule, task),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// 할 일 한 건 — 체크로 완료를 토글한다. 담당자가 지정된 항목은 담당자 본인/관리자만
  /// 서버가 허용하고, 미지정 항목은 누구나 가능하다 (웹 월간일정과 같은 서버 규칙).
  Widget _buildScheduleTaskItem(Schedule schedule, ScheduleTask task) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space2),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
      decoration: BoxDecoration(
        color: task.isCompleted
            ? AppSemanticColors.statusSuccessBackground
            : AppSemanticColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => _toggleTaskCompletion(schedule, task),
            icon: Icon(
              task.isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              size: 18,
              color: task.isCompleted
                  ? AppSemanticColors.statusSuccessIcon
                  : AppSemanticColors.textTertiary,
            ),
            tooltip: task.isCompleted ? '완료 해제' : '완료',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: AppSpacing.space2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.space1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.content,
                    style: AppTypography.bodySmall.copyWith(
                      color: task.isCompleted
                          ? AppSemanticColors.textTertiary
                          : AppSemanticColors.textPrimary,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (task.assigneeName != null &&
                      task.assigneeName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        task.assigneeName!,
                        style: AppTypography.caption.copyWith(
                          color: AppSemanticColors.textTertiary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteScheduleDialog(Schedule schedule) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: '일정 삭제',
      message: '\'${schedule.title}\' 일정을 삭제하시겠습니까?',
      confirmText: '삭제',
      cancelText: '취소',
      confirmVariant: SeedButtonVariant.critical,
    );

    if (confirmed != true || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    final scheduleProvider = context.read<ScheduleProvider>();
    final companyId = authProvider.currentUser?.company?.id ?? '1';

    final success = await scheduleProvider.deleteSchedule(
      scheduleId: schedule.id,
      companyId: companyId.toString(),
    );

    if (mounted) {
      if (success) {
        AppSnackBar.showSuccess(context, message: '일정이 삭제되었습니다');
      } else {
        AppSnackBar.showError(context, message: '일정 삭제에 실패했습니다');
      }
    }
  }

  /// 휴무 달력 탭 빌드
  Widget _buildVacationCalendar() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 근무조정 컨텍스트 — 다음 달만 받기 제한 · 이번 달 마감일 (행사는 날짜별 배지·신청 시 안내로 대체)
          Consumer<VacationProvider>(
            builder: (context, vacationProvider, _) {
              final month = DateTime(_currentDate.year, _currentDate.month);
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
                  // 보고 있는 달 휴무의 '신청 마감일' (그 전 달에 위치)
                  deadline: vacationProvider.deadlineForTargetMonth(month),
                  deadlineTargetMonth: month,
                  deadlinePassed: vacationProvider
                      .isDeadlinePassedForTargetMonth(month),
                ),
              );
            },
          ),

          // 달력 위젯 — 하나의 연속된 흰 표면 (그림자 없이 얇은 보더만)
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space4,
              vertical: AppSpacing.space3,
            ),
            decoration: BoxDecoration(
              color: AppSemanticColors.surfaceDefault,
              borderRadius: BorderRadius.circular(AppBorderRadius.xl),
              border: Border.all(
                color: AppSemanticColors.borderSubtle,
                width: 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: VacationCalendarWidget(
              currentDate: _currentDate,
              onDateChanged: (date) {
                setState(() {
                  _currentDate = date;
                });
                final vacationProvider = context.read<VacationProvider>();
                final authProvider = context.read<AuthProvider>();
                final companyId = authProvider.currentUser?.company?.id ?? '1';
                vacationProvider.loadCalendarData(date, companyId: companyId);

                // Analytics 캘린더 조회 이벤트
                AnalyticsService().logCalendarView(
                  viewType: 'month',
                  date: date.toIso8601String().split('T')[0],
                );
              },
              onDateSelected: (date) {
                setState(() {
                  _selectedDate = date;
                });
              },
              roleFilters: _roleFilters,
              onRoleFiltersChanged: (newRoles) {
                setState(() {
                  _roleFilters = newRoles;
                });
                final vacationProvider = context.read<VacationProvider>();
                vacationProvider.setRoleFilters(newRoles);
                final authProvider = context.read<AuthProvider>();
                final companyId = authProvider.currentUser?.company?.id ?? '1';
                vacationProvider.loadCalendarData(
                  _currentDate,
                  companyId: companyId,
                );
              },
            ),
          ),

          // 선택된 날짜 정보
          if (_selectedDate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space4,
                AppSpacing.space2,
                AppSpacing.space4,
                AppSpacing.space4,
              ),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppSemanticColors.surfaceDefault,
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
                  border: Border.all(
                    color: AppSemanticColors.borderDefault,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.space5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(
                                    AppSpacing.space3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppSemanticColors.backgroundTertiary,
                                    borderRadius: BorderRadius.circular(
                                      AppBorderRadius.xl2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.calendar_today,
                                    color: AppSemanticColors.textSecondary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.space3),
                                Expanded(
                                  child: Text(
                                    _formatSelectedDate(_selectedDate!),
                                    style: AppTypography.heading6.copyWith(
                                      fontWeight: AppTypography.fontWeightBold,
                                      color: AppSemanticColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '날짜 선택 해제',
                            onPressed: () {
                              setState(() {
                                _selectedDate = null;
                              });
                            },
                            icon: Container(
                              padding: const EdgeInsets.all(AppSpacing.space2),
                              decoration: BoxDecoration(
                                color: AppSemanticColors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(
                                  AppBorderRadius.xl,
                                ),
                              ),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: AppSemanticColors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.space4),

                      Consumer<VacationProvider>(
                        builder: (context, vacationProvider, child) {
                          final vacations = vacationProvider
                              .getVacationsForDate(_selectedDate!);

                          if (vacations.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.space2,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.event_available,
                                    color: AppSemanticColors.textTertiary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: AppSpacing.space3),
                                  Text(
                                    '이 날짜에는 휴무 신청이 없습니다.',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppSemanticColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.space3,
                                  vertical: AppSpacing.space1_5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppSemanticColors
                                      .interactivePrimaryDefault
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppBorderRadius.full,
                                  ),
                                ),
                                child: Text(
                                  '휴무자 ${vacations.length}명',
                                  style: AppTypography.labelLarge.copyWith(
                                    color: AppSemanticColors
                                        .interactivePrimaryDefault,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.space3),
                              ...vacations.map(
                                (vacation) => Container(
                                  margin: const EdgeInsets.only(
                                    bottom: AppSpacing.space2,
                                  ),
                                  padding: const EdgeInsets.all(
                                    AppSpacing.space4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppSemanticColors.surfaceDefault,
                                    borderRadius: BorderRadius.circular(
                                      AppBorderRadius.xl2,
                                    ),
                                    border: Border.all(
                                      color: _getStatusTextColor(
                                        vacation.status,
                                      ).withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(
                                          AppSpacing.space2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusTextColor(
                                            vacation.status,
                                          ).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            AppBorderRadius.xl,
                                          ),
                                        ),
                                        child: Icon(
                                          _getStatusIcon(vacation.status),
                                          size: 16,
                                          color: _getStatusTextColor(
                                            vacation.status,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.space3),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            _buildVacationTypeShape(vacation),
                                            const SizedBox(
                                              width: AppSpacing.space2,
                                            ),
                                            Expanded(
                                              child: Text(
                                                vacation.displayName,
                                                style: AppTypography.bodyLarge
                                                    .copyWith(
                                                      color: AppSemanticColors
                                                          .textPrimary,
                                                      fontWeight: AppTypography
                                                          .fontWeightSemibold,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.space2,
                                          vertical: AppSpacing.space1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusTextColor(
                                            vacation.status,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            AppBorderRadius.lg,
                                          ),
                                        ),
                                        child: Text(
                                          vacation.statusText,
                                          style: AppTypography.labelSmall
                                              .copyWith(
                                                color: AppSemanticColors
                                                    .textInverse,
                                                fontWeight: AppTypography
                                                    .fontWeightBold,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 하단 통계 섹션 (관리자만)
          if (AdminUtils.canAccessAdminPages(
            context.read<AuthProvider>().currentUser,
          ))
            Consumer<VacationProvider>(
              builder: (context, vacationProvider, child) {
                return Container(
                  margin: const EdgeInsets.fromLTRB(
                    AppSpacing.space6,
                    AppSpacing.space2,
                    AppSpacing.space6,
                    AppSpacing.space4,
                  ),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.surfaceDefault,
                    borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                    border: Border.all(
                      color: AppSemanticColors.borderDefault,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.space4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            '${_currentDate.month}월 총 휴무',
                            _getMonthlyTotal(vacationProvider).toString(),
                            AppSemanticColors.interactivePrimaryDefault,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.space3),
                        Expanded(
                          child: _buildStatItem(
                            '승인 대기',
                            _getMonthlyPending(vacationProvider).toString(),
                            AppSemanticColors.statusWarningIcon,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.space3),
                        Expanded(
                          child: _buildStatItem(
                            '승인됨',
                            _getMonthlyApproved(vacationProvider).toString(),
                            AppSemanticColors.statusSuccessIcon,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.space3),
                        Expanded(
                          child: _buildStatItem(
                            '거절됨',
                            _getMonthlyRejected(vacationProvider).toString(),
                            AppSemanticColors.statusErrorIcon,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          // 하단 여백
          const SizedBox(height: AppSpacing.space20 + AppSpacing.space6),
        ],
      ),
    );
  }

  Color _getStatusBgColor(VacationStatus status) {
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

  IconData _getStatusIcon(VacationStatus status) {
    switch (status) {
      case VacationStatus.approved:
        return Icons.check_circle;
      case VacationStatus.rejected:
        return Icons.cancel;
      case VacationStatus.pending:
        return Icons.schedule;
    }
  }

  Widget _buildVacationTypeShape(VacationRequest vacation) {
    // 필수 휴무일 때만 별표 표시
    if (vacation.type == VacationType.mandatory) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CustomPaint(
          painter: StarPainter(color: AppSemanticColors.statusWarningIcon),
          size: const Size(16, 16),
        ),
      );
    }

    // 개인 휴무(연차/반차)는 도형 없이 빈 공간
    return const SizedBox.shrink();
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: AppSpacing.space8,
          height: AppSpacing.space8,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          ),
          child: Center(
            child: Text(
              value,
              style: AppTypography.labelLarge.copyWith(
                color: color,
                fontWeight: AppTypography.fontWeightBold,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.space2),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppSemanticColors.textTertiary,
            fontWeight: AppTypography.fontWeightMedium,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  int _getMonthlyTotal(VacationProvider provider) {
    final monthStart = DateTime(_currentDate.year, _currentDate.month, 1);
    final monthEnd = DateTime(_currentDate.year, _currentDate.month + 1, 0);

    int total = 0;
    for (
      var date = monthStart;
      date.isBefore(monthEnd.add(const Duration(days: 1)));
      date = date.add(const Duration(days: 1))
    ) {
      final dayVacations = provider.getVacationsForDate(date);
      total += dayVacations.length;
    }
    return total;
  }

  int _getMonthlyPending(VacationProvider provider) {
    final monthStart = DateTime(_currentDate.year, _currentDate.month, 1);
    final monthEnd = DateTime(_currentDate.year, _currentDate.month + 1, 0);

    int pending = 0;
    for (
      var date = monthStart;
      date.isBefore(monthEnd.add(const Duration(days: 1)));
      date = date.add(const Duration(days: 1))
    ) {
      final dayVacations = provider.getVacationsForDate(date);
      pending += dayVacations
          .where((v) => v.status == VacationStatus.pending)
          .length;
    }
    return pending;
  }

  int _getMonthlyApproved(VacationProvider provider) {
    final monthStart = DateTime(_currentDate.year, _currentDate.month, 1);
    final monthEnd = DateTime(_currentDate.year, _currentDate.month + 1, 0);

    int approved = 0;
    for (
      var date = monthStart;
      date.isBefore(monthEnd.add(const Duration(days: 1)));
      date = date.add(const Duration(days: 1))
    ) {
      final dayVacations = provider.getVacationsForDate(date);
      approved += dayVacations
          .where((v) => v.status == VacationStatus.approved)
          .length;
    }
    return approved;
  }

  int _getMonthlyRejected(VacationProvider provider) {
    final monthStart = DateTime(_currentDate.year, _currentDate.month, 1);
    final monthEnd = DateTime(_currentDate.year, _currentDate.month + 1, 0);

    int rejected = 0;
    for (
      var date = monthStart;
      date.isBefore(monthEnd.add(const Duration(days: 1)));
      date = date.add(const Duration(days: 1))
    ) {
      final dayVacations = provider.getVacationsForDate(date);
      rejected += dayVacations
          .where((v) => v.status == VacationStatus.rejected)
          .length;
    }
    return rejected;
  }

  Widget _buildFab() {
    final authProvider = context.read<AuthProvider>();
    final isAdmin = AdminUtils.canAccessAdminPages(authProvider.currentUser);

    if (isAdmin) {
      return ScaleTransition(
        scale: _fabAnimationController,
        child: FloatingActionButton(
          heroTag: 'admin_calendar_fab',
          onPressed: _showAdminActionDialog,
          backgroundColor: AppSemanticColors.interactivePrimaryDefault,
          child: Icon(Icons.add, color: AppSemanticColors.textInverse),
        ),
      );
    }

    return ScaleTransition(
      scale: _fabAnimationController,
      child: Container(
        decoration: BoxDecoration(
          color: AppSemanticColors.interactivePrimaryDefault,
          borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
        ),
        child: FloatingActionButton.extended(
          heroTag: 'calendar_fab',
          onPressed: _showVacationRequestDialog,
          backgroundColor: AppColors.transparent,
          elevation: 0,
          icon: Icon(
            Icons.add_circle_outline,
            color: AppSemanticColors.textInverse,
            size: 24,
          ),
          label: Text(
            '휴무 추가',
            style: AppTypography.labelLarge.copyWith(
              color: AppSemanticColors.textInverse,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleFab() {
    return ScaleTransition(
      scale: _fabAnimationController,
      child: FloatingActionButton(
        heroTag: 'schedule_calendar_fab',
        onPressed: _showAddScheduleDialog,
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        child: Icon(Icons.add, color: AppSemanticColors.textInverse),
      ),
    );
  }

  void _showAddScheduleDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final locationController = TextEditingController();
    // 기본 4종은 카테고리 코드, 커스텀 구분은 'label:<id>' 형식 — 웹과 같은 컨벤션.
    String selectedCategory = 'MEETING';
    // 색상 없음(빈 문자열)이 기본값 — 카테고리 기본색으로 자동 폴백된다.
    String selectedColorHex = '';
    // 기관이 만든 커스텀 일정 구분. 시트가 뜬 뒤 비동기로 합류한다.
    List<ScheduleLabel> customLabels = [];
    // 기본 구분(회의 등)의 기관별 상태 — 이름·색 변경, 숨김 반영.
    // 비어 있으면(로드 전/실패) 하드코딩 4종으로 동작한다.
    List<ScheduleCategorySetting> baseCategories = [];
    void Function(VoidCallback)? modalSetState;
    DateTime startDate = _scheduleSelectedDate ?? DateTime.now();
    DateTime endDate = _scheduleSelectedDate ?? DateTime.now();
    bool isAllDay = true;
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 18, minute: 0);
    bool sendNotification = false;
    Set<String> selectedParticipantIds = {};

    // 회원 목록 로드
    final authProvider = context.read<AuthProvider>();
    final adminProvider = context.read<AdminProvider>();
    final companyId = authProvider.currentUser?.company?.id ?? '';
    if (companyId.isNotEmpty && adminProvider.companyMembers.isEmpty) {
      adminProvider.loadCompanyMembers(companyId.toString());
    }

    // 커스텀 일정 구분 로드 — 실패해도 기본 4종으로 등록은 계속 가능해야 한다
    ApiService()
        .getScheduleLabels(companyId: companyId.toString())
        .then((data) {
          final list = data['labels'];
          if (list is! List) return;
          final labels = list
              .whereType<Map<String, dynamic>>()
              .map(ScheduleLabel.fromJson)
              .toList();
          customLabels = labels;
          modalSetState?.call(() {});
        })
        .catchError((_) {});

    // 기본 구분의 기관별 설정(이름·색·숨김) 로드
    ApiService()
        .getScheduleCategorySettings(companyId: companyId.toString())
        .then((data) {
          final list = data['categories'];
          if (list is! List || list.isEmpty) return;
          baseCategories = list
              .whereType<Map<String, dynamic>>()
              .map(ScheduleCategorySetting.fromJson)
              .toList();
          // 기본 선택(회의)이 숨겨져 있으면 첫 보이는 구분으로 바꾼다
          if (!selectedCategory.startsWith('label:')) {
            final current = baseCategories
                .where((c) => c.category == selectedCategory)
                .toList();
            if (current.isNotEmpty && current.first.hidden) {
              final visible = baseCategories.where((c) => !c.hidden).toList();
              if (visible.isNotEmpty) selectedCategory = visible.first.category;
            }
          }
          modalSetState?.call(() {});
        })
        .catchError((_) {});

    // AppBottomSheet.show로 바꾸지 않고 유지: 이미 토큰 스타일(둥근 상단·
    // surfaceDefault·핸들바)을 자체로 완전히 갖춰서 교체해도 시각적으로
    // 달라지는 게 없다.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppSemanticColors.surfaceDefault,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppBorderRadius.xl2),
        ),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            modalSetState = setModalState;
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.space4,
                right: AppSpacing.space4,
                top: AppSpacing.space4,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                    AppSpacing.space4,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 핸들
                    Center(
                      child: Container(
                        width: AppSpacing.space10,
                        height: AppSpacing.space1,
                        decoration: BoxDecoration(
                          color: AppSemanticColors.borderDefault,
                          borderRadius: BorderRadius.circular(
                            AppBorderRadius.sm,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space4),
                    // 헤더
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '일정 등록',
                          style: AppTypography.heading5.copyWith(
                            color: AppSemanticColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          tooltip: '닫기',
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close,
                            color: AppSemanticColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space4),

                    // 제목
                    SeedTextField(
                      label: '제목 *',
                      controller: titleController,
                      placeholder: '일정 제목을 입력하세요',
                    ),
                    const SizedBox(height: AppSpacing.space3),

                    // 내용
                    SeedTextField(
                      label: '내용',
                      controller: contentController,
                      placeholder: '일정 내용을 입력하세요',
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppSpacing.space3),

                    // 일정 구분 — 기본 4종 + 기관 커스텀 구분. 커스텀 구분을
                    // 고르면 그 구분의 색이 아래 색상에 바로 적용된다.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedCategory,
                            decoration: InputDecoration(
                              labelText: '일정 구분',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppBorderRadius.lg,
                                ),
                              ),
                            ),
                            items: [
                              // 기관 설정이 로드되면 이름 변경·숨김을 반영하고,
                              // 아니면 하드코딩 4종으로 동작한다
                              if (baseCategories.isEmpty) ...[
                                const DropdownMenuItem(
                                  value: 'MEETING',
                                  child: Text('회의'),
                                ),
                                const DropdownMenuItem(
                                  value: 'EVENT',
                                  child: Text('행사'),
                                ),
                                const DropdownMenuItem(
                                  value: 'TRAINING',
                                  child: Text('교육'),
                                ),
                                const DropdownMenuItem(
                                  value: 'OTHER',
                                  child: Text('기타'),
                                ),
                              ] else
                                for (final base in baseCategories.where(
                                  (c) =>
                                      !c.hidden ||
                                      c.category == selectedCategory,
                                ))
                                  DropdownMenuItem(
                                    value: base.category,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: colorFromHex(base.color) ??
                                                AppSemanticColors
                                                    .interactivePrimaryDefault,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(
                                          width: AppSpacing.space2,
                                        ),
                                        Text(base.name),
                                      ],
                                    ),
                                  ),
                              for (final label in customLabels)
                                DropdownMenuItem(
                                  value: 'label:${label.id}',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: colorFromHex(label.color) ??
                                              AppSemanticColors
                                                  .interactivePrimaryDefault,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(
                                        width: AppSpacing.space2,
                                      ),
                                      Text(label.name),
                                    ],
                                  ),
                                ),
                            ],
                            onChanged: (value) {
                              setModalState(() {
                                final wasLabel = selectedCategory.startsWith(
                                  'label:',
                                );
                                selectedCategory = value ?? 'MEETING';
                                if (value != null &&
                                    value.startsWith('label:')) {
                                  final id = int.tryParse(
                                    value.substring(6),
                                  );
                                  for (final label in customLabels) {
                                    if (label.id == id) {
                                      selectedColorHex = label.color;
                                      break;
                                    }
                                  }
                                } else if (wasLabel) {
                                  // 커스텀 구분에서 기본 구분으로 돌아오면
                                  // 데려왔던 구분색도 내려놓는다
                                  selectedColorHex = '';
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.space2),
                        SeedButton(
                          label: '구분 관리',
                          variant: SeedButtonVariant.neutralOutline,
                          size: SeedButtonSize.small,
                          onPressed: () {
                            _showScheduleLabelManageSheet(
                              companyId: companyId.toString(),
                              onLabelsChanged: (labels) {
                                customLabels = labels;
                                // 고른 구분이 삭제됐으면 기본값으로 되돌린다
                                if (selectedCategory.startsWith('label:') &&
                                    !labels.any(
                                      (l) =>
                                          'label:${l.id}' == selectedCategory,
                                    )) {
                                  selectedCategory = 'MEETING';
                                }
                                modalSetState?.call(() {});
                              },
                              onBaseCategoriesChanged: (categories) {
                                baseCategories = categories;
                                // 고른 기본 구분이 숨겨졌으면 첫 보이는 구분으로
                                if (!selectedCategory.startsWith('label:')) {
                                  final current = categories
                                      .where(
                                        (c) => c.category == selectedCategory,
                                      )
                                      .toList();
                                  if (current.isNotEmpty &&
                                      current.first.hidden) {
                                    final visible = categories
                                        .where((c) => !c.hidden)
                                        .toList();
                                    if (visible.isNotEmpty) {
                                      selectedCategory =
                                          visible.first.category;
                                    }
                                  }
                                }
                                modalSetState?.call(() {});
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space3),

                    // 색상 — 기본 구분일 때만. 커스텀 구분은 자기 색이 곧 일정
                    // 색이라 따로 고를 게 없다 (다른 색은 구분 관리에서 바꾼다).
                    if (!selectedCategory.startsWith('label:')) ...[
                      Text(
                        '색상',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppSemanticColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space2),
                      Wrap(
                        spacing: AppSpacing.space2,
                        runSpacing: AppSpacing.space2,
                        children: [
                          _buildScheduleColorSwatch(
                            color: null,
                            isSelected: selectedColorHex.isEmpty,
                            tooltip: '색상 없음',
                            onTap: () {
                              setModalState(() {
                                selectedColorHex = '';
                              });
                            },
                          ),
                          for (final option in ScheduleColorPalette.values)
                            _buildScheduleColorSwatch(
                              color: option.color,
                              isSelected: selectedColorHex == option.hex,
                              tooltip: option.name,
                              onTap: () {
                                setModalState(() {
                                  selectedColorHex = option.hex;
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.space3),
                    ],

                    // 장소
                    SeedTextField(
                      label: '장소',
                      controller: locationController,
                      placeholder: '장소를 입력하세요',
                    ),
                    const SizedBox(height: AppSpacing.space3),

                    // 종일 여부
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '종일',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppSemanticColors.textPrimary,
                          ),
                        ),
                        Switch(
                          value: isAllDay,
                          onChanged: (value) {
                            setModalState(() {
                              isAllDay = value;
                            });
                          },
                          activeTrackColor:
                              AppSemanticColors.interactivePrimaryDefault,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space2),

                    // 시작일 / 종료일
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  startDate = picked;
                                  if (endDate.isBefore(startDate)) {
                                    endDate = startDate;
                                  }
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: '시작일',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppBorderRadius.lg,
                                  ),
                                ),
                                suffixIcon: const Icon(
                                  Icons.calendar_today,
                                  size: 18,
                                ),
                              ),
                              child: Text(
                                '${startDate.month}/${startDate.day}',
                                style: AppTypography.bodyMedium,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.space3),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: endDate,
                                firstDate: startDate,
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  endDate = picked;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: '종료일',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppBorderRadius.lg,
                                  ),
                                ),
                                suffixIcon: const Icon(
                                  Icons.calendar_today,
                                  size: 18,
                                ),
                              ),
                              child: Text(
                                '${endDate.month}/${endDate.day}',
                                style: AppTypography.bodyMedium,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space3),

                    // 시간 선택 (종일이 아닌 경우)
                    if (!isAllDay) ...[
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: startTime,
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    startTime = picked;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: '시작 시간',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppBorderRadius.lg,
                                    ),
                                  ),
                                  suffixIcon: const Icon(
                                    Icons.access_time,
                                    size: 18,
                                  ),
                                ),
                                child: Text(
                                  '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                                  style: AppTypography.bodyMedium,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.space3),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: endTime,
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    endTime = picked;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: '종료 시간',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppBorderRadius.lg,
                                    ),
                                  ),
                                  suffixIcon: const Icon(
                                    Icons.access_time,
                                    size: 18,
                                  ),
                                ),
                                child: Text(
                                  '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                                  style: AppTypography.bodyMedium,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.space3),
                    ],

                    // 참석자 선택
                    Consumer<AdminProvider>(
                      builder: (context, adminProv, _) {
                        final members = adminProv.companyMembers
                            .where((u) => u.status == 'active')
                            .toList();
                        if (members.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '참석자 (${selectedParticipantIds.length}명 선택)',
                              style: AppTypography.labelLarge.copyWith(
                                color: AppSemanticColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.space2),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 150),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppSemanticColors.borderDefault,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppBorderRadius.lg,
                                ),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: members.length,
                                itemBuilder: (context, index) {
                                  final member = members[index];
                                  final isSelected = selectedParticipantIds
                                      .contains(member.id.toString());
                                  return CheckboxListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.space2,
                                    ),
                                    title: Text(
                                      member.name,
                                      style: AppTypography.bodySmall,
                                    ),
                                    subtitle: Text(
                                      member.role == 'caregiver'
                                          ? '요양보호사'
                                          : '사무직',
                                      style: AppTypography.caption.copyWith(
                                        color: AppSemanticColors.textTertiary,
                                      ),
                                    ),
                                    value: isSelected,
                                    onChanged: (checked) {
                                      setModalState(() {
                                        if (checked == true) {
                                          selectedParticipantIds.add(
                                            member.id.toString(),
                                          );
                                        } else {
                                          selectedParticipantIds.remove(
                                            member.id.toString(),
                                          );
                                        }
                                      });
                                    },
                                    activeColor: AppSemanticColors
                                        .interactivePrimaryDefault,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: AppSpacing.space3),
                          ],
                        );
                      },
                    ),

                    // 알림 발송
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '알림 발송',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppSemanticColors.textPrimary,
                          ),
                        ),
                        Switch(
                          value: sendNotification,
                          onChanged: (value) {
                            setModalState(() {
                              sendNotification = value;
                            });
                          },
                          activeTrackColor:
                              AppSemanticColors.interactivePrimaryDefault,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space4),

                    // 등록 버튼
                    SizedBox(
                      width: double.infinity,
                      child: SeedButton(
                        label: '등록',
                        variant: SeedButtonVariant.brandSolid,
                        size: SeedButtonSize.large,
                        onPressed: () async {
                          if (titleController.text.trim().isEmpty) {
                            AppSnackBar.showWarning(context,
                                message: '제목을 입력해주세요');
                            return;
                          }

                          final authProvider = context.read<AuthProvider>();
                          final scheduleProvider = context
                              .read<ScheduleProvider>();
                          final companyId =
                              authProvider.currentUser?.company?.id ?? '1';

                          final startDateStr =
                              '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
                          final endDateStr =
                              '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

                          // 커스텀 구분은 category 대신 labelId로 보낸다
                          // (서버 category는 OTHER로 채움 — 웹과 같은 계약)
                          final isCustomLabel = selectedCategory.startsWith(
                            'label:',
                          );
                          final scheduleData = <String, dynamic>{
                            'title': titleController.text.trim(),
                            'content': contentController.text.trim().isEmpty
                                ? null
                                : contentController.text.trim(),
                            'category': isCustomLabel
                                ? 'OTHER'
                                : selectedCategory,
                            if (isCustomLabel)
                              'labelId': int.tryParse(
                                selectedCategory.substring(6),
                              ),
                            'color': selectedColorHex,
                            'location': locationController.text.trim().isEmpty
                                ? null
                                : locationController.text.trim(),
                            'startDate': startDateStr,
                            'endDate': endDateStr,
                            'isAllDay': isAllDay,
                            'sendNotification': sendNotification,
                            if (selectedParticipantIds.isNotEmpty)
                              'participantIds': selectedParticipantIds
                                  .map((id) => int.tryParse(id) ?? 0)
                                  .toList(),
                          };

                          if (!isAllDay) {
                            scheduleData['startTime'] =
                                '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
                            scheduleData['endTime'] =
                                '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';
                          }

                          Navigator.pop(context);

                          final success = await scheduleProvider.createSchedule(
                            companyId: companyId.toString(),
                            scheduleData: scheduleData,
                          );

                          if (mounted) {
                            if (success) {
                              AppSnackBar.showSuccess(context,
                                  message: '일정이 등록되었습니다');
                            } else {
                              AppSnackBar.showError(context,
                                  message: '일정 등록에 실패했습니다');
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space2),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 일정 구분 관리 시트 — 기본 구분(이름·색 변경, 숨김)과
  /// 기관 커스텀 구분(이름+색 추가·수정·삭제)을 함께 관리한다.
  /// 웹 관리자 화면의 '구분 관리' 다이얼로그와 같은 기능이다.
  /// 변경이 있을 때마다 콜백으로 최신 목록을 돌려준다.
  void _showScheduleLabelManageSheet({
    required String companyId,
    required void Function(List<ScheduleLabel>) onLabelsChanged,
    required void Function(List<ScheduleCategorySetting>)
        onBaseCategoriesChanged,
  }) {
    final nameController = TextEditingController();
    String colorHex = ScheduleColorPalette.values.first.hex;
    int? editingId; // 커스텀 구분 수정 중이면 라벨 id
    String? editingBase; // 기본 구분 수정 중이면 카테고리 코드 (editingId와 배타)
    List<ScheduleLabel> labels = [];
    List<ScheduleCategorySetting> baseCats = [];
    bool isLoading = true;
    bool isSaving = false;

    // AppBottomSheet.show로 바꾸지 않고 유지: 이미 토큰 스타일(둥근 상단·
    // surfaceDefault·핸들바)을 자체로 완전히 갖춰서 교체해도 시각적으로
    // 달라지는 게 없다.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppSemanticColors.surfaceDefault,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppBorderRadius.xl2),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> reload() async {
              try {
                final data = await ApiService().getScheduleLabels(
                  companyId: companyId,
                );
                final list = data['labels'];
                labels = list is List
                    ? list
                          .whereType<Map<String, dynamic>>()
                          .map(ScheduleLabel.fromJson)
                          .toList()
                    : [];
                onLabelsChanged(labels);
              } catch (_) {
                // 목록 로드 실패 — 빈 목록으로 두고 추가는 계속 시도할 수 있게 한다
              }
              try {
                final data = await ApiService().getScheduleCategorySettings(
                  companyId: companyId,
                );
                final list = data['categories'];
                if (list is List && list.isNotEmpty) {
                  baseCats = list
                      .whereType<Map<String, dynamic>>()
                      .map(ScheduleCategorySetting.fromJson)
                      .toList();
                  onBaseCategoriesChanged(baseCats);
                }
              } catch (_) {
                // 기본 구분 설정 로드 실패 — 섹션을 비워둔다
              }
              if (sheetContext.mounted) {
                setSheetState(() => isLoading = false);
              }
            }

            if (isLoading && labels.isEmpty && baseCats.isEmpty) {
              reload();
            }

            void resetForm() {
              nameController.clear();
              editingId = null;
              editingBase = null;
              colorHex = ScheduleColorPalette.values.first.hex;
            }

            Future<void> save() async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                AppSnackBar.showWarning(context, message: '구분 이름을 입력해주세요');
                return;
              }
              setSheetState(() => isSaving = true);
              try {
                if (editingBase != null) {
                  // 기본 구분 — 이름·색 덮어쓰기 (삭제는 없고 숨김만 있다)
                  await ApiService().updateScheduleCategorySetting(
                    companyId: companyId,
                    category: editingBase!,
                    name: name,
                    color: colorHex,
                  );
                } else if (editingId == null) {
                  await ApiService().createScheduleLabel(
                    companyId: companyId,
                    name: name,
                    color: colorHex,
                  );
                } else {
                  await ApiService().updateScheduleLabel(
                    companyId: companyId,
                    labelId: editingId!,
                    name: name,
                    color: colorHex,
                  );
                }
                resetForm();
                await reload();
              } catch (_) {
                if (sheetContext.mounted) {
                  AppSnackBar.showError(context, message: '구분 저장에 실패했습니다');
                }
              }
              if (sheetContext.mounted) {
                setSheetState(() => isSaving = false);
              }
            }

            Future<void> toggleBaseHidden(
              ScheduleCategorySetting setting,
            ) async {
              setSheetState(() => isSaving = true);
              try {
                await ApiService().updateScheduleCategorySetting(
                  companyId: companyId,
                  category: setting.category,
                  hidden: !setting.hidden,
                );
                await reload();
              } catch (_) {
                if (sheetContext.mounted) {
                  AppSnackBar.showError(context, message: '기본 구분 변경에 실패했습니다');
                }
              }
              if (sheetContext.mounted) {
                setSheetState(() => isSaving = false);
              }
            }

            Future<void> resetBase(ScheduleCategorySetting setting) async {
              setSheetState(() => isSaving = true);
              try {
                await ApiService().resetScheduleCategorySetting(
                  companyId: companyId,
                  category: setting.category,
                );
                if (editingBase == setting.category) resetForm();
                await reload();
              } catch (_) {
                if (sheetContext.mounted) {
                  AppSnackBar.showError(
                    context,
                    message: '기본 구분 되돌리기에 실패했습니다',
                  );
                }
              }
              if (sheetContext.mounted) {
                setSheetState(() => isSaving = false);
              }
            }

            Future<void> remove(ScheduleLabel label) async {
              final confirmed = await AppDialog.showConfirm(
                context,
                title: '구분 삭제',
                message:
                    "'${label.name}' 구분을 삭제하시겠습니까?\n이 구분을 쓰던 일정은 구분만 지워집니다.",
                confirmText: '삭제',
                cancelText: '취소',
                confirmVariant: SeedButtonVariant.critical,
              );
              if (confirmed != true) return;
              setSheetState(() => isSaving = true);
              try {
                await ApiService().deleteScheduleLabel(
                  companyId: companyId,
                  labelId: label.id,
                );
                if (editingId == label.id) resetForm();
                await reload();
              } catch (_) {
                if (sheetContext.mounted) {
                  AppSnackBar.showError(context, message: '구분 삭제에 실패했습니다');
                }
              }
              if (sheetContext.mounted) {
                setSheetState(() => isSaving = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.space4,
                right: AppSpacing.space4,
                top: AppSpacing.space4,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                    AppSpacing.space4,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: AppSpacing.space10,
                        height: AppSpacing.space1,
                        decoration: BoxDecoration(
                          color: AppSemanticColors.borderDefault,
                          borderRadius: BorderRadius.circular(
                            AppBorderRadius.sm,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '일정 구분 관리',
                          style: AppTypography.heading5.copyWith(
                            color: AppSemanticColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          tooltip: '닫기',
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: Icon(
                            Icons.close,
                            color: AppSemanticColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '구분을 고르면 일정에 그 색이 자동으로 적용됩니다',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppSemanticColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space3),

    // 기본 구분 — 이름·색 변경과 숨김만 (기존 일정이 물고 있어 삭제는 없다)
                    if (baseCats.isNotEmpty) ...[
                      Text(
                        '기본 구분',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppSemanticColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      for (final base in baseCats)
                        Opacity(
                          opacity: base.hidden ? 0.45 : 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.space1,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: colorFromHex(base.color) ??
                                        AppSemanticColors
                                            .interactivePrimaryDefault,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.space3),
                                Expanded(
                                  child: Text(
                                    base.hidden
                                        ? '${base.name} (숨김)'
                                        : base.name,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppSemanticColors.textPrimary,
                                      fontWeight:
                                          editingBase == base.category
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (base.customized)
                                  IconButton(
                                    onPressed: isSaving
                                        ? null
                                        : () => resetBase(base),
                                    icon: Icon(
                                      Icons.restart_alt,
                                      size: 20,
                                      color: AppSemanticColors.textSecondary,
                                    ),
                                    tooltip: '기본값으로 되돌리기',
                                  ),
                                IconButton(
                                  onPressed: isSaving
                                      ? null
                                      : () {
                                          setSheetState(() {
                                            editingId = null;
                                            editingBase = base.category;
                                            nameController.text = base.name;
                                            colorHex = base.color;
                                          });
                                        },
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                    color: AppSemanticColors
                                        .interactivePrimaryDefault,
                                  ),
                                  tooltip: '수정',
                                ),
                                IconButton(
                                  onPressed: isSaving
                                      ? null
                                      : () => toggleBaseHidden(base),
                                  icon: Icon(
                                    base.hidden
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20,
                                    color: AppSemanticColors.textSecondary,
                                  ),
                                  tooltip: base.hidden ? '보이기' : '숨기기',
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.space3),
                      Text(
                        '내가 만든 구분',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppSemanticColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],

                    // 기존 구분 목록
                    if (isLoading)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.space4),
                          child: CircularProgressIndicator(
                            color: AppSemanticColors.interactivePrimaryDefault,
                          ),
                        ),
                      )
                    else if (labels.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.space3,
                        ),
                        child: Text(
                          '아직 만든 구분이 없습니다. 아래에서 추가해보세요.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppSemanticColors.textTertiary,
                          ),
                        ),
                      )
                    else
                      for (final label in labels)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.space1,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: colorFromHex(label.color) ??
                                      AppSemanticColors
                                          .interactivePrimaryDefault,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.space3),
                              Expanded(
                                child: Text(
                                  label.name,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppSemanticColors.textPrimary,
                                    fontWeight: editingId == label.id
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: isSaving
                                    ? null
                                    : () {
                                        setSheetState(() {
                                          editingBase = null;
                                          editingId = label.id;
                                          nameController.text = label.name;
                                          colorHex = label.color;
                                        });
                                      },
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                  color: AppSemanticColors
                                      .interactivePrimaryDefault,
                                ),
                                tooltip: '수정',
                              ),
                              IconButton(
                                onPressed: isSaving
                                    ? null
                                    : () => remove(label),
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: AppSemanticColors.statusErrorIcon,
                                ),
                                tooltip: '삭제',
                              ),
                            ],
                          ),
                        ),
                    const SizedBox(height: AppSpacing.space3),

                    // 추가/수정 폼
                    SeedTextField(
                      label: editingBase != null
                          ? '기본 구분 이름 수정'
                          : (editingId == null ? '새 구분 이름' : '구분 이름 수정'),
                      controller: nameController,
                      placeholder: '예: 운영, 인사, 회계, 사업',
                    ),
                    const SizedBox(height: AppSpacing.space3),
                    Text(
                      '색상',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppSemanticColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    Wrap(
                      spacing: AppSpacing.space2,
                      runSpacing: AppSpacing.space2,
                      children: [
                        for (final option in ScheduleColorPalette.values)
                          _buildScheduleColorSwatch(
                            color: option.color,
                            isSelected: colorHex == option.hex,
                            tooltip: option.name,
                            onTap: () {
                              setSheetState(() {
                                colorHex = option.hex;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space4),
                    Row(
                      children: [
                        if (editingId != null || editingBase != null) ...[
                          Expanded(
                            child: SeedButton(
                              label: '취소',
                              variant: SeedButtonVariant.neutralOutline,
                              size: SeedButtonSize.large,
                              onPressed: isSaving
                                  ? null
                                  : () => setSheetState(resetForm),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.space2),
                        ],
                        Expanded(
                          child: SeedButton(
                            label: (editingId == null && editingBase == null)
                                ? '추가'
                                : '수정 저장',
                            variant: SeedButtonVariant.brandSolid,
                            size: SeedButtonSize.large,
                            isLoading: isSaving,
                            onPressed: isSaving ? null : save,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space2),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 일정 색상 선택 스와치. [color]가 null이면 "색상 없음" 옵션(카테고리 기본색 폴백)이다.
  Widget _buildScheduleColorSwatch({
    required Color? color,
    required bool isSelected,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color ?? AppSemanticColors.surfaceDefault,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? AppSemanticColors.interactivePrimaryDefault
                  : AppSemanticColors.borderDefault,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: color == null
              ? Icon(
                  Icons.block,
                  size: 16,
                  color: AppSemanticColors.textTertiary,
                )
              : (isSelected
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: AppSemanticColors.textInverse,
                      )
                    : null),
        ),
      ),
    );
  }

  void _showAdminActionDialog() {
    // 앱 공통 액션 시트 문법(둥근 상단+surfaceDefault+핸들바+틴트 아이콘)을 그대로
    // 쓴다 — 손조립 Container/Column 대신 showAppActionSheet.
    showAppActionSheet(
      context,
      title: '관리자 기능',
      actions: [
        AppSheetAction(
          icon: Icons.event_available,
          label: '휴무 추가',
          onSelected: _showAddVacationDialog,
        ),
        AppSheetAction(
          icon: Icons.settings,
          label: '휴무 제한 설정',
          onSelected: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const AdminVacationLimitsSettingScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showAddVacationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AdminVacationAddDialog(selectedDate: _selectedDate),
    );

    if (result == true) {
      final vacationProvider = context.read<VacationProvider>();
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.company?.id ?? '1';
      vacationProvider.loadCalendarData(_currentDate, companyId: companyId);
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
