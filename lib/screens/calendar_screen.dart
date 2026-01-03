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
      duration: AppTransitions.slow,
      vsync: this,
    );
    _filterAnimationController = AnimationController(
      duration: AppTransitions.normal,
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
      body: CustomScrollView(
        slivers: [
          // 파란계열 그라데이션 앱바
          SliverAppBar(
            expandedHeight: 64.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.transparent,
            centerTitle: true,
            title: Text(
              '휴무 캘린더',
              style: AppTypography.heading5.copyWith(
                color: AppSemanticColors.textInverse,
                shadows: [
                  Shadow(
                    color: AppColors.black.withValues(alpha: 0.26),
                    offset: const Offset(1, 1),
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
                    AppSemanticColors.interactivePrimaryActive,
                    AppSemanticColors.interactivePrimaryDefault,
                    AppSemanticColors.interactivePrimaryHover,
                  ],
                ),
              ),
            ),
          ),

          // 달력 위젯 - 디자인 시스템 스타일
          SliverToBoxAdapter(
            child: Container(
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
                    offset: Offset(0, 1),
                  ),
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.06),
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
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space4,
                  AppSpacing.space2,
                  AppSpacing.space4,
                  AppSpacing.space4,
                ),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppSemanticColors.surfaceDefault,
                        AppSemanticColors.backgroundSecondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withValues(alpha: 0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
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
                                      gradient: LinearGradient(
                                        colors: [
                                          AppSemanticColors
                                              .interactivePrimaryDefault
                                              .withValues(alpha: 0.8),
                                          AppSemanticColors.interactivePrimaryDefault,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppBorderRadius.xl2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppSemanticColors
                                              .interactivePrimaryDefault
                                              .withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.calendar_today,
                                      color: AppSemanticColors.textInverse,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.space3),
                                  Expanded(
                                    child: Text(
                                      _formatSelectedDate(_selectedDate!),
                                      style: AppTypography.heading6.copyWith(
                                        fontWeight:
                                            AppTypography.fontWeightBold,
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
                                padding: const EdgeInsets.all(
                                  AppSpacing.space2,
                                ),
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
                              return Container(
                                padding: const EdgeInsets.all(
                                  AppSpacing.space5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppSemanticColors.backgroundSecondary,
                                  borderRadius: BorderRadius.circular(
                                    AppBorderRadius.xl2,
                                  ),
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
                                        ).withValues(alpha:0.2),
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
                                            ).withValues(alpha:0.1),
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
                                              // 휴무 유형 도형
                                              _buildVacationTypeShape(vacation),
                                              const SizedBox(
                                                width: AppSpacing.space2,
                                              ),
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
                                            color: _getStatusTextColor(
                                              vacation.status,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              AppBorderRadius.lg,
                                            ),
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
            ),


          // 하단 통계 섹션
          SliverToBoxAdapter(
            child: Consumer<VacationProvider>(
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
                        offset: Offset(0, 1),
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
          ),

          // 하단 여백 - 플로팅 액션 버튼이 잘리지 않도록 충분한 여백 확보
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: AppSpacing.space20 + AppSpacing.space6,
            ),
          ),
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
                AppSemanticColors.interactivePrimaryDefault
                    .withValues(alpha: 0.8),
                AppSemanticColors.interactivePrimaryDefault,
                AppSemanticColors.interactivePrimaryDefault
                    .withValues(alpha: 0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
            boxShadow: [
              BoxShadow(
                color: AppSemanticColors.interactivePrimaryDefault
                    .withValues(alpha: 0.4),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
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
              style: AppTypography.buttonLarge.copyWith(
                color: AppSemanticColors.textInverse,
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
      return Container(
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
            color: color.withValues(alpha:0.1),
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
