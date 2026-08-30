import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/dispatch.dart';
import '../../providers/dispatch_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/dispatch_algorithm.dart';
import '../seed/seed_button.dart';

/// 어르신 출결 관리.
///
/// 날짜를 고르고 그날 안 오시는 분(결석)과 보호자가 직접 데려오는 분(개인등하원)을
/// 체크한다. 결석은 등원·하원 모두에서, 개인등원/개인하원은 그 방향에서만 빠지므로
/// 기사님이 헛걸음하지 않는다.
///
/// 저장은 백엔드 elder_attendance로 간다 — 관리자 웹의 출결관리와 같은 데이터다.
class SeniorAbsenceView extends StatefulWidget {
  const SeniorAbsenceView({super.key});

  @override
  State<SeniorAbsenceView> createState() => _SeniorAbsenceViewState();
}

class _SeniorAbsenceViewState extends State<SeniorAbsenceView> {
  DateTime _date = DateTime.now();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DispatchProvider>();
    final dateStr = formatDate(_date);
    final seniors = provider.seniors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: SeedButton(
            label: '${_date.year}년 ${_date.month}월 ${_date.day}일',
            onPressed: _pickDate,
            variant: SeedButtonVariant.neutralOutline,
            prefixIcon: Icons.event_outlined,
          ),
        ),
        const SizedBox(height: AppSpacing.space3),
        if (seniors.isEmpty)
          Expanded(child: _buildEmpty())
        else
          Expanded(child: _buildList(provider, seniors, dateStr)),
      ],
    );
  }

  Widget _buildList(
    DispatchProvider provider,
    List<Senior> seniors,
    String dateStr,
  ) {
    // 노선별로 묶어 보여준다 — 결석은 대개 "이 차에 누가 안 타나"로 확인한다
    final routes = provider.routes;
    final grouped = <String, List<Senior>>{};
    for (final senior in seniors) {
      grouped.putIfAbsent(senior.routeId, () => []).add(senior);
    }

    // 결석 수는 백엔드 출결 기준으로 센다 (배차표와 같은 데이터를 봐야 한다)
    final absentIds = <int>{};
    for (final senior in seniors) {
      final id = senior.elderlyId;
      if (id == null) continue;
      if (provider.attendanceOf(id, dateStr)?.isAbsent ?? false) {
        absentIds.add(id);
      }
    }
    final absentCount = absentIds.length;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.space6),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.space2),
          child: Text(
            absentCount == 0 ? '결석 없음' : '결석 $absentCount명',
            style: AppTypography.bodySmall.copyWith(
              color: absentCount == 0
                  ? AppSemanticColors.textTertiary
                  : AppSemanticColors.statusWarningText,
              fontWeight: AppTypography.fontWeightMedium,
            ),
          ),
        ),
        for (final route in routes)
          if ((grouped[route.id] ?? []).isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
              child: Text(
                '${route.name} (${route.type})',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppSemanticColors.textSecondary,
                  fontWeight: AppTypography.fontWeightSemibold,
                ),
              ),
            ),
            ...(grouped[route.id]!
              ..sort((a, b) => a.boardingOrder.compareTo(b.boardingOrder))).map(
              (senior) => _buildTile(provider, senior, dateStr),
            ),
          ],
      ],
    );
  }

  /// 그날 그 어르신의 출결 상태.
  /// 저장된 기록이 없으면 출석 + 어르신 고정 설정(항상 개인등하원)을 기본으로 본다.
  ElderDayAttendance _stateOf(
    DispatchProvider provider,
    Senior senior,
    String dateStr,
  ) {
    final elderlyId = senior.elderlyId;
    if (elderlyId == null) {
      return ElderDayAttendance(elderlyId: -1, date: dateStr);
    }

    final saved = provider.attendanceOf(elderlyId, dateStr);
    if (saved != null) return saved;

    return ElderDayAttendance(
      elderlyId: elderlyId,
      date: dateStr,
      personalPickup: senior.personalPickup,
      personalDropoff: senior.personalDropoff,
    );
  }

  Future<void> _apply(
    DispatchProvider provider,
    ElderDayAttendance next,
  ) async {
    final ok = await provider.saveAttendances([next]);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출결 저장에 실패했습니다')),
      );
    }
  }

  Widget _buildTile(DispatchProvider provider, Senior senior, String dateStr) {
    // 회원관리와 연결되지 않은 옛 데이터는 출결을 저장할 곳이 없다
    if (senior.elderlyId == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.space2),
        padding: const EdgeInsets.all(AppSpacing.space3),
        decoration: BoxDecoration(
          color: AppSemanticColors.surfaceDefault,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border.all(color: AppSemanticColors.borderSubtle),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                senior.name,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppSemanticColors.textSecondary,
                ),
              ),
            ),
            Text(
              '회원관리 연결 필요',
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    final state = _stateOf(provider, senior, dateStr);
    final isAbsent = state.isAbsent;
    final isPickupRoute = _routeTypeOf(provider, senior) == RouteType.toWork;
    final personalChecked = isPickupRoute
        ? state.personalPickup
        : state.personalDropoff;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space2),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space2,
      ),
      decoration: BoxDecoration(
        color: isAbsent
            ? AppSemanticColors.statusWarningBackground
            : AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(
          color: isAbsent
              ? AppSemanticColors.statusWarningBorder
              : AppSemanticColors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isAbsent,
            onChanged: (checked) => _apply(
              provider,
              ElderDayAttendance(
                elderlyId: state.elderlyId,
                date: dateStr,
                status: checked == true ? '결석' : '출석',
                personalPickup: state.personalPickup,
                personalDropoff: state.personalDropoff,
              ),
            ),
            activeColor: AppSemanticColors.statusWarningIcon,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  senior.name,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textPrimary,
                    decoration: isAbsent ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  '결석 · 탑승 ${senior.boardingOrder}번',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          // 보호자가 직접 데려오는 날은 그 방향 차량에서만 빠진다
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isPickupRoute ? '개인등원' : '개인하원',
                style: AppTypography.bodySmall.copyWith(
                  color: isAbsent
                      ? AppSemanticColors.textDisabled
                      : AppSemanticColors.textSecondary,
                ),
              ),
              Checkbox(
                value: personalChecked,
                onChanged: isAbsent
                    ? null
                    : (checked) => _apply(
                        provider,
                        ElderDayAttendance(
                          elderlyId: state.elderlyId,
                          date: dateStr,
                          status: state.status,
                          personalPickup: isPickupRoute
                              ? checked == true
                              : state.personalPickup,
                          personalDropoff: isPickupRoute
                              ? state.personalDropoff
                              : checked == true,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 이 어르신이 배정된 노선의 방향 (등원/하원)
  String _routeTypeOf(DispatchProvider provider, Senior senior) {
    for (final route in provider.routes) {
      if (route.id == senior.routeId) return route.type;
    }
    return RouteType.toWork;
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.groups_outlined,
            size: 40,
            color: AppSemanticColors.textDisabled,
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            '배차에 등록된 어르신이 없습니다',
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space1),
          Text(
            '배차 설정에서 노선에 어르신을 추가해주세요',
            style: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
