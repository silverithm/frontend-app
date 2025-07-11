import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vacation_provider.dart';
import '../providers/auth_provider.dart';
import '../models/vacation_request.dart';
import '../widgets/vacation_calendar_widget.dart';
import '../widgets/vacation_request_dialog.dart';
import '../services/analytics_service.dart';
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
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // 현대적인 앱바 - 다른 화면들과 통일된 스타일
          SliverAppBar(
            expandedHeight: 60.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            centerTitle: true,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade600,
                    Colors.blue.shade400,
                    Colors.cyan.shade300,
                  ],
                ),
              ),
              child: FlexibleSpaceBar(
                title: const Text(
                  '휴무 캘린더',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        offset: Offset(1, 1),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
                centerTitle: true,
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue.shade600,
                        Colors.blue.shade400,
                        Colors.cyan.shade300,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 달력 위젯
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
                      colors: [Colors.white, Colors.blue.shade50],
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
                                          Colors.blue.shade400,
                                          Colors.blue.shade600,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.shade300
                                              .withOpacity(0.4),
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
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '휴무자 ${vacations.length}명',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
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
                                      color: _getStatusColor(vacation.status),
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

          // 하단 여백
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
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
                Colors.blue.shade400,
                Colors.blue.shade600,
                Colors.blue.shade800,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade400.withOpacity(0.4),
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

  Color _getStatusColor(VacationStatus status) {
    // 모든 상태에 대해 흰색 배경으로 통일
    return Colors.white;
  }

  Color _getStatusTextColor(VacationStatus status) {
    switch (status) {
      case VacationStatus.approved:
        return Colors.green.shade700;
      case VacationStatus.rejected:
        return Colors.red.shade700;
      case VacationStatus.pending:
        return Colors.orange.shade700;
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
