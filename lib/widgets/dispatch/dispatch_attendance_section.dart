import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/dispatch.dart';
import '../../providers/dispatch_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/dispatch_algorithm.dart';

/// 배차표 아래 붙는 출결 섹션 — 차량(노선)별로 어르신 결석·개인등하원·사유를 바로 손본다.
///
/// 예전엔 "출결" 탭이 따로 있었지만, 배차표를 보면서 바로 결석 체크를 하는 게
/// 현장 흐름이라 배차표 화면 하나로 합쳤다. 날짜는 배차표가 고른 것을 그대로 쓴다.
///
/// 저장은 백엔드 elder_attendance로 간다 — 관리자 웹의 출결관리와 같은 데이터다.
class DispatchAttendanceSection extends StatelessWidget {
  final DateTime date;

  const DispatchAttendanceSection({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DispatchProvider>();
    final dateStr = formatDate(date);
    final seniors = provider.seniors;

    if (seniors.isEmpty) return const SizedBox.shrink();

    final routes = provider.routes;
    final grouped = <String, List<Senior>>{};
    for (final senior in seniors) {
      grouped.putIfAbsent(senior.routeId, () => []).add(senior);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        0,
        AppSpacing.space4,
        AppSpacing.space4,
      ),
      padding: const EdgeInsets.all(AppSpacing.space3),
      decoration: BoxDecoration(
        color: AppSemanticColors.backgroundTertiary,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '출결',
            style: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.textSecondary,
              fontWeight: AppTypography.fontWeightSemibold,
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          for (final route in routes)
            if ((grouped[route.id] ?? []).isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.space1),
                child: Text(
                  '${route.name} (${route.type})',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textTertiary,
                    fontWeight: AppTypography.fontWeightMedium,
                  ),
                ),
              ),
              ...(grouped[route.id]!
                ..sort((a, b) => a.boardingOrder.compareTo(b.boardingOrder))).map(
                (senior) => DispatchElderAttendanceTile(
                  senior: senior,
                  routeType: route.type,
                  dateStr: dateStr,
                ),
              ),
            ],
        ],
      ),
    );
  }
}

/// 어르신 한 명의 출결 상태(저장된 기록 or 기본값)
ElderDayAttendance attendanceStateOf(
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

Future<bool> applyAttendance(
  BuildContext context,
  DispatchProvider provider,
  ElderDayAttendance next,
) async {
  final ok = await provider.saveAttendances([next]);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('출결 저장에 실패했습니다')),
    );
  }
  return ok;
}

/// 한 줄짜리 출결 타일 — 결석/개인등하원 체크박스 + 사유
class DispatchElderAttendanceTile extends StatefulWidget {
  final Senior senior;
  final String routeType;
  final String dateStr;

  const DispatchElderAttendanceTile({
    super.key,
    required this.senior,
    required this.routeType,
    required this.dateStr,
  });

  @override
  State<DispatchElderAttendanceTile> createState() => _DispatchElderAttendanceTileState();
}

class _DispatchElderAttendanceTileState extends State<DispatchElderAttendanceTile> {
  late final TextEditingController _reasonController;
  String? _lastNote;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DispatchProvider>();
    final senior = widget.senior;

    if (senior.elderlyId == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space1),
        child: Row(
          children: [
            Expanded(
              child: Text(
                senior.name,
                style: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.textSecondary,
                ),
              ),
            ),
            Text(
              '회원관리 연결 필요',
              style: AppTypography.caption.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    final state = attendanceStateOf(provider, senior, widget.dateStr);
    if (_lastNote != state.note) {
      _lastNote = state.note;
      _reasonController.text = state.note ?? '';
    }

    final isAbsent = state.isAbsent;
    final isPickupRoute = widget.routeType == RouteType.toWork;
    final personalChecked = isPickupRoute ? state.personalPickup : state.personalDropoff;
    final personalLabel = isPickupRoute ? '개인등원' : '개인하원';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space1),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
      decoration: BoxDecoration(
        color: isAbsent
            ? AppSemanticColors.statusWarningBackground
            : AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: isAbsent,
                onChanged: (checked) => applyAttendance(
                  context,
                  provider,
                  ElderDayAttendance(
                    elderlyId: state.elderlyId,
                    date: widget.dateStr,
                    status: checked == true ? '결석' : '출석',
                    personalPickup: state.personalPickup,
                    personalDropoff: state.personalDropoff,
                    note: state.note,
                  ),
                ),
                activeColor: AppSemanticColors.statusWarningIcon,
              ),
              Expanded(
                child: Text(
                  senior.name,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textPrimary,
                    decoration: isAbsent ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              Text(
                personalLabel,
                style: AppTypography.caption.copyWith(
                  color: isAbsent
                      ? AppSemanticColors.textDisabled
                      : AppSemanticColors.textSecondary,
                ),
              ),
              Checkbox(
                value: personalChecked,
                onChanged: isAbsent
                    ? null
                    : (checked) => applyAttendance(
                        context,
                        provider,
                        ElderDayAttendance(
                          elderlyId: state.elderlyId,
                          date: widget.dateStr,
                          status: state.status,
                          personalPickup: isPickupRoute
                              ? checked == true
                              : state.personalPickup,
                          personalDropoff: isPickupRoute
                              ? state.personalDropoff
                              : checked == true,
                          note: state.note,
                        ),
                      ),
              ),
            ],
          ),
          if (isAbsent)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.space8,
                right: AppSpacing.space2,
                bottom: AppSpacing.space2,
              ),
              child: TextField(
                controller: _reasonController,
                style: AppTypography.caption,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '사유(선택)',
                  border: UnderlineInputBorder(),
                ),
                onSubmitted: (value) => applyAttendance(
                  context,
                  provider,
                  ElderDayAttendance(
                    elderlyId: state.elderlyId,
                    date: widget.dateStr,
                    status: state.status,
                    personalPickup: state.personalPickup,
                    personalDropoff: state.personalDropoff,
                    note: value.trim().isEmpty ? null : value.trim(),
                  ),
                ),
                onEditingComplete: () => FocusScope.of(context).unfocus(),
              ),
            ),
        ],
      ),
    );
  }
}
