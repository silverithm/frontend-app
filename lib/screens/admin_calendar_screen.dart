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
import 'admin_vacation_limits_setting_screen.dart';
import 'dart:math' as math;

class AdminCalendarScreen extends StatefulWidget {
  const AdminCalendarScreen({super.key});

  @override
  State<AdminCalendarScreen> createState() => _AdminCalendarScreenState();
}

class _AdminCalendarScreenState extends State<AdminCalendarScreen>
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
      AnalyticsService().logScreenView(screenName: 'admin_calendar_screen');
    });
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _filterAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('관리자 달력', style: TextStyle(color:Colors.white),),
        backgroundColor: AppSemanticColors.interactiveSecondaryDefault,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.event,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '전체 휴가 일정 관리',
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ADMIN',
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Consumer<VacationProvider>(
        builder: (context, vacationProvider, child) {
          return SingleChildScrollView(
            child: Column(
              children: [
                // 필터 섹션 (위로 이동)
                Container(
                  decoration: BoxDecoration(
                    color: AppSemanticColors.surfaceDefault,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('전체', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('요양보호사', 'CAREGIVER'),
                        const SizedBox(width: 8),
                        _buildFilterChip('사무실', 'OFFICE'),
                      ],
                    ),
                  ),
                ),
                
                // 달력 위젯 - 동적 높이 조정 (필터 제거)
                VacationCalendarWidget(
                  currentDate: _currentDate,
                  roleFilter: _roleFilter,
                  onDateChanged: (date) {
                    setState(() {
                      _currentDate = date;
                    });
                    final vacationProvider = context.read<VacationProvider>();
                    final authProvider = context.read<AuthProvider>();
                    final companyId = authProvider.currentUser?.company?.id ?? '1';
                    vacationProvider.loadCalendarData(date, companyId: companyId);
                  },
                  onDateSelected: (date) {
                    setState(() {
                      _selectedDate = date;
                    });
                    if (date != null) {
                      _showDateDetailsBottomSheet(date);
                    }
                  },
                  onRoleFilterChanged: null, // 필터 기능 제거
                ),
                
                // 하단 통계 섹션
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space4),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.surfaceDefault,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(
                        '이번달 총 휴가',
                        _getMonthlyTotal(vacationProvider).toString(),
                        Colors.blue.shade500,
                      ),
                      _buildStatItem(
                        '승인 대기',
                        _getMonthlyPending(vacationProvider).toString(),
                        Colors.amber.shade400,
                      ),
                      _buildStatItem(
                        '승인됨',
                        _getMonthlyApproved(vacationProvider).toString(),
                        Colors.green.shade400,
                      ),
                      _buildStatItem(
                        '거절됨',
                        _getMonthlyRejected(vacationProvider).toString(),
                        Colors.red.shade400,
                      ),
                    ],
                  ),
                ),
                
                // 하단 여백
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
      
      floatingActionButton: FloatingActionButton(
        onPressed: _showAdminActionDialog,
        backgroundColor: AppSemanticColors.interactiveSecondaryDefault,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAdminActionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              '관리자 기능',
              style: AppTypography.heading5,
            ),
            const SizedBox(height: 20),
            
            // 휴무 추가
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.event_available, color: Colors.blue.shade600),
              ),
              title: const Text('휴무 추가'),
              subtitle: const Text('직원의 휴무를 직접 추가합니다'),
              onTap: () {
                Navigator.pop(context);
                _showAddVacationDialog();
              },
            ),
            
            const Divider(),
            
            // 휴무 제한 설정
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.settings, color: Colors.orange.shade600),
              ),
              title: const Text('휴무 제한 설정'),
              subtitle: const Text('날짜별 최대 휴무 인원을 설정합니다'),
              onTap: () {
                Navigator.pop(context);
                _showVacationLimitDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddVacationDialog() {
    // TODO: 휴무 추가 다이얼로그 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('휴무 추가 기능은 개발 중입니다')),
    );
  }

  void _showVacationLimitDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AdminVacationLimitsSettingScreen(),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _roleFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppSemanticColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _roleFilter = value;
        });
        // 필터 변경 시 vacation provider의 roleFilter도 업데이트
        final vacationProvider = context.read<VacationProvider>();
        vacationProvider.setRoleFilter(value);
        // 달력 데이터는 다시 로드하지 않고, 휴무 제한 정보만 업데이트
        final authProvider = context.read<AuthProvider>();
        final companyId = authProvider.currentUser?.company?.id ?? '1';
        final startDate = DateTime(_currentDate.year, _currentDate.month, 1);
        final endDate = DateTime(_currentDate.year, _currentDate.month + 1, 0);
        vacationProvider.loadVacationLimits(startDate, endDate, companyId: companyId);
      },
      backgroundColor: AppSemanticColors.surfaceDefault,
      selectedColor: AppSemanticColors.interactiveSecondaryDefault,
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppSemanticColors.textSecondary,
          ),
        ),
      ],
    );
  }

  void _showDateDetailsBottomSheet(DateTime date) {
    final vacationProvider = context.read<VacationProvider>();
    final dayVacations = vacationProvider.getVacationsForDate(date);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // 핸들
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 헤더
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: AppSemanticColors.interactiveSecondaryDefault,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${date.year}년 ${date.month}월 ${date.day}일',
                    style: AppTypography.heading5,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.interactiveSecondaryDefault.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${dayVacations.length}건',
                      style: TextStyle(
                        color: AppSemanticColors.interactiveSecondaryDefault,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 휴가 목록
            Expanded(
              child: dayVacations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_available,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '이 날에는 휴가가 없습니다',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: dayVacations.length,
                      itemBuilder: (context, index) {
                        final vacation = dayVacations[index];
                        return _buildVacationItem(vacation);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVacationItem(VacationRequest vacation) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (vacation.status) {
      case VacationStatus.approved:
        statusColor = Colors.green.shade400.withOpacity(0.8); // 투명도가 있는 연한 초록색
        statusIcon = Icons.check_circle;
        statusText = '승인됨';
        break;
      case VacationStatus.rejected:
        statusColor = Colors.red.shade400.withOpacity(0.75); // 투명도가 있는 연한 빨간색
        statusIcon = Icons.cancel;  
        statusText = '거절됨';
        break;
      default:
        statusColor = Colors.amber.shade400.withOpacity(0.8); // 투명도가 있는 앰버색
        statusIcon = Icons.pending;
        statusText = '대기중';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.1),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        title: Text(
          vacation.userName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getVacationTypeText(vacation.type)),
            if (vacation.reason != null && vacation.reason!.isNotEmpty)
              Text(
                vacation.reason!,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // 헬퍼 메서드들
  int _getMonthlyTotal(VacationProvider provider) {
    final monthStart = DateTime(_currentDate.year, _currentDate.month, 1);
    final monthEnd = DateTime(_currentDate.year, _currentDate.month + 1, 0);
    
    print('[AdminCalendar] 통계 계산 - 필터: $_roleFilter');
    
    int total = 0;
    for (var date = monthStart; date.isBefore(monthEnd.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      // getVacationsForDate는 이미 현재 roleFilter가 적용된 결과를 반환함
      final dayVacations = provider.getVacationsForDate(date);
      total += dayVacations.length;
      
      if (dayVacations.isNotEmpty) {
        print('[AdminCalendar] ${date.day}일: ${dayVacations.length}건 (필터: $_roleFilter)');
      }
    }
    
    print('[AdminCalendar] 이번달 총 휴가: $total (필터: $_roleFilter)');
    return total;
  }

  int _getMonthlyPending(VacationProvider provider) {
    final monthStart = DateTime(_currentDate.year, _currentDate.month, 1);
    final monthEnd = DateTime(_currentDate.year, _currentDate.month + 1, 0);
    
    int pending = 0;
    for (var date = monthStart; date.isBefore(monthEnd.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      // getVacationsForDate는 이미 현재 roleFilter가 적용된 결과를 반환함
      final dayVacations = provider.getVacationsForDate(date);
      pending += dayVacations.where((v) => v.status == VacationStatus.pending).length;
    }
    
    print('[AdminCalendar] 승인 대기: $pending (필터: $_roleFilter)');
    return pending;
  }

  int _getMonthlyApproved(VacationProvider provider) {
    final monthStart = DateTime(_currentDate.year, _currentDate.month, 1);
    final monthEnd = DateTime(_currentDate.year, _currentDate.month + 1, 0);
    
    int approved = 0;
    for (var date = monthStart; date.isBefore(monthEnd.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      // getVacationsForDate는 이미 현재 roleFilter가 적용된 결과를 반환함
      final dayVacations = provider.getVacationsForDate(date);
      approved += dayVacations.where((v) => v.status == VacationStatus.approved).length;
    }
    
    print('[AdminCalendar] 승인됨: $approved (필터: $_roleFilter)');
    return approved;
  }

  int _getMonthlyRejected(VacationProvider provider) {
    final monthStart = DateTime(_currentDate.year, _currentDate.month, 1);
    final monthEnd = DateTime(_currentDate.year, _currentDate.month + 1, 0);
    
    int rejected = 0;
    for (var date = monthStart; date.isBefore(monthEnd.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      // getVacationsForDate는 이미 현재 roleFilter가 적용된 결과를 반환함
      final dayVacations = provider.getVacationsForDate(date);
      rejected += dayVacations.where((v) => v.status == VacationStatus.rejected).length;
    }
    
    print('[AdminCalendar] 거절됨: $rejected (필터: $_roleFilter)');
    return rejected;
  }

  String _getVacationTypeText(VacationType type) {
    switch (type) {
      case VacationType.mandatory:
        return '의무 휴가';
      case VacationType.personal:
        return '개인 휴가';
    }
  }
}