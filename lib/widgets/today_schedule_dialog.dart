import 'package:flutter/material.dart';

import '../models/schedule.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'seed/seed_button.dart';

/// 접속 시 오늘 일정 알림 팝업 (하루 1회).
/// AppDialog.showCustom으로 감싸서 띄운다.
class TodayScheduleDialog extends StatelessWidget {
  final List<Schedule> schedules;
  final VoidCallback? onViewSchedule;

  const TodayScheduleDialog({
    super.key,
    required this.schedules,
    this.onViewSchedule,
  });

  Color _labelColor(Schedule schedule) {
    final hex = schedule.label?.color;
    if (hex == null || hex.isEmpty) {
      return AppSemanticColors.interactivePrimaryDefault;
    }
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return AppSemanticColors.interactivePrimaryDefault;
    return Color(cleaned.length == 8 ? value : 0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final dateLabel =
        '${now.month}월 ${now.day}일 (${weekdays[now.weekday - 1]})';
    final visible = schedules.take(6).toList();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.space6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('오늘 일정 ${schedules.length}건', style: AppTypography.heading5),
          const SizedBox(height: AppSpacing.space1),
          Text(
            '$dateLabel 예정된 일정입니다.',
            style: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          ...visible.map(
            (schedule) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space3),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _labelColor(schedule),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  SizedBox(
                    width: 44,
                    child: Text(
                      schedule.timeText,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppSemanticColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: Text(
                      schedule.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppSemanticColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (schedules.length > 6)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space2),
              child: Text(
                '외 ${schedules.length - 6}건',
                style: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.space4),
          Row(
            children: [
              Expanded(
                child: SeedButton(
                  label: '닫기',
                  variant: SeedButtonVariant.neutralWeak,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              Expanded(
                child: SeedButton(
                  label: '일정 보기',
                  variant: SeedButtonVariant.brandSolid,
                  onPressed: () {
                    Navigator.of(context).pop();
                    onViewSchedule?.call();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
