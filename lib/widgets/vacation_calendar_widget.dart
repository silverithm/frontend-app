import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vacation_provider.dart';
import '../models/vacation_request.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/role_utils.dart';
import 'dart:math' as math;

class VacationCalendarWidget extends StatefulWidget {
  final DateTime currentDate;
  final Function(DateTime) onDateChanged;
  final Function(DateTime?) onDateSelected;

  /// 직종 다중 선택 (빈 목록 = 전체)
  final List<String> roleFilters;
  final Function(List<String>)? onRoleFiltersChanged;

  const VacationCalendarWidget({
    super.key,
    required this.currentDate,
    required this.onDateChanged,
    required this.onDateSelected,
    this.roleFilters = const [],
    this.onRoleFiltersChanged,
  });

  @override
  State<VacationCalendarWidget> createState() => _VacationCalendarWidgetState();
}

class _VacationCalendarWidgetState extends State<VacationCalendarWidget>
    with TickerProviderStateMixin {
  DateTime? _selectedDate;
  // 직종별 한도(limit) 기반 색상·카운트는 한도가 정의되는 단일 선택일 때만 의미가 있다
  bool get _isSingleRole => widget.roleFilters.length == 1;
  final List<String> _weekdays = ['일', '월', '화', '수', '목', '금', '토'];
  late AnimationController _animationController;
  late AnimationController _expandController;
  late Animation<double> _fadeAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _expandController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  void _previousMonth() {
    final newDate = DateTime(
      widget.currentDate.year,
      widget.currentDate.month - 1,
    );
    widget.onDateChanged(newDate);
  }

  void _nextMonth() {
    final newDate = DateTime(
      widget.currentDate.year,
      widget.currentDate.month + 1,
    );
    widget.onDateChanged(newDate);
  }

  void _selectDate(DateTime date) {
    setState(() {
      if (_selectedDate == date) {
        _selectedDate = null;
      } else {
        _selectedDate = date;
      }
    });
    widget.onDateSelected(_selectedDate);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return _isSameDay(date, today);
  }

  bool _isSameMonth(DateTime date) {
    return date.year == widget.currentDate.year &&
        date.month == widget.currentDate.month;
  }

  String _formatYearMonth(DateTime date) {
    return '${date.year}년 ${date.month}월';
  }

  List<DateTime> _getDaysInMonth() {
    final firstDay = DateTime(
      widget.currentDate.year,
      widget.currentDate.month,
      1,
    );
    final lastDay = DateTime(
      widget.currentDate.year,
      widget.currentDate.month + 1,
      0,
    );

    // 일요일을 0으로 하는 달력을 위한 정확한 계산
    // Flutter weekday: 1=월, 2=화, 3=수, 4=목, 5=금, 6=토, 7=일
    // 우리가 원하는 것: 0=일, 1=월, 2=화, 3=수, 4=목, 5=금, 6=토
    int getWeekdayForSunday(DateTime date) {
      return date.weekday == 7 ? 0 : date.weekday;
    }

    final firstWeekday = getWeekdayForSunday(firstDay);
    final lastWeekday = getWeekdayForSunday(lastDay);

    final startDate = firstDay.subtract(Duration(days: firstWeekday));
    final endDate = lastDay.add(Duration(days: 6 - lastWeekday));

    final days = <DateTime>[];
    var current = startDate;

    while (!current.isAfter(endDate)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }

    return days;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VacationProvider>(
      builder: (context, vacationProvider, child) {
        final days = _getDaysInMonth();

        // 흰 표면 위 얇은 하단 구분선 하나로 각 행을 구분한다 (카드 중첩·배경 블록 없음)
        final rowDivider = BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppSemanticColors.borderSubtle, width: 1),
          ),
        );

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 월 네비게이션 헤더
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space4,
                  vertical: AppSpacing.space3,
                ),
                decoration: rowDivider,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: _previousMonth,
                      icon: Icon(
                        Icons.chevron_left,
                        color: AppSemanticColors.textSecondary,
                        size: 20,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppSemanticColors.backgroundTertiary,
                        shape: const CircleBorder(),
                      ),
                    ),

                    Text(
                      _formatYearMonth(widget.currentDate),
                      style: AppTypography.heading6.copyWith(
                        fontWeight: AppTypography.fontWeightBold,
                        color: AppSemanticColors.textPrimary,
                      ),
                    ),

                    IconButton(
                      onPressed: _nextMonth,
                      icon: Icon(
                        Icons.chevron_right,
                        color: AppSemanticColors.textSecondary,
                        size: 20,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppSemanticColors.backgroundTertiary,
                        shape: const CircleBorder(),
                      ),
                    ),
                  ],
                ),
              ),

              // role 필터 버튼들 — 같은 표면, 하단 구분선으로만 분리
              if (widget.onRoleFiltersChanged != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space4,
                    vertical: AppSpacing.space3,
                  ),
                  decoration: rowDivider,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildRoleFilterButton(
                          RoleUtils.allRole,
                          '전체',
                          Icons.people,
                        ),
                        // 관리자 화면에서 만든 역할까지 그대로 노출
                        for (final role
                            in context
                                .watch<VacationProvider>()
                                .availableRoles) ...[
                          const SizedBox(width: AppSpacing.space2),
                          _buildRoleFilterButton(
                            role,
                            RoleUtils.displayName(role),
                            _roleFilterIcon(role),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // 요일 헤더 — 같은 표면, 하단 구분선으로만 분리
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space4,
                  vertical: AppSpacing.space3,
                ),
                decoration: rowDivider,
                child: Row(
                  children: _weekdays.map((weekday) {
                    final index = _weekdays.indexOf(weekday);
                    return Expanded(
                      child: Center(
                        child: Text(
                          weekday,
                          style: AppTypography.labelMedium.copyWith(
                            fontWeight: AppTypography.fontWeightBold,
                            color: index == 0
                                ? AppSemanticColors.statusErrorIcon
                                : index == 6
                                ? AppSemanticColors.statusInfoIcon
                                : AppSemanticColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // 이름 표시 옵션 — 같은 표면, 하단 구분선으로만 분리
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space4,
                  vertical: AppSpacing.space3,
                ),
                decoration: rowDivider,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.space1_5),
                          decoration: BoxDecoration(
                            color: AppSemanticColors.statusInfoBackground,
                            borderRadius: BorderRadius.circular(
                              AppBorderRadius.md,
                            ),
                          ),
                          child: Icon(
                            Icons.people_alt_outlined,
                            size: 16,
                            color: AppSemanticColors.statusInfoIcon,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.space2_5),
                        Text(
                          '휴무자 이름 표시',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: AppTypography.fontWeightSemibold,
                            color: AppSemanticColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: _toggleExpanded,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space3_5,
                          vertical: AppSpacing.space2,
                        ),
                        decoration: BoxDecoration(
                          color: _isExpanded
                              ? AppSemanticColors.brandWeak
                              : AppSemanticColors.backgroundTertiary,
                          borderRadius: BorderRadius.circular(
                            AppBorderRadius.full,
                          ),
                          border: Border.all(
                            color: _isExpanded
                                ? AppSemanticColors.brandDefault
                                : AppSemanticColors.borderDefault,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isExpanded
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              size: 16,
                              color: _isExpanded
                                  ? AppSemanticColors.brandPressed
                                  : AppSemanticColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.space1_5),
                            Text(
                              _isExpanded ? '숨기기' : '보기',
                              style: AppTypography.labelSmall.copyWith(
                                fontWeight: AppTypography.fontWeightSemibold,
                                color: _isExpanded
                                    ? AppSemanticColors.brandPressed
                                    : AppSemanticColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 달력 그리드 - 세로만 확장, 가로는 화면에 맞춤
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Builder(
                  builder: (context) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final horizontalPadding = 32.0; // 좌우 패딩 (16*2)
                    final spacing = 6.0; // 그리드 간격

                    // 가로 너비는 항상 화면에 맞춤 (7등분)
                    final cellWidth =
                        (screenWidth - horizontalPadding - (spacing * 6)) / 7;

                    // 확장 모드일 때 최대 휴무자 수 계산 (세로 확장용)
                    int maxVacationsInDay = 0;
                    if (_isExpanded) {
                      for (final day in days) {
                        if (_isSameMonth(day)) {
                          final vacationsForDay = vacationProvider
                              .getVacationsForDate(day);
                          if (vacationsForDay.length > maxVacationsInDay) {
                            maxVacationsInDay = vacationsForDay.length;
                          }
                        }
                      }
                      if (maxVacationsInDay == 0) maxVacationsInDay = 1;
                    }

                    // 정확한 행 수 계산
                    final rows = (days.length / 7).ceil();

                    // 높이 계산
                    final dateTextHeight = _isExpanded ? 22.0 : 28.0;
                    final maxGridHeight = _isExpanded
                        ? MediaQuery.of(context).size.height *
                              0.7 // 확장 모드 시 더 큰 영역 사용
                        : MediaQuery.of(context).size.height * 0.35;

                    if (_isExpanded) {
                      // 확장 모드: 주별로 동적 높이 조정
                      // 주별로 그룹화
                      List<List<DateTime>> weeks = [];
                      for (int i = 0; i < days.length; i += 7) {
                        weeks.add(
                          days.sublist(i, math.min(i + 7, days.length)),
                        );
                      }

                      return Column(
                        children: weeks.map((weekDays) {
                          // 이번 주에서 가장 많은 휴무자 수 계산 (필터링 적용)
                          int maxVacationsInWeek = 0;
                          for (final day in weekDays) {
                            if (_isSameMonth(day)) {
                              // getVacationsForDate는 이미 roleFilter가 적용된 결과를 반환함
                              final vacations = vacationProvider
                                  .getVacationsForDate(day);
                              print(
                                '[Calendar] 날짜: ${day.day}, 필터링된 휴무자: ${vacations.length}, 필터: ${widget.roleFilters}',
                              );

                              if (vacations.length > maxVacationsInWeek) {
                                maxVacationsInWeek = vacations.length;
                              }
                            }
                          }

                          print(
                            '[Calendar] 주별 최대 휴무자 수: $maxVacationsInWeek (필터: ${widget.roleFilters})',
                          );

                          // 주별 동적 높이 계산
                          // 기본 높이: 30 (날짜 + 패딩)
                          // 휴무자당: 18 (이름 표시 공간)
                          // 휴무 제한 표시 공간: 20 (전체 모드가 아닐 때만)
                          double baseHeight = 30.0;
                          double vacationHeight = maxVacationsInWeek * 18.0;
                          double limitHeight = _isSingleRole ? 20.0 : 0.0;
                          double weekHeight = math.max(
                            50.0,
                            baseHeight + vacationHeight + limitHeight,
                          );

                          print(
                            '[Calendar] 높이 계산 - 기본: $baseHeight, 휴무자: $vacationHeight, 제한: $limitHeight, 총: $weekHeight',
                          );

                          return Container(
                            margin: EdgeInsets.only(bottom: spacing),
                            child: Row(
                              children: weekDays.map((day) {
                                return Expanded(
                                  child: Container(
                                    height: weekHeight,
                                    margin: EdgeInsets.only(right: spacing),
                                    child: _buildCalendarCell(
                                      day,
                                      vacationProvider,
                                      dateTextHeight,
                                      weekHeight,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        }).toList(),
                      );
                    } else {
                      // 기본 모드: 개선된 점 표시
                      // 각 날짜의 최대 휴무 수 계산
                      int maxVacationsInWeek = 0;
                      for (int i = 0; i < days.length; i++) {
                        final vacations = vacationProvider.getVacationsForDate(
                          days[i],
                        );
                        if (vacations.length > maxVacationsInWeek) {
                          maxVacationsInWeek = vacations.length;
                        }
                      }

                      // 동적 셀 높이 계산
                      final baseCellHeight = 44.0;
                      final additionalHeight = maxVacationsInWeek > 3
                          ? 12.0
                          : 0.0;
                      final cellHeight = baseCellHeight + additionalHeight;
                      final actualGridHeight =
                          (cellHeight * rows) + (spacing * (rows - 1));

                      return Container(
                        height: actualGridHeight,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                childAspectRatio: cellWidth / cellHeight,
                                crossAxisSpacing: spacing,
                                mainAxisSpacing: spacing,
                              ),
                          itemCount: days.length,
                          itemBuilder: (context, index) => _buildCalendarCell(
                            days[index],
                            vacationProvider,
                            dateTextHeight,
                            cellHeight,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),

              // 색상별 범례 추가
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppSemanticColors.backgroundSecondary,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: AppSemanticColors.borderDefault,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 신청 상태
                    _buildCompactLegendItem(
                      '승인',
                      AppSemanticColors.statusSuccessIcon.withValues(
                        alpha: 0.8,
                      ),
                      Icons.check_circle,
                    ),
                    _buildCompactLegendItem(
                      '대기',
                      AppSemanticColors.statusWarningIcon.withValues(
                        alpha: 0.8,
                      ),
                      Icons.schedule,
                    ),
                    _buildCompactLegendItem(
                      '거절',
                      AppSemanticColors.statusErrorIcon.withValues(alpha: 0.75),
                      Icons.cancel,
                    ),

                    // 구분선
                    Container(
                      width: 1,
                      height: 12,
                      color: AppSemanticColors.borderDefault,
                    ),

                    // 연차/반차 구분
                    _buildDurationLegendItem(
                      '연차',
                      AppSemanticColors.statusInfoBackground,
                      AppSemanticColors.statusInfoBorder,
                      AppSemanticColors.statusInfoText,
                      '연',
                    ),
                    _buildDurationLegendItem(
                      '반차',
                      AppSemanticColors.statusWarningBackground,
                      AppSemanticColors.statusWarningBorder,
                      AppSemanticColors.statusWarningText,
                      '반',
                    ),

                    // 구분선
                    Container(
                      width: 1,
                      height: 12,
                      color: AppSemanticColors.borderDefault,
                    ),

                    // 필수 휴무만 표시
                    _buildTypeLegendItem(
                      '필수',
                      AppSemanticColors.statusWarningIcon.withValues(
                        alpha: 0.9,
                      ),
                      Icons.star,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalendarCell(
    DateTime date,
    VacationProvider vacationProvider,
    double dateTextHeight,
    double cellHeight,
  ) {
    final vacations = vacationProvider.getVacationsForDate(date);
    final isSelected =
        _selectedDate != null && _isSameDay(date, _selectedDate!);
    final isToday = _isToday(date);

    // 날짜별 여유 인원 확인
    final isAvailable = vacationProvider.isDateAvailable(date);
    final currentCount = vacationProvider.getVacationCountForDate(date);
    final limit = vacationProvider.getVacationLimitForDate(date);

    // 색상 결정 (같은 달의 날짜만, 전체 모드가 아닐 때만)
    Color? availabilityColor;
    if (_isSameMonth(date) && _isSingleRole) {
      if (isAvailable) {
        availabilityColor =
            AppSemanticColors.statusSuccessBackground; // 여유 있음 - 연한 초록
      } else {
        availabilityColor =
            AppSemanticColors.statusErrorBackground; // 인원 초과 - 연한 빨강
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? AppSemanticColors.statusInfoIcon
            : isToday
            ? AppSemanticColors.statusInfoBackground
            : availabilityColor ?? AppColors.transparent, // 여유 인원에 따른 색상
        borderRadius: BorderRadius.circular(8),
        border: isToday && !isSelected
            ? Border.all(color: AppSemanticColors.statusInfoBorder, width: 1.5)
            : _isSameMonth(date) && _isSingleRole && !isAvailable && !isSelected
            ? Border.all(
                color: AppSemanticColors.statusErrorBorder,
                width: 1,
              ) // 인원 초과 시 빨간 테두리
            : _isSameMonth(date) &&
                  _isSingleRole &&
                  isAvailable &&
                  !isSelected &&
                  !isToday
            ? Border.all(
                color: AppSemanticColors.statusSuccessBorder,
                width: 1,
              ) // 여유 있을 시 초록 테두리
            : null,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppSemanticColors.statusInfoBorder.withValues(
                    alpha: 0.4,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _selectDate(date),
          child: Container(
            width: double.infinity,
            height: cellHeight,
            padding: const EdgeInsets.all(3),
            child: _isExpanded
                ? Stack(
                    children: [
                      // 날짜 숫자 (좌측 상단)
                      Positioned(
                        top: 2,
                        left: 2,
                        child: Text(
                          date.day.toString(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: !_isSameMonth(date)
                                ? AppSemanticColors.textDisabled
                                : isSelected
                                ? AppSemanticColors.textInverse
                                : isToday
                                ? AppSemanticColors.statusInfoText
                                : date.weekday == DateTime.sunday
                                ? AppSemanticColors.statusErrorIcon
                                : date.weekday == DateTime.saturday
                                ? AppSemanticColors.statusInfoIcon
                                : AppSemanticColors.textPrimary,
                          ),
                        ),
                      ),

                      // 휴무자 이름들 (가운데부터 위쪽으로)
                      if (_isSameMonth(date) && vacations.isNotEmpty)
                        Positioned(
                          top: 18, // 날짜와 간격
                          left: 0,
                          right: 0,
                          bottom: _isSingleRole
                              ? 18 // 휴무 제한 표시 공간 확보
                              : 2, // 전체 모드일 때는 최소 간격만
                          child: _buildVacationIndicator(date, vacations),
                        ),

                      // 인원 수 표시 (하단, 전체 모드가 아닐 때만)
                      if (_isSameMonth(date) && _isSingleRole)
                        Positioned(
                          bottom: 2,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.white.withValues(alpha: 0.2)
                                    : isAvailable
                                    ? AppSemanticColors.statusSuccessBackground
                                    : AppSemanticColors.statusErrorBackground,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.white.withValues(alpha: 0.4)
                                      : isAvailable
                                      ? AppSemanticColors.statusSuccessBorder
                                      : AppSemanticColors.statusErrorBorder,
                                  width: 0.5,
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '$currentCount/$limit',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AppSemanticColors.textInverse
                                        : isAvailable
                                        ? AppSemanticColors.statusSuccessText
                                        : AppSemanticColors.statusErrorText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : Stack(
                    children: [
                      // 날짜 숫자 (좌측 상단)
                      Positioned(
                        top: 2,
                        left: 2,
                        child: Text(
                          date.day.toString(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: !_isSameMonth(date)
                                ? AppSemanticColors.textDisabled
                                : isSelected
                                ? AppSemanticColors.textInverse
                                : isToday
                                ? AppSemanticColors.statusInfoText
                                : date.weekday == DateTime.sunday
                                ? AppSemanticColors.statusErrorIcon
                                : date.weekday == DateTime.saturday
                                ? AppSemanticColors.statusInfoIcon
                                : AppSemanticColors.textPrimary,
                          ),
                        ),
                      ),

                      // 휴무자 표시 영역 (중앙)
                      if (_isSameMonth(date) && vacations.isNotEmpty)
                        Positioned(
                          top: 16,
                          left: 2,
                          right: 2,
                          bottom: _isSingleRole ? 12 : 2,
                          child: _buildVacationIndicator(date, vacations),
                        ),

                      // 인원 수 표시 (하단, 전체 모드가 아닐 때만)
                      if (_isSameMonth(date) && _isSingleRole)
                        Positioned(
                          bottom: 2,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.white.withValues(alpha: 0.2)
                                    : isAvailable
                                    ? AppSemanticColors.statusSuccessBackground
                                    : AppSemanticColors.statusErrorBackground,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.white.withValues(alpha: 0.4)
                                      : isAvailable
                                      ? AppSemanticColors.statusSuccessBorder
                                      : AppSemanticColors.statusErrorBorder,
                                  width: 0.5,
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '$currentCount/$limit',
                                  style: TextStyle(
                                    fontSize: 5,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AppSemanticColors.textInverse
                                        : isAvailable
                                        ? AppSemanticColors.statusSuccessText
                                        : AppSemanticColors.statusErrorText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildVacationIndicator(
    DateTime date,
    List<VacationRequest> vacations,
  ) {
    if (!_isSameMonth(date) || vacations.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_isExpanded) {
      // 확장 모드: 휴무자 이름들을 표시 (동적 높이, overflow 방지)
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: vacations.map((vacation) {
            return Container(
              width: double.infinity,
              height: 16.0,
              margin: const EdgeInsets.only(bottom: 1.5),
              padding: const EdgeInsets.symmetric(
                horizontal: 0.5,
                vertical: 0.5,
              ),
              decoration: BoxDecoration(
                color: _getStatusColor(vacation.status),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: _getStatusColor(
                      vacation.status,
                    ).withValues(alpha: 0.3),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // 이름 표시 (우선순위)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            vacation.userName,
                            style: const TextStyle(
                              fontSize: 7.0,
                              fontWeight: FontWeight.w600,
                              color: AppSemanticColors.textInverse,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 1),
                        Container(
                          width: 8,
                          height: 8,
                          child: _buildVacationTypeIcon(vacation),
                        ),
                      ],
                    ),
                  ),

                  // 휴무 유형 아이콘 (오른쪽)
                ],
              ),
            );
          }).toList(),
        ),
      );
    } else {
      // 기본 모드: 작은 점들로 표시, overflow 방지
      return Container(
        padding: const EdgeInsets.all(1),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 사용 가능한 너비 계산 (패딩 제외)
            final availableWidth = constraints.maxWidth - 2; // 좌우 패딩 1씩 제외

            // 점 하나의 크기 (점 크기 + 마진)
            const dotSize = 6.0;
            const dotMargin = 1.0;
            const dotTotalWidth = dotSize + dotMargin;

            // 최대 표시 가능한 점의 개수 계산
            final maxDots = (availableWidth / dotTotalWidth).floor();

            // overflow 방지를 위해 최소 1개, 최대 3개로 제한
            final actualMaxDots = maxDots.clamp(1, 3);

            return Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 동그라미들 (최대 3개)
                  ...() {
                    final List<Widget> dots = [];
                    final int totalVacations = vacations.length;
                    final int maxDisplay = actualMaxDots.clamp(1, 3);

                    // 3개 초과일 때는 2개 점 + 1개 +N 동그라미
                    if (totalVacations > 3) {
                      // 첫 2개 점 표시
                      for (int i = 0; i < 2; i++) {
                        final vacation = vacations.elementAt(i);
                        dots.add(
                          Container(
                            width: dotSize,
                            height: dotSize,
                            margin: const EdgeInsets.only(right: dotMargin),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getStatusColor(vacation.status),
                              boxShadow: [
                                BoxShadow(
                                  color: _getStatusColor(
                                    vacation.status,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 1,
                                  offset: const Offset(0, 0.5),
                                ),
                              ],
                            ),
                            // 필수휴무인 경우 작은 별표 표시
                            child: vacation.type == VacationType.mandatory
                                ? Center(
                                    child: Container(
                                      width: 3,
                                      height: 3,
                                      child: CustomPaint(
                                        painter: StarPainter(
                                          color: AppSemanticColors
                                              .statusWarningIcon
                                              .withValues(alpha: 0.9),
                                        ),
                                        size: const Size(3, 3),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        );
                      }

                      // +N 동그라미 (마지막)
                      dots.add(
                        Container(
                          width: dotSize,
                          height: dotSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppSemanticColors.textSecondary,
                            boxShadow: [
                              BoxShadow(
                                color: AppSemanticColors.textDisabled
                                    .withValues(alpha: 0.3),
                                blurRadius: 1,
                                offset: const Offset(0, 0.5),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '+${totalVacations - 2}',
                              style: const TextStyle(
                                fontSize: 4,
                                fontWeight: FontWeight.bold,
                                color: AppSemanticColors.textInverse,
                              ),
                            ),
                          ),
                        ),
                      );
                    } else {
                      // 3개 이하일 때는 모든 점 표시
                      for (
                        int i = 0;
                        i < totalVacations && i < maxDisplay;
                        i++
                      ) {
                        final vacation = vacations.elementAt(i);
                        final isLast =
                            i == totalVacations - 1 || i == maxDisplay - 1;

                        dots.add(
                          Container(
                            width: dotSize,
                            height: dotSize,
                            margin: EdgeInsets.only(
                              right: isLast ? 0 : dotMargin,
                            ),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getStatusColor(vacation.status),
                              boxShadow: [
                                BoxShadow(
                                  color: _getStatusColor(
                                    vacation.status,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 1,
                                  offset: const Offset(0, 0.5),
                                ),
                              ],
                            ),
                            // 필수휴무인 경우 작은 별표 표시
                            child: vacation.type == VacationType.mandatory
                                ? Center(
                                    child: Container(
                                      width: 3,
                                      height: 3,
                                      child: CustomPaint(
                                        painter: StarPainter(
                                          color: AppSemanticColors
                                              .statusWarningIcon
                                              .withValues(alpha: 0.9),
                                        ),
                                        size: const Size(3, 3),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        );
                      }
                    }

                    return dots;
                  }(),
                ],
              ),
            );
          },
        ),
      );
    }
  }

  Widget _buildVacationTypeIcon(VacationRequest vacation) {
    if (vacation.type == VacationType.mandatory) {
      // 필수 휴무는 별표 표시 (우선순위)
      return CustomPaint(
        painter: StarPainter(
          color: AppSemanticColors.statusWarningIcon.withValues(alpha: 0.9),
        ),
        size: const Size(8, 8),
      );
    } else {
      // 연차/반차는 동그라미에 텍스트 표시
      String text;
      if (vacation.duration == VacationDuration.unused) {
        text = '';
      } else if (vacation.duration == VacationDuration.fullDay) {
        text = '연';
      } else {
        text = '반'; // 오전반차, 오후반차 모두 "반"으로 표시
      }

      if (text.isEmpty) {
        return const SizedBox.shrink();
      }

      // 연차와 반차 구분을 위한 색상 설정
      Color backgroundColor;
      Color borderColor;
      Color textColor;

      if (vacation.duration == VacationDuration.fullDay) {
        // 연차 - 파란색 계열
        backgroundColor = AppSemanticColors.statusInfoBackground.withValues(
          alpha: 0.8,
        );
        borderColor = AppSemanticColors.statusInfoBorder;
        textColor = AppSemanticColors.statusInfoText;
      } else {
        // 반차 - 오렌지색 계열
        backgroundColor = AppSemanticColors.statusWarningBackground.withValues(
          alpha: 0.8,
        );
        borderColor = AppSemanticColors.statusWarningBorder;
        textColor = AppSemanticColors.statusWarningText;
      }

      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 5,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      );
    }
  }

  Color _getStatusColor(VacationStatus status) {
    switch (status) {
      case VacationStatus.approved:
        return AppSemanticColors.statusSuccessIcon.withValues(
          alpha: 0.8,
        ); // 투명도가 있는 연한 초록색
      case VacationStatus.rejected:
        return AppSemanticColors.statusErrorIcon.withValues(
          alpha: 0.75,
        ); // 투명도가 있는 연한 빨간색
      case VacationStatus.pending:
        return AppSemanticColors.statusWarningIcon.withValues(
          alpha: 0.8,
        ); // 투명도가 있는 앰버색 (더 세련된 노란색)
    }
  }

  Widget _buildCompactLegendItem(String label, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppSemanticColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeLegendItem(String label, Color color, IconData icon) {
    Widget shape;

    if (label == '필수') {
      // 별표
      shape = Container(
        width: 8,
        height: 8,
        child: CustomPaint(
          painter: StarPainter(color: color),
          size: const Size(8, 8),
        ),
      );
    } else {
      // 기본 원형
      shape = Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        shape,
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppSemanticColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDurationLegendItem(
    String label,
    Color backgroundColor,
    Color borderColor,
    Color textColor,
    String durationText,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor,
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Center(
            child: Text(
              durationText,
              style: TextStyle(
                fontSize: 5,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppSemanticColors.textPrimary,
          ),
        ),
      ],
    );
  }

  IconData _roleFilterIcon(String role) {
    switch (RoleUtils.normalize(role)) {
      case 'caregiver':
        return Icons.favorite;
      case 'office':
        return Icons.business;
      default:
        return Icons.badge_outlined;
    }
  }

  Widget _buildRoleFilterButton(String role, String label, IconData icon) {
    final normalized = RoleUtils.normalize(role);
    final isSelected = normalized == RoleUtils.allRole
        ? widget.roleFilters.isEmpty
        : widget.roleFilters.contains(normalized);

    return GestureDetector(
      onTap: () {
        final current = List<String>.from(widget.roleFilters);
        if (normalized == RoleUtils.allRole) {
          current.clear();
        } else if (current.contains(normalized)) {
          current.remove(normalized);
        } else {
          current.add(normalized);
        }
        widget.onRoleFiltersChanged?.call(current);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppSemanticColors.interactivePrimaryDefault
              : AppSemanticColors.surfaceDefault,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppSemanticColors.interactivePrimaryDefault
                : AppSemanticColors.borderDefault,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: AppSemanticColors.borderDefault.withValues(
                      alpha: 0.5,
                    ),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon(
            //   icon,
            //   size: 16,
            //   color: isSelected ? AppColors.white : AppSemanticColors.textSecondary,
            // ),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppSemanticColors.textInverse
                    : AppSemanticColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
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
