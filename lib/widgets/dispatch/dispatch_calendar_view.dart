import 'package:flutter/material.dart';

import '../../models/dispatch.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/dispatch_algorithm.dart';

/// 한 달 배차 현황 달력.
///
/// 칸마다 그날 노선이 어떻게 돌아가는지를 점 세 개(정상/대체/운행없음)로 요약한다.
/// 숫자를 다 적으면 폰 화면에서 읽히지 않아 색점으로 줄였고, 대체나 운행없음이
/// 있는 날만 눈에 띄도록 테두리를 준다.
class DispatchCalendarView extends StatelessWidget {
  final DateTime month;
  final Map<String, DispatchDaySummary> summary;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToday;

  const DispatchCalendarView({
    super.key,
    required this.month,
    required this.summary,
    required this.onDateSelected,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        const SizedBox(height: AppSpacing.space3),
        _buildWeekdayRow(),
        const SizedBox(height: AppSpacing.space1),
        _buildGrid(),
        const SizedBox(height: AppSpacing.space4),
        _buildLegend(),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Text(
          '${month.year}년 ${month.month}월',
          style: AppTypography.heading6.copyWith(
            color: AppSemanticColors.textPrimary,
            fontWeight: AppTypography.fontWeightBold,
          ),
        ),
        const SizedBox(width: AppSpacing.space2),
        TextButton(
          onPressed: onToday,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
            visualDensity: VisualDensity.compact,
          ),
          child: Text(
            '오늘',
            style: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.textLink,
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onPreviousMonth,
          icon: const Icon(Icons.chevron_left),
          tooltip: '이전 달',
          color: AppSemanticColors.textSecondary,
        ),
        IconButton(
          onPressed: onNextMonth,
          icon: const Icon(Icons.chevron_right),
          tooltip: '다음 달',
          color: AppSemanticColors.textSecondary,
        ),
      ],
    );
  }

  Widget _buildWeekdayRow() {
    const labels = ['일', '월', '화', '수', '목', '금', '토'];
    return Row(
      children: List.generate(7, (index) {
        return Expanded(
          child: Center(
            child: Text(
              labels[index],
              style: AppTypography.bodySmall.copyWith(
                color: index == 0
                    ? AppSemanticColors.statusErrorText
                    : AppSemanticColors.textTertiary,
                fontWeight: AppTypography.fontWeightMedium,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildGrid() {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    // DateTime.weekday는 월=1 … 일=7이라 일요일 시작 달력에서는 앞 칸 수가 이만큼이다
    final leadingBlanks = firstDay.weekday % 7;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(7, (col) {
            final cellIndex = row * 7 + col;
            final day = cellIndex - leadingBlanks + 1;

            if (day < 1 || day > daysInMonth) {
              return const Expanded(child: SizedBox(height: 62));
            }

            final date = DateTime(month.year, month.month, day);
            return Expanded(
              child: _DayCell(
                date: date,
                summary: summary[formatDate(date)],
                onTap: () => onDateSelected(date),
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: AppSpacing.space4,
      runSpacing: AppSpacing.space2,
      children: const [
        _LegendItem(color: AppSemanticColors.statusSuccessIcon, label: '정상'),
        _LegendItem(color: AppSemanticColors.statusWarningIcon, label: '대체'),
        _LegendItem(color: AppSemanticColors.statusErrorIcon, label: '운행없음'),
        _LegendItem(color: AppSemanticColors.textDisabled, label: '휴일'),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final DispatchDaySummary? summary;
  final VoidCallback onTap;

  const _DayCell({required this.date, required this.summary, required this.onTap});

  bool get _isToday {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final isSunday = date.weekday == DateTime.sunday;
    final isHoliday = summary?.isHoliday ?? isSunday;

    // 손볼 일이 있는 날(대체·운행없음)만 테두리로 도드라지게 한다
    final needsAttention =
        (summary?.substituteCount ?? 0) > 0 || (summary?.noServiceCount ?? 0) > 0;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: isHoliday
            ? AppSemanticColors.backgroundTertiary
            : AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          child: Container(
            height: 62,
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.space1,
              horizontal: AppSpacing.space1,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              border: Border.all(
                color: _isToday
                    ? AppSemanticColors.borderFocus
                    : needsAttention
                    ? AppSemanticColors.statusWarningBorder
                    : AppSemanticColors.borderSubtle,
                width: _isToday ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: AppTypography.bodySmall.copyWith(
                    color: isSunday
                        ? AppSemanticColors.statusErrorText
                        : AppSemanticColors.textPrimary,
                    fontWeight: _isToday
                        ? AppTypography.fontWeightBold
                        : AppTypography.fontWeightMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.space1),
                if (isHoliday)
                  Text(
                    '휴무',
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 10,
                      color: AppSemanticColors.textDisabled,
                    ),
                  )
                else
                  _buildDots(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDots() {
    final s = summary;
    if (s == null || s.totalRoutes == 0) {
      return const SizedBox(height: 6);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (s.normalCount > 0)
          _Dot(
            color: AppSemanticColors.statusSuccessIcon,
            count: s.normalCount,
          ),
        if (s.substituteCount > 0)
          _Dot(
            color: AppSemanticColors.statusWarningIcon,
            count: s.substituteCount,
          ),
        if (s.noServiceCount > 0)
          _Dot(color: AppSemanticColors.statusErrorIcon, count: s.noServiceCount),
      ],
    );
  }
}

/// 노선 수만큼 점을 찍되, 많으면 화면이 지저분해지므로 3개까지만 찍고 나머지는 숫자로
class _Dot extends StatelessWidget {
  final Color color;
  final int count;

  const _Dot({required this.color, required this.count});

  @override
  Widget build(BuildContext context) {
    final dots = count > 3 ? 1 : count;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < dots; i++)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          if (count > 3)
            Text(
              '$count',
              style: AppTypography.bodySmall.copyWith(fontSize: 10, color: color),
            ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.space1_5),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppSemanticColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
