import 'package:flutter/material.dart';

import '../models/schedule.dart';
import '../models/schedule_colors.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'common/app_sheet_frame.dart';
import 'seed/seed_button.dart';

/// 접속 시 오늘 일정 알림 (하루 1회).
///
/// B안(2026-11-12): 가운데 창 대신 아래에서 올라오는 시트 — `showAppSheet`로 띄운다
/// (손잡이 → 제목 20/w700 → 설명 → 일정 줄 → 단추 줄 닫기 1 : 일정 보기 1.7).
class TodayScheduleDialog extends StatelessWidget {
  final List<Schedule> schedules;
  final VoidCallback? onViewSchedule;

  const TodayScheduleDialog({
    super.key,
    required this.schedules,
    this.onViewSchedule,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final dateLabel =
        '${now.month}월 ${now.day}일 (${weekdays[now.weekday - 1]})';
    final visible = schedules.take(6).toList();

    return AppSheetFrame(
      title: '오늘 일정 ${schedules.length}건',
      message: '$dateLabel 예정된 일정입니다.',
      actions: AppSheetActions(
        cancel: SeedButton(
          label: '닫기',
          variant: SeedButtonVariant.neutralWeak,
          size: SeedButtonSize.large,
          onPressed: () => Navigator.of(context).pop(),
        ),
        confirm: SeedButton(
          label: '일정 보기',
          variant: SeedButtonVariant.brandSolid,
          size: SeedButtonSize.large,
          onPressed: () {
            Navigator.of(context).pop();
            onViewSchedule?.call();
          },
        ),
      ),
      children: [
        const SizedBox(height: AppSpacing.space4),
        ...visible.map(
          (schedule) => ConstrainedBox(
            // 줄 사이는 선 없이 줄 높이(44 이상)로 나눈다
            constraints: const BoxConstraints(minHeight: AppSpacing.iconCircle),
            child: Row(
              children: [
                Container(
                  width: AppSpacing.space2,
                  height: AppSpacing.space2,
                  decoration: BoxDecoration(
                    color: scheduleDisplayColor(schedule),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.space2_5),
                // 시각 칸은 최소 폭만 잡는다 — 글자가 커져도 숫자가 둘로 갈라지지 않게
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: AppSpacing.space12,
                  ),
                  child: Text(
                    schedule.timeText,
                    maxLines: 1,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppSemanticColors.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.space2),
                Expanded(
                  child: Text(
                    schedule.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
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
            padding: const EdgeInsets.only(top: AppSpacing.space1),
            child: Text(
              '외 ${schedules.length - 6}건',
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
