import 'package:flutter/material.dart';

import '../../models/dispatch.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'dispatch_status_style.dart';

/// 노선 하나의 그날 배차 결과 카드.
/// 달력 상세와 목록 화면이 같은 카드를 쓴다 — 같은 정보를 두 모양으로 보여줄 이유가 없다.
class DispatchRouteCard extends StatelessWidget {
  final RouteDispatch dispatch;

  /// 탑승 어르신 명단을 펼쳐 보일지. 목록 화면에서는 접어 둔다.
  final bool showPassengers;

  const DispatchRouteCard({
    super.key,
    required this.dispatch,
    this.showPassengers = true,
  });

  @override
  Widget build(BuildContext context) {
    final style = DispatchStatusStyle.of(dispatch.status);
    final driver = dispatch.driver;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space3),
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(color: AppSemanticColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        dispatch.routeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppSemanticColors.textPrimary,
                          fontWeight: AppTypography.fontWeightSemibold,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    _Chip(
                      label: dispatch.routeType,
                      foreground: AppSemanticColors.textSecondary,
                      background: AppSemanticColors.backgroundTertiary,
                    ),
                  ],
                ),
              ),
              _Chip(
                label: style.label,
                foreground: style.foreground,
                background: style.background,
                icon: style.icon,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),

          if (driver == null)
            Text(
              dispatch.reason ?? '운행 없음',
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            )
          else ...[
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 18,
                  color: AppSemanticColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.space2),
                Text(
                  driver.driverName,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textPrimary,
                    fontWeight: AppTypography.fontWeightMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.space2),
                Text(
                  dispatch.driverRole ?? '',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
              ],
            ),
            if (driver.vehicleName.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.space1_5),
              Row(
                children: [
                  Icon(
                    Icons.directions_bus_outlined,
                    size: 18,
                    color: AppSemanticColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Text(
                    driver.vehicleName,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ],

          // 대체 운행이면 원래 누가 몰던 자리인지 밝힌다. 이유 없이 사람이 바뀌면 현장이 혼란스럽다.
          if (dispatch.status == DispatchStatus.substitute &&
              dispatch.originalMainDriver != null) ...[
            const SizedBox(height: AppSpacing.space2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space3,
                vertical: AppSpacing.space2,
              ),
              decoration: BoxDecoration(
                color: AppSemanticColors.statusWarningBackground,
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              ),
              child: Text(
                '주운전자 ${dispatch.originalMainDriver!.driverName} 휴무로 대체',
                style: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.statusWarningText,
                ),
              ),
            ),
          ],

          if (showPassengers && dispatch.passengers.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.space3),
            Divider(height: 1, color: AppSemanticColors.borderSubtle),
            const SizedBox(height: AppSpacing.space3),
            Text(
              '탑승 어르신 ${dispatch.passengers.length}명',
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.space2),
            Wrap(
              spacing: AppSpacing.space2,
              runSpacing: AppSpacing.space2,
              children: dispatch.passengers
                  .map(
                    (senior) => _Chip(
                      label: '${senior.boardingOrder}. ${senior.name}',
                      foreground: AppSemanticColors.textSecondary,
                      background: AppSemanticColors.backgroundSecondary,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  const _Chip({
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space2,
        vertical: AppSpacing.space1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: AppSpacing.space1),
          ],
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 11,
              color: foreground,
              fontWeight: AppTypography.fontWeightMedium,
            ),
          ),
        ],
      ),
    );
  }
}
