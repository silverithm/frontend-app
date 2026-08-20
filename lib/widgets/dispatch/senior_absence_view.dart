import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/dispatch.dart';
import '../../providers/dispatch_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/dispatch_algorithm.dart';
import '../seed/seed_button.dart';

/// 어르신 결석 관리.
///
/// 날짜를 고르고 그날 안 오시는 분을 체크한다. 결석으로 잡히면 그날 탑승 명단에서
/// 빠지므로, 기사님이 헛걸음하지 않는다.
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

    final absentCount = provider.absencesOn(dateStr).length;

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

  Widget _buildTile(DispatchProvider provider, Senior senior, String dateStr) {
    final isAbsent = provider.isAbsent(senior.id, dateStr);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space2),
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
      child: CheckboxListTile(
        value: isAbsent,
        onChanged: (checked) {
          if (checked == true) {
            provider.addAbsence(
              SeniorAbsence(seniorId: senior.id, date: dateStr),
            );
          } else {
            provider.removeAbsence(senior.id, dateStr);
          }
        },
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
        title: Text(
          senior.name,
          style: AppTypography.bodyMedium.copyWith(
            color: AppSemanticColors.textPrimary,
            decoration: isAbsent ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          '탑승 ${senior.boardingOrder}번',
          style: AppTypography.bodySmall.copyWith(
            color: AppSemanticColors.textTertiary,
          ),
        ),
        activeColor: AppSemanticColors.statusWarningIcon,
      ),
    );
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
