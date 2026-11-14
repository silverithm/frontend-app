import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vacation_request.dart';
import '../models/vacation_kind.dart';
import '../providers/vacation_provider.dart';
import '../providers/auth_provider.dart';
import 'package:intl/intl.dart';
import '../services/analytics_service.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';
import '../utils/korean_keep_all.dart';
import '../utils/role_utils.dart';
import 'common/app_dialog.dart';
import 'common/app_sheet_frame.dart';
import 'common/app_snackbar.dart';
import 'seed/seed_button.dart';
import 'common/app_choice_grid.dart';
import 'seed/seed_text_field.dart';
import 'vacation_planning_banner.dart';

/// 휴무 신청 — B안(2026-11-12)부터 가운데 대화상자가 아니라 아래에서 올라오는 시트의 내용이다.
/// `showAppSheet(context, builder: (_) => VacationRequestDialog(...))`로 띄운다
/// (이름·생성자는 예전 그대로 — 부르는 쪽이 바뀌지 않게).
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

class _VacationRequestDialogState extends State<VacationRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  // 웹 VACATION_KIND_OPTIONS·앱 관리자 폼(AdminVacationAddDialog)과 같은 6종 단일 선택.
  // 유형(일반/필수/대체)과 기간(연차/반차)을 한 목록에서 함께 고르므로
  // '필수 반차' 같은 조합이 생기지 않는다.
  VacationKind _selectedKind = VacationKind.regular;
  VacationDetailType _detailType =
      VacationDetailType.personal; // 연차 계열이 아닐 때만 쓰는 세부 유형
  bool _isSubmitting = false;

  // 선택 날짜의 휴무 현황 — 제한 인원이 보여야 겹치기 전에 조정할 수 있다
  int? _dayVacationCount;
  int? _dayMaxPeople;
  bool _hasExplicitLimit = false;

  // 예전 대화상자의 등장(흐려졌다 떠오름)·제출 때 살짝 줄어듦 연출은 뺐다 —
  // 시트가 스스로 올라오고, 제출 중은 단추의 불러오는 표시가 알린다.

  @override
  void initState() {
    super.initState();
    // 이 날짜에 몇 명이 쉬는지·제한이 몇 명인지 불러온다 (실패해도 신청은 막지 않는다)
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDateStatus());
  }

  @override
  void dispose() {
    _reasonController.dispose();
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

  /// B안 안내 상자: 테두리 없이 옅은 빨강 바탕, 모서리 12. 줄은 낱말 단위로만 바꾼다(keepAll).
  Widget _buildNoticeBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3_5,
      ),
      decoration: BoxDecoration(
        color: AppSemanticColors.statusErrorBackground,
        borderRadius: BorderRadius.circular(AppBorderRadius.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: AppSemanticColors.statusErrorIcon,
              ),
              const SizedBox(width: AppSpacing.space2),
              Expanded(
                child: Text(
                  _vacationNoticeTitle,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppSemanticColors.textPrimary,
                  ),
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
                    style: AppTypography.bodySmall.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      keepAll(notice),
                      style: AppTypography.bodySmall.copyWith(
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
        type: _typeForSubmit(_selectedKind),
        duration: _durationForSubmit(_selectedKind),
        isVacationUsed: _selectedKind.useAnnualLeave,
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
          vacationType: _selectedKind.name,
          startDate: widget.selectedDate.toIso8601String().split('T')[0],
          endDate: widget.selectedDate.toIso8601String().split('T')[0],
        );

        Navigator.of(context).pop();
        AppSnackBar.showSuccess(
          context,
          message: '${_selectedKind.label} 신청이 완료되었습니다',
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
      }
    }
  }

  String _formatSelectedDate(DateTime date) {
    final weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    final weekday = weekdays[date.weekday % 7];
    return '${date.year}년 ${date.month}월 ${date.day}일 ($weekday)';
  }

  /// 화면에서 고른 한 가지 종류(VacationKind)를 서버 필드(type/duration)로 되돌린다.
  VacationType _typeForSubmit(VacationKind kind) {
    switch (kind.serverType) {
      case 'mandatory':
        return VacationType.mandatory;
      case 'substitute':
        return VacationType.substitute;
      default:
        return VacationType.personal;
    }
  }

  VacationDuration _durationForSubmit(VacationKind kind) {
    switch (kind.serverDuration) {
      case 'FULL_DAY':
        return VacationDuration.fullDay;
      case 'HALF_DAY_AM':
        return VacationDuration.halfDayAm;
      case 'HALF_DAY_PM':
        return VacationDuration.halfDayPm;
      default:
        return VacationDuration.unused;
    }
  }

  @override
  Widget build(BuildContext context) {
    // B안 시트(시안 390-05c): 손잡이 → 제목 18 + 닫기 → 날짜 칸 → 안내 → 종류 칩 → 사유 → 큰 신청 단추.
    // 예전 대화상자의 테두리 상자(날짜·종류·사유)는 걷고 간격으로 나눈다.
    return AppSheetFrame(
      // 제출 버튼 — "다음 달만 받기"가 켜져 있고 이 날짜가 밖이면 아예 누르지 못하게 한다
      actions: AppSheetActions(
        confirm: Builder(
          builder: (context) {
            final isAllowed = context
                .watch<VacationProvider>()
                .isDateAllowedForRequest(widget.selectedDate);
            return SeedButton(
              label: !isAllowed
                  ? '신청할 수 없는 날짜예요'
                  : _isSubmitting
                  ? '신청 중...'
                  : '휴무 신청하기',
              onPressed: (_isSubmitting || !isAllowed) ? null : _submitRequest,
              variant: SeedButtonVariant.brandSolid,
              size: SeedButtonSize.large,
              isLoading: _isSubmitting,
            );
          },
        ),
      ),
      children: [
        // 헤더 — 제목 + 닫기
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  '휴무 신청',
                  style: AppTypography.heading5.copyWith(
                    color: AppSemanticColors.textPrimary,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: '닫기',
              onPressed: _isSubmitting ? null : () => Navigator.pop(context),
              style: IconButton.styleFrom(
                backgroundColor: AppSemanticColors.fillDefault,
              ),
              icon: Icon(
                Icons.close_rounded,
                color: AppSemanticColors.textSecondary,
                size: 22,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.space4),

        // 선택된 날짜 — 회색으로 채운 칸 하나(테두리·아이콘 타일 없음)
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space3_5,
          ),
          decoration: BoxDecoration(
            color: AppSemanticColors.fillDefault,
            borderRadius: BorderRadius.circular(AppBorderRadius.control),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '선택된 날짜',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: Text(
                      _formatSelectedDate(widget.selectedDate),
                      textAlign: TextAlign.end,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppSemanticColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              // 같은 직종이 이 날 몇 명 쉬는지 — 웹 근무조정과 같은 정보
              if (_dayVacationCount != null && _dayMaxPeople != null) ...[
                const SizedBox(height: AppSpacing.space1),
                Text(
                  _dayVacationCount! >= _dayMaxPeople!
                      ? '휴무 인원 $_dayVacationCount/$_dayMaxPeople명 · 마감'
                      : '휴무 인원 $_dayVacationCount/$_dayMaxPeople명',
                  textAlign: TextAlign.end,
                  style: AppTypography.titleSmall.copyWith(
                    color: _dayVacationCount! >= _dayMaxPeople!
                        ? AppSemanticColors.statusErrorText
                        : AppSemanticColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.space4),

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
            final deadline = vacationProvider.deadlineForTargetMonth(month);
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
                const SizedBox(height: AppSpacing.space3),
              ],
            );
          },
        ),

        // 신청 전 확인할 것들 — 배차·최소 인원처럼 시스템이 다 막지 못하는 부분
        _buildNoticeBox(),

        const SizedBox(height: AppSpacing.space6),

        // 폼
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 휴무 종류 — 웹 관리자(VACATION_KIND_OPTIONS)·앱 관리자 폼과 같은
              // 6종 단일 선택. 유형(일반·필수·대체)과 기간(연차·반차)을 한 목록에서
              // 함께 고르므로 '필수 반차' 같은 조합이 생기지 않는다.
              Text(
                '휴무 종류',
                style: AppTypography.titleSmall.copyWith(
                  color: AppSemanticColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.space2_5),
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

              // 연차 계열이 아닌 종류(일반/필수/대체)를 골랐을 때만
              // 세부 유형을 이어서 고른다 (대체휴무는 자동으로 substitute)
              if (_selectedKind == VacationKind.regular ||
                  _selectedKind == VacationKind.mandatory) ...[
                const SizedBox(height: AppSpacing.space5),
                Text(
                  '세부 유형',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppSemanticColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space2_5),
                AppChoiceGrid<VacationDetailType>(
                  values: VacationDetailType.values,
                  selected: _detailType,
                  labelOf: (detail) => detail.label,
                  onSelected: (detail) => setState(() => _detailType = detail),
                ),
              ],

              const SizedBox(height: AppSpacing.space6),

              // 사유 입력 — 라벨 줄 + 회색으로 채운 입력칸 하나(상자 안 상자 없음)
              Row(
                children: [
                  Flexible(
                    child: Text(
                      '휴무 사유',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppSemanticColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space2,
                      vertical: AppSpacing.space0_5,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedKind.reasonRequired
                          ? AppSemanticColors.statusErrorBackground
                          : AppSemanticColors.fillDefault,
                      borderRadius: BorderRadius.circular(AppBorderRadius.full),
                    ),
                    child: Text(
                      _selectedKind.reasonRequired ? '필수' : '선택사항',
                      style: AppTypography.bodySmall.copyWith(
                        color: _selectedKind.reasonRequired
                            ? AppSemanticColors.statusErrorText
                            : AppSemanticColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space2_5),
              SeedTextField(
                label: '휴무 사유',
                showLabel: false,
                controller: _reasonController,
                maxLines: 5,
                size: SeedTextFieldSize.large,
                placeholder: _selectedKind.reasonRequired
                    ? '필수 휴무 사유를 상세히 입력해주세요...\n\n예시:\n• 정기 교육 참석\n• 건강검진\n• 회사 행사 등'
                    : '휴무 사유를 상세히 입력해주세요...\n\n예시:\n• 개인 사정\n• 병원 진료\n• 가족 행사 등',
                validator: (value) {
                  if (_selectedKind.reasonRequired &&
                      (value == null || value.trim().isEmpty)) {
                    return '필수 휴무는 사유를 반드시 입력해주세요';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
