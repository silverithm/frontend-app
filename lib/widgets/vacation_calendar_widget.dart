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

  const VacationCalendarWidget({
    super.key,
    required this.currentDate,
    required this.onDateChanged,
    required this.onDateSelected,
    this.roleFilter = 'all',
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

                // 달력 그리드 - 고정 높이로 계산
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Builder(
                    builder: (context) {
                      final screenWidth = MediaQuery.of(context).size.width;
                      final horizontalPadding = 32.0; // 좌우 패딩 (16*2)
                      final spacing = 6.0; // 그리드 간격 증가 (4 -> 6)
                      final cellWidth =
                          (screenWidth - horizontalPadding - (spacing * 6)) / 7;

                      // 확장 모드일 때 최대 휴가자 수 계산
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

                      // 기본 모드: 화면에 꽉 차게, 확장 모드: 제한된 높이 + 스크롤
                      final dateTextHeight = _isExpanded
                          ? 22.0
                          : 28.0; // 기본 모드에서 더 크게
                      final maxGridHeight = _isExpanded
                          ? MediaQuery.of(context).size.height *
                                0.6 // 확장 모드: 60%
                          : MediaQuery.of(context).size.height *
                                0.45; // 기본 모드: 45%로 축소

                      if (_isExpanded) {
                        // 확장 모드: 스크롤 가능한 고정 높이
                        final maxCellHeight = 80.0; // 확장 모드 최대 셀 높이
                        final gridHeight = math.min(
                          maxCellHeight * rows + spacing * (rows - 1),
                          maxGridHeight,
                        );

                        return Container(
                          height: gridHeight,
                          child: SingleChildScrollView(
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 7,
                                    childAspectRatio: cellWidth / maxCellHeight,
                                    crossAxisSpacing: spacing,
                                    mainAxisSpacing: spacing,
                                  ),
                              itemCount: days.length,
                              itemBuilder: (context, index) =>
                                  _buildCalendarCell(
                                    days[index],
                                    vacationProvider,
                                    dateTextHeight,
                                    maxCellHeight,
                                  ),
                            ),
                          ),
                        );
                      } else {
                        // 기본 모드: 적당한 크기로 가운데 배치
                        final actualGridHeight =
                            maxGridHeight * 0.8; // 전체 높이의 80%만 사용
                        final cellHeight =
                            (actualGridHeight - spacing * (rows - 1)) / rows;

                        return Container(
                          height: maxGridHeight, // 전체 높이는 유지
                          child: Center(
                            // 가운데 정렬
                            child: Container(
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
                                itemBuilder: (context, index) =>
                                    _buildCalendarCell(
                                      days[index],
                                      vacationProvider,
                                      dateTextHeight,
                                      cellHeight,
                                    ),
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),

                // 하단 여백
                const SizedBox(height: 8),
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

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blue.shade600
            : isToday
            ? Colors.blue.shade50
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isToday && !isSelected
            ? Border.all(color: Colors.blue.shade300, width: 1.5)
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 날짜 숫자 - 고정 높이
                SizedBox(
                  height: dateTextHeight,
                  child: Center(
                    child: Text(
                      date.day.toString(),
                      style: TextStyle(
                        fontSize: _isExpanded ? 13 : 16,
                        fontWeight: FontWeight.w600,
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

                // 휴가자 표시 영역 - 남은 공간 사용
                if (_isSameMonth(date) && vacations.isNotEmpty)
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 2),
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
                height: 13.0,
                margin: const EdgeInsets.only(bottom: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
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
                child: Center(
                  child: Text(
                    vacation.userName.length > 4
                        ? '${vacation.userName.substring(0, 3)}..'
                        : vacation.userName,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
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
}
