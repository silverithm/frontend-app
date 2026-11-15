import 'package:flutter/material.dart';

import '../models/schedule.dart';
import '../models/schedule_colors.dart';
import '../theme/app_colors.dart';
import '../theme/app_lines.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'common/app_sheet_frame.dart';
import 'common/member_avatar.dart';
import 'seed/seed_button.dart';

/// 접속 시 오늘 일정 알림 (하루 1회).
///
/// B안(2026-11-12): 가운데 창 대신 아래에서 올라오는 시트 — `showAppSheet`로 띄운다
/// (손잡이 → 제목 18/w700 → 설명 → 일정 줄 → 단추 줄 닫기 1 : 일정 보기 1.7).
/// 2026-11-16: 시각 순으로 줄 세우고, 줄마다 분류·장소·담당과 담당자 사진(줄 사이 선).
class TodayScheduleDialog extends StatelessWidget {
  final List<Schedule> schedules;
  final VoidCallback? onViewSchedule;

  const TodayScheduleDialog({
    super.key,
    required this.schedules,
    this.onViewSchedule,
  });

  static const int _maxRows = 5;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final dateLabel =
        '${now.month}월 ${now.day}일 (${weekdays[now.weekday - 1]})';
    // 시각 순(종일 먼저) — 등록 순서대로 두면 09:30·14:00·11:00처럼 뒤섞였다
    final sorted = [...schedules]..sort(Schedule.compareByTime);
    // 다섯 줄까지 — 줄마다 분류·담당이 붙어 높아져서, 여섯이면 작은 폰(360×640)에서 단추가 화면 밖으로 밀렸다
    final visible = sorted.take(_maxRows).toList();

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
        const SizedBox(height: AppSpacing.space3),
        ...AppLines.between([for (final s in visible) _row(s)]),
        if (schedules.length > _maxRows)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.space2),
            child: Text(
              '외 ${schedules.length - _maxRows}건',
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  /// 한 줄 — 시각(고정 폭, 굵게) | 제목 + '● 분류 · 장소' | 담당 사진.
  Widget _row(Schedule schedule) {
    final color = scheduleDisplayColor(schedule);
    final manager = schedule.managerName?.trim() ?? '';
    final managerIsAdmin = schedule.managerType == 'ADMIN';
    final sub = [
      schedule.categoryText,
      if (schedule.location != null && schedule.location!.trim().isNotEmpty)
        schedule.location!.trim(),
      if (manager.isNotEmpty) '$manager 담당',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2_5),
      child: Row(
        children: [
          // 시각 칸은 최소 폭만 잡는다 — 글자가 커져도 숫자가 둘로 갈라지지 않게
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 52),
            child: Text(
              schedule.timeText,
              maxLines: 1,
              style: AppTypography.titleSmall.copyWith(
                color: AppSemanticColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppSemanticColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppSemanticColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (manager.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.space3),
            MemberAvatar(
              name: manager,
              memberId: managerIsAdmin ? null : schedule.managerId?.toString(),
              adminId: managerIsAdmin ? schedule.managerId?.toString() : null,
              size: 32,
            ),
          ],
        ],
      ),
    );
  }
}
