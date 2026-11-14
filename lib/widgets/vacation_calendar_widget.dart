import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vacation_request.dart';
import '../providers/vacation_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/korean_holidays.dart';
import '../utils/role_utils.dart';
import 'calendar/month_chip_grid.dart';
import 'seed/seed_chip.dart';

/// 근무조정 달력 — 크로박스 홈 달력처럼 화면을 꽉 채운다(2026-11-14 시안).
///
/// 머리줄(큰 달 이름 · ‹ › · 펼치기 · 오늘) → 직종 칩 → 꽉 찬 달력.
/// 칸마다 휴무자 이름을 상태 색 칩으로(승인 연두 · 대기 노랑 · 거절 옅게), 넘치면 '+n'.
/// 예전엔 점만 찍고 '휴무자 이름 표시 [보기]'를 눌러야 이름이 보였다.
/// 고른 날·시트·펼치기는 화면(calendar_screen)이 들고 있고, 이 위젯은 그리기만 한다.
class VacationCalendarWidget extends StatelessWidget {
  final DateTime currentDate;
  final DateTime? selectedDate;
  final bool showSelection;
  final bool expanded;
  final bool sheetOpen;
  final double bodyHeight;
  final DraggableScrollableController sheet;
  final double sheetSplit;
  final ValueChanged<int> onMoveMonth;
  final VoidCallback onToday;
  final VoidCallback onToggleExpanded;
  final ValueChanged<DateTime> onDayTap;

  /// 직종 다중 선택 (빈 목록 = 전체)
  final List<String> roleFilters;
  final Function(List<String>)? onRoleFiltersChanged;

  const VacationCalendarWidget({
    super.key,
    required this.currentDate,
    required this.selectedDate,
    required this.showSelection,
    required this.expanded,
    required this.sheetOpen,
    required this.bodyHeight,
    required this.sheet,
    required this.sheetSplit,
    required this.onMoveMonth,
    required this.onToday,
    required this.onToggleExpanded,
    required this.onDayTap,
    this.roleFilters = const [],
    this.onRoleFiltersChanged,
  });

  // 직종별 한도(limit) 기반 색상·카운트는 한도가 정의되는 단일 선택일 때만 의미가 있다
  bool get _isSingleRole => roleFilters.length == 1;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final vacationProvider = context.watch<VacationProvider>();
    return Column(
      children: [
        CalendarHeaderBar(
          month: currentDate,
          onPrevious: () => onMoveMonth(-1),
          onNext: () => onMoveMonth(1),
          onToday: onToday,
          expanded: expanded,
          onToggleExpanded: onToggleExpanded,
        ),

        // 직종 거르기 칩 — 작은 칩(32), 옆으로 밀어 본다
        if (onRoleFiltersChanged != null)
          SizedBox(
            height: 44,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space4,
                vertical: AppSpacing.space1,
              ),
              child: Row(
                children: [
                  _roleChip(RoleUtils.allRole, '전체'),
                  // 관리자 화면에서 만든 역할까지 그대로 노출
                  for (final role in vacationProvider.availableRoles) ...[
                    const SizedBox(width: AppSpacing.space1_5),
                    _roleChip(role, RoleUtils.displayName(role)),
                  ],
                ],
              ),
            ),
          ),

