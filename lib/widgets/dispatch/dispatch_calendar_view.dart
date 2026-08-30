import 'package:flutter/material.dart';

import '../../models/dispatch.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/dispatch_algorithm.dart';
import '../seed/seed_button.dart';

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

  /// 펼쳐보기. 접었을 때는 달력이 한 화면에 들어오는 것이 먼저라 이름을 숨기고,
  /// 펼치면 그날 나오는 사람을 칸 안에 다 적는다.
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  const DispatchCalendarView({
    super.key,
    required this.month,
    required this.summary,
    required this.onDateSelected,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onToday,
    this.isExpanded = false,
    required this.onToggleExpanded,
  });

  /// 접었을 때는 날짜와 점만, 펼치면 이름까지 들어가야 하므로 칸이 커진다.
  double get _cellHeight => isExpanded ? 96 : 52;

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
        // 범례는 색 뜻을 처음 볼 때만 필요하다. 접힌 상태에서는 한 화면을 지키는 쪽이 낫다.
        if (isExpanded) ...[
          const SizedBox(height: AppSpacing.space3),
          _buildLegend(),
        ],
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
        SeedButton(
          label: '오늘',
          onPressed: onToday,
          variant: SeedButtonVariant.brandWeak,
          size: SeedButtonSize.xsmall,
        ),
        const Spacer(),
        IconButton(
          onPressed: onToggleExpanded,
          icon: Icon(isExpanded ? Icons.unfold_less : Icons.unfold_more, size: 20),
          tooltip: isExpanded ? '접기' : '펼쳐보기',
          color: AppSemanticColors.textSecondary,
        ),
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
        // 세로로 늘리라고(stretch) 하면 안 된다. 이 달력은 스크롤 목록 안에 들어가
        // 높이가 무한대라, 늘리려는 순간 칸이 무한 높이를 받아 레이아웃이 통째로
        // 무너지고 화면이 빈 채로 남았다. 칸(_DayCell)은 스스로 62의 높이를 가진다.
        return Row(
          children: List.generate(7, (col) {
            final cellIndex = row * 7 + col;
            final day = cellIndex - leadingBlanks + 1;

            if (day < 1 || day > daysInMonth) {
              return Expanded(child: SizedBox(height: _cellHeight));
            }

            final date = DateTime(month.year, month.month, day);
            return Expanded(
              child: _DayCell(
                date: date,
                summary: summary[formatDate(date)],
                height: _cellHeight,
                showNames: isExpanded,
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
  final double height;
  final bool showNames;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.summary,
    required this.height,
    required this.showNames,
    required this.onTap,
  });

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
            height: height,
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
                const SizedBox(height: 1),
                if (isHoliday)
                  Text(
                    '휴무',
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 10,
                      color: AppSemanticColors.textDisabled,
                    ),
                  )
                else ...[
                  if (showNames) ...[
                    _buildDriverNames(),
                    const SizedBox(height: 1),
                  ],
                  _buildDots(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 그날 운전자 이름. 칸이 좁아 세 명까지 적고 나머지는 +N으로 접는다.
  ///
  /// 이름 뒤 직책("이광성팀장")까지 넣으면 칸 폭을 넘겨 "이광성…"으로 잘렸다.
  /// 달력에서 알아야 할 것은 누가 나오는지이지 직책이 아니므로 이름만 남긴다.
  Widget _buildDriverNames() {
    final names = (summary?.driverNames ?? const <String>[]).map(_stripTitle).toList();
    if (names.isEmpty) return const SizedBox(height: 24);

    const visible = 3;
    final shown = names.take(visible).toList();
    final rest = names.length - shown.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final name in shown)
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 9,
              height: 1.2,
              color: AppSemanticColors.textSecondary,
            ),
          ),
        if (rest > 0)
          Text(
            '+$rest',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 9,
              height: 1.2,
              fontWeight: AppTypography.fontWeightSemibold,
              color: AppSemanticColors.interactivePrimaryDefault,
            ),
          ),
      ],
    );
  }

  /// "이광성팀장" -> "이광성". 이름만 남기고 흔한 직책 꼬리를 뗀다.
  static String _stripTitle(String name) {
    const titles = ['팀장', '실장', '부장', '과장', '차장', '대리', '주임', '반장', '소장', '원장', '센터장'];
    for (final t in titles) {
      // 이름이 통째로 직책인 경우까지 지우지 않도록 남는 글자가 두 자 이상일 때만 뗀다
      if (name.endsWith(t) && name.length - t.length >= 2) {
        return name.substring(0, name.length - t.length);
      }
    }
    return name;
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
