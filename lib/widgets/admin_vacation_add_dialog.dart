import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../models/vacation_kind.dart';
import 'common/app_sheet_frame.dart';
import 'common/app_snackbar.dart';
import 'seed/seed_button.dart';
import 'common/app_choice_grid.dart';
import 'seed/seed_text_field.dart';

/// 관리자가 직원 휴무를 대신 등록하는 창. 등록하면 `true`로 닫힌다.
///
/// 지금 여는 곳(calendar_screen.dart)은 `showDialog`로 가운데 창을 띄운다 — 그 호출은 그대로 둔다.
/// B안 아래 시트로 띄우려면 [showAsSheet]를 쓴다(같은 위젯·같은 반환값).
class AdminVacationAddDialog extends StatefulWidget {
  final DateTime? selectedDate;

  /// true면 가운데 창(Dialog) 대신 아래 시트 내용(AppSheetFrame)을 그린다. [showAsSheet]가 넘긴다.
  final bool asSheet;

  const AdminVacationAddDialog({
    super.key,
    this.selectedDate,
    this.asSheet = false,
  });

  /// B안 아래 시트로 띄운다. 등록하면 true, 그냥 닫으면 null.
  static Future<bool?> showAsSheet(
    BuildContext context, {
    DateTime? selectedDate,
  }) {
    return showAppSheet<bool>(
      context,
      builder: (_) => AdminVacationAddDialog(
        selectedDate: selectedDate,
        asSheet: true,
      ),
    );
  }

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
    final actions = AppSheetActions(
      cancel: SeedButton(
        label: '취소',
        size: SeedButtonSize.large,
        variant: SeedButtonVariant.neutralWeak,
        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
      ),
      confirm: SeedButton(
        label: '휴무 등록',
        size: SeedButtonSize.large,
        variant: SeedButtonVariant.brandSolid,
        isLoading: _isSubmitting,
        onPressed: _isSubmitting ? null : _submitVacation,
      ),
    );

