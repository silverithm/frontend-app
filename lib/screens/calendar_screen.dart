import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vacation_provider.dart';
import '../providers/auth_provider.dart';
import '../models/vacation_request.dart';
import '../widgets/vacation_calendar_widget.dart';
import '../widgets/vacation_request_dialog.dart';
import '../services/analytics_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vacationProvider = context.read<VacationProvider>();
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.company?.id ?? '1';
      vacationProvider.loadCalendarData(_currentDate, companyId: companyId);
      _fabAnimationController.forward();

      // Analytics 화면 조회 이벤트
      AnalyticsService().logScreenView(screenName: 'calendar_screen');
      AnalyticsService().logCalendarView(
        viewType: 'month',
        date: _currentDate.toIso8601String().split('T')[0],
      );
    });
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _filterAnimationController.dispose();
    super.dispose();
  }

  void _showVacationRequestDialog() {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('날짜를 먼저 선택해주세요'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
      backgroundColor: const Color(0xFFEFF6FF), // blue.50 - 파란계열 배경
      body: CustomScrollView(
        slivers: [
          // 파란계열 그라데이션 앱바
          SliverAppBar(
            expandedHeight: 64.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            centerTitle: true,
            title: const Text(
              '휴무 캘린더',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: 20,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(1, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2563EB), // blue.600
                    Color(0xFF3B82F6), // blue.500
                    Color(0xFF60A5FA), // blue.400
                  ],
                ),
              ),
            ),
          ),

          // 달력 위젯 - 디자인 시스템 스타일
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(24), // spacing.6
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12), // xl
                border: Border.all(
                  color: const Color(0xFFE5E7EB), // gray.200
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000), // shadows.sm
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
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
                  final companyId =
                      authProvider.currentUser?.company?.id ?? '1';
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
                  final companyId =
                      authProvider.currentUser?.company?.id ?? '1';
                  vacationProvider.loadCalendarData(
                    _currentDate,
                    companyId: companyId,
                  );
                },
              ),
            ),
          ),

          // 선택된 날짜 정보
          if (_selectedDate != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, AppSemanticColors.backgroundSecondary],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
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
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppSemanticColors.interactivePrimaryDefault.withValues(alpha: 0.8),
                                          AppSemanticColors.interactivePrimaryDefault,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppSemanticColors.interactivePrimaryDefault.withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.calendar_today,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _formatSelectedDate(_selectedDate!),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
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
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Consumer<VacationProvider>(
                          builder: (context, vacationProvider, child) {
                            final vacations = vacationProvider
                                .getVacationsForDate(_selectedDate!);

                            if (vacations.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.event_available,
                                      color: Colors.grey.shade400,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      '이 날짜에는 휴무 신청이 없습니다.',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
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
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppSemanticColors.interactivePrimaryDefault.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '휴무자 ${vacations.length}명',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppSemanticColors.interactivePrimaryDefault,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...vacations.map(
                                  (vacation) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _getStatusTextColor(
                                          vacation.status,
                                        ).withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: _getStatusTextColor(
                                              vacation.status,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
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
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              // 휴무 유형 도형
                                              _buildVacationTypeShape(vacation),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  vacation.displayName,
                                                  style: const TextStyle(
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusTextColor(
                                              vacation.status,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            vacation.statusText,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
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
            ),


          // 하단 통계 섹션
          SliverToBoxAdapter(
            child: Consumer<VacationProvider>(
              builder: (context, vacationProvider, child) {
                return Container(
                  margin: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            '${_currentDate.month}월 총 휴가',
                            _getMonthlyTotal(vacationProvider).toString(),
                            const Color(0xFF3B82F6), // blue.500
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatItem(
                            '승인 대기',
                            _getMonthlyPending(vacationProvider).toString(),
                            const Color(0xFFF59E0B), // amber.500
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatItem(
                            '승인됨',
                            _getMonthlyApproved(vacationProvider).toString(),
                            const Color(0xFF10B981), // emerald.500
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatItem(
                            '거절됨',
                            _getMonthlyRejected(vacationProvider).toString(),
                            const Color(0xFFEF4444), // red.500
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 하단 여백 - 플로팅 액션 버튼이 잘리지 않도록 충분한 여백 확보
          const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimationController,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppSemanticColors.interactivePrimaryDefault.withValues(alpha: 0.8),
                AppSemanticColors.interactivePrimaryDefault,
                AppSemanticColors.interactivePrimaryDefault.withValues(alpha: 1.2, red: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppSemanticColors.interactivePrimaryDefault.withValues(alpha: 0.4),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: _showVacationRequestDialog,
            backgroundColor: Colors.transparent,
            elevation: 0,
            icon: const Icon(
              Icons.add_circle_outline,
              color: Colors.white,
              size: 24,
            ),
            label: const Text(
              '휴무 추가',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusBgColor(VacationStatus status) {
    switch (status) {
      case VacationStatus.approved:
        return const Color(0xFFDCFCE7); // green.100
      case VacationStatus.rejected:
        return const Color(0xFFFEE2E2); // red.100
      case VacationStatus.pending:
        return const Color(0xFFFEF3C7); // yellow.100
    }
  }

  Color _getStatusTextColor(VacationStatus status) {
    switch (status) {
      case VacationStatus.approved:
        return const Color(0xFF15803D); // green.700
      case VacationStatus.rejected:
        return const Color(0xFFB91C1C); // red.700
      case VacationStatus.pending:
        return const Color(0xFFA16207); // yellow.700
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
      return Container(
        width: 16,
        height: 16,
        child: CustomPaint(
          painter: StarPainter(color: Colors.yellow.shade600),
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
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF6B7280), // gray.500
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 14,
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
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF3B82F6), // blue.500
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE5E7EB),
        width: 1,
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280), // gray.500
            fontSize: 12,
            fontWeight: FontWeight.w500,
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
