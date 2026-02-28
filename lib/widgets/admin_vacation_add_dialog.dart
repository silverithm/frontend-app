import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

class AdminVacationAddDialog extends StatefulWidget {
  final DateTime? selectedDate;
  
  const AdminVacationAddDialog({
    super.key,
    this.selectedDate,
  });

  @override
  State<AdminVacationAddDialog> createState() => _AdminVacationAddDialogState();
}

class _AdminVacationAddDialogState extends State<AdminVacationAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  
  DateTime? _selectedDate;
  String _selectedDuration = 'FULL_DAY';
  String _selectedType = 'personal'; // 'personal' = 일반, 'mandatory' = 필수
  int? _selectedMemberId;
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    _loadMembers();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    
    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.company?.id?.toString() ?? '';
      
      print('[AdminVacationAddDialog] 회사 회원 조회 시작 - companyId: $companyId');
      
      final result = await ApiService().getCompanyMembers(companyId: companyId);
      
      print('[AdminVacationAddDialog] API 응답: $result');
      
      if (result['members'] != null) {
        // 활성화된 회원만 필터링 (active 상태)
        final allMembers = List<Map<String, dynamic>>.from(result['members']);
        final activeMembers = allMembers.where((member) {
          final status = member['status']?.toString().toLowerCase();
          // active, approved 둘 다 허용
          return status == 'active' || status == 'approved';
        }).toList();
        
        setState(() {
          _members = activeMembers;
        });
        print('[AdminVacationAddDialog] 전체 회원 수: ${allMembers.length}');
        print('[AdminVacationAddDialog] 활성 회원 수: ${_members.length}');
      }
    } catch (e) {
      print('[AdminVacationAddDialog] 직원 목록 로드 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('직원 목록을 불러올 수 없습니다: ${e.toString()}'),
            backgroundColor: AppSemanticColors.statusErrorIcon,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)), // 1년 전부터 선택 가능
      lastDate: DateTime.now().add(const Duration(days: 365)), // 1년 후까지 선택 가능
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppSemanticColors.interactivePrimaryDefault,
              onPrimary: AppSemanticColors.textInverse,
              surface: AppSemanticColors.surfaceDefault,
              onSurface: AppSemanticColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitVacation() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('휴무 날짜를 선택해주세요'),
          backgroundColor: AppSemanticColors.statusErrorIcon,
        ),
      );
      return;
    }
    if (_selectedMemberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('직원을 선택해주세요'),
          backgroundColor: AppSemanticColors.statusErrorIcon,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.company?.id?.toString() ?? '';
      
      final result = await ApiService().createVacationByAdmin(
        companyId: companyId,
        memberId: _selectedMemberId!,
        date: '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
        duration: _selectedDuration,
        reason: _reasonController.text.isNotEmpty ? _reasonController.text : null,
        type: _selectedType,
      );

      if (mounted) {
        if (result['success'] == true || result['data'] != null) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('휴무가 성공적으로 등록되었습니다'),
              backgroundColor: AppSemanticColors.statusSuccessIcon,
            ),
          );
        } else {
          throw Exception(result['error'] ?? '휴무 등록 실패');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('휴무 등록 실패: ${e.toString()}'),
            backgroundColor: AppSemanticColors.statusErrorIcon,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 키보드 숨기기
        FocusScope.of(context).unfocus();
      },
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5, vertical: AppSpacing.space6),
        child: GestureDetector(
          onTap: () {}, // Dialog 내부 클릭 시 이벤트 전파 차단
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(maxWidth: 500, maxHeight: MediaQuery.of(context).size.height * 0.85),
            padding: const EdgeInsets.all(AppSpacing.space6),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                children: [
                  Icon(
                    Icons.event_note,
                    color: AppSemanticColors.textSecondary,
                    size: 28,
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Text(
                    '휴무 추가',
                    style: AppTypography.heading4.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space6),

              // 직원 선택
              Text(
                '직원 선택',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<int>(
                      value: _selectedMemberId,
                      decoration: InputDecoration(
                        hintText: '직원을 선택하세요',
                        filled: true,
                        fillColor: AppSemanticColors.backgroundSecondary,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space4,
                          vertical: AppSpacing.space3,
                        ),
                      ),
                      items: _members.map((member) {
                        final name = member['name'] ?? '이름 없음';
                        final role = _getRoleDisplayName(member['role'] ?? '');
                        return DropdownMenuItem<int>(
                          value: member['id'],
                          child: Text(
                            '$name - $role',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedMemberId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return '직원을 선택해주세요';
                        }
                        return null;
                      },
                    ),
              const SizedBox(height: AppSpacing.space4),
              
              // 날짜 선택
              Text(
                '휴무 날짜',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),
              Material(
                color: AppColors.transparent,
                child: InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space4,
                      vertical: AppSpacing.space3_5,
                    ),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                      border: Border.all(
                        color: _selectedDate != null
                            ? AppSemanticColors.interactivePrimaryDefault.withValues(alpha:0.2)
                            : AppColors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: _selectedDate != null
                                  ? AppSemanticColors.interactivePrimaryDefault
                                  : AppSemanticColors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.space3),
                            Text(
                              _selectedDate != null
                                  ? '${_selectedDate!.year}년 ${_selectedDate!.month}월 ${_selectedDate!.day}일'
                                  : '날짜를 선택하세요',
                              style: AppTypography.bodyLarge.copyWith(
                                color: _selectedDate != null
                                    ? AppSemanticColors.textPrimary
                                    : AppSemanticColors.textSecondary,
                                fontWeight: _selectedDate != null
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          color: AppSemanticColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.space4),

              // 휴무 타입 선택
              Text(
                '휴무 타입',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),
              Row(
                children: [
                  // 일반 휴무 버튼
                  Expanded(
                    child: _buildTypeOptionButton(
                      text: '일반',
                      isSelected: _selectedType == 'personal',
                      onTap: () => setState(() => _selectedType = 'personal'),
                      selectedColor: AppSemanticColors.statusInfoBackground,
                      selectedTextColor: AppSemanticColors.statusInfoText,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  // 필수 휴무 버튼
                  Expanded(
                    child: _buildTypeOptionButton(
                      text: '필수',
                      isSelected: _selectedType == 'mandatory',
                      onTap: () => setState(() => _selectedType = 'mandatory'),
                      selectedColor: AppSemanticColors.statusErrorBackground,
                      selectedTextColor: AppSemanticColors.statusErrorText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space4),

              // 휴무 기간
              Text(
                '휴무 기간',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),
              DropdownButtonFormField<String>(
                value: _selectedDuration,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppSemanticColors.backgroundSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space4,
                    vertical: AppSpacing.space3,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'FULL_DAY',
                    child: Text('하루 종일 (연차)'),
                  ),
                  DropdownMenuItem(
                    value: 'HALF_DAY_AM',
                    child: Text('오전 반차'),
                  ),
                  DropdownMenuItem(
                    value: 'HALF_DAY_PM',
                    child: Text('오후 반차'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedDuration = value!;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.space4),
              
              // 휴무 사유
              Text(
                '휴무 사유 (선택)',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '휴무 사유를 입력하세요',
                  filled: true,
                  fillColor: AppSemanticColors.backgroundSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(AppSpacing.space4),
                ),
              ),
              const SizedBox(height: AppSpacing.space6),

              // 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  shadcn.GhostButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  shadcn.PrimaryButton(
                    onPressed: _isSubmitting ? null : _submitVacation,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                            ),
                          )
                        : const Text('휴무 등록'),
                  ),
                ],
              ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  );
  }

  Widget _buildTypeOptionButton({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
    required Color selectedColor,
    required Color selectedTextColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppBorderRadius.xl),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3_5),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : AppSemanticColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          border: Border.all(
            color: isSelected ? selectedTextColor : AppSemanticColors.borderDefault,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: AppTypography.bodyMedium.copyWith(
              color: isSelected ? selectedTextColor : AppSemanticColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'caregiver':
        return '요양보호사';
      case 'office':
        return '사무실';
      case 'admin':
        return '관리자';
      default:
        return role;
    }
  }
}