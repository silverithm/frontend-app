import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/schedule_provider.dart';
import '../providers/auth_provider.dart';
import '../models/schedule.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_loading.dart';

class AdminScheduleCalendarScreen extends StatefulWidget {
  const AdminScheduleCalendarScreen({super.key});

  @override
  State<AdminScheduleCalendarScreen> createState() =>
      _AdminScheduleCalendarScreenState();
}

class _AdminScheduleCalendarScreenState
    extends State<AdminScheduleCalendarScreen> {
  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSchedules();
    });
  }

  Future<void> _loadSchedules() async {
    final authProvider = context.read<AuthProvider>();
    final scheduleProvider = context.read<ScheduleProvider>();
    final companyId = authProvider.currentUser?.company?.id ?? '1';
    await scheduleProvider.loadCalendarData(_currentMonth, companyId: companyId);
  }

  void _goToPreviousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _loadSchedules();
  }

  void _goToNextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _loadSchedules();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      body: Consumer<ScheduleProvider>(
        builder: (context, scheduleProvider, child) {
          return Column(
            children: [
              // 월 네비게이션
              _buildMonthNavigation(),
              // 요일 헤더
              _buildWeekdayHeader(),
              // 달력
              Expanded(
                child: scheduleProvider.isLoading
                    ? const Center(child: AppLoading())
                    : _buildCalendar(scheduleProvider),
              ),
              // 선택된 날짜의 일정 목록
              if (_selectedDate != null)
                _buildScheduleList(scheduleProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMonthNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _goToPreviousMonth,
            icon: Icon(
              Icons.chevron_left,
              color: AppSemanticColors.textPrimary,
            ),
          ),
          Text(
            DateFormat('yyyy년 MM월').format(_currentMonth),
            style: AppTypography.heading6.copyWith(
              color: AppSemanticColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            onPressed: _goToNextMonth,
            icon: Icon(
              Icons.chevron_right,
              color: AppSemanticColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeader() {
    const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppSemanticColors.borderDefault,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: weekdays.map((day) {
          final isWeekend = day == '일' || day == '토';
          return Expanded(
            child: Center(
              child: Text(
                day,
                style: AppTypography.labelMedium.copyWith(
                  color: isWeekend
                      ? (day == '일'
                          ? AppSemanticColors.statusErrorIcon
                          : AppSemanticColors.statusInfoIcon)
                      : AppSemanticColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendar(ScheduleProvider scheduleProvider) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;

    final totalCells = ((firstWeekday + daysInMonth) / 7).ceil() * 7;
    final today = DateTime.now();

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.space2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        final dayOffset = index - firstWeekday;
        if (dayOffset < 0 || dayOffset >= daysInMonth) {
          return const SizedBox();
        }

        final date = DateTime(_currentMonth.year, _currentMonth.month, dayOffset + 1);
        final isToday = date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;
        final isSelected = _selectedDate != null &&
            date.year == _selectedDate!.year &&
            date.month == _selectedDate!.month &&
            date.day == _selectedDate!.day;
        final hasSchedules = scheduleProvider.hasSchedulesOnDate(date);
        final isWeekend = index % 7 == 0 || index % 7 == 6;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = date;
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
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${dayOffset + 1}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: isSelected
                        ? AppSemanticColors.textInverse
                        : isWeekend
                            ? (index % 7 == 0
                                ? AppSemanticColors.statusErrorIcon
                                : AppSemanticColors.statusInfoIcon)
                            : AppSemanticColors.textPrimary,
                    fontWeight: isToday || isSelected ? FontWeight.bold : null,
                  ),
                ),
                if (hasSchedules)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppSemanticColors.textInverse
                          : AppSemanticColors.statusInfoIcon,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScheduleList(ScheduleProvider scheduleProvider) {
    final schedules = scheduleProvider.getSchedulesForDate(_selectedDate!);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.3,
      ),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        border: Border(
          top: BorderSide(
            color: AppSemanticColors.borderDefault,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.space4),
            child: Row(
              children: [
                Text(
                  DateFormat('MM월 dd일 (E)', 'ko').format(_selectedDate!),
                  style: AppTypography.labelLarge.copyWith(
                    color: AppSemanticColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: AppSpacing.space2),
                Text(
                  '${schedules.length}건',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: schedules.isEmpty
                ? Center(
                    child: Text(
                      '등록된 일정이 없습니다',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppSemanticColors.textTertiary,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space4,
                    ),
                    itemCount: schedules.length,
                    itemBuilder: (context, index) {
                      return _buildScheduleItem(schedules[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(Schedule schedule) {
    final labelColor = schedule.label != null
        ? Color(int.parse(schedule.label!.color.replaceFirst('#', '0xFF')))
        : AppSemanticColors.statusInfoIcon;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space2),
      padding: const EdgeInsets.all(AppSpacing.space3),
      decoration: BoxDecoration(
        color: AppSemanticColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border(
          left: BorderSide(
            color: labelColor,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.space1),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space2,
                        vertical: AppSpacing.space0_5,
                      ),
                      decoration: BoxDecoration(
                        color: labelColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppBorderRadius.base),
                      ),
                      child: Text(
                        schedule.categoryText,
                        style: AppTypography.caption.copyWith(
                          color: labelColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (schedule.timeText.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.space2),
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: AppSemanticColors.textTertiary,
                      ),
                      const SizedBox(width: AppSpacing.space1),
                      Text(
                        schedule.timeText,
                        style: AppTypography.caption.copyWith(
                          color: AppSemanticColors.textTertiary,
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
    );
  }
}
