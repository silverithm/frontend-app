import 'package:flutter/material.dart';
import '../models/vacation_planning.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// 근무조정 컨텍스트 배너 — "다음 달만 받기" 제한, 이번 달 마감일, 걸린 중요 행사를 한눈에 보여준다.
/// 서버 에러 메시지에만 기대지 않고, 신청 전에 먼저 안내한다.
/// (웹 EmployeeCalendar.tsx의 안내 Banner와 같은 정보를 앱 톤으로 옮긴 것)
class VacationPlanningBanner extends StatelessWidget {
  final bool nextMonthOnly;
  final DateTime? allowedMonth; // nextMonthOnly가 켜졌을 때 신청 가능한 달
  final DateTime? deadline; // [deadlineTargetMonth]월 휴무의 신청 마감일 (없으면 null)
  final bool deadlinePassed;

  /// 마감일이 관장하는 휴무 월. 마감일은 정의상 그 전 달에 위치한다
  /// (예: 9월 휴무 마감일은 8월 16일). 문구에 이 달을 명시해
  /// 마감일이 어느 달 휴무에 적용되는지 헷갈리지 않게 한다.
  final DateTime? deadlineTargetMonth;
  final List<VacationEvent> events; // 표시할 행사 (보통 선택된 날짜 또는 이번 달 것)
  final String? eventsHeading;

  const VacationPlanningBanner({
    super.key,
    this.nextMonthOnly = false,
    this.allowedMonth,
    this.deadline,
    this.deadlinePassed = false,
    this.deadlineTargetMonth,
    this.events = const [],
    this.eventsHeading,
  });

  bool get _hasContent =>
      nextMonthOnly || deadline != null || events.isNotEmpty;

  String _formatMonth(DateTime date) => '${date.year}년 ${date.month}월';

  String _formatDate(DateTime date) => '${date.month}월 ${date.day}일';

  /// 마감이 관장하는 달 이름. 지정이 없으면 마감일의 다음 달로 계산한다
  /// — 마감일은 정의상 대상 월의 전 달에 있다.
  String _targetMonthLabel() {
    final target = deadlineTargetMonth ??
        (deadline != null
            ? DateTime(deadline!.year, deadline!.month + 1, 1)
            : null);
    if (target == null) return '다음 달';
    return '${target.month}월';
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasContent) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (nextMonthOnly && allowedMonth != null)
          _buildNotice(
            icon: Icons.event_available_rounded,
            background: AppSemanticColors.statusInfoBackground,
            border: AppSemanticColors.statusInfoBorder,
            iconColor: AppSemanticColors.statusInfoIcon,
            title: '${_formatMonth(allowedMonth!)} 휴무만 신청할 수 있어요',
            description:
                '기관 설정에 따라 바로 다음 달 휴무만 받고 있습니다. 다른 달 휴무가 필요하면 관리자에게 말씀해주세요.',
          ),
        if (deadline != null) ...[
          if (nextMonthOnly) const SizedBox(height: AppSpacing.space2),
          _buildNotice(
            icon: deadlinePassed
                ? Icons.event_busy_rounded
                : Icons.schedule_rounded,
            background: deadlinePassed
                ? AppSemanticColors.statusErrorBackground
                : AppSemanticColors.statusWarningBackground,
            border: deadlinePassed
                ? AppSemanticColors.statusErrorBorder
                : AppSemanticColors.statusWarningBorder,
            iconColor: deadlinePassed
                ? AppSemanticColors.statusErrorIcon
                : AppSemanticColors.statusWarningIcon,
            title: deadlinePassed
                ? '${_targetMonthLabel()} 휴무 신청이 ${_formatDate(deadline!)}에 마감됐어요'
                : '${_targetMonthLabel()} 휴무 신청 마감일: ${_formatDate(deadline!)}',
            description: deadlinePassed
                ? '마감을 놓친 휴무는 관리자에게 직접 문의해주세요.'
                : '마감일까지 근무표에 반영할 휴무를 신청해주세요.',
          ),
        ],
        if (events.isNotEmpty) ...[
          if (nextMonthOnly || deadline != null)
            const SizedBox(height: AppSpacing.space2),
          _buildNotice(
            icon: Icons.push_pin_rounded,
            background: AppColors.purple50,
            border: AppColors.purple200,
            iconColor: AppColors.purple600,
            title: eventsHeading ?? '이 기간 중요 행사가 있어요',
            description: events
                .map(
                  (e) => e.description != null
                      ? '· ${e.title} — ${e.description}'
                      : '· ${e.title}',
                )
                .join('\n'),
          ),
        ],
      ],
    );
  }

  Widget _buildNotice({
    required IconData icon,
    required Color background,
    required Color border,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.space4),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: AppSpacing.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppSemanticColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  description,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