    // 아래 시트(B안) — 손잡이 + 제목 18 + 칸들 + 단추 줄(취소 1 : 등록 1.7)
    if (widget.asSheet) {
      return GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: AppSheetFrame(
            title: '휴무 추가',
            actions: actions,
            children: [
              const SizedBox(height: AppSpacing.space5),
              ..._buildFields(),
            ],
          ),
        ),
      );
    }

    // 가운데 창 — 지금 여는 곳(showDialog)이 쓰는 모습. B안 모서리 24·흰 바탕, 칸은 회색 채움.
    return GestureDetector(
      onTap: () {
        // 키보드 숨기기
        FocusScope.of(context).unfocus();
      },
      child: Dialog(
        // AppDialog.showCustom과 동일한 shape·배경 토큰 (호출부는 AdminVacationAddDialog
        // 시그니처를 그대로 쓰므로 정적 헬퍼를 직접 호출할 수 없어, 산출 스타일만 맞춘다)
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.sheet),
        ),
        backgroundColor: AppSemanticColors.surfaceCard,
        surfaceTintColor: AppColors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5, vertical: AppSpacing.space6),
        child: GestureDetector(
          onTap: () {}, // Dialog 내부 클릭 시 이벤트 전파 차단
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(maxWidth: 480, maxHeight: MediaQuery.of(context).size.height * 0.85),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.space6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.event_note,
                          color: AppSemanticColors.textSecondary,
                          size: 28,
                        ),
                        const SizedBox(width: AppSpacing.space3),
                        Flexible(
                          child: Text(
                            '휴무 추가',
                            style: AppTypography.heading4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space6),
                    ..._buildFields(),
                    const SizedBox(height: AppSpacing.space6),
                    // 버튼 — 시트와 같은 단추 줄(취소 1 : 등록 1.7, 높이 52)
                    actions,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 칸 위 이름표 — SeedTextField 라벨과 같은 14/w600.
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space2),
      child: Text(
        text,
        style: AppTypography.titleSmall.copyWith(
          color: AppSemanticColors.textPrimary,
        ),
      ),
    );
  }

  /// 가운데 창과 시트가 같이 쓰는 입력 칸들(직원 · 날짜 · 종류 · 사유).
  List<Widget> _buildFields() {
    OutlineInputBorder stroke(Color? color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.control),
          borderSide: color == null
              ? BorderSide.none
              : BorderSide(color: color, width: 2),
        );
    return [
      // 직원 선택
      _buildLabel('직원 선택'),
      _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DropdownButtonFormField<int>(
              value: _selectedMemberId,
              isExpanded: true,
              borderRadius: BorderRadius.circular(AppBorderRadius.control),
              decoration: InputDecoration(
                hintText: '직원을 선택하세요',
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppSemanticColors.textTertiary,
                ),
                // B안 입력칸 — 회색 채움, 테두리 없음. 누르면 틸 2px, 틀리면 빨강 2px(SeedTextField와 같다)
                filled: true,
                fillColor: AppSemanticColors.fillDefault,
                border: stroke(null),
                enabledBorder: stroke(null),
                focusedBorder: stroke(AppSemanticColors.borderFocus),
                errorBorder: stroke(AppSemanticColors.statusErrorText),
                focusedErrorBorder: stroke(AppSemanticColors.statusErrorText),
                errorStyle: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.statusErrorText,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space4,
                  vertical: AppSpacing.space3_5,
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

      // 날짜 선택 — 회색 채운 칸 하나(테두리 없음), 높이 52 이상
      _buildLabel('휴무 날짜'),
      Material(
        color: AppSemanticColors.fillDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.control),
        child: InkWell(
          onTap: _selectDate,
          borderRadius: BorderRadius.circular(AppBorderRadius.control),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.buttonHeightLarge,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space4,
                vertical: AppSpacing.space3,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: _selectedDate != null
                        ? AppSemanticColors.interactivePrimaryDefault
                        : AppSemanticColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  // 글자를 키워도 오른쪽으로 넘치지 않게 남은 폭 안에서 줄을 넘긴다
                  Expanded(
                    child: Text(
                      _selectedDate != null
                          ? '${_selectedDate!.year}년 ${_selectedDate!.month}월 ${_selectedDate!.day}일'
                          : '날짜를 선택하세요',
                      style: AppTypography.bodyMedium.copyWith(
                        color: _selectedDate != null
                            ? AppSemanticColors.textPrimary
                            : AppSemanticColors.textSecondary,
                      ),
                    ),
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
      ),
      const SizedBox(height: AppSpacing.space4),

      // 휴무 종류 — 웹 관리자와 같은 6가지. 유형(일반·필수·대체)과
      // 기간(연차·반차)이 한 목록에 들어 있어 고르는 순간 둘 다 정해진다.
      _buildLabel('휴무 종류'),
      // 같은 폭 칸 3개씩(크로박스 고르기 칸) — 줄 끝이 들쭉날쭉하지 않게
      AppChoiceGrid<VacationKind>(
        values: VacationKind.values,
        selected: _selectedKind,
        labelOf: (kind) => kind.label,
        onSelected: (kind) => setState(() => _selectedKind = kind),
      ),
      const SizedBox(height: AppSpacing.space2),
      Text(
        _selectedKind.description,
        style: AppTypography.bodySmall.copyWith(
          color: AppSemanticColors.textSecondary,
        ),
      ),
      const SizedBox(height: AppSpacing.space4),

      // 휴무 사유
      _buildLabel('휴무 사유 (선택)'),
      SeedTextField(
        label: '휴무 사유',
        // 바로 위에 동일한 라벨(Text)이 이미 있어 중복 표시를 피한다
        showLabel: false,
        controller: _reasonController,
        placeholder: '휴무 사유를 입력하세요',
        maxLines: 3,
      ),
    ];
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