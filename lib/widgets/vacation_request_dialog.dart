import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vacation_request.dart';
import '../providers/vacation_provider.dart';
import '../providers/auth_provider.dart';
import 'package:intl/intl.dart';
import '../services/analytics_service.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';
import '../utils/role_utils.dart';
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
  VacationDetailType _detailType = VacationDetailType.personal; // 연차 미사용 세부 유형
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

  /// 같은 노선의 다른 운전자가 이미 그날 휴무인지 확인한다.
  /// 배차에 배정되지 않은 직원이면 조회 없이 통과시킨다.
  /// 조회가 실패해도 신청을 막지는 않는다 (배차는 보조 규칙).
  /// 휴무 신청 전 주의사항 — 웹(vacationGuard.ts)과 같은 문구를 쓴다
  static const List<String> _vacationNotices = [
    '본인이 주운전자 · 부운전자인지 확인해 주세요.',
    '요양팀은 최소 휴무 인원을 확인해 주세요.',
    '휴무 신청은 선착순이 아닙니다. 같은 날 신청이 몰리면 서로 배려해 조정해 주세요.',
    '근무표는 모든 선생님과의 약속입니다. 변동이 없도록 심사숙고해 입력해 주세요.',
  ];

  Widget _buildNoticeBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppSemanticColors.statusWarningBackground,
        borderRadius: BorderRadius.circular(AppSpacing.space4),
        border: Border.all(color: AppSemanticColors.statusWarningBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppSemanticColors.statusWarningIcon,
              ),
              const SizedBox(width: AppSpacing.space2),
              Text(
                '신청 전 확인해 주세요',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppSemanticColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          ..._vacationNotices.map(
            (notice) => Padding(
              padding: const EdgeInsets.only(top: AppSpacing.space1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('· ', style: TextStyle(color: AppSemanticColors.textSecondary)),
                  Expanded(
                    child: Text(
                      notice,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppSemanticColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _findDriverConflict(String memberName, String companyId) async {
    if (companyId.isEmpty || memberName.trim().isEmpty) return null;
    try {
      final roles = await ApiService().getDriverRoles(
        memberName: memberName,
        companyId: companyId,
      );
      if (roles.isEmpty) return null;

      final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
      final calendar = await ApiService().getVacationCalendar(
        startDate: dateStr,
        endDate: dateStr,
        companyId: companyId,
      );

      final raw = calendar['vacations'] ?? calendar['content'] ?? calendar['data'];
      final onVacation = <String>{};
      if (raw is List) {
        for (final item in raw) {
          if (item is! Map) continue;
          // 반려된 건은 그날 쉬는 게 아니므로 제외
          final status = (item['status'] ?? '').toString().toUpperCase();
          if (status == 'REJECTED') continue;
          final name =
              (item['userName'] ?? item['memberName'] ?? item['name'] ?? '').toString().trim();
          if (name.isNotEmpty) onVacation.add(name);
        }
      }

      for (final role in roles) {
        final coDrivers = role['coDrivers'];
        if (coDrivers is! List) continue;
        for (final other in coDrivers) {
          final name = other.toString().trim();
          if (name.isEmpty || !onVacation.contains(name)) continue;
          return '${role['routeName']}(${role['routeType']}) 노선의 $name 선생님이 이미 휴무입니다.';
        }
      }
      return null;
    } catch (e) {
      print('[휴무] 배차 충돌 확인 실패: $e');
      return null;
    }
  }

  Future<void> _showDriverConflictDialog(String detail) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('같은 노선 운전자가 이미 휴무입니다'),
        content: Text(
          '$detail\n\n'
          '같은 노선의 운전자가 함께 쉬면 그날 차량을 운행할 사람이 없습니다.\n'
          '휴무일을 조정하거나 관리자와 먼저 상의해 주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
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

    // 같은 노선의 주·부운전자가 함께 쉬면 그날 차량을 몰 사람이 없다 — 신청 전에 막는다
    final conflict = await _findDriverConflict(
      authProvider.currentUser!.name,
      authProvider.currentUser!.company?.id ?? '',
    );
    if (conflict != null && mounted) {
      setState(() {
        _isSubmitting = false;
      });
      await _showDriverConflictDialog(conflict);
      return;
    }

    _submitAnimationController.forward();

    try {
      final success = await vacationProvider.createVacationRequest(
        userId: authProvider.currentUser!.id,
        userName: authProvider.currentUser!.name,
        // 배정된 역할이 있으면 그것으로 신청한다 (없을 때만 기존 분류)
        userRole: RoleUtils.normalize(
          authProvider.currentUser!.position?.isNotEmpty == true
              ? authProvider.currentUser!.position
              : authProvider.currentUser!.role,
        ),
        date: widget.selectedDate,
        type: _selectedType,
        duration: _selectedDuration,
        isVacationUsed: _isVacationUsed,
        vacationDetailType: _detailType.serverValue,
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

                      // 신청 전 확인할 것들 — 배차·최소 인원처럼 시스템이 다 막지 못하는 부분
                      _buildNoticeBox(),

                      const SizedBox(height: AppSpacing.space5),

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

                                      const SizedBox(width: AppSpacing.space3),

                                      // 대체휴무 (연차 차감 없이 근무일과 맞바꾸는 휴무)
                                      _buildOptionButton(
                                        text: '대체',
                                        isSelected: _selectedType == VacationType.substitute,
                                        onTap: () {
                                          setState(() {
                                            _selectedType = VacationType.substitute;
                                          });
                                        },
                                        selectedColor: AppSemanticColors.statusInfoBorder,
                                        selectedTextColor: AppSemanticColors.statusInfoIcon,
                                      ),
                                    ],
                                  ),

                                  // 연차 미사용 세부 유형 (대체휴무는 자동으로 substitute)
                                  if (!_isVacationUsed &&
                                      _selectedType != VacationType.substitute) ...[
                                    const SizedBox(height: AppSpacing.space4),
                                    Text(
                                      '세부 유형',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppSemanticColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.space2),
                                    Wrap(
                                      spacing: AppSpacing.space2,
                                      runSpacing: AppSpacing.space2,
                                      children: VacationDetailType.values.map((detail) {
                                        final isSelected = _detailType == detail;
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _detailType = detail;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.space3,
                                              vertical: AppSpacing.space2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppSemanticColors.interactivePrimaryDefault
                                                  : AppSemanticColors.backgroundTertiary,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              detail.label,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? AppSemanticColors.textInverse
                                                    : AppSemanticColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
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