        Expanded(
          child: MonthChipGrid(
            month: currentDate,
            selected: selectedDate,
            showSelection: showSelection,
            expanded: expanded,
            sheetOpen: sheetOpen,
            bodyHeight: bodyHeight,
            sheet: sheet,
            sheetSplit: sheetSplit,
            onTapDay: onDayTap,
            onSwipeMonth: onMoveMonth,
            chipsFor: (date) => [
              for (final v in vacationProvider.getVacationsForDate(date))
                vacationChip(v),
            ],
            holidayFor: (date) => KoreanHolidays.getHolidayName(date) != null,
            // 직종 하나를 고르면 여유(옅은 초록)·초과(옅은 빨강) 바탕 — 예전 그대로
            tintFor: _isSingleRole
                ? (date) => vacationProvider.isDateAvailable(date)
                      ? AppSemanticColors.statusSuccessBackground
                      : AppSemanticColors.statusErrorBackground
                : null,
            badgeFor: (date) => _badge(vacationProvider, date),
            // 직종 하나를 고르면 칸 맨 아래에 '인원/한도'(예전엔 날짜와 겹치는 오른쪽 위였다)
            footerFor: _isSingleRole
                ? (date) => Text(
                    '${vacationProvider.getVacationCountForDate(date)}/${vacationProvider.getVacationLimitForDate(date)}',
                    style: AppTypography.calendarCell.copyWith(
                      height: 1.1,
                      fontWeight: AppTypography.fontWeightBold,
                      color: vacationProvider.isDateAvailable(date)
                          ? AppSemanticColors.statusSuccessText
                          : AppSemanticColors.statusErrorText,
                    ),
                  )
                : null,
            // '다음 달만 받기'가 켜져 있으면 이 날짜로는 신청할 수 없음을 옅게(탭은 막지 않는다)
            dimFor: (date) =>
                vacationProvider.isNextMonthOnly &&
                !vacationProvider.isDateAllowedForRequest(date),
          ),
        ),
      ],
    );
  }

  Widget _roleChip(String role, String label) {
    final normalized = RoleUtils.normalize(role);
    final isSelected = normalized == RoleUtils.allRole
        ? roleFilters.isEmpty
        : roleFilters.contains(normalized);
    return SeedChip(
      label: label,
      selected: isSelected,
      size: SeedChipSize.small,
      onTap: () {
        final current = List<String>.from(roleFilters);
        if (normalized == RoleUtils.allRole) {
          current.clear();
        } else if (current.contains(normalized)) {
          current.remove(normalized);
        } else {
          current.add(normalized);
        }
        onRoleFiltersChanged?.call(current);
      },
    );
  }

  /// 칸 오른쪽 위 — 마감일 별 · 중요 행사 핀.
  Widget? _badge(VacationProvider provider, DateTime date) {
    final deadline = provider.deadlineForMonth(
      DateTime(date.year, date.month, 1),
    );
    final isDeadlineDay = deadline != null && _sameDay(deadline, date);
    final hasEvent = provider.eventsForDate(date).isNotEmpty;
    final marks = <Widget>[
      if (isDeadlineDay)
        const Icon(
          Icons.star_rounded,
          size: 11,
          color: AppSemanticColors.statusWarningIcon,
        ),
      if (hasEvent)
        const Icon(
          Icons.push_pin_rounded,
          size: 10,
          color: AppColors.purple600,
        ),
    ];
    if (marks.isEmpty) return null;
    return Row(mainAxisSize: MainAxisSize.min, children: marks);
  }

  /// 휴무자 한 사람의 칩 — 승인 연두 · 대기 노랑 · 거절 옅은 빨강(흐리게), 끝에 연·반·필수 표시.
  static CalendarChipData vacationChip(VacationRequest v) {
    final Color color;
    switch (v.status) {
      case VacationStatus.approved:
        color = AppColors.green200;
      case VacationStatus.pending:
        color = AppColors.yellow200;
      case VacationStatus.rejected:
        color = AppColors.red200;
    }
    return CalendarChipData(
      label: v.userName,
      color: color,
      faded: v.status == VacationStatus.rejected,
      trailing: vacationKindMark(v),
    );
  }

  /// 연차 '연' · 반차 '반' · 필수 별 — 칩 끝의 작은 표시(연차를 쓰지 않는 휴무는 없음).
  static Widget? vacationKindMark(
    VacationRequest vacation, {
    double size = 10,
  }) {
    if (vacation.type == VacationType.mandatory) {
      return CustomPaint(
        painter: StarPainter(color: AppSemanticColors.statusWarningIcon),
        size: Size(size, size),
      );
    }
    if (vacation.duration == VacationDuration.unused) return null;
    final full = vacation.duration == VacationDuration.fullDay;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white.withValues(alpha: 0.85),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          full ? '연' : '반',
          style: AppTypography.calendarCell.copyWith(
            height: 1,
            color: full
                ? AppSemanticColors.statusInfoText
                : AppSemanticColors.statusWarningText,
          ),
        ),
      ),
    );
  }
}

/// 색 안내 — 그날 시트 아래에 둔다(달력 판을 넓게 쓰려고 판 밖으로 뺐다).
class VacationCalendarLegend extends StatelessWidget {
  const VacationCalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final labelStyle = AppTypography.bodySmall.copyWith(
      color: AppSemanticColors.textSecondary,
    );
    Widget item(Widget sample, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        sample,
        const SizedBox(width: AppSpacing.space1),
        Text(label, style: labelStyle),
      ],
    );
    Widget swatch(Color color, {bool faded = false}) => Opacity(
      opacity: faded ? 0.45 : 1,
      child: Container(
        width: 18,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
    Widget letter(String t, Color fg) => Container(
      width: 14,
      height: 14,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppSemanticColors.fillDefault,
      ),
      child: Text(
        t,
        style: AppTypography.calendarCell.copyWith(height: 1, color: fg),
      ),
    );
    return Wrap(
      spacing: AppSpacing.space3,
      runSpacing: AppSpacing.space1_5,
      children: [
        item(swatch(AppColors.green200), '승인'),
        item(swatch(AppColors.yellow200), '대기'),
        item(swatch(AppColors.red200, faded: true), '거절'),
        item(letter('연', AppSemanticColors.statusInfoText), '연차'),
        item(letter('반', AppSemanticColors.statusWarningText), '반차'),
        item(
          CustomPaint(
            painter: StarPainter(color: AppSemanticColors.statusWarningIcon),
            size: const Size(12, 12),
          ),
          '필수',
        ),
      ],
    );
  }
}

// 별표 그리기를 위한 CustomPainter
class StarPainter extends CustomPainter {
  final Color color;

  StarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.4;

    for (int i = 0; i < 10; i++) {
      // -90도부터 시작하여 별표가 위를 향하도록 수정
      final angle = ((i * 36) - 90) * (3.14159 / 180);
      final radius = i % 2 == 0 ? outerRadius : innerRadius;
      final x = centerX + radius * math.cos(angle);
      final y = centerY + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
