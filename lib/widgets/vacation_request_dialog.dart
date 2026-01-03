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

// Design System Colors - Following design_system_guide_v2.json
class DesignSystemColors {
  // Blue palette
  static const Color blue50 = Color(0xFFEFF6FF);
  static const Color blue100 = Color(0xFFDBEAFE);
  static const Color blue200 = Color(0xFFBFDBFE);
  static const Color blue300 = Color(0xFF93C5FD);
  static const Color blue400 = Color(0xFF60A5FA);
  static const Color blue500 = Color(0xFF3B82F6);
  static const Color blue600 = Color(0xFF2563EB);
  static const Color blue700 = Color(0xFF1D4ED8);
  static const Color blue800 = Color(0xFF1E40AF);
  
  // Gray palette
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);
  
  // Green palette
  static const Color green50 = Color(0xFFF0FDF4);
  static const Color green100 = Color(0xFFDCFCE7);
  static const Color green300 = Color(0xFF86EFAC);
  static const Color green600 = Color(0xFF16A34A);
  static const Color green800 = Color(0xFF166534);
  
  // Orange palette  
  static const Color orange50 = Color(0xFFFEFCE8);
  static const Color orange100 = Color(0xFFFEF9C3);
  static const Color orange300 = Color(0xFFFDE047);
  static const Color orange400 = Color(0xFFFACC15);
  static const Color orange800 = Color(0xFF854D0E);
  
  // Red palette
  static const Color red50 = Color(0xFFFEF2F2);
  static const Color red100 = Color(0xFFFEE2E2);
  static const Color red300 = Color(0xFFFCA5A5);
  static const Color red400 = Color(0xFFF87171);
  static const Color red600 = Color(0xFFDC2626);
  static const Color red800 = Color(0xFF991B1B);
  
  // Semantic colors
  static const Color backgroundPrimary = AppColors.white;
  static const Color backgroundSecondary = gray50;
  static const Color backgroundElevated = AppColors.white;
  static const Color surfaceDefault = AppColors.white;
  static const Color surfaceHover = gray50;
  static const Color borderDefault = gray200;
  static const Color borderFocus = blue500;
  static const Color textPrimary = gray900;
  static const Color textSecondary = gray700;
  static const Color textTertiary = gray500;
  static const Color interactivePrimaryDefault = blue600;
  static const Color interactivePrimaryHover = blue700;
}

// Design System Spacing - Following design_system_guide_v2.json
class DesignSystemSpacing {
  static const double xs = 2.0;    // 0.5
  static const double sm = 4.0;    // 1
  static const double md = 8.0;    // 2
  static const double lg = 12.0;   // 3
  static const double xl = 16.0;   // 4
  static const double xl2 = 20.0;  // 5
  static const double xl3 = 24.0;  // 6
  static const double xl4 = 32.0;  // 8
  static const double xl5 = 48.0;  // 12
}

