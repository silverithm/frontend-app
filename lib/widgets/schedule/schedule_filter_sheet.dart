import 'package:flutter/material.dart';

import '../../models/schedule.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/schedule_filter.dart';
import '../common/app_dialog.dart';
import '../seed/seed_button.dart';
import '../seed/seed_list_cell.dart';

/// 월간일정 '일정 필터' 시트를 연다 — 웹 월간일정의 일정 필터 팝오버와 같은 두 묶음.
///
/// 고르는 즉시 [onChanged]로 달력에 반영한다(웹 팝오버와 같은 즉시 적용).
/// 시트를 닫을 '확인'은 되돌리기가 아니라 그냥 닫기다.
Future<void> showScheduleFilterSheet(
  BuildContext context, {
  required List<String> values,
  required ValueChanged<List<String>> onChanged,
  required List<Schedule> monthSchedules,
  required List<ScheduleLabel> labels,
  required bool Function(Schedule) isMine,
  String? Function(String personKey)? fallbackName,
}) {
  return AppBottomSheet.show<void>(
    context,
    title: '일정 필터',
    // 담당자·구분이 많은 기관에서 시트가 화면 높이를 넘으면 안쪽에서 스크롤한다
    isScrollControlled: true,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: ScheduleFilterSheet(
        initialValues: values,
        onChanged: onChanged,
        monthSchedules: monthSchedules,
        labels: labels,
        isMine: isMine,
        fallbackName: fallbackName,
      ),
    ),
  );
}

class ScheduleFilterSheet extends StatefulWidget {
  final List<String> initialValues;
  final ValueChanged<List<String>> onChanged;

  /// 보고 있는 달의 일정 전체(필터 걸기 전) — 담당자 목록과 완료 수를 여기서 센다
  final List<Schedule> monthSchedules;

  /// 기관이 만든 일정 구분
  final List<ScheduleLabel> labels;
  final bool Function(Schedule) isMine;
  final String? Function(String personKey)? fallbackName;

  const ScheduleFilterSheet({
    super.key,
    required this.initialValues,
    required this.onChanged,
    required this.monthSchedules,
    required this.labels,
    required this.isMine,
    this.fallbackName,
  });

  @override
  State<ScheduleFilterSheet> createState() => _ScheduleFilterSheetState();
}

class _ScheduleFilterSheetState extends State<ScheduleFilterSheet> {
  late List<String> _values = List.of(widget.initialValues);

  void _toggle(String value) {
    setState(() {
      _values = _values.contains(value)
          ? (_values.where((v) => v != value).toList())
          : [..._values, value];
    });
    widget.onChanged(_values);
  }

  void _clear() {
    setState(() => _values = []);
    widget.onChanged(_values);
  }

  @override
  Widget build(BuildContext context) {
    // 일정 구분을 골라 두면 담당자 옆 숫자도 그 구분 안에서 센다 — 목록과 달력이 같은 일정을 말한다
    final kindMatched = widget.monthSchedules
        .where((s) => matchesKindFilter(s, _values))
        .toList();
    final people = collectPersonOptions(
      kindMatched,
      _values,
      fallbackName: widget.fallbackName,
    );
    final mine = kindMatched.where(widget.isMine).toList();

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space4,
                AppSpacing.space1,
                AppSpacing.space4,
                AppSpacing.space4,
              ),
              children: [
                SeedListSection(
                  title: '담당자',
                  children: [
                    _FilterRow(
                      label: '나',
                      checked: _values.contains(kMySchedulesFilter),
                      trailing: _doneText(
                        mine.where((s) => s.isCompleted).length,
                        mine.length,
                      ),
                      onTap: () => _toggle(kMySchedulesFilter),
                    ),
                    for (final person in people)
                      _FilterRow(
                        label: person.name,
                        checked: _values.contains(personFilterValue(person.key)),
                        trailing: _doneText(person.done, person.total),
                        onTap: () => _toggle(personFilterValue(person.key)),
                      ),
                  ],
                ),
                if (people.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.space2,
                      left: AppSpacing.space1,
                    ),
                    child: Text(
                      '이 달에는 담당자를 정한 일정이 없습니다',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppSemanticColors.textTertiary,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.space2),
                SeedListSection(
                  title: '일정 구분',
                  children: [
                    for (final label in widget.labels)
                      _FilterRow(
                        label: label.name,
                        checked: _values.contains(labelFilterValue(label.id)),
                        onTap: () => _toggle(labelFilterValue(label.id)),
                      ),
                    _FilterRow(
                      label: '구분 없음',
                      checked: _values.contains(kNoLabelFilter),
                      onTap: () => _toggle(kNoLabelFilter),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 아래 단추 줄 — B안: 위 선 없이 흰 띠, 보조 단추는 회색 채움, 큰 단추(54)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space5,
              AppSpacing.space2,
              AppSpacing.space5,
              AppSpacing.space3,
            ),
            child: Row(
              children: [
                Expanded(
                  child: SeedButton(
                    label: '모두 해제',
                    variant: SeedButtonVariant.neutralWeak,
                    size: SeedButtonSize.large,
                    isDisabled: _values.isEmpty,
                    onPressed: _clear,
                  ),
                ),
                const SizedBox(width: AppSpacing.space2),
                Expanded(
                  child: SeedButton(
                    label: '확인',
                    variant: SeedButtonVariant.brandSolid,
                    size: SeedButtonSize.large,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 이름 옆 숫자 — 그 사람이 맡은 이번 달 일정 중 수행완료된 수
  Widget _doneText(int done, int total) {
    return Text(
      total > 0 ? '완료 $done/$total' : '일정 없음',
      style: AppTypography.bodySmall.copyWith(
        color: AppSemanticColors.textTertiary,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// 체크 한 줄 — 줄 전체가 눌린다(체크 칸만 노리지 않게).
class _FilterRow extends StatelessWidget {
  final String label;
  final bool checked;
  final Widget? trailing;
  final VoidCallback onTap;

  const _FilterRow({
    required this.label,
    required this.checked,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.space4),
            child: Row(
              children: [
                // 기본 Checkbox는 미체크일 때 검은 2px 테두리라 틸 앱 톤에서 튄다
                // (채팅방 만들기의 사람 고르기와 같은 모양).
                Checkbox(
                  value: checked,
                  onChanged: (_) => onTap(),
                  activeColor: AppSemanticColors.interactivePrimaryDefault,
                  checkColor: AppSemanticColors.textInverse,
                  side: const BorderSide(
                    color: AppSemanticColors.borderHover,
                    width: 1.5,
                  ),
                ),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppSemanticColors.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.space2),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
