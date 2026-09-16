import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/dispatch.dart';
import '../../providers/dispatch_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

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

/// 어르신 한 명의 출결 토글 — 결석/개인등하원 스위치 두 줄 + 사유.
///
/// 배차표의 어르신 시트(다른 차량으로 이동 버튼 위)에서 쓰인다. 이름은 시트
/// 제목에 이미 나와 있으므로 여기서는 상태 토글만 보여준다.
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
      return Text(
        '회원관리 연결이 필요합니다',
        style: AppTypography.bodySmall.copyWith(
          color: AppSemanticColors.textTertiary,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ToggleRow(
          label: '결석',
          value: isAbsent,
          onChanged: (checked) => applyAttendance(
            context,
            provider,
            ElderDayAttendance(
              elderlyId: state.elderlyId,
              date: widget.dateStr,
              status: checked ? '결석' : '출석',
              personalPickup: state.personalPickup,
              personalDropoff: state.personalDropoff,
              note: state.note,
            ),
          ),
        ),
        Divider(height: 1, color: AppSemanticColors.borderSubtle),
        _ToggleRow(
          label: personalLabel,
          value: personalChecked,
          isDisabled: isAbsent,
          onChanged: (checked) => applyAttendance(
            context,
            provider,
            ElderDayAttendance(
              elderlyId: state.elderlyId,
              date: widget.dateStr,
              status: state.status,
              personalPickup: isPickupRoute ? checked : state.personalPickup,
              personalDropoff: isPickupRoute ? state.personalDropoff : checked,
              note: state.note,
            ),
          ),
        ),
        if (isAbsent) ...[
          Divider(height: 1, color: AppSemanticColors.borderSubtle),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
            child: TextField(
              controller: _reasonController,
              style: AppTypography.bodySmall,
              decoration: InputDecoration(
                isDense: true,
                labelText: '사유(선택)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.md),
                ),
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
      ],
    );
  }
}

/// 시트 안의 토글 한 줄 — 라벨 + 체크박스. 캡처 자동화가 "시트 안의 첫
/// 체크박스가 결석이다"라고 가정하므로(순서 고정), Checkbox 타입을 유지한다.
class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final bool isDisabled;
  final ValueChanged<bool>? onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    this.isDisabled = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: isDisabled
                    ? AppSemanticColors.textDisabled
                    : AppSemanticColors.textPrimary,
              ),
            ),
          ),
          Checkbox(
            value: value,
            onChanged: isDisabled ? null : (checked) => onChanged?.call(checked == true),
            activeColor: AppSemanticColors.interactivePrimaryDefault,
          ),
        ],
      ),
    );
  }
}
