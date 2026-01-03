import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/admin_utils.dart';
import '../utils/constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class AdminVacationLimitScreen extends StatefulWidget {
  const AdminVacationLimitScreen({super.key});

  @override
  State<AdminVacationLimitScreen> createState() => _AdminVacationLimitScreenState();
}

class _AdminVacationLimitScreenState extends State<AdminVacationLimitScreen> {
  DateTime _selectedDate = DateTime.now();
  final Map<String, Map<String, int>> _vacationLimits = {};
  final Map<String, Map<String, TextEditingController>> _controllers = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _generateWeekDates();
    _loadVacationLimits();
  }

  @override
  void dispose() {
    // 컨트롤러 정리
    for (var dayControllers in _controllers.values) {
      for (var controller in dayControllers.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _generateWeekDates() {
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final dateKey = _formatDate(date);
      
      _vacationLimits[dateKey] = {
        'caregiver': 0,
        'office': 0,
      };
      
      _controllers[dateKey] = {
        'caregiver': TextEditingController(),
        'office': TextEditingController(),
      };
    }
  }

  void _loadVacationLimits() async {
    final authProvider = context.read<AuthProvider>();
    final adminProvider = context.read<AdminProvider>();
    final companyId = authProvider.currentUser?.company?.id ?? '';
    
    if (companyId.isNotEmpty) {
      final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      
      await adminProvider.loadVacationLimits(
        companyId,
        _formatDate(startOfWeek),
        _formatDate(endOfWeek),
      );
      
      // 로드된 데이터를 UI에 반영
      for (var dateKey in _vacationLimits.keys) {
        final caregiverLimit = adminProvider.vacationLimits['${dateKey}_caregiver'];
        final officeLimit = adminProvider.vacationLimits['${dateKey}_office'];
        
        if (caregiverLimit != null) {
          _vacationLimits[dateKey]!['caregiver'] = caregiverLimit.maxPeople;
          _controllers[dateKey]!['caregiver']!.text = caregiverLimit.maxPeople.toString();
        }
        
        if (officeLimit != null) {
          _vacationLimits[dateKey]!['office'] = officeLimit.maxPeople;
          _controllers[dateKey]!['office']!.text = officeLimit.maxPeople.toString();
        }
      }
      
      setState(() {});
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDisplayDate(DateTime date) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${date.month}/${date.day} (${weekdays[date.weekday - 1]})';
  }

  void _changeWeek(int direction) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: 7 * direction));
      
      // 기존 컨트롤러 정리
      for (var dayControllers in _controllers.values) {
        for (var controller in dayControllers.values) {
          controller.dispose();
        }
      }
      
      _vacationLimits.clear();
      _controllers.clear();
      _generateWeekDates();
      _loadVacationLimits();
    });
  }

  void _saveVacationLimits() async {
    if (_isSaving) return;
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      final authProvider = context.read<AuthProvider>();
      final adminProvider = context.read<AdminProvider>();
      final companyId = authProvider.currentUser?.company?.id ?? '';
      
      if (companyId.isEmpty) {
        throw Exception('회사 정보를 찾을 수 없습니다.');
      }
      
      List<VacationLimit> limits = [];
      
      for (var dateKey in _vacationLimits.keys) {
        final caregiverText = _controllers[dateKey]!['caregiver']!.text;
        final officeText = _controllers[dateKey]!['office']!.text;
        
        final caregiverLimit = int.tryParse(caregiverText) ?? 0;
        final officeLimit = int.tryParse(officeText) ?? 0;
        
        limits.add(VacationLimit(
          date: dateKey,
          maxPeople: caregiverLimit,
          role: 'caregiver',
        ));
        
        limits.add(VacationLimit(
          date: dateKey,
          maxPeople: officeLimit,
          role: 'office',
        ));
      }
      
      final success = await adminProvider.saveVacationLimits(companyId, limits);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('휴무 한도가 저장되었습니다.'),
            backgroundColor: AppSemanticColors.statusSuccessIcon,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장에 실패했습니다: ${e.toString()}'),
            backgroundColor: AppSemanticColors.statusErrorIcon,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!AdminUtils.canManageVacations(authProvider.currentUser)) {
          return _buildNoPermissionView();
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              '휴무 한도 설정',
              style: AppTypography.heading6.copyWith(
                color: AppSemanticColors.textInverse,
              ),
            ),
            backgroundColor: AppColors.purple600,
            foregroundColor: AppSemanticColors.textInverse,
            elevation: 0,
            actions: [
              IconButton(
                icon: _isSaving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppSemanticColors.textInverse),
                        ),
                      )
                    : const Icon(Icons.save),
                onPressed: _isSaving ? null : _saveVacationLimits,
              ),
            ],
          ),
          body: Column(
            children: [
              // 주간 네비게이션
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.purple600,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => _changeWeek(-1),
                      icon: Icon(Icons.chevron_left, color: AppSemanticColors.textInverse),
                    ),
                    Text(
                      '${_formatDisplayDate(_selectedDate.subtract(Duration(days: _selectedDate.weekday - 1)))} ~ ${_formatDisplayDate(_selectedDate.add(Duration(days: 7 - _selectedDate.weekday)))}',
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppSemanticColors.textInverse,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _changeWeek(1),
                      icon: Icon(Icons.chevron_right, color: AppSemanticColors.textInverse),
                    ),
                  ],
                ),
              ),

              // 안내 텍스트
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppSemanticColors.statusInfoBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppSemanticColors.statusInfoBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppSemanticColors.statusInfoIcon, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '각 날짜별로 최대 휴무 가능 인원을 설정하세요.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppSemanticColors.statusInfoText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 날짜별 카드 리스트
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _vacationLimits.keys.length,
                  itemBuilder: (context, index) {
                    final dateKey = _vacationLimits.keys.elementAt(index);
                    final date = DateTime.parse(dateKey);
                    return _buildDateCard(date, dateKey);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoPermissionView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('휴무 한도 설정'),
        backgroundColor: AppSemanticColors.statusErrorIcon,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppSemanticColors.statusErrorIcon,
            ),
            const SizedBox(height: 16),
            Text(
              '관리자 권한이 필요합니다',
              style: AppTypography.heading5.copyWith(
                color: AppSemanticColors.statusErrorIcon,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '휴무 한도 설정 기능을 사용하려면 관리자 권한이 필요합니다.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateCard(DateTime date, String dateKey) {
    final isToday = date.day == DateTime.now().day &&
                   date.month == DateTime.now().month &&
                   date.year == DateTime.now().year;
    final isWeekend = date.weekday >= 6;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isToday ? Border.all(color: AppColors.purple600, width: 2) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 날짜 헤더
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppColors.purple600
                          : isWeekend
                              ? AppSemanticColors.statusErrorBackground
                              : AppSemanticColors.statusInfoBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _formatDisplayDate(date),
                      style: AppTypography.labelMedium.copyWith(
                        color: isToday
                            ? AppSemanticColors.textInverse
                            : isWeekend
                                ? AppSemanticColors.statusErrorText
                                : AppSemanticColors.statusInfoText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.statusWarningBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '오늘',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppSemanticColors.statusWarningText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              // 요양보호사 한도 설정
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.favorite,
                              color: AppColors.red500,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '요양보호사',
                              style: AppTypography.labelMedium.copyWith(
                                color: AppSemanticColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _controllers[dateKey]!['caregiver']!,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '0',
                            suffix: const Text('명'),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (value) {
                            final limit = int.tryParse(value) ?? 0;
                            _vacationLimits[dateKey]!['caregiver'] = limit;
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // 사무실 한도 설정
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.business,
                              color: AppSemanticColors.statusInfoIcon,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '사무실',
                              style: AppTypography.labelMedium.copyWith(
                                color: AppSemanticColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _controllers[dateKey]!['office']!,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '0',
                            suffix: const Text('명'),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (value) {
                            final limit = int.tryParse(value) ?? 0;
                            _vacationLimits[dateKey]!['office'] = limit;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}