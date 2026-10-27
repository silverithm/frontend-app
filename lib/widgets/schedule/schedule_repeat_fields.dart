import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/schedule_repeat.dart';
import '../seed/seed_chip.dart';

/// 일정 등록 시트의 "반복" 칸 — 반복 안 함 / 매주(요일 고르기) / 매월 같은 날짜.
/// 서버에는 반복이 없어, 등록할 때 날짜마다 일정 한 건씩 만든다(웹 ScheduleRepeatFields와 같은 규칙).
class ScheduleRepeatFields extends StatelessWidget {
  final DateTime startDate;
  final ScheduleRepeatRule value;
  final ValueChanged<ScheduleRepeatRule> onChanged;

  const ScheduleRepeatFields({
    super.key,
    required this.startDate,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dates = value.isRepeating
        ? expandScheduleRepeatDates(startDate, value)
        : const <DateTime>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '반복',
          style: AppTypography.titleSmall.copyWith(
            color: AppSemanticColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.space2),
        Wrap(
          spacing: AppSpacing.space2,
          runSpacing: AppSpacing.space2,
          children: [
            _kindChip('반복 안 함', ScheduleRepeatKind.none),
            _kindChip('매주', ScheduleRepeatKind.weekly),
            _kindChip('매월 같은 날짜', ScheduleRepeatKind.monthly),
          ],
        ),
        if (value.kind == ScheduleRepeatKind.weekly) ...[
          const SizedBox(height: AppSpacing.space3),
          _buildWeekdayPicker(),
        ],
        if (value.isRepeating) ...[
          const SizedBox(height: AppSpacing.space4),
          _buildUntilField(context),
          const SizedBox(height: AppSpacing.space2),
          ..._buildSummary(dates),
        ],
      ],
    );
  }

  Widget _kindChip(String label, ScheduleRepeatKind kind) {
    return SeedChip(
      label: label,
      selected: value.kind == kind,
      onTap: () => onChanged(
        kind == ScheduleRepeatKind.none
            ? ScheduleRepeatRule.none
            : value.copyWith(kind: kind),
      ),
    );
  }

  Widget _buildWeekdayPicker() {
    final selected = value.weekdaysFor(startDate);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final weekday in scheduleRepeatWeekdayOrder)
          _WeekdayButton(
            label: scheduleRepeatWeekdayName(weekday),
            selected: selected.contains(weekday),
            onTap: () {
              final next = {...selected};
              if (!next.remove(weekday)) next.add(weekday);
              // 마지막 하나를 끄면 시작일 요일로 돌아간다 — 요일 없는 매주는 없다
              onChanged(value.copyWith(weekdays: next));
            },
          ),
      ],
    );
  }

  Widget _buildUntilField(BuildContext context) {
    final until = value.until;
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: until != null && !until.isBefore(startDate)
              ? until
              : startDate,
          firstDate: startDate,
          lastDate: DateTime(2030),
        );
        if (picked != null) onChanged(value.copyWith(until: picked));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '반복 끝나는 날',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          ),
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          until == null ? '골라 주세요' : formatScheduleRepeatDay(until),
          style: AppTypography.bodyMedium.copyWith(
            color: until == null
                ? AppSemanticColors.textTertiary
                : AppSemanticColors.textPrimary,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSummary(List<DateTime> dates) {
    final until = value.until;
    if (until == null) {
      return [_note('반복이 끝나는 날을 골라 주세요', warn: true)];
    }
    if (until.isBefore(
      DateTime(startDate.year, startDate.month, startDate.day),
    )) {
      return [_note('끝나는 날이 시작일보다 빠릅니다', warn: true)];
    }
    final capped = dates.length >= maxScheduleRepeatCount;
    return [
      _note(
        '${describeScheduleRepeat(value, startDate, dates.length)}'
        ' · ${formatScheduleRepeatRange(dates.first, dates.last)}'
        '${capped ? ' (최대 $maxScheduleRepeatCount건까지만 등록합니다)' : ''}',
      ),
      if (value.kind == ScheduleRepeatKind.monthly && startDate.day > 28)
        _note('${startDate.day}일이 없는 달은 건너뜁니다'),
    ];
  }

  Widget _note(String text, {bool warn = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space1),
      child: Text(
        text,
        style: AppTypography.bodySmall.copyWith(
          color: warn
              ? AppSemanticColors.statusErrorText
              : AppSemanticColors.textSecondary,
        ),
      ),
    );
  }
}

/// "10/20 (화)" — 올해가 아니면 "2027. 3/31 (수)"
String formatScheduleRepeatDay(DateTime d, {DateTime? now}) {
  final thisYear = (now ?? DateTime.now()).year;
  final yearPrefix = d.year == thisYear ? '' : '${d.year}. ';
  return '$yearPrefix${d.month}/${d.day} (${scheduleRepeatWeekdayName(d.weekday)})';
}

/// "10/20 ~ 12/31" — 올해가 아닌 날은 해를 붙인다
String formatScheduleRepeatRange(
  DateTime first,
  DateTime last, {
  DateTime? now,
}) {
  final thisYear = (now ?? DateTime.now()).year;
  String day(DateTime d) =>
      '${d.year == thisYear ? '' : '${d.year}. '}${d.month}/${d.day}';
  return '${day(first)} ~ ${day(last)}';
}

class _WeekdayButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _WeekdayButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label요일',
      excludeSemantics: true,
      child: Material(
        color: selected
            ? AppSemanticColors.brandDefault
            : AppSemanticColors.interactiveSecondaryDefault,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Text(
                label,
                style: (selected ? AppTypography.titleSmall : AppTypography.bodyMedium)
                    .copyWith(
                  color: selected
                      ? AppSemanticColors.textInverse
                      : AppSemanticColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
