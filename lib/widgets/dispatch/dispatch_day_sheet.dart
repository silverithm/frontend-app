import 'package:flutter/material.dart';

import '../../models/dispatch.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'dispatch_route_card.dart';

/// 달력에서 하루를 눌렀을 때 올라오는 그날 배차 상세.
class DispatchDaySheet extends StatelessWidget {
  final DateTime date;
  final DailyDispatch dispatch;

  const DispatchDaySheet({super.key, required this.date, required this.dispatch});

  static Future<void> show(
    BuildContext context, {
    required DateTime date,
    required DailyDispatch dispatch,
  }) {
    // AppBottomSheet.show로 바꾸지 않고 유지: 토큰 스타일(둥근 상단·핸들바)을
    // 이미 자체로 갖췄고, 목록 길이에 따라 늘어나는 DraggableScrollableSheet가
    // 필요한데 AppBottomSheet.show는 고정 높이 Container만 지원해서 대체 불가.
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppSemanticColors.backgroundPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppBorderRadius.xl2),
        ),
      ),
      builder: (_) => DispatchDaySheet(date: date, dispatch: dispatch),
    );
  }

  String get _dateLabel {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${date.month}월 ${date.day}일 (${weekdays[date.weekday - 1]})';
  }

  @override
  Widget build(BuildContext context) {
    final dispatches = dispatch.routeDispatches;
    final isHoliday =
        dispatches.isNotEmpty &&
        dispatches.every((d) => d.status == DispatchStatus.holiday);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: AppSpacing.space2),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppSemanticColors.borderDefault,
                borderRadius: BorderRadius.circular(AppBorderRadius.full),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space5,
                AppSpacing.space4,
                AppSpacing.space5,
                AppSpacing.space2,
              ),
              child: Row(
                children: [
                  Text(
                    _dateLabel,
                    style: AppTypography.heading6.copyWith(
                      color: AppSemanticColors.textPrimary,
                      fontWeight: AppTypography.fontWeightBold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '노선 ${dispatches.length}개',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppSemanticColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isHoliday
                  ? _buildHolidayView()
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.space5,
                        AppSpacing.space2,
                        AppSpacing.space5,
                        AppSpacing.space6,
                      ),
                      itemCount: dispatches.length,
                      itemBuilder: (context, index) =>
                          DispatchRouteCard(dispatch: dispatches[index]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHolidayView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.weekend_outlined,
            size: 40,
            color: AppSemanticColors.textDisabled,
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            '이날은 운행이 없습니다',
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
