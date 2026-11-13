import 'package:flutter/material.dart';

import '../../models/dispatch.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_lines.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'dispatch_status_style.dart';
import '../common/app_tag.dart';

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

    // B안 카드 — 테두리 없는 흰 상자, 모서리 16, 안쪽 16, 카드끼리 간격 10
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppBorderRadius.card),
        border: AppLines.cardBorder,
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
                        style: AppTypography.titleMedium.copyWith(
                          color: AppSemanticColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    AppTag(label: dispatch.routeType),
                  ],
                ),
              ),
              AppTag(label: style.label, tone: style.tone, icon: style.icon),
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
                  size: 20,
                  color: AppSemanticColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.space2),
                Text(
                  driver.driverName,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppSemanticColors.textPrimary,
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
                    size: 20,
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
                borderRadius: BorderRadius.circular(AppBorderRadius.control),
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
            // B안: 구분선 대신 간격으로 나눈다
            const SizedBox(height: AppSpacing.space5),
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
                    (senior) => AppTag(
                      label: '${senior.boardingOrder}. ${senior.name}',
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
