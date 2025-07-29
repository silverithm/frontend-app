import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/admin_utils.dart';
import '../utils/constants.dart';

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
          const SnackBar(
            content: Text('휴가 한도가 저장되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장에 실패했습니다: ${e.toString()}'),
            backgroundColor: Colors.red,
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
            title: const Text(
              '휴가 한도 설정',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.purple.shade600,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: _isSaving 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                  color: Colors.purple.shade600,
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
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                    ),
                    Text(
                      '${_formatDisplayDate(_selectedDate.subtract(Duration(days: _selectedDate.weekday - 1)))} ~ ${_formatDisplayDate(_selectedDate.add(Duration(days: 7 - _selectedDate.weekday)))}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _changeWeek(1),
                      icon: const Icon(Icons.chevron_right, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              // 안내 텍스트
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
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
        title: const Text('휴가 한도 설정'),
        backgroundColor: Colors.red.shade600,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '관리자 권한이 필요합니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '휴가 한도 설정 기능을 사용하려면 관리자 권한이 필요합니다.',
              style: TextStyle(
                color: Colors.grey.shade600,
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
          border: isToday ? Border.all(color: Colors.purple.shade600, width: 2) : null,
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
                          ? Colors.purple.shade600
                          : isWeekend 
                              ? Colors.red.shade100
                              : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _formatDisplayDate(date),
                      style: TextStyle(
                        color: isToday 
                            ? Colors.white
                            : isWeekend 
                                ? Colors.red.shade800
                                : Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '오늘',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 12,
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
                              color: Colors.pink.shade600,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '요양보호사',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
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
                              color: Colors.blue.shade600,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '사무실',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
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