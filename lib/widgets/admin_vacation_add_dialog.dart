import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../models/vacation_kind.dart';
import 'common/app_snackbar.dart';
import 'seed/seed_button.dart';
import 'seed/seed_chip.dart';
import 'seed/seed_text_field.dart';

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
  /// 웹 관리자와 같은 6가지 종류에서 하나를 고른다 (유형과 기간이 여기서 함께 정해진다)
  VacationKind _selectedKind = VacationKind.regular;
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
        AppSnackBar.showError(
          context,
          message: '직원 목록을 불러올 수 없습니다: ${e.toString()}',
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
      AppSnackBar.showError(context, message: '휴무 날짜를 선택해주세요');
      return;
    }
    if (_selectedMemberId == null) {
      AppSnackBar.showError(context, message: '직원을 선택해주세요');
      return;
    }
    // 필수휴무는 웹과 같이 사유를 반드시 받는다
    if (_selectedKind.reasonRequired && _reasonController.text.trim().isEmpty) {
      AppSnackBar.showError(context, message: '필수휴무는 사유를 입력해주세요');
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
        duration: _selectedKind.serverDuration,
        reason: _reasonController.text.isNotEmpty ? _reasonController.text : null,
        type: _selectedKind.serverType,
        // 연차로 기록하지 않는 종류(일반·필수·대체)는 서버가 duration을 UNUSED로 고정한다
        useAnnualLeave: _selectedKind.useAnnualLeave,
        reasonRequired: _selectedKind.reasonRequired,
      );

      if (mounted) {
        if (result['success'] == true || result['data'] != null) {
          Navigator.of(context).pop(true);
          AppSnackBar.showSuccess(context, message: '휴무가 성공적으로 등록되었습니다');
        } else {
          throw Exception(result['error'] ?? '휴무 등록 실패');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: '휴무 등록 실패: ${e.toString()}');
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
        // AppDialog.showCustom과 동일한 shape·배경 토큰 (호출부는 AdminVacationAddDialog
        // 시그니처를 그대로 쓰므로 정적 헬퍼를 직접 호출할 수 없어, 산출 스타일만 맞춘다)
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        ),
        backgroundColor: AppSemanticColors.surfaceDefault,
        insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5, vertical: AppSpacing.space6),
        child: GestureDetector(
          onTap: () {}, // Dialog 내부 클릭 시 이벤트 전파 차단
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(maxWidth: 480, maxHeight: MediaQuery.of(context).size.height * 0.85),
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
                        hintStyle: TextStyle(color: AppSemanticColors.textTertiary),
                        filled: true,
                        fillColor: AppSemanticColors.backgroundSecondary,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                          borderSide: BorderSide.none,
                        ),
                        // SeedTextField와 동일한 상태색 — 검증 실패 시 기본 Material 빨강으로
                        // 새지 않도록 focus·error 보더를 토큰으로 명시한다
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                          borderSide: BorderSide(
                            color: AppSemanticColors.borderFocus,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                          borderSide: BorderSide(
                            color: AppSemanticColors.statusErrorIcon,
                            width: 1.5,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                          borderSide: BorderSide(
                            color: AppSemanticColors.statusErrorIcon,
                            width: 2,
                          ),
                        ),
                        errorStyle: TextStyle(
                          color: AppSemanticColors.statusErrorText,
                          fontSize: AppTypography.fontSizeXs,
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

              // 휴무 종류 — 웹 관리자와 같은 6가지. 유형(일반·필수·대체)과
              // 기간(연차·반차)이 한 목록에 들어 있어 고르는 순간 둘 다 정해진다.
              Text(
                '휴무 종류',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),
              Wrap(
                spacing: AppSpacing.space2,
                runSpacing: AppSpacing.space2,
                children: VacationKind.values.map((kind) {
                  return SeedChip(
                    label: kind.label,
                    selected: _selectedKind == kind,
                    onTap: () => setState(() => _selectedKind = kind),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.space1),
              Text(
                _selectedKind.description,
                style: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.textSecondary,
                ),
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
              SeedTextField(
                label: '휴무 사유',
                // 바로 위에 동일한 라벨(Text)이 이미 있어 중복 표시를 피한다
                showLabel: false,
                controller: _reasonController,
                placeholder: '휴무 사유를 입력하세요',
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.space6),

              // 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SeedButton(
                    label: '취소',
                    variant: SeedButtonVariant.neutralWeak,
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  SeedButton(
                    label: '휴무 등록',
                    variant: SeedButtonVariant.brandSolid,
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _submitVacation,
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