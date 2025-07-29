import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/vacation_limit.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';

class AdminVacationLimitsSettingScreen extends StatefulWidget {
  const AdminVacationLimitsSettingScreen({super.key});

  @override
  State<AdminVacationLimitsSettingScreen> createState() => 
      _AdminVacationLimitsSettingScreenState();
}

class _AdminVacationLimitsSettingScreenState 
    extends State<AdminVacationLimitsSettingScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedRole = 'CAREGIVER'; // 'CAREGIVER', 'OFFICE', 'all'
  Map<String, Map<String, VacationLimit>> _limitsData = {}; // date -> role -> limit
  bool _isLoading = false;
  bool _isSaving = false;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _initializeControllersForCurrentMonth();
    _loadVacationLimits();
  }

  void _initializeControllersForCurrentMonth() {
    final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    
    for (var date = firstDay; !date.isAfter(lastDay); date = date.add(const Duration(days: 1))) {
      final dateKey = _formatDate(date);
      
      // CAREGIVER 컨트롤러 - 기본값 3으로 설정 (API에서 로드될 때까지)
      final caregiverKey = '${dateKey}_CAREGIVER';
      _controllers[caregiverKey] = TextEditingController(text: '3');
      
      // OFFICE 컨트롤러 - 기본값 3으로 설정 (API에서 로드될 때까지)
      final officeKey = '${dateKey}_OFFICE';
      _controllers[officeKey] = TextEditingController(text: '3');
    }
  }

  @override
  void dispose() {
    // TextEditingController들 정리
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadVacationLimits() async {
    setState(() => _isLoading = true);
    
    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.company?.id?.toString() ?? '';
      
      // 선택된 달의 첫째 날과 마지막 날 계산
      final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
      
      final result = await ApiService().getVacationLimits(
        start: _formatDate(firstDay),
        end: _formatDate(lastDay),
        companyId: companyId,
      );
      
      print('[VacationLimits] API 응답: $result');
      
      if (result['limits'] != null) {
        final limitsData = <String, Map<String, VacationLimit>>{};
        final limitsList = result['limits'] as List<dynamic>;
        
        // 응답 데이터 파싱 - 배열 형태의 데이터를 날짜별로 그룹화
        for (final limitItem in limitsList) {
          final limitMap = limitItem as Map<String, dynamic>;
          final date = limitMap['date'] as String;
          final role = (limitMap['role'] as String).toUpperCase();
          
          if (limitsData[date] == null) {
            limitsData[date] = {};
          }
          
          limitsData[date]![role] = VacationLimit.fromJson({
            'id': limitMap['id'],
            'date': date,
            'role': role,
            'maxPeople': limitMap['maxPeople'],
          });
        }
        
        setState(() {
          _limitsData = limitsData;
          _initializeControllers();
        });
      }
    } catch (e) {
      print('[VacationLimits] 로드 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('휴무 제한 데이터 로드 실패: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _initializeControllers() {
    // 기존 컨트롤러들 정리
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    
    // 새 컨트롤러들 생성
    final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    
    for (var date = firstDay; !date.isAfter(lastDay); date = date.add(const Duration(days: 1))) {
      final dateKey = _formatDate(date);
      
      // CAREGIVER 컨트롤러
      final caregiverKey = '${dateKey}_CAREGIVER';
      final caregiverLimit = _limitsData[dateKey]?['CAREGIVER']?.maxPeople ?? 3;
      _controllers[caregiverKey] = TextEditingController(text: caregiverLimit.toString());
      
      // OFFICE 컨트롤러
      final officeKey = '${dateKey}_OFFICE';
      final officeLimit = _limitsData[dateKey]?['OFFICE']?.maxPeople ?? 3;
      _controllers[officeKey] = TextEditingController(text: officeLimit.toString());
    }
  }

  Future<void> _saveVacationLimits() async {
    setState(() => _isSaving = true);
    
    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.company?.id?.toString() ?? '';
      
      // 변경된 데이터 수집
      final limitsToSave = <Map<String, dynamic>>[];
      
      for (final entry in _controllers.entries) {
        final parts = entry.key.split('_');
        if (parts.length != 2) continue;
        
        final date = parts[0];
        final role = parts[1];
        final maxPeople = int.tryParse(entry.value.text) ?? 0;
        
        limitsToSave.add({
          'date': date,
          'maxPeople': maxPeople,
          'role': role,
        });
      }
      
      print('[VacationLimits] 저장할 데이터: $limitsToSave');
      
      final result = await ApiService().saveVacationLimits(
        companyId: companyId,
        limits: limitsToSave,
      );
      
      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('휴무 제한이 성공적으로 저장되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
        }
        // 데이터 다시 로드
        await _loadVacationLimits();
      } else {
        throw Exception(result['message'] ?? '저장 실패');
      }
    } catch (e) {
      print('[VacationLimits] 저장 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('휴무 제한 저장 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatYearMonth(DateTime date) {
    return '${date.year}년 ${date.month}월';
  }

  void _previousMonth() {
    // 기존 컨트롤러 정리
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
    });
    _initializeControllersForCurrentMonth();
    _loadVacationLimits();
  }

  void _nextMonth() {
    // 기존 컨트롤러 정리
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
    });
    _initializeControllersForCurrentMonth();
    _loadVacationLimits();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('휴무 제한 설정', style: TextStyle(color: Colors.white)),
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
                    Icons.settings,
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
                        '날짜별 최대 휴무 인원 설정',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 월 선택 헤더
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _previousMonth,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        _formatYearMonth(_selectedDate),
                        style: AppTypography.heading5,
                      ),
                      IconButton(
                        onPressed: _nextMonth,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),

                // 역할 필터 탭
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildRoleTab('요양보호사', 'CAREGIVER')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildRoleTab('사무실', 'OFFICE')),
                    ],
                  ),
                ),

                // 제한 설정 테이블
                Expanded(
                  child: _buildLimitsTable(),
                ),

                // 저장 버튼을 아래로 이동
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveVacationLimits,
                        icon: _isSaving 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.save, color: Colors.white),
                        label: Text(
                          _isSaving ? '저장 중...' : '휴무 제한 저장하기',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppSemanticColors.interactiveSecondaryDefault,
                          disabledBackgroundColor: Colors.grey.shade400,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRoleTab(String label, String role) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppSemanticColors.interactiveSecondaryDefault : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? AppSemanticColors.interactiveSecondaryDefault 
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLimitsTable() {
    final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    final days = <DateTime>[];
    
    for (var date = firstDay; !date.isAfter(lastDay); date = date.add(const Duration(days: 1))) {
      days.add(date);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 안내 텍스트
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '각 날짜별로 최대 휴무 가능 인원을 설정하세요.',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 날짜별 카드 리스트
          ...days.map((date) => _buildDateCard(date)).toList(),
        ],
      ),
    );
  }

  Widget _buildDateCard(DateTime date) {
    final dateKey = _formatDate(date);
    final isSunday = date.weekday == DateTime.sunday;
    final isSaturday = date.weekday == DateTime.saturday;
    final isWeekend = isSunday || isSaturday;
    final weekdayNames = ['', '월', '화', '수', '목', '금', '토', '일'];
    final weekdayName = weekdayNames[date.weekday];
    
    print('[_buildDateCard] dateKey: $dateKey, selectedRole: $_selectedRole');
    print('[_buildDateCard] controllers: ${_controllers.keys.toList()}');
    
    // 색상 결정
    Color borderColor;
    Color headerColor;
    Color headerTextColor;
    Color weekdayBgColor;
    Color weekdayTextColor;
    
    if (isSunday) {
      // 일요일 - 빨간색
      borderColor = Colors.red.shade200;
      headerColor = Colors.red.shade100;
      headerTextColor = Colors.red.shade700;
      weekdayBgColor = Colors.red.shade50;
      weekdayTextColor = Colors.red.shade600;
    } else if (isSaturday) {
      // 토요일 - 파란색
      borderColor = Colors.blue.shade200;
      headerColor = Colors.blue.shade100;
      headerTextColor = Colors.blue.shade700;
      weekdayBgColor = Colors.blue.shade50;
      weekdayTextColor = Colors.blue.shade600;
    } else {
      // 평일 - 회색
      borderColor = Colors.grey.shade200;
      headerColor = Colors.grey.shade100;
      headerTextColor = Colors.grey.shade800;
      weekdayBgColor = Colors.grey.shade50;
      weekdayTextColor = Colors.grey.shade600;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: isWeekend ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
                    color: headerColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${date.month}월 ${date.day}일',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: headerTextColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: weekdayBgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$weekdayName요일',
                    style: TextStyle(
                      fontSize: 12,
                      color: weekdayTextColor,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 인원 수 설정
            if (_selectedRole == 'CAREGIVER') ...[
              // 요양보호사 모드
              _buildLimitInputCard('요양보호사', '${dateKey}_CAREGIVER', Icons.favorite),
            ] else if (_selectedRole == 'OFFICE') ...[
              // 사무실 모드
              _buildLimitInputCard('사무실', '${dateKey}_OFFICE', Icons.business),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLimitInputCard(String title, String key, IconData icon) {
    final controller = _controllers[key];
    if (controller == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                '최대',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                height: 36,
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppSemanticColors.interactiveSecondaryDefault, width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(0),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    // 빈 문자열이면 0으로 설정
                    if (value.isEmpty) {
                      return;
                    }
                    
                    // 숫자만 허용하고 음수 방지
                    final number = int.tryParse(value);
                    if (number == null || number < 0) {
                      // 이전 값을 유지하되, 잘못된 입력은 제거
                      final validText = value.replaceAll(RegExp(r'[^0-9]'), '');
                      if (validText.isNotEmpty) {
                        controller.value = TextEditingValue(
                          text: validText,
                          selection: TextSelection.fromPosition(
                            TextPosition(offset: validText.length),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '명',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}