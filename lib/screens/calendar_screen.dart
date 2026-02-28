import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vacation_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/admin_provider.dart' hide VacationRequest;
import '../models/vacation_request.dart';
import '../models/schedule.dart';
import '../models/user.dart';
import '../utils/admin_utils.dart';
import '../widgets/vacation_calendar_widget.dart';
import '../widgets/vacation_request_dialog.dart';
import '../widgets/admin_vacation_add_dialog.dart';
import '../services/analytics_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';
import 'admin_vacation_limits_setting_screen.dart';
import '../providers/notice_provider.dart';
import 'notice_detail_screen.dart';
import 'dart:async';
import 'dart:math' as math;

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with TickerProviderStateMixin {
  DateTime _currentDate = DateTime.now();
  DateTime? _selectedDate;
  String _roleFilter = 'all';
  late AnimationController _fabAnimationController;
  late AnimationController _filterAnimationController;
  late TabController _tabController;

  // 공지 티커용 상태
  int _currentNoticeIndex = 0;
  Timer? _noticeTimer;

  // 일정 달력용 상태
  DateTime _scheduleCurrentDate = DateTime.now();
  DateTime? _scheduleSelectedDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      scheduleProvider.loadCalendarData(_scheduleCurrentDate, companyId: companyId.toString());
      context.read<NoticeProvider>().loadPublishedNotices(
        companyId: companyId,
        refresh: true,
      );

      _fabAnimationController.forward();

      // 공지 티커 타이머 시작
      _startNoticeTimer();

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

  void _startNoticeTimer() {
    _noticeTimer?.cancel();
    _noticeTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      final notices = context.read<NoticeProvider>().publishedNotices;
      if (notices.length > 1) {
        setState(() {
          _currentNoticeIndex = (_currentNoticeIndex + 1) % notices.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _tabController.dispose();
    _fabAnimationController.dispose();
    _filterAnimationController.dispose();
    super.dispose();
  }

  void _showVacationRequestDialog() {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '날짜를 먼저 선택해주세요',
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textInverse,
            ),
          ),
          backgroundColor: AppSemanticColors.statusWarningIcon,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          ),
        ),
      );
      return;
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
                  final isAdmin = AdminUtils.canAccessAdminPages(context.read<AuthProvider>().currentUser);
                  final accentColor = AppSemanticColors.interactivePrimaryDefault;
                  return Container(
                    color: AppSemanticColors.interactivePrimaryDefault,
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AppSemanticColors.textInverse,
                      indicatorWeight: 2,
                      labelColor: AppSemanticColors.textInverse,
                      unselectedLabelColor: AppSemanticColors.textInverse.withValues(alpha: 0.5),
                      labelStyle: AppTypography.labelLarge.copyWith(
                        fontWeight: AppTypography.fontWeightSemibold,
                      ),
                      unselectedLabelStyle: AppTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.normal,
                      ),
                      tabs: const [
                        Tab(text: '휴무 달력'),
                        Tab(text: '일정 달력'),
                      ],
                    ),
                  );
                  },
                ),
              ),
            ),
            // 공지사항 티커
            SliverToBoxAdapter(
              child: _buildNoticeTicker(),
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
        print('[CalendarScreen] 일정 달력 빌드 - 로딩: ${scheduleProvider.isLoading}, 일정수: ${scheduleProvider.schedules.length}, 날짜별: ${scheduleProvider.schedulesByDate.keys.toList()}');
        return SingleChildScrollView(
          child: Column(
            children: [
              // 달력 위젯
              Container(
                margin: const EdgeInsets.all(AppSpacing.space6),
                decoration: BoxDecoration(
                  color: AppSemanticColors.surfaceDefault,
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  border: Border.all(
                    color: AppSemanticColors.borderDefault,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.04),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
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
        // 월 네비게이션
        Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _scheduleCurrentDate = DateTime(
                      _scheduleCurrentDate.year,
                      _scheduleCurrentDate.month - 1,
                    );
                  });
                  final authProvider = context.read<AuthProvider>();
                  final companyId = authProvider.currentUser?.company?.id ?? '1';
                  provider.loadCalendarData(_scheduleCurrentDate, companyId: companyId.toString());
                },
                icon: Icon(
                  Icons.chevron_left,
                  color: AppSemanticColors.textSecondary,
                ),
              ),
              Text(
                '${_scheduleCurrentDate.year}년 ${_scheduleCurrentDate.month}월',
                style: AppTypography.heading6.copyWith(
                  fontWeight: AppTypography.fontWeightSemibold,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _scheduleCurrentDate = DateTime(
                      _scheduleCurrentDate.year,
                      _scheduleCurrentDate.month + 1,
                    );
                  });
                  final authProvider = context.read<AuthProvider>();
                  final companyId = authProvider.currentUser?.company?.id ?? '1';
                  provider.loadCalendarData(_scheduleCurrentDate, companyId: companyId.toString());
                },
                icon: Icon(
                  Icons.chevron_right,
                  color: AppSemanticColors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // 요일 헤더
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
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

        const SizedBox(height: AppSpacing.space2),

        // 달력 그리드
        _buildScheduleCalendarGrid(provider),

        const SizedBox(height: AppSpacing.space4),
      ],
    );
  }

  Widget _buildScheduleCalendarGrid(ScheduleProvider provider) {
    final firstDayOfMonth = DateTime(_scheduleCurrentDate.year, _scheduleCurrentDate.month, 1);
    final lastDayOfMonth = DateTime(_scheduleCurrentDate.year, _scheduleCurrentDate.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7;

    final days = <Widget>[];

    // 이전 달 빈 칸
    for (int i = 0; i < firstWeekday; i++) {
      days.add(const SizedBox());
    }

    // 현재 달의 날짜들
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(_scheduleCurrentDate.year, _scheduleCurrentDate.month, day);
      final isSelected = _scheduleSelectedDate != null &&
          _scheduleSelectedDate!.year == date.year &&
          _scheduleSelectedDate!.month == date.month &&
          _scheduleSelectedDate!.day == date.day;
      final isToday = DateTime.now().year == date.year &&
          DateTime.now().month == date.month &&
          DateTime.now().day == date.day;
      final hasSchedule = provider.hasSchedulesOnDate(date);

      // 디버깅 (일정이 있는 날짜 확인)
      if (day == 1 || hasSchedule) {
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        print('[CalendarScreen] $day일 확인 - dateKey: $dateKey, hasSchedule: $hasSchedule');
        if (day == 1) {
          print('[CalendarScreen] 저장된 모든 키: ${provider.schedulesByDate.keys.toList()}');
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
                      ? AppSemanticColors.interactivePrimaryDefault.withValues(alpha: 0.1)
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
                          padding: const EdgeInsets.all(AppSpacing.space3),
                          decoration: BoxDecoration(
                            color: AppSemanticColors.backgroundTertiary,
                            borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
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
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space5),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
                    border: Border.all(
                      color: AppSemanticColors.borderSubtle,
                      width: 1,
                    ),
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
                        color: AppSemanticColors.statusSuccessIcon.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppBorderRadius.full),
                      ),
                      child: Text(
                        '일정 ${schedules.length}건',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppSemanticColors.statusSuccessIcon,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space3),
                    ...schedules.map((schedule) => _buildScheduleItem(schedule)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleItem(Schedule schedule) {
    final categoryColor = _getCategoryColor(schedule.category);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space2),
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
        border: Border.all(
          color: categoryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: categoryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.title,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppSemanticColors.textPrimary,
                    fontWeight: AppTypography.fontWeightSemibold,
                  ),
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
                    if (schedule.location != null && schedule.location!.isNotEmpty) ...[
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
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space2,
              vertical: AppSpacing.space1,
            ),
            decoration: BoxDecoration(
              color: categoryColor,
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
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'MEETING':
        return AppSemanticColors.interactivePrimaryDefault;
      case 'EVENT':
        return AppSemanticColors.statusSuccessIcon;
      case 'TRAINING':
        return AppSemanticColors.statusWarningIcon;
      case 'OTHER':
      default:
        return AppSemanticColors.textSecondary;
    }
  }

  Widget _buildNoticeTicker() {
    return Consumer<NoticeProvider>(
      builder: (context, noticeProvider, child) {
        final notices = noticeProvider.publishedNotices;
        if (notices.isEmpty) return const SizedBox.shrink();

        final safeIndex = _currentNoticeIndex % notices.length;
        final currentNotice = notices[safeIndex];

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NoticeDetailScreen(noticeId: currentNotice.id),
              ),
            );
          },
          child: Container(
            color: AppSemanticColors.backgroundPrimary,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space4,
              vertical: AppSpacing.space2,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space2,
                    vertical: AppSpacing.space1,
                  ),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.statusInfoBackground,
                    borderRadius: BorderRadius.circular(AppBorderRadius.base),
                  ),
                  child: Text(
                    '공지',
                    style: AppTypography.caption.copyWith(
                      color: AppSemanticColors.statusInfoIcon,
                      fontWeight: AppTypography.fontWeightSemibold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.space2),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppTransitions.slow,
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.5),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      currentNotice.title,
                      key: ValueKey(currentNotice.id),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppSemanticColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (notices.length > 1) ...[
                  const SizedBox(width: AppSpacing.space2),
                  Text(
                    '${safeIndex + 1}/${notices.length}',
                    style: AppTypography.caption.copyWith(
                      color: AppSemanticColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// 휴무 달력 탭 빌드
  Widget _buildVacationCalendar() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 달력 위젯
          Container(
            margin: const EdgeInsets.all(AppSpacing.space6),
            decoration: BoxDecoration(
              color: AppSemanticColors.surfaceDefault,
              borderRadius: BorderRadius.circular(AppBorderRadius.xl),
              border: Border.all(
                color: AppSemanticColors.borderDefault,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.04),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.06),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
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
              roleFilter: _roleFilter,
              onRoleFilterChanged: (newRole) {
                setState(() {
                  _roleFilter = newRole;
                });
                final vacationProvider = context.read<VacationProvider>();
                vacationProvider.setRoleFilter(newRole);
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
                                  padding: const EdgeInsets.all(AppSpacing.space3),
                                  decoration: BoxDecoration(
                                    color: AppSemanticColors.backgroundTertiary,
                                    borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
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
                            onPressed: () {
                              setState(() {
                                _selectedDate = null;
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

                      Consumer<VacationProvider>(
                        builder: (context, vacationProvider, child) {
                          final vacations = vacationProvider.getVacationsForDate(_selectedDate!);

                          if (vacations.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(AppSpacing.space5),
                              decoration: BoxDecoration(
                                color: AppSemanticColors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
                                border: Border.all(
                                  color: AppSemanticColors.borderSubtle,
                                  width: 1,
                                ),
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
                                  color: AppSemanticColors.interactivePrimaryDefault.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppBorderRadius.full),
                                ),
                                child: Text(
                                  '휴무자 ${vacations.length}명',
                                  style: AppTypography.labelLarge.copyWith(
                                    color: AppSemanticColors.interactivePrimaryDefault,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.space3),
                              ...vacations.map(
                                (vacation) => Container(
                                  margin: const EdgeInsets.only(bottom: AppSpacing.space2),
                                  padding: const EdgeInsets.all(AppSpacing.space4),
                                  decoration: BoxDecoration(
                                    color: AppSemanticColors.surfaceDefault,
                                    borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
                                    border: Border.all(
                                      color: _getStatusTextColor(vacation.status).withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(AppSpacing.space2),
                                        decoration: BoxDecoration(
                                          color: _getStatusTextColor(vacation.status).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                                        ),
                                        child: Icon(
                                          _getStatusIcon(vacation.status),
                                          size: 16,
                                          color: _getStatusTextColor(vacation.status),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.space3),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            _buildVacationTypeShape(vacation),
                                            const SizedBox(width: AppSpacing.space2),
                                            Expanded(
                                              child: Text(
                                                vacation.displayName,
                                                style: AppTypography.bodyLarge.copyWith(
                                                  color: AppSemanticColors.textPrimary,
                                                  fontWeight: AppTypography.fontWeightSemibold,
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
                                          color: _getStatusTextColor(vacation.status),
                                          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                                        ),
                                        child: Text(
                                          vacation.statusText,
                                          style: AppTypography.labelSmall.copyWith(
                                            color: AppSemanticColors.textInverse,
                                            fontWeight: AppTypography.fontWeightBold,
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
          if (AdminUtils.canAccessAdminPages(context.read<AuthProvider>().currentUser))
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
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.04),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _roleFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: isSelected
              ? AppSemanticColors.textInverse
              : AppSemanticColors.textSecondary,
          fontWeight: isSelected
              ? AppTypography.fontWeightSemibold
              : AppTypography.fontWeightMedium,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _roleFilter = value;
        });
        final vacationProvider = context.read<VacationProvider>();
        vacationProvider.setRoleFilter(value);
        final authProvider = context.read<AuthProvider>();
        final companyId = authProvider.currentUser?.company?.id ?? '1';
        vacationProvider.loadCalendarData(_currentDate, companyId: companyId);
      },
      backgroundColor: AppSemanticColors.surfaceDefault,
      selectedColor: AppSemanticColors.interactivePrimaryDefault,
      checkmarkColor: AppSemanticColors.textInverse,
      side: BorderSide(
        color: isSelected
            ? AppSemanticColors.interactivePrimaryDefault
            : AppSemanticColors.borderSubtle,
        width: 1,
      ),
    );
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
    for (var date = monthStart; date.isBefore(monthEnd.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      final dayVacations = provider.getVacationsForDate(date);
      total += dayVacations.length;
    }
    return total;
  }

  int _getMonthlyPending(VacationProvider provider) {
    final monthStart = DateTime(_currentDate.year, _currentDate.month, 1);
    final monthEnd = DateTime(_currentDate.year, _currentDate.month + 1, 0);

    int pending = 0;
    for (var date = monthStart; date.isBefore(monthEnd.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      final dayVacations = provider.getVacationsForDate(date);
      pending += dayVacations.where((v) => v.status == VacationStatus.pending).length;
    }
    return pending;
  }

  int _getMonthlyApproved(VacationProvider provider) {
    final monthStart = DateTime(_currentDate.year, _currentDate.month, 1);
    final monthEnd = DateTime(_currentDate.year, _currentDate.month + 1, 0);

    int approved = 0;
    for (var date = monthStart; date.isBefore(monthEnd.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      final dayVacations = provider.getVacationsForDate(date);
      approved += dayVacations.where((v) => v.status == VacationStatus.approved).length;
    }
    return approved;
  }

  int _getMonthlyRejected(VacationProvider provider) {
    final monthStart = DateTime(_currentDate.year, _currentDate.month, 1);
    final monthEnd = DateTime(_currentDate.year, _currentDate.month + 1, 0);

    int rejected = 0;
    for (var date = monthStart; date.isBefore(monthEnd.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      final dayVacations = provider.getVacationsForDate(date);
      rejected += dayVacations.where((v) => v.status == VacationStatus.rejected).length;
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
    String selectedCategory = 'MEETING';
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppSemanticColors.surfaceDefault,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppBorderRadius.xl2)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.space4,
                right: AppSpacing.space4,
                top: AppSpacing.space4,
                bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.space4,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 핸들
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppSemanticColors.borderDefault,
                          borderRadius: BorderRadius.circular(2),
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
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, color: AppSemanticColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space4),

                    // 제목
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: '제목 *',
                        hintText: '일정 제목을 입력하세요',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space3),

                    // 내용
                    TextField(
                      controller: contentController,
                      decoration: InputDecoration(
                        labelText: '내용',
                        hintText: '일정 내용을 입력하세요',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                        ),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppSpacing.space3),

                    // 카테고리
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: InputDecoration(
                        labelText: '카테고리',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'MEETING', child: Text('회의')),
                        DropdownMenuItem(value: 'EVENT', child: Text('행사')),
                        DropdownMenuItem(value: 'TRAINING', child: Text('교육')),
                        DropdownMenuItem(value: 'OTHER', child: Text('기타')),
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          selectedCategory = value ?? 'MEETING';
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.space3),

                    // 장소
                    TextField(
                      controller: locationController,
                      decoration: InputDecoration(
                        labelText: '장소',
                        hintText: '장소를 입력하세요',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                        ),
                      ),
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
                          activeTrackColor: AppSemanticColors.interactivePrimaryDefault,
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
                                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                                ),
                                suffixIcon: const Icon(Icons.calendar_today, size: 18),
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
                                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                                ),
                                suffixIcon: const Icon(Icons.calendar_today, size: 18),
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
                                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                                  ),
                                  suffixIcon: const Icon(Icons.access_time, size: 18),
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
                                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                                  ),
                                  suffixIcon: const Icon(Icons.access_time, size: 18),
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
                                border: Border.all(color: AppSemanticColors.borderDefault),
                                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: members.length,
                                itemBuilder: (context, index) {
                                  final member = members[index];
                                  final isSelected = selectedParticipantIds.contains(member.id.toString());
                                  return CheckboxListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
                                    title: Text(
                                      member.name,
                                      style: AppTypography.bodySmall,
                                    ),
                                    subtitle: Text(
                                      member.role == 'caregiver' ? '요양보호사' : '사무직',
                                      style: AppTypography.caption.copyWith(
                                        color: AppSemanticColors.textTertiary,
                                      ),
                                    ),
                                    value: isSelected,
                                    onChanged: (checked) {
                                      setModalState(() {
                                        if (checked == true) {
                                          selectedParticipantIds.add(member.id.toString());
                                        } else {
                                          selectedParticipantIds.remove(member.id.toString());
                                        }
                                      });
                                    },
                                    activeColor: AppSemanticColors.interactivePrimaryDefault,
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
                          activeTrackColor: AppSemanticColors.interactivePrimaryDefault,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space4),

                    // 등록 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (titleController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('제목을 입력해주세요')),
                            );
                            return;
                          }

                          final authProvider = context.read<AuthProvider>();
                          final scheduleProvider = context.read<ScheduleProvider>();
                          final companyId = authProvider.currentUser?.company?.id ?? '1';

                          final startDateStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
                          final endDateStr = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

                          final scheduleData = <String, dynamic>{
                            'title': titleController.text.trim(),
                            'content': contentController.text.trim().isEmpty
                                ? null
                                : contentController.text.trim(),
                            'category': selectedCategory,
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success ? '일정이 등록되었습니다' : '일정 등록에 실패했습니다'),
                                backgroundColor: success
                                    ? AppSemanticColors.statusSuccessIcon
                                    : AppSemanticColors.statusErrorIcon,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppSemanticColors.interactivePrimaryDefault,
                          foregroundColor: AppSemanticColors.textInverse,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                          ),
                        ),
                        child: Text(
                          '등록',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppSemanticColors.textInverse,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

  void _showAdminActionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppBorderRadius.xl2)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.space5),
              decoration: BoxDecoration(
                color: AppSemanticColors.borderSubtle,
                borderRadius: BorderRadius.circular(AppBorderRadius.base),
              ),
            ),
            Text(
              '관리자 기능',
              style: AppTypography.heading5,
            ),
            const SizedBox(height: AppSpacing.space5),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(AppSpacing.space2),
                decoration: BoxDecoration(
                  color: AppSemanticColors.statusInfoBackground,
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                ),
                child: Icon(Icons.event_available, color: AppSemanticColors.statusInfoIcon),
              ),
              title: const Text('휴무 추가'),
              subtitle: const Text('직원의 휴무를 직접 추가합니다'),
              onTap: () {
                Navigator.pop(context);
                _showAddVacationDialog();
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(AppSpacing.space2),
                decoration: BoxDecoration(
                  color: AppSemanticColors.statusWarningBackground,
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                ),
                child: Icon(Icons.settings, color: AppSemanticColors.statusWarningIcon),
              ),
              title: const Text('휴무 제한 설정'),
              subtitle: const Text('날짜별 최대 휴무 인원을 설정합니다'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AdminVacationLimitsSettingScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddVacationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AdminVacationAddDialog(
        selectedDate: _selectedDate,
      ),
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
