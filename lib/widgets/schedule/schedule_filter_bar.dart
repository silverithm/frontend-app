import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../seed/seed_chip.dart';

/// 월간일정 달 이동 줄 아래 한 줄 — '일정 필터' 칩과 이번 달 수행완료 수.
///
/// 담당자를 고르면 칩이 '일정 필터 · 김민지'로 길어진다. 예전엔 Row에 Spacer와 나란히 둬서
/// 칩이 남은 폭의 절반만 받고 칩 안 글자가 넘쳤다(2단계 뒤 21px, 2026-11-12). 이제 한 줄에
/// 둘이 안 들어가면 완료 수가 다음 줄로 내려가고, 칩 하나가 줄보다 넓을 때(글자를 아주 크게
/// 했을 때)만 칩을 줄 폭에 맞춰 줄인다 — 평소 크기에서는 그대로다.
class ScheduleFilterBar extends StatelessWidget {
  const ScheduleFilterBar({
    super.key,
    required this.label,
    required this.filtered,
    required this.onTap,
    required this.done,
    required this.total,
    this.showProgress = true,
  });

  /// 칩 글자 — scheduleFilterButtonLabel()이 만든 것
  final String label;

  /// 필터를 걸었는지(칩이 틸로 채워진다)
  final bool filtered;
  final VoidCallback onTap;

  /// 걸린 일정 중 수행완료 수 / 걸린 일정 수
  final int done;
  final int total;

  /// 이번 달 일정이 하나도 없으면 완료 수를 그리지 않는다
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        AppSpacing.space2,
        AppSpacing.space4,
        AppSpacing.space2,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.space2,
        runSpacing: AppSpacing.space1,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: SeedChip(
              label: label,
              selected: filtered,
              size: SeedChipSize.small,
              prefixIcon: Icons.filter_list,
              onTap: onTap,
            ),
          ),
          if (showProgress)
            Semantics(
              label: '${filtered ? '필터한' : '이번 달'} 일정 '
                  '$total건 중 $done건 수행완료',
              excludeSemantics: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AppSemanticColors.statusSuccessIcon,
                  ),
                  const SizedBox(width: AppSpacing.space1),
                  Text(
                    '완료 $done/$total',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppSemanticColors.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
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
