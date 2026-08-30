import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/dispatch.dart';
import '../../providers/dispatch_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/dispatch_algorithm.dart';
import '../../utils/dispatch_board_text.dart';

/// 노선배차표 — 하루치 배차를 한 화면에 본다.
///
/// 센터장이 매일 카톡방에 올리던 표를 그대로 옮긴 화면이다. 선생님들이 앱에서
/// "오늘 우리 차 누가 타지"를 스크롤 없이 확인하는 것이 목적이라, 노선 목록이 아니라
/// 차량-회차-명단 한 덩어리로 조밀하게 보여준다.
///
/// 규칙과 문구는 관리자 웹(DispatchBoard.tsx / dispatchBoardText.ts)과 같다.
class DispatchBoardView extends StatefulWidget {
  const DispatchBoardView({super.key});

  @override
  State<DispatchBoardView> createState() => _DispatchBoardViewState();
}

class _DispatchBoardViewState extends State<DispatchBoardView> {
  late DateTime _date;
  String _routeType = RouteType.toWork;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime(_date.year + 1),
      locale: const Locale('ko'),
    );
    if (picked == null || !mounted) return;

    // 달이 바뀌었는지는 상태를 바꾸기 전에 봐야 한다
    final movedToAnotherMonth =
        picked.month != _date.month || picked.year != _date.year;

    setState(() => _date = picked);

    if (movedToAnotherMonth) {
      await context.read<DispatchProvider>().loadAttendancesForMonth(picked);
    }
  }

  Future<void> _copyText(DailyDispatch daily) async {
    await Clipboard.setData(
      ClipboardData(text: buildDispatchBoardText(daily, _routeType)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('배차표를 복사했습니다')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DispatchProvider>();
    final daily = provider.dispatchForDate(_date);
    final dispatches = selectRouteDispatches(daily, _routeType);
    final personal = _routeType == RouteType.toWork
        ? daily.personalPickupSeniors
        : daily.personalDropoffSeniors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildControls(daily),
        _buildHeader(daily, personal),
        Expanded(
          child: dispatches.isEmpty
              ? Center(
                  child: Text(
                    '$_routeType 노선이 없습니다',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppSemanticColors.textTertiary,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space4,
                    0,
                    AppSpacing.space4,
                    AppSpacing.space4,
                  ),
                  itemCount: dispatches.length,
                  itemBuilder: (_, index) =>
                      _RouteBlock(dispatch: dispatches[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildControls(DailyDispatch daily) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        0,
        AppSpacing.space4,
        AppSpacing.space2,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(formatBoardDate(formatDate(_date))),
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          _DirectionToggle(
            value: _routeType,
            onChanged: (value) => setState(() => _routeType = value),
          ),
          const SizedBox(width: AppSpacing.space2),
          IconButton(
            onPressed: () => _copyText(daily),
            icon: const Icon(Icons.copy_outlined),
            tooltip: '텍스트 복사',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(DailyDispatch daily, List<Senior> personal) {
    final personalLabel = _routeType == RouteType.toWork ? '개인등원' : '개인하원';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        0,
        AppSpacing.space4,
        AppSpacing.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${formatBoardDate(daily.date)} $_routeType',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppSemanticColors.textPrimary,
                  fontWeight: AppTypography.fontWeightSemibold,
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              Text(
                '총 ${countAttending(daily, _routeType)}명',
                style: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.interactivePrimaryDefault,
                  fontWeight: AppTypography.fontWeightSemibold,
                ),
              ),
            ],
          ),
          if (personal.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.space1),
            Text(
              '[$personalLabel : ${personal.map((s) => s.name).join(', ')}]',
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 등원/하원 전환
class _DirectionToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _DirectionToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppSemanticColors.backgroundTertiary,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: RouteType.values.map((type) {
          final selected = value == type;
          return GestureDetector(
            onTap: () => onChanged(type),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space3,
                vertical: AppSpacing.space2,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppSemanticColors.surfaceDefault
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppBorderRadius.sm),
              ),
              child: Text(
                type,
                style: AppTypography.bodySmall.copyWith(
                  color: selected
                      ? AppSemanticColors.textPrimary
                      : AppSemanticColors.textTertiary,
                  fontWeight: selected
                      ? AppTypography.fontWeightSemibold
                      : AppTypography.fontWeightNormal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 차량 한 대 — 헤드라인 + 회차별 명단
class _RouteBlock extends StatelessWidget {
  final RouteDispatch dispatch;

  const _RouteBlock({required this.dispatch});

  @override
  Widget build(BuildContext context) {
    final isOff =
        dispatch.status == DispatchStatus.noService ||
        dispatch.status == DispatchStatus.holiday;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space2),
      padding: const EdgeInsets.all(AppSpacing.space3),
      decoration: BoxDecoration(
        color: isOff
            ? AppSemanticColors.backgroundTertiary
            : AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppSemanticColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  buildRouteHeadline(dispatch),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textPrimary,
                    fontWeight: AppTypography.fontWeightSemibold,
                  ),
                ),
              ),
              if (!isOff)
                Text(
                  '${dispatch.passengers.length}명',
                  style: AppTypography.caption.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.space1),

          if (isOff)
            Text(
              dispatch.reason ?? dispatch.status,
              style: AppTypography.caption.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            )
          else if (dispatch.tripGroups.isEmpty)
            Text(
              '탑승 없음',
              style: AppTypography.caption.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            )
          else
            ...dispatch.tripGroups.map(
              (group) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (group.tripOrder != null) ...[
                      Text(
                        '${group.tripOrder}차)',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppSemanticColors.interactivePrimaryDefault,
                          fontWeight: AppTypography.fontWeightSemibold,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space1),
                    ],
                    Expanded(
                      child: Text(
                        group.seniors.map((s) => s.name).join(' '),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppSemanticColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
