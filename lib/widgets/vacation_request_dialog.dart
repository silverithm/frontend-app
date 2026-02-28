import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vacation_request.dart';
import '../providers/vacation_provider.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

class VacationRequestDialog extends StatefulWidget {
  final DateTime selectedDate;
  final VoidCallback? onRequestSubmitted;

  const VacationRequestDialog({
    super.key,
    required this.selectedDate,
    this.onRequestSubmitted,
  });

  @override
  State<VacationRequestDialog> createState() => _VacationRequestDialogState();
}

class _VacationRequestDialogState extends State<VacationRequestDialog>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  VacationType _selectedType = VacationType.personal;
  VacationDuration _selectedDuration = VacationDuration.fullDay;
  bool _isVacationUsed = false; // 연차 사용 여부
  bool _isSubmitting = false;

  late AnimationController _animationController;
  late AnimationController _submitAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  static const List<BoxShadow> _shadowSm = [
    BoxShadow(
      color: Color(0x1A000000), // black 0.1
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x0F000000), // black 0.06
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> _shadowXl = [
    BoxShadow(
      color: Color(0x40000000), // black 0.25
      blurRadius: 50,
      offset: Offset(0, 25),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _submitAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(
        parent: _submitAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _animationController.dispose();
    _submitAnimationController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final vacationProvider = context.read<VacationProvider>();

    if (authProvider.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('로그인이 필요합니다'),
          backgroundColor: AppSemanticColors.statusErrorIcon,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.space3),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    _submitAnimationController.forward();

    try {
      final success = await vacationProvider.createVacationRequest(
        userId: authProvider.currentUser!.id,
        userName: authProvider.currentUser!.name,
        userRole: authProvider.currentUser!.role,
        date: widget.selectedDate,
        type: _selectedType,
        duration: _selectedDuration,
        isVacationUsed: _isVacationUsed,
        reason: _reasonController.text.trim().isNotEmpty
            ? _reasonController.text.trim()
            : null,
        password: '',
        companyId: authProvider.currentUser!.company?.id ?? '1',
      );

      if (success && mounted) {
        // Analytics 휴무 신청 이벤트 기록
        await AnalyticsService().logVacationRequest(
          vacationType: _selectedType.toString().split('.').last,
          startDate: widget.selectedDate.toIso8601String().split('T')[0],
          endDate: widget.selectedDate.toIso8601String().split('T')[0],
        );

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isVacationUsed
                  ? '${_getDurationDisplayText(_selectedDuration)} 신청이 완료되었습니다'
                  : '미사용 휴무 신청이 완료되었습니다',
            ),
            backgroundColor: AppSemanticColors.statusSuccessIcon,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.space3),
            ),
          ),
        );
        widget.onRequestSubmitted?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('신청 실패: ${e.toString()}'),
            backgroundColor: AppSemanticColors.statusErrorIcon,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.space3),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        _submitAnimationController.reverse();
      }
    }
  }

  String _formatSelectedDate(DateTime date) {
    final weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    final weekday = weekdays[date.weekday % 7];
    return '${date.year}년 ${date.month}월 ${date.day}일 ($weekday)';
  }

  String _getDurationDisplayText(VacationDuration duration) {
    switch (duration) {
      case VacationDuration.unused:
        return '미사용';
      case VacationDuration.fullDay:
        return '연차';
      case VacationDuration.halfDayAm:
        return '오전 반차';
      case VacationDuration.halfDayPm:
        return '오후 반차';
    }
  }

  Widget _buildOptionButton({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
    required Color selectedColor,
    required Color selectedTextColor,
  }) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    selectedColor.withValues(alpha: 0.20),
                    selectedColor.withValues(alpha: 0.60),
                  ],
                )
              : null,
          color: !isSelected ? AppSemanticColors.backgroundSecondary : null,
          borderRadius: BorderRadius.circular(AppSpacing.space3),
          border: Border.all(
            color: isSelected ? selectedColor.withValues(alpha: 0.6) : AppSemanticColors.borderDefault,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? _shadowSm : null,
        ),
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.space3),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.space3,
                horizontal: AppSpacing.space2,
              ),
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isSelected ? selectedTextColor.withValues(alpha: 0.9) : AppSemanticColors.textSecondary,
                    letterSpacing: -0.025,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Dialog(
            backgroundColor: AppColors.transparent,
            elevation: 0,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: AppSemanticColors.surfaceDefault,
                borderRadius: BorderRadius.circular(AppSpacing.space6),
                border: Border.all(
                  color: AppSemanticColors.borderDefault,
                  width: 1,
                ),
                boxShadow: _shadowXl,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.space6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 헤더
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppSemanticColors.interactivePrimaryDefault,
                                      AppSemanticColors.interactivePrimaryDefault,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(AppSpacing.space4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppSemanticColors.interactivePrimaryActive.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.event_note_rounded,
                                  color: AppColors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.space3),
                              Text(
                                '휴무 신청',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: AppSemanticColors.textPrimary,
                                  letterSpacing: -0.025,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppSemanticColors.backgroundSecondary,
                              borderRadius: BorderRadius.circular(AppSpacing.space2),
                              border: Border.all(
                                color: AppSemanticColors.borderDefault,
                                width: 1,
                              ),
                            ),
                            child: IconButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => Navigator.pop(context),
                              icon: Icon(
                                Icons.close_rounded,
                                color: AppSemanticColors.textSecondary,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.space6),

                      // 선택된 날짜 표시
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.space5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppSemanticColors.statusInfoBackground,
                              AppSemanticColors.statusInfoBackground.withValues(alpha: 0.6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppSpacing.space4),
                          border: Border.all(
                            color: AppSemanticColors.statusInfoBorder,
                            width: 1,
                          ),
                          boxShadow: _shadowSm,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppSemanticColors.interactivePrimaryDefault,
                                borderRadius: BorderRadius.circular(AppSpacing.space3),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppSemanticColors.interactivePrimaryDefault.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.calendar_today_rounded,
                                color: AppColors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.space4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '선택된 날짜',
                                    style: TextStyle(
                                      color: AppSemanticColors.interactivePrimaryDefault,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.025,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.space1),
                                  Text(
                                    _formatSelectedDate(widget.selectedDate),
                                    style: TextStyle(
                                      color: AppSemanticColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      letterSpacing: -0.025,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.space6),

                      // 폼
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 연차 사용 여부 선택 (미사용/사용)
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.space5),
                              decoration: BoxDecoration(
                                color: AppSemanticColors.surfaceDefault,
                                borderRadius: BorderRadius.circular(AppSpacing.space4),
                                border: Border.all(
                                  color: AppSemanticColors.borderDefault,
                                  width: 1,
                                ),
                                boxShadow: _shadowSm,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '연차 사용 여부',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppSemanticColors.textPrimary,
                                      letterSpacing: -0.025,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.space3),

                                  // 연차 사용 여부 선택
                                  Row(
                                    children: [
                                      // 미사용
                                      _buildOptionButton(
                                        text: '미사용',
                                        isSelected: !_isVacationUsed,
                                        onTap: () {
                                          setState(() {
                                            _isVacationUsed = false;
                                          });
                                        },
                                        selectedColor: AppSemanticColors.statusWarningBorder,
                                        selectedTextColor: AppSemanticColors.statusWarningText,
                                      ),

                                      const SizedBox(width: AppSpacing.space2),

                                      // 사용
                                      _buildOptionButton(
                                        text: '사용',
                                        isSelected: _isVacationUsed,
                                        onTap: () {
                                          setState(() {
                                            _isVacationUsed = true;
                                          });
                                        },
                                        selectedColor: AppSemanticColors.interactivePrimaryActive,
                                        selectedTextColor: AppSemanticColors.interactivePrimaryDefault,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: AppSpacing.space4),

                            // 연차 유형 선택 (사용 선택시에만 표시)
                            if (_isVacationUsed)
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.space5),
                                decoration: BoxDecoration(
                                  color: AppSemanticColors.surfaceDefault,
                                  borderRadius: BorderRadius.circular(AppSpacing.space4),
                                  border: Border.all(
                                    color: AppSemanticColors.borderDefault,
                                    width: 1,
                                  ),
                                  boxShadow: _shadowSm,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '연차 유형',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppSemanticColors.textPrimary,
                                        letterSpacing: -0.025,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.space3),

                                    // 연차 유형 선택 버튼들
                                    Row(
                                      children: [
                                        // 연차
                                        _buildOptionButton(
                                          text: '연차',
                                          isSelected: _selectedDuration == VacationDuration.fullDay,
                                          onTap: () {
                                            setState(() {
                                              _selectedDuration = VacationDuration.fullDay;
                                            });
                                          },
                                          selectedColor: AppSemanticColors.statusSuccessBorder,
                                          selectedTextColor: AppSemanticColors.statusSuccessIcon,
                                        ),

                                        const SizedBox(width: AppSpacing.space2),

                                        // 오전 반차
                                        _buildOptionButton(
                                          text: '오전 반차',
                                          isSelected: _selectedDuration == VacationDuration.halfDayAm,
                                          onTap: () {
                                            setState(() {
                                              _selectedDuration = VacationDuration.halfDayAm;
                                            });
                                          },
                                          selectedColor: AppSemanticColors.statusWarningBorder,
                                          selectedTextColor: AppSemanticColors.statusWarningText,
                                        ),

                                        const SizedBox(width: AppSpacing.space2),

                                        // 오후 반차
                                        _buildOptionButton(
                                          text: '오후 반차',
                                          isSelected: _selectedDuration == VacationDuration.halfDayPm,
                                          onTap: () {
                                            setState(() {
                                              _selectedDuration = VacationDuration.halfDayPm;
                                            });
                                          },
                                          selectedColor: AppSemanticColors.interactivePrimaryActive,
                                          selectedTextColor: AppSemanticColors.interactivePrimaryDefault,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                            if (_isVacationUsed) const SizedBox(height: AppSpacing.space4),

                            // 휴무 유형 선택
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.space5),
                              decoration: BoxDecoration(
                                color: AppSemanticColors.surfaceDefault,
                                borderRadius: BorderRadius.circular(AppSpacing.space4),
                                border: Border.all(
                                  color: AppSemanticColors.borderDefault,
                                  width: 1,
                                ),
                                boxShadow: _shadowSm,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '휴무 유형',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppSemanticColors.textPrimary,
                                      letterSpacing: -0.025,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.space3),

                                  // 한 줄로 배치
                                  Row(
                                    children: [
                                      // 일반 휴무
                                      _buildOptionButton(
                                        text: '일반',
                                        isSelected: _selectedType == VacationType.personal,
                                        onTap: () {
                                          setState(() {
                                            _selectedType = VacationType.personal;
                                          });
                                        },
                                        selectedColor: AppSemanticColors.interactivePrimaryActive,
                                        selectedTextColor: AppSemanticColors.interactivePrimaryDefault,
                                      ),

                                      const SizedBox(width: AppSpacing.space3),

                                      // 필수 휴무
                                      _buildOptionButton(
                                        text: '필수',
                                        isSelected: _selectedType == VacationType.mandatory,
                                        onTap: () {
                                          setState(() {
                                            _selectedType = VacationType.mandatory;
                                          });
                                        },
                                        selectedColor: AppSemanticColors.statusErrorBorder,
                                        selectedTextColor: AppSemanticColors.statusErrorIcon,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: AppSpacing.space4),

                            // 사유 입력
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.space5),
                              decoration: BoxDecoration(
                                color: AppSemanticColors.surfaceDefault,
                                borderRadius: BorderRadius.circular(AppSpacing.space4),
                                border: Border.all(
                                  color: AppSemanticColors.borderDefault,
                                  width: 1,
                                ),
                                boxShadow: _shadowSm,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.edit_note_rounded,
                                        color: AppSemanticColors.textSecondary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: AppSpacing.space2),
                                      Text(
                                        '휴무 사유',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: AppSemanticColors.textPrimary,
                                          letterSpacing: -0.025,
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.only(left: AppSpacing.space2),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.space2,
                                          vertical: AppSpacing.space1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _selectedType == VacationType.mandatory
                                              ? AppSemanticColors.statusErrorBackground
                                              : AppSemanticColors.backgroundTertiary,
                                          borderRadius: BorderRadius.circular(AppSpacing.space2),
                                        ),
                                        child: Text(
                                          _selectedType == VacationType.mandatory ? '필수' : '선택사항',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: _selectedType == VacationType.mandatory
                                                ? AppSemanticColors.statusErrorIcon
                                                : AppSemanticColors.textTertiary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.space4),
                                  TextFormField(
                                    controller: _reasonController,
                                    maxLines: 5,
                                    maxLength: 200,
                                    validator: (value) {
                                      if (_selectedType == VacationType.mandatory &&
                                          (value == null || value.trim().isEmpty)) {
                                        return '필수 휴무는 사유를 반드시 입력해주세요';
                                      }
                                      return null;
                                    },
                                    decoration: InputDecoration(
                                      hintText: _selectedType == VacationType.mandatory
                                          ? '필수 휴무 사유를 상세히 입력해주세요...\n\n예시:\n• 정기 교육 참석\n• 건강검진\n• 회사 행사 등'
                                          : '휴무 사유를 상세히 입력해주세요...\n\n예시:\n• 개인 사정\n• 병원 진료\n• 가족 행사 등',
                                      hintStyle: TextStyle(
                                        color: AppSemanticColors.textTertiary,
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppSpacing.space4),
                                        borderSide: BorderSide(
                                          color: AppSemanticColors.borderDefault,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppSpacing.space4),
                                        borderSide: BorderSide(
                                          color: AppSemanticColors.borderFocus,
                                          width: 2,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppSpacing.space4),
                                        borderSide: BorderSide(
                                          color: AppSemanticColors.borderDefault,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppSpacing.space4),
                                        borderSide: BorderSide(
                                          color: AppSemanticColors.statusErrorIcon,
                                          width: 2,
                                        ),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppSpacing.space4),
                                        borderSide: BorderSide(
                                          color: AppSemanticColors.statusErrorIcon,
                                          width: 2,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: AppSemanticColors.backgroundSecondary,
                                      contentPadding: const EdgeInsets.all(AppSpacing.space5),
                                      counterStyle: TextStyle(
                                        color: AppSemanticColors.textTertiary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: AppSpacing.space6),

                            // 제출 버튼
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppSemanticColors.interactivePrimaryDefault,
                                    AppSemanticColors.interactivePrimaryDefault,
                                    AppSemanticColors.interactivePrimaryDefault,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(AppSpacing.space4),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppSemanticColors.interactivePrimaryActive.withValues(alpha: 0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: shadcn.PrimaryButton(
                                onPressed: _isSubmitting ? null : _submitRequest,
                                child: _isSubmitting
                                    ? Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                AppColors.white,
                                              ),
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.space3),
                                          Text(
                                            '신청 중...',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.white,
                                              letterSpacing: -0.025,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        '휴무 신청하기',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.white,
                                          letterSpacing: -0.025,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
