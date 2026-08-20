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
import 'common/app_dialog.dart';
import 'common/app_snackbar.dart';
import 'seed/seed_button.dart';
import 'seed/seed_text_field.dart';
import 'vacation_planning_banner.dart';

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

  // 선택 날짜의 휴무 현황 — 제한 인원이 보여야 겹치기 전에 조정할 수 있다
  int? _dayVacationCount;
  int? _dayMaxPeople;
  bool _hasExplicitLimit = false;

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

    // 이 날짜에 몇 명이 쉬는지·제한이 몇 명인지 불러온다 (실패해도 신청은 막지 않는다)
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDateStatus());

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
  /// 휴무 신청 전 필수 숙지 사항 — 웹(src/lib/vacationGuard.ts VACATION_NOTICES)과 같은 문구·제목을 쓴다
  static const String _vacationNoticeTitle = '휴무 등록 전 필수 숙지 사항';
  static const List<String> _vacationNotices = [
    '근무표는 모든 선생님과의 약속입니다. 본인의 일정 변동이 다른 선생님들의 업무 과중을 불러일으키니, 심사숙고하여 정해진 기일까지 입력 부탁드립니다.',
    '휴무 신청은 선착순이 아닙니다. 특정일에 휴무가 중복될 경우 서로 배려하여 조정 부탁드립니다.',
    '당일 최소 휴무 인원과 주/부운전자 중복 여부를 꼭 확인하시기 바랍니다.',
    '휴무, 연차 사용의 최종 승인은 센터 운영 전반을 고려하여 이루어집니다.',
  ];

  Widget _buildNoticeBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppSemanticColors.statusErrorBackground,
        borderRadius: BorderRadius.circular(AppSpacing.space4),
        border: Border.all(color: AppSemanticColors.statusErrorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppSemanticColors.statusErrorIcon,
              ),
              const SizedBox(width: AppSpacing.space2),
              Text(
                _vacationNoticeTitle,
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
                  Text(
                    '· ',
                    style: TextStyle(color: AppSemanticColors.textSecondary),
                  ),
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

  Future<void> _loadDateStatus() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;
    final companyId = user.company?.id ?? '';
    if (companyId.isEmpty) return;
    final role = RoleUtils.normalize(
      user.position?.isNotEmpty == true ? user.position : user.role,
    );
    final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    try {
      final day = await ApiService().getVacationForDate(
        date: dateStr,
        companyId: companyId,
        role: role,
      );
      final limits = await ApiService().getVacationLimits(
        start: dateStr,
        end: dateStr,
        companyId: companyId,
        role: role,
      );
      final limitsList = limits['limits'];
      if (!mounted) return;
      setState(() {
        _dayVacationCount = (day['totalVacationers'] as num?)?.toInt();
        _dayMaxPeople = (day['maxPeople'] as num?)?.toInt();
        // 표시용 기본값(3명)과 달리, 실제 차단은 관리자가 명시한 제한이 있을 때만 한다
        _hasExplicitLimit = limitsList is List && limitsList.isNotEmpty;
      });
    } catch (e) {
      print('[휴무] 날짜 현황 조회 실패: $e');
    }
  }

  Future<String?> _findDriverConflict(
    String memberName,
    String companyId,
  ) async {
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

      final raw =
          calendar['vacations'] ?? calendar['content'] ?? calendar['data'];
      final onVacation = <String>{};
      if (raw is List) {
        for (final item in raw) {
          if (item is! Map) continue;
          // 반려된 건은 그날 쉬는 게 아니므로 제외
          final status = (item['status'] ?? '').toString().toUpperCase();
          if (status == 'REJECTED') continue;
          final name =
              (item['userName'] ?? item['memberName'] ?? item['name'] ?? '')
                  .toString()
                  .trim();
          if (name.isNotEmpty) onVacation.add(name);
        }
      }

      for (final role in roles) {
        final coDrivers = role['coDrivers'];
        if (coDrivers is! List) continue;

        final others = coDrivers
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
        // 운전자가 셋인 노선에서 한 명 쉬는 건 문제가 아니다.
        // 내가 쉬었을 때 남는 운전자가 하나도 없을 때만 알린다.
        final remaining = others.where((n) => !onVacation.contains(n)).toList();
        if (remaining.isNotEmpty) continue;

        final resting = others.where((n) => onVacation.contains(n)).join(', ');
        return '${role['routeName']}(${role['routeType']}) 노선 — $resting 선생님이 이미 휴무입니다.';
      }
      return null;
    } catch (e) {
      print('[휴무] 배차 충돌 확인 실패: $e');
      return null;
    }
  }

  /// 운행 공백을 알리되 신청을 막지는 않는다 — 사정이 있을 수 있어 최종 판단은 관리자가 한다.
  Future<bool?> _showDriverConflictDialog(String detail) async {
    if (!mounted) return false;
    return AppDialog.showConfirm(
      context,
      title: '이 날 운행할 운전자가 없습니다',
      message:
          '$detail\n\n'
          '지금 신청하면 그날 이 노선을 운행할 사람이 없습니다.\n'
          '그래도 신청하시겠습니까? 관리자가 확인 후 조정할 수 있습니다.',
      confirmText: '그래도 신청',
      cancelText: '취소',
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final vacationProvider = context.read<VacationProvider>();

    if (authProvider.currentUser == null) {
      AppSnackBar.showError(context, message: '로그인이 필요합니다');
      return;
    }

    // 기관이 "다음 달만 받기"를 켜뒀으면 화면에서 먼저 막는다 (서버도 같은 규칙으로 한 번 더 막는다)
    if (!vacationProvider.isDateAllowedForRequest(widget.selectedDate)) {
      final allowedMonth = vacationProvider.nextMonthOnlyMonth;
      AppDialog.showAlert(
        context,
        title: '신청할 수 없는 날짜입니다',
        message:
            '${allowedMonth.year}년 ${allowedMonth.month}월 휴무만 신청하실 수 있습니다.',
      );
      return;
    }

    // 관리자가 이 날짜에 제한을 걸어뒀고 이미 가득 찼으면 바로 알린다 (서버도 같은 규칙으로 거절한다)
    if (_hasExplicitLimit &&
        _dayVacationCount != null &&
        _dayMaxPeople != null &&
        _dayVacationCount! >= _dayMaxPeople!) {
      AppDialog.showAlert(
        context,
        title: '휴무 인원이 가득 찼습니다',
        message:
            '${widget.selectedDate.month}월 ${widget.selectedDate.day}일은 '
            '휴무 가능 인원($_dayMaxPeople명)이 이미 채워졌습니다.\n'
            '다른 날짜를 선택하시거나 관리자에게 문의해주세요.',
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
      final proceed = await _showDriverConflictDialog(conflict);
      if (proceed != true) return;
      if (!mounted) return;
      setState(() {
        _isSubmitting = true;
      });
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
        AppSnackBar.showSuccess(
          context,
          message: _isVacationUsed
              ? '${_getDurationDisplayText(_selectedDuration)} 신청이 완료되었습니다'
              : '미사용 휴무 신청이 완료되었습니다',
        );
        widget.onRequestSubmitted?.call();
      } else if (mounted) {
        // 서버가 거절한 사유(제한 인원 초과 등)를 알림창으로 — 조용히 실패하면 몇 번이고 다시 누르게 된다
        final reason = vacationProvider.errorMessage.trim();
        AppDialog.showAlert(
          context,
          title: '신청이 접수되지 않았어요',
          message: reason.isNotEmpty
              ? reason
              : '휴무 신청에 실패했습니다. 잠시 후 다시 시도해주세요.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: '신청 실패: ${e.toString()}');
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
          color: isSelected
              ? selectedColor.withValues(alpha: 0.15)
              : AppSemanticColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(AppSpacing.space3),
          border: Border.all(
            color: isSelected
                ? selectedColor.withValues(alpha: 0.6)
                : AppSemanticColors.borderDefault,
            width: isSelected ? 2 : 1,
          ),
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
                    color: isSelected
                        ? selectedTextColor.withValues(alpha: 0.9)
                        : AppSemanticColors.textSecondary,
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
                borderRadius: BorderRadius.circular(AppBorderRadius.xl3),
                // 다이얼로그 표면 자체의 부양 그림자 — 떠 있는 오버레이 요소로 허용 범위
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 50,
                    offset: Offset(0, 25),
                  ),
                ],
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
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppSemanticColors.brandWeak,
                                  borderRadius: BorderRadius.circular(
                                    AppBorderRadius.xl2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.event_note_rounded,
                                  color: AppSemanticColors.brandPressed,
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
                              borderRadius: BorderRadius.circular(
                                AppSpacing.space2,
                              ),
                              border: Border.all(
                                color: AppSemanticColors.borderDefault,
                                width: 1,
                              ),
                            ),
                            child: IconButton(
                              tooltip: '닫기',
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
                          color: AppSemanticColors.statusInfoBackground,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.space4,
                          ),
                          border: Border.all(
                            color: AppSemanticColors.statusInfoBorder,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppSemanticColors.brandWeak,
                                borderRadius: BorderRadius.circular(
                                  AppBorderRadius.xl,
                                ),
                              ),
                              child: const Icon(
                                Icons.calendar_today_rounded,
                                color: AppSemanticColors.brandPressed,
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
                                      color: AppSemanticColors
                                          .interactivePrimaryDefault,
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
                                  // 같은 직종이 이 날 몇 명 쉬는지 — 웹 근무조정과 같은 정보
                                  if (_dayVacationCount != null &&
                                      _dayMaxPeople != null) ...[
                                    const SizedBox(height: AppSpacing.space1),
                                    Text(
                                      _dayVacationCount! >= _dayMaxPeople!
                                          ? '휴무 인원 $_dayVacationCount/$_dayMaxPeople명 · 마감'
                                          : '휴무 인원 $_dayVacationCount/$_dayMaxPeople명',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _dayVacationCount! >= _dayMaxPeople!
                                            ? AppSemanticColors.statusErrorText
                                            : AppSemanticColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.space5),

                      // 근무조정 컨텍스트 — 다음 달만 받기 제한 · 이번 달 마감일 · 이 날의 중요 행사
                      Consumer<VacationProvider>(
                        builder: (context, vacationProvider, _) {
                          final month = DateTime(
                            widget.selectedDate.year,
                            widget.selectedDate.month,
                          );
                          final allowedMonth = vacationProvider.isNextMonthOnly
                              ? vacationProvider.nextMonthOnlyMonth
                              : null;
                          // 신청하려는 날짜가 속한 달의 '신청 마감일' —
                          // 마감일은 그 전 달에 있다 (9월 휴무 마감 = 8월 16일)
                          final deadline = vacationProvider
                              .deadlineForTargetMonth(month);
                          final warnEvents = vacationProvider
                              .eventsForDate(widget.selectedDate)
                              .where((e) => e.warnOnRequest)
                              .toList();
                          final hasBanner =
                              allowedMonth != null ||
                              deadline != null ||
                              warnEvents.isNotEmpty;
                          if (!hasBanner) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              VacationPlanningBanner(
                                nextMonthOnly: vacationProvider.isNextMonthOnly,
                                allowedMonth: allowedMonth,
                                deadline: deadline,
                                deadlineTargetMonth: month,
                                deadlinePassed: vacationProvider
                                    .isDeadlinePassedForTargetMonth(month),
                                events: warnEvents,
                                eventsHeading: '이 날은 기관 행사가 있습니다',
                              ),
                              const SizedBox(height: AppSpacing.space5),
                            ],
                          );
                        },
                      ),

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
                                borderRadius: BorderRadius.circular(
                                  AppBorderRadius.xl2,
                                ),
                                border: Border.all(
                                  color: AppSemanticColors.borderSubtle,
                                  width: 1,
                                ),
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
                                        selectedColor: AppSemanticColors
                                            .statusWarningBorder,
                                        selectedTextColor:
                                            AppSemanticColors.statusWarningText,
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
                                        selectedColor: AppSemanticColors
                                            .interactivePrimaryActive,
                                        selectedTextColor: AppSemanticColors
                                            .interactivePrimaryDefault,
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
                                padding: const EdgeInsets.all(
                                  AppSpacing.space5,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    AppBorderRadius.xl2,
                                  ),
                                  border: Border.all(
                                    color: AppSemanticColors.borderSubtle,
                                    width: 1,
                                  ),
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
                                          isSelected:
                                              _selectedDuration ==
                                              VacationDuration.fullDay,
                                          onTap: () {
                                            setState(() {
                                              _selectedDuration =
                                                  VacationDuration.fullDay;
                                            });
                                          },
                                          selectedColor: AppSemanticColors
                                              .statusSuccessBorder,
                                          selectedTextColor: AppSemanticColors
                                              .statusSuccessIcon,
                                        ),

                                        const SizedBox(
                                          width: AppSpacing.space2,
                                        ),

                                        // 오전 반차
                                        _buildOptionButton(
                                          text: '오전 반차',
                                          isSelected:
                                              _selectedDuration ==
                                              VacationDuration.halfDayAm,
                                          onTap: () {
                                            setState(() {
                                              _selectedDuration =
                                                  VacationDuration.halfDayAm;
                                            });
                                          },
                                          selectedColor: AppSemanticColors
                                              .statusWarningBorder,
                                          selectedTextColor: AppSemanticColors
                                              .statusWarningText,
                                        ),

                                        const SizedBox(
                                          width: AppSpacing.space2,
                                        ),

                                        // 오후 반차
                                        _buildOptionButton(
                                          text: '오후 반차',
                                          isSelected:
                                              _selectedDuration ==
                                              VacationDuration.halfDayPm,
                                          onTap: () {
                                            setState(() {
                                              _selectedDuration =
                                                  VacationDuration.halfDayPm;
                                            });
                                          },
                                          selectedColor: AppSemanticColors
                                              .interactivePrimaryActive,
                                          selectedTextColor: AppSemanticColors
                                              .interactivePrimaryDefault,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                            if (_isVacationUsed)
                              const SizedBox(height: AppSpacing.space4),

                            // 휴무 유형 선택
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.space5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AppBorderRadius.xl2,
                                ),
                                border: Border.all(
                                  color: AppSemanticColors.borderSubtle,
                                  width: 1,
                                ),
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
                                        isSelected:
                                            _selectedType ==
                                            VacationType.personal,
                                        onTap: () {
                                          setState(() {
                                            _selectedType =
                                                VacationType.personal;
                                          });
                                        },
                                        selectedColor: AppSemanticColors
                                            .interactivePrimaryActive,
                                        selectedTextColor: AppSemanticColors
                                            .interactivePrimaryDefault,
                                      ),

                                      const SizedBox(width: AppSpacing.space3),

                                      // 필수 휴무
                                      _buildOptionButton(
                                        text: '필수',
                                        isSelected:
                                            _selectedType ==
                                            VacationType.mandatory,
                                        onTap: () {
                                          setState(() {
                                            _selectedType =
                                                VacationType.mandatory;
                                          });
                                        },
                                        selectedColor:
                                            AppSemanticColors.statusErrorBorder,
                                        selectedTextColor:
                                            AppSemanticColors.statusErrorIcon,
                                      ),

                                      const SizedBox(width: AppSpacing.space3),

                                      // 대체휴무 (연차 차감 없이 근무일과 맞바꾸는 휴무)
                                      _buildOptionButton(
                                        text: '대체',
                                        isSelected:
                                            _selectedType ==
                                            VacationType.substitute,
                                        onTap: () {
                                          setState(() {
                                            _selectedType =
                                                VacationType.substitute;
                                          });
                                        },
                                        selectedColor:
                                            AppSemanticColors.statusInfoBorder,
                                        selectedTextColor:
                                            AppSemanticColors.statusInfoIcon,
                                      ),
                                    ],
                                  ),

                                  // 연차 미사용 세부 유형 (대체휴무는 자동으로 substitute)
                                  if (!_isVacationUsed &&
                                      _selectedType !=
                                          VacationType.substitute) ...[
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
                                      children: VacationDetailType.values.map((
                                        detail,
                                      ) {
                                        final isSelected =
                                            _detailType == detail;
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
                                                  ? AppSemanticColors
                                                        .interactivePrimaryDefault
                                                  : AppSemanticColors
                                                        .backgroundTertiary,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              detail.label,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? AppSemanticColors
                                                          .textInverse
                                                    : AppSemanticColors
                                                          .textSecondary,
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
                                borderRadius: BorderRadius.circular(
                                  AppBorderRadius.xl2,
                                ),
                                border: Border.all(
                                  color: AppSemanticColors.borderSubtle,
                                  width: 1,
                                ),
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
                                        margin: const EdgeInsets.only(
                                          left: AppSpacing.space2,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.space2,
                                          vertical: AppSpacing.space1,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              _selectedType ==
                                                  VacationType.mandatory
                                              ? AppSemanticColors
                                                    .statusErrorBackground
                                              : AppSemanticColors
                                                    .backgroundTertiary,
                                          borderRadius: BorderRadius.circular(
                                            AppSpacing.space2,
                                          ),
                                        ),
                                        child: Text(
                                          _selectedType ==
                                                  VacationType.mandatory
                                              ? '필수'
                                              : '선택사항',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color:
                                                _selectedType ==
                                                    VacationType.mandatory
                                                ? AppSemanticColors
                                                      .statusErrorIcon
                                                : AppSemanticColors
                                                      .textTertiary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.space4),
                                  SeedTextField(
                                    label: '휴무 사유',
                                    showLabel: false,
                                    controller: _reasonController,
                                    maxLines: 5,
                                    size: SeedTextFieldSize.large,
                                    placeholder:
                                        _selectedType == VacationType.mandatory
                                        ? '필수 휴무 사유를 상세히 입력해주세요...\n\n예시:\n• 정기 교육 참석\n• 건강검진\n• 회사 행사 등'
                                        : '휴무 사유를 상세히 입력해주세요...\n\n예시:\n• 개인 사정\n• 병원 진료\n• 가족 행사 등',
                                    validator: (value) {
                                      if (_selectedType ==
                                              VacationType.mandatory &&
                                          (value == null ||
                                              value.trim().isEmpty)) {
                                        return '필수 휴무는 사유를 반드시 입력해주세요';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: AppSpacing.space6),

                            // 제출 버튼 — "다음 달만 받기"가 켜져 있고 이 날짜가 밖이면 아예 누르지 못하게 한다
                            Builder(
                              builder: (context) {
                                final isAllowed = context
                                    .watch<VacationProvider>()
                                    .isDateAllowedForRequest(
                                      widget.selectedDate,
                                    );
                                return SeedButton(
                                  label: !isAllowed
                                      ? '신청할 수 없는 날짜예요'
                                      : _isSubmitting
                                      ? '신청 중...'
                                      : '휴무 신청하기',
                                  onPressed: (_isSubmitting || !isAllowed)
                                      ? null
                                      : _submitRequest,
                                  variant: SeedButtonVariant.brandSolid,
                                  size: SeedButtonSize.large,
                                  isLoading: _isSubmitting,
                                );
                              },
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
