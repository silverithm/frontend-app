import 'package:flutter/material.dart';

import '../../models/dispatch.dart';
import '../../models/vacation_request.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/dispatch_algorithm.dart';
import '../seed/seed_button.dart';
import 'dispatch_route_card.dart';
import 'dispatch_status_style.dart';

/// 기간을 정해 날짜별 배차를 쭉 훑어보는 화면.
///
/// 달력이 "이 달이 어떤가"를 보는 자리라면 여기는 "언제 누가 대신 모는가"를
/// 찾는 자리다. 그래서 노선·상태로 걸러낼 수 있게 했다.
class DispatchListView extends StatefulWidget {
  final DispatchSettings settings;
  final List<VacationRequest> vacations;

  /// 그 기간의 어르신 출결. 결석·개인등하원이 탑승 명단에 반영된다.
  final List<ElderDayAttendance> attendances;

  const DispatchListView({
    super.key,
    required this.settings,
    required this.vacations,
    this.attendances = const [],
  });

  @override
  State<DispatchListView> createState() => _DispatchListViewState();
}

class _DispatchListViewState extends State<DispatchListView> {
  late DateTime _start;
  late DateTime _end;
  String _routeFilter = 'all';
  String _statusFilter = 'all';

  /// 간소 보기. 한 달치를 훑을 때 카드가 크면 스크롤만 하다 끝나서,
  /// 한 줄로 접어 한 화면에 많이 담을 수 있게 한다.
  bool _compact = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, 1);
    _end = DateTime(now.year, now.month + 1, 0);
  }

  List<DailyDispatch> get _dispatches {
    final result = <DailyDispatch>[];
    var cursor = DateTime(_start.year, _start.month, _start.day);
    final last = DateTime(_end.year, _end.month, _end.day);

    while (!cursor.isAfter(last)) {
      result.add(
        dailyDispatch(
          cursor,
          widget.settings,
          widget.vacations,
          attendances: widget.attendances,
        ),
      );
      cursor = cursor.add(const Duration(days: 1));
    }
    return result;
  }

  List<DailyDispatch> get _filtered {
    return _dispatches
        .map((daily) {
          final kept = daily.routeDispatches.where((rd) {
            if (_routeFilter != 'all' && rd.routeId != _routeFilter) return false;
            if (_statusFilter != 'all' && rd.status != _statusFilter) return false;
            return true;
          }).toList();
          return DailyDispatch(date: daily.date, routeDispatches: kept);
        })
        .where((daily) => daily.routeDispatches.isNotEmpty)
        .toList();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: _start, end: _end),
      locale: const Locale('ko', 'KR'),
    );
    if (picked == null) return;
    setState(() {
      _start = picked.start;
      _end = picked.end;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFilters(),
        const SizedBox(height: AppSpacing.space3),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: AppSpacing.space6),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final daily = filtered[index];
                    return _buildDaySection(daily);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SeedButton(
                label: '${_label(_start)} ~ ${_label(_end)}',
                onPressed: _pickRange,
                variant: SeedButtonVariant.neutralOutline,
                prefixIcon: Icons.date_range_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.space2),
            // 한 달치를 훑을 땐 접어서, 한 건을 자세히 볼 땐 펼쳐서 본다
            IconButton(
              onPressed: () => setState(() => _compact = !_compact),
              icon: Icon(
                _compact ? Icons.unfold_more : Icons.unfold_less,
                size: 20,
              ),
              tooltip: _compact ? '자세히 보기' : '간소하게 보기',
              color: AppSemanticColors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space2),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                value: _routeFilter,
                hint: '전체 노선',
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('전체 노선')),
                  ...widget.settings.routes.map(
                    (r) => DropdownMenuItem(
                      value: r.id,
                      child: Text(
                        '${r.name} (${r.type})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _routeFilter = v ?? 'all'),
              ),
            ),
            const SizedBox(width: AppSpacing.space2),
            Expanded(
              child: _buildDropdown(
                value: _statusFilter,
                hint: '전체 상태',
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('전체 상태')),
                  DropdownMenuItem(
                    value: DispatchStatus.normal,
                    child: Text('정상'),
                  ),
                  DropdownMenuItem(
                    value: DispatchStatus.substitute,
                    child: Text('대체'),
                  ),
                  DropdownMenuItem(
                    value: DispatchStatus.noService,
                    child: Text('운행없음'),
                  ),
                  DropdownMenuItem(
                    value: DispatchStatus.holiday,
                    child: Text('휴일'),
                  ),
                ],
                onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space3_5),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border.all(color: AppSemanticColors.borderDefault),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(hint),
          items: items,
          onChanged: onChanged,
          icon: Icon(Icons.expand_more, color: AppSemanticColors.textTertiary),
          style: AppTypography.bodySmall.copyWith(
            color: AppSemanticColors.textPrimary,
          ),
        ),
      ),
    );
  }

  /// 한 줄 요약: 노선 · 차량/운전자 · 상태
  Widget _buildCompactRow(RouteDispatch rd) {
    final style = DispatchStatusStyle.of(rd.status);
    final vehicle = rd.driver?.vehicleName.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space2,
      ),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(color: AppSemanticColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              [
                (vehicle != null && vehicle.isNotEmpty) ? vehicle : rd.routeName,
                if (rd.driver != null) rd.driver!.driverName,
              ].join('/'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textPrimary,
                fontWeight: AppTypography.fontWeightMedium,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          Text(
            rd.routeType,
            style: AppTypography.caption.copyWith(
              color: AppSemanticColors.textTertiary,
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: style.background,
              borderRadius: BorderRadius.circular(AppBorderRadius.sm),
            ),
            child: Text(
              style.label,
              style: AppTypography.caption.copyWith(color: style.foreground),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySection(DailyDispatch daily) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.space3,
            bottom: AppSpacing.space2,
          ),
          child: Text(
            _sectionLabel(daily.date),
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textSecondary,
              fontWeight: AppTypography.fontWeightSemibold,
            ),
          ),
        ),
        if (_compact)
          ...daily.routeDispatches.map(_buildCompactRow)
        else
          ...daily.routeDispatches.map(
            (rd) => DispatchRouteCard(dispatch: rd, showPassengers: false),
          ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.filter_alt_off_outlined,
            size: 40,
            color: AppSemanticColors.textDisabled,
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            '조건에 맞는 배차가 없습니다',
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _label(DateTime date) => '${date.year}.${date.month}.${date.day}';

  String _sectionLabel(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    final date = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${date.month}월 ${date.day}일 (${weekdays[date.weekday - 1]})';
  }
}