// Design System Shadows
class DesignSystemShadows {
  static List<BoxShadow> sm = [
    BoxShadow(
      color: AppColors.black.withValues(alpha:0.1),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: AppColors.black.withValues(alpha:0.06),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];
  
  static List<BoxShadow> md = [
    BoxShadow(
      color: AppColors.black.withValues(alpha:0.1),
      blurRadius: 15,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: AppColors.black.withValues(alpha:0.05),
      blurRadius: 6,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> xl = [
    BoxShadow(
      color: AppColors.black.withValues(alpha:0.25),
      blurRadius: 50,
      offset: const Offset(0, 25),
    ),
  ];
}

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
          backgroundColor: DesignSystemColors.red600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignSystemSpacing.lg),
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
            backgroundColor: DesignSystemColors.green600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignSystemSpacing.lg),
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
            backgroundColor: DesignSystemColors.red600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignSystemSpacing.lg),
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
                    selectedColor.withValues(alpha:0.20),
                    selectedColor.withValues(alpha:0.60),
                  ],
                )
              : null,
          color: !isSelected ? DesignSystemColors.surfaceHover : null,
          borderRadius: BorderRadius.circular(DesignSystemSpacing.lg),
          border: Border.all(
            color: isSelected ? selectedColor.withValues(alpha:0.6) : DesignSystemColors.borderDefault,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? DesignSystemShadows.sm : null,
        ),
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(DesignSystemSpacing.lg),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: DesignSystemSpacing.lg,
                horizontal: DesignSystemSpacing.md,
              ),
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isSelected ? selectedTextColor.withValues(alpha:0.9) : DesignSystemColors.textSecondary,
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
                color: DesignSystemColors.backgroundElevated,
                borderRadius: BorderRadius.circular(DesignSystemSpacing.xl3),
                border: Border.all(
                  color: DesignSystemColors.borderDefault,
                  width: 1,
                ),
                boxShadow: DesignSystemShadows.xl,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(DesignSystemSpacing.xl3),
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
                                      DesignSystemColors.blue500,
                                      DesignSystemColors.blue600,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(DesignSystemSpacing.xl),
                                  boxShadow: [
                                    BoxShadow(
                                      color: DesignSystemColors.blue300.withValues(alpha:0.4),
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
                              const SizedBox(width: DesignSystemSpacing.lg),
                              Text(
                                '휴무 신청',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: DesignSystemColors.textPrimary,
                                  letterSpacing: -0.025,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: DesignSystemColors.surfaceHover,
                              borderRadius: BorderRadius.circular(DesignSystemSpacing.md),
                              border: Border.all(
                                color: DesignSystemColors.borderDefault,
                                width: 1,
                              ),
                            ),
                            child: IconButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => Navigator.pop(context),
                              icon: Icon(
                                Icons.close_rounded,
                                color: DesignSystemColors.textSecondary,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: DesignSystemSpacing.xl3),

                      // 선택된 날짜 표시
                      Container(
                        padding: const EdgeInsets.all(DesignSystemSpacing.xl2),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              DesignSystemColors.blue50,
                              DesignSystemColors.blue100.withValues(alpha:0.6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(DesignSystemSpacing.xl),
                          border: Border.all(
                            color: DesignSystemColors.blue200,
                            width: 1,
                          ),
                          boxShadow: DesignSystemShadows.sm,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: DesignSystemColors.blue600,
                                borderRadius: BorderRadius.circular(DesignSystemSpacing.lg),
                                boxShadow: [
                                  BoxShadow(
                                    color: DesignSystemColors.blue600.withValues(alpha:0.2),
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
                            const SizedBox(width: DesignSystemSpacing.xl),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '선택된 날짜',
                                    style: TextStyle(
                                      color: DesignSystemColors.blue600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.025,
                                    ),
                                  ),
                                  const SizedBox(height: DesignSystemSpacing.sm),
                                  Text(
                                    _formatSelectedDate(widget.selectedDate),
                                    style: TextStyle(
                                      color: DesignSystemColors.blue800,
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

                      const SizedBox(height: DesignSystemSpacing.xl3),

                      // 폼
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 연차 사용 여부 선택 (미사용/사용)
                            Container(
                              padding: const EdgeInsets.all(DesignSystemSpacing.xl2),
                              decoration: BoxDecoration(
                                color: DesignSystemColors.surfaceDefault,
                                borderRadius: BorderRadius.circular(DesignSystemSpacing.xl),
                                border: Border.all(
                                  color: DesignSystemColors.borderDefault,
                                  width: 1,
                                ),
                                boxShadow: DesignSystemShadows.sm,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '연차 사용 여부',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: DesignSystemColors.textPrimary,
                                      letterSpacing: -0.025,
                                    ),
                                  ),
                                  const SizedBox(height: DesignSystemSpacing.lg),

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
                                        selectedColor: DesignSystemColors.orange300,
                                        selectedTextColor: DesignSystemColors.orange800,
                                      ),

                                      const SizedBox(width: DesignSystemSpacing.md),

                                      // 사용
                                      _buildOptionButton(
                                        text: '사용',
                                        isSelected: _isVacationUsed,
                                        onTap: () {
                                          setState(() {
                                            _isVacationUsed = true;
                                          });
                                        },
                                        selectedColor: DesignSystemColors.blue400,
                                        selectedTextColor: DesignSystemColors.blue700,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: DesignSystemSpacing.xl),

                            // 연차 유형 선택 (사용 선택시에만 표시)
                            if (_isVacationUsed)
                              Container(
                                padding: const EdgeInsets.all(DesignSystemSpacing.xl2),
                                decoration: BoxDecoration(
                                  color: DesignSystemColors.surfaceDefault,
                                  borderRadius: BorderRadius.circular(DesignSystemSpacing.xl),
                                  border: Border.all(
                                    color: DesignSystemColors.borderDefault,
                                    width: 1,
                                  ),
                                  boxShadow: DesignSystemShadows.sm,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '연차 유형',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: DesignSystemColors.textPrimary,
                                        letterSpacing: -0.025,
                                      ),
                                    ),
                                    const SizedBox(height: DesignSystemSpacing.lg),

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
                                          selectedColor: DesignSystemColors.green300,
                                          selectedTextColor: DesignSystemColors.green600,
                                        ),

                                        const SizedBox(width: DesignSystemSpacing.md),

                                        // 오전 반차
                                        _buildOptionButton(
                                          text: '오전 반차',
                                          isSelected: _selectedDuration == VacationDuration.halfDayAm,
                                          onTap: () {
                                            setState(() {
                                              _selectedDuration = VacationDuration.halfDayAm;
                                            });
                                          },
                                          selectedColor: DesignSystemColors.orange300,
                                          selectedTextColor: DesignSystemColors.orange800,
                                        ),

                                        const SizedBox(width: DesignSystemSpacing.md),

                                        // 오후 반차
                                        _buildOptionButton(
                                          text: '오후 반차',
                                          isSelected: _selectedDuration == VacationDuration.halfDayPm,
                                          onTap: () {
                                            setState(() {
                                              _selectedDuration = VacationDuration.halfDayPm;
                                            });
                                          },
                                          selectedColor: DesignSystemColors.blue400,
                                          selectedTextColor: DesignSystemColors.blue700,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                            if (_isVacationUsed) const SizedBox(height: DesignSystemSpacing.xl),

                            // 휴무 유형 선택
                            Container(
                              padding: const EdgeInsets.all(DesignSystemSpacing.xl2),
                              decoration: BoxDecoration(
                                color: DesignSystemColors.surfaceDefault,
                                borderRadius: BorderRadius.circular(DesignSystemSpacing.xl),
                                border: Border.all(
                                  color: DesignSystemColors.borderDefault,
                                  width: 1,
                                ),
                                boxShadow: DesignSystemShadows.sm,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '휴무 유형',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: DesignSystemColors.textPrimary,
                                      letterSpacing: -0.025,
                                    ),
                                  ),
                                  const SizedBox(height: DesignSystemSpacing.lg),

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
                                        selectedColor: DesignSystemColors.blue400,
                                        selectedTextColor: DesignSystemColors.blue700,
                                      ),

                                      const SizedBox(width: DesignSystemSpacing.lg),

                                      // 필수 휴무
                                      _buildOptionButton(
                                        text: '필수',
                                        isSelected: _selectedType == VacationType.mandatory,
                                        onTap: () {
                                          setState(() {
                                            _selectedType = VacationType.mandatory;
                                          });
                                        },
                                        selectedColor: DesignSystemColors.red300,
                                        selectedTextColor: DesignSystemColors.red600,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: DesignSystemSpacing.xl),

                            // 사유 입력
                            Container(
                              padding: const EdgeInsets.all(DesignSystemSpacing.xl2),
                              decoration: BoxDecoration(
                                color: DesignSystemColors.surfaceDefault,
                                borderRadius: BorderRadius.circular(DesignSystemSpacing.xl),
                                border: Border.all(
                                  color: DesignSystemColors.borderDefault,
                                  width: 1,
                                ),
                                boxShadow: DesignSystemShadows.sm,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.edit_note_rounded,
                                        color: DesignSystemColors.textSecondary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: DesignSystemSpacing.md),
                                      Text(
                                        '휴무 사유',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: DesignSystemColors.textPrimary,
                                          letterSpacing: -0.025,
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.only(left: DesignSystemSpacing.md),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: DesignSystemSpacing.md,
                                          vertical: DesignSystemSpacing.xs,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _selectedType == VacationType.mandatory
                                              ? DesignSystemColors.red100
                                              : DesignSystemColors.gray100,
                                          borderRadius: BorderRadius.circular(DesignSystemSpacing.md),
                                        ),
                                        child: Text(
                                          _selectedType == VacationType.mandatory ? '필수' : '선택사항',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: _selectedType == VacationType.mandatory
                                                ? DesignSystemColors.red600
                                                : DesignSystemColors.textTertiary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: DesignSystemSpacing.xl),
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
                                        color: DesignSystemColors.textTertiary,
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(DesignSystemSpacing.xl),
                                        borderSide: BorderSide(
                                          color: DesignSystemColors.borderDefault,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(DesignSystemSpacing.xl),
                                        borderSide: BorderSide(
                                          color: DesignSystemColors.borderFocus,
                                          width: 2,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(DesignSystemSpacing.xl),
                                        borderSide: BorderSide(
                                          color: DesignSystemColors.borderDefault,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(DesignSystemSpacing.xl),
                                        borderSide: BorderSide(
                                          color: DesignSystemColors.red400,
                                          width: 2,
                                        ),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(DesignSystemSpacing.xl),
                                        borderSide: BorderSide(
                                          color: DesignSystemColors.red600,
                                          width: 2,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: DesignSystemColors.backgroundSecondary,
                                      contentPadding: const EdgeInsets.all(DesignSystemSpacing.xl2),
                                      counterStyle: TextStyle(
                                        color: DesignSystemColors.textTertiary,
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

                            const SizedBox(height: DesignSystemSpacing.xl3),

                            // 제출 버튼
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    DesignSystemColors.blue500,
                                    DesignSystemColors.blue600,
                                    DesignSystemColors.blue700,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(DesignSystemSpacing.xl),
                                boxShadow: [
                                  BoxShadow(
                                    color: DesignSystemColors.blue400.withValues(alpha:0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submitRequest,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.transparent,
                                  shadowColor: AppColors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: DesignSystemSpacing.xl + 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(DesignSystemSpacing.xl),
                                  ),
                                  elevation: 0,
                                ),
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
                                          const SizedBox(width: DesignSystemSpacing.lg),
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