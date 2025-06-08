import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vacation_provider.dart';
import '../models/vacation_request.dart';
import 'dart:math' as math;

class VacationCalendarWidget extends StatefulWidget {
  final DateTime currentDate;
  final Function(DateTime) onDateChanged;
  final Function(DateTime?) onDateSelected;
  final String roleFilter;
  final Function(String)? onRoleFilterChanged;

  const VacationCalendarWidget({
    super.key,
    required this.currentDate,
    required this.onDateChanged,
    required this.onDateSelected,
    this.roleFilter = 'all',
    this.onRoleFilterChanged,
  });

  @override
  State<VacationCalendarWidget> createState() => _VacationCalendarWidgetState();
}

class _VacationCalendarWidgetState extends State<VacationCalendarWidget>
    with TickerProviderStateMixin {
  DateTime? _selectedDate;
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

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.grey.shade50,
                        Colors.grey.shade100,
                        Colors.grey.shade200,
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: _previousMonth,
                          icon: Icon(
                            Icons.chevron_left,
                            color: Colors.grey.shade700,
                            size: 24,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      Text(
                        _formatYearMonth(widget.currentDate),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                          letterSpacing: -0.5,
                        ),
                      ),

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: _nextMonth,
                          icon: Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade700,
                            size: 24,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // role 필터 버튼들
                if (widget.onRoleFilterChanged != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildRoleFilterButton('all', '전체', Icons.people),
                        const SizedBox(width: 8),
                        _buildRoleFilterButton(
                          'CAREGIVER',
                          '요양보호사',
                          Icons.favorite,
                        ),
                        const SizedBox(width: 8),
                        _buildRoleFilterButton('OFFICE', '사무실', Icons.business),
                      ],
                    ),
                  ),

                // 요일 헤더
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                    ),
                  ),
                  child: Row(
                    children: _weekdays.map((weekday) {
                      final index = _weekdays.indexOf(weekday);
                      return Expanded(
                        child: Center(
                          child: Text(
                            weekday,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: index == 0
                                  ? Colors.red.shade600
                                  : index == 6
                                  ? Colors.blue.shade600
                                  : Colors.grey.shade700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // 이름 표시 옵션
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.people_alt_outlined,
                              size: 16,
                              color: Colors.blue.shade600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '휴가자 이름 표시',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: _toggleExpanded,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: _isExpanded
                                ? LinearGradient(
                                    colors: [
                                      Colors.blue.shade500,
                                      Colors.blue.shade600,
                                    ],
                                  )
                                : null,
                            color: _isExpanded ? null : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isExpanded
                                  ? Colors.blue.shade600
                                  : Colors.grey.shade300,
                              width: 1,
                            ),
                            boxShadow: _isExpanded
                                ? [
                                    BoxShadow(
                                      color: Colors.blue.shade300.withOpacity(
                                        0.3,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
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
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isExpanded ? '숨기기' : '보기',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _isExpanded
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                  letterSpacing: -0.2,
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

                      // 확장 모드일 때 최대 휴가자 수 계산 (세로 확장용)
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
                        // 확장 모드: 세로만 확장, 스크롤 개선
                        final baseCellHeight = 50.0; // 기본 높이
                        final additionalHeight =
                            maxVacationsInDay * 18.0; // 휴가자당 18px
                        final dynamicCellHeight =
                            baseCellHeight + additionalHeight;
                        final maxCellHeight = 150.0; // 최대 높이 제한 증가
                        final cellHeight = math.min(
                          dynamicCellHeight,
                          maxCellHeight,
                        );

                        final totalGridHeight =
                            cellHeight * rows + spacing * (rows - 1);
                        final containerHeight = math.min(
                          totalGridHeight,
                          maxGridHeight,
                        );

                        return Container(
                          height: containerHeight,
                          child: totalGridHeight > maxGridHeight
                              ? SingleChildScrollView(
                                  physics:
                                      const ClampingScrollPhysics(), // 스크롤 물리 개선
                                  child: GridView.builder(
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    padding: EdgeInsets.zero,
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 7,
                                          childAspectRatio:
                                              cellWidth / cellHeight,
                                          crossAxisSpacing: spacing,
                                          mainAxisSpacing: spacing,
                                        ),
                                    itemCount: days.length,
                                    itemBuilder: (context, index) =>
                                        _buildCalendarCell(
                                          days[index],
                                          vacationProvider,
                                          dateTextHeight,
                                          cellHeight,
                                        ),
                                  ),
                                )
                              : GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 7,
                                        childAspectRatio:
                                            cellWidth / cellHeight,
                                        crossAxisSpacing: spacing,
                                        mainAxisSpacing: spacing,
                                      ),
                                  itemCount: days.length,
                                  itemBuilder: (context, index) =>
                                      _buildCalendarCell(
                                        days[index],
                                        vacationProvider,
                                        dateTextHeight,
                                        cellHeight,
                                      ),
                                ),
                        );
                      } else {
                        // 기본 모드: 개선된 점 표시
                        final actualGridHeight = maxGridHeight * 0.9;
                        final cellHeight =
                            (actualGridHeight - spacing * (rows - 1)) / rows;

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
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200, width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 신청 상태
                      _buildCompactLegendItem(
                        '승인',
                        Colors.green.shade500,
                        Icons.check_circle,
                      ),
                      _buildCompactLegendItem(
                        '대기',
                        Colors.orange.shade500,
                        Icons.schedule,
                      ),
                      _buildCompactLegendItem(
                        '거절',
                        Colors.red.shade500,
                        Icons.cancel,
                      ),

                      // 구분선
                      Container(
                        width: 1,
                        height: 12,
                        color: Colors.grey.shade300,
                      ),

                      // 필수 휴무만 표시
                      _buildTypeLegendItem(
                        '필수',
                        Colors.red.shade600,
                        Icons.star,
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
    if (_isSameMonth(date) && widget.roleFilter != 'all') {
      if (isAvailable) {
        availabilityColor = Colors.green.shade50; // 여유 있음 - 연한 초록
      } else {
        availabilityColor = Colors.red.shade50; // 인원 초과 - 연한 빨강
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blue.shade600
            : isToday
            ? Colors.blue.shade50
            : availabilityColor ?? Colors.transparent, // 여유 인원에 따른 색상
        borderRadius: BorderRadius.circular(8),
        border: isToday && !isSelected
            ? Border.all(color: Colors.blue.shade300, width: 1.5)
            : _isSameMonth(date) &&
                  widget.roleFilter != 'all' &&
                  !isAvailable &&
                  !isSelected
            ? Border.all(color: Colors.red.shade300, width: 1) // 인원 초과 시 빨간 테두리
            : _isSameMonth(date) &&
                  widget.roleFilter != 'all' &&
                  isAvailable &&
                  !isSelected &&
                  !isToday
            ? Border.all(
                color: Colors.green.shade300,
                width: 1,
              ) // 여유 있을 시 초록 테두리
            : null,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.blue.shade300.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
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
                                ? Colors.grey.shade300
                                : isSelected
                                ? Colors.white
                                : isToday
                                ? Colors.blue.shade700
                                : date.weekday == DateTime.sunday
                                ? Colors.red.shade600
                                : date.weekday == DateTime.saturday
                                ? Colors.blue.shade600
                                : Colors.grey.shade800,
                          ),
                        ),
                      ),

                      // 휴가자 이름들 (가운데부터 위쪽으로)
                      if (_isSameMonth(date) && vacations.isNotEmpty)
                        Positioned(
                          top: 18, // 20 -> 18로 날짜와 간격 줄임
                          left: 0,
                          right: 0,
                          bottom: widget.roleFilter != 'all'
                              ? 15
                              : 0, // 20 -> 15로 인원 수 표시 공간 줄임
                          child: _buildVacationIndicator(date, vacations),
                        ),

                      // 인원 수 표시 (하단, 전체 모드가 아닐 때만)
                      if (_isSameMonth(date) && widget.roleFilter != 'all')
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
                                    ? Colors.white.withOpacity(0.2)
                                    : isAvailable
                                    ? Colors.green.shade100
                                    : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.4)
                                      : isAvailable
                                      ? Colors.green.shade300
                                      : Colors.red.shade300,
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
                                        ? Colors.white
                                        : isAvailable
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 기본 모드: 개선된 점 표시
                      Expanded(
                        flex: 3,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 날짜 숫자
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  date.day.toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: !_isSameMonth(date)
                                        ? Colors.grey.shade300
                                        : isSelected
                                        ? Colors.white
                                        : isToday
                                        ? Colors.blue.shade700
                                        : date.weekday == DateTime.sunday
                                        ? Colors.red.shade600
                                        : date.weekday == DateTime.saturday
                                        ? Colors.blue.shade600
                                        : Colors.grey.shade800,
                                  ),
                                ),
                              ),
                            ),
                            // 인원 수 표시 (전체 모드가 아닐 때만)
                            if (_isSameMonth(date) &&
                                widget.roleFilter != 'all')
                              Flexible(
                                child: Container(
                                  margin: const EdgeInsets.only(top: 0.5),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 1.5,
                                    vertical: 0.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.2)
                                        : isAvailable
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white.withOpacity(0.4)
                                          : isAvailable
                                          ? Colors.green.shade300
                                          : Colors.red.shade300,
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
                                            ? Colors.white
                                            : isAvailable
                                            ? Colors.green.shade700
                                            : Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // 휴가자 표시 영역
                      if (_isSameMonth(date) && vacations.isNotEmpty)
                        Expanded(
                          flex: 2,
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 1),
                            child: _buildVacationIndicator(date, vacations),
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
      // 확장 모드: 휴가자 이름들을 안전하게 표시
      return ClipRect(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: vacations.map((vacation) {
              return Container(
                width: double.infinity,
                height: 16.0,
                margin: const EdgeInsets.only(bottom: 1.5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 1.5,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(vacation.status),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: _getStatusColor(vacation.status).withOpacity(0.3),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 이름 표시 (가능한 많은 공간 사용)
                    Expanded(
                      child: Text(
                        vacation.userName,
                        style: const TextStyle(
                          fontSize: 9.0,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 필수휴무인 경우에만 매우 작은 아이콘 표시
                    if (vacation.type == VacationType.mandatory)
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.only(left: 1),
                        child: CustomPaint(
                          painter: StarPainter(
                            color: Colors.white.withOpacity(0.9),
                          ),
                          size: const Size(4, 4),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      );
    } else {
      // 기본 모드: 개선된 점 표시
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxHeight: 20),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 3,
            runSpacing: 2,
            children: [
              if (vacations.length <= 3)
                ...vacations.map((vacation) {
                  return Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getStatusColor(vacation.status),
                      boxShadow: [
                        BoxShadow(
                          color: _getStatusColor(
                            vacation.status,
                          ).withOpacity(0.4),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    // 필수휴무인 경우 작은 별표 표시
                    child: vacation.type == VacationType.mandatory
                        ? Center(
                            child: Container(
                              width: 4,
                              height: 4,
                              child: CustomPaint(
                                painter: StarPainter(color: Colors.white),
                                size: const Size(4, 4),
                              ),
                            ),
                          )
                        : null,
                  );
                })
              else ...[
                ...vacations.take(2).map((vacation) {
                  return Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getStatusColor(vacation.status),
                      boxShadow: [
                        BoxShadow(
                          color: _getStatusColor(
                            vacation.status,
                          ).withOpacity(0.4),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: vacation.type == VacationType.mandatory
                        ? Center(
                            child: Container(
                              width: 4,
                              height: 4,
                              child: CustomPaint(
                                painter: StarPainter(color: Colors.white),
                                size: const Size(4, 4),
                              ),
                            ),
                          )
                        : null,
                  );
                }),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade400.withOpacity(0.4),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    '+${vacations.length - 2}',
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
  }

  Color _getStatusColor(VacationStatus status) {
    switch (status) {
      case VacationStatus.approved:
        return Colors.green.shade500;
      case VacationStatus.rejected:
        return Colors.red.shade500;
      case VacationStatus.pending:
        return Colors.orange.shade500;
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
            color: Colors.grey.shade700,
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
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleFilterButton(String role, String label, IconData icon) {
    final isSelected = widget.roleFilter == role;

    return GestureDetector(
      onTap: () => widget.onRoleFilterChanged?.call(role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [Colors.blue.shade500, Colors.blue.shade600],
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.shade300.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.grey.shade200.withOpacity(0.5),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey.shade700,
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
      final angle = (i * 36) * (3.14159 / 180);
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
