import 'package:flutter/material.dart';

import '../../models/dispatch.dart';
import '../../theme/app_colors.dart';

/// 배차 상태를 색과 아이콘으로 옮긴다.
///
/// 달력 칸, 목록 배지, 상세 시트가 같은 상태를 다른 색으로 칠하면 읽는 사람이
/// 매번 범례를 다시 봐야 한다. 그래서 한 곳에서만 정한다.
class DispatchStatusStyle {
  final Color foreground;
  final Color background;
  final Color border;
  final IconData icon;
  final String label;

  const DispatchStatusStyle({
    required this.foreground,
    required this.background,
    required this.border,
    required this.icon,
    required this.label,
  });

  static DispatchStatusStyle of(String status) {
    switch (status) {
      case DispatchStatus.normal:
        return const DispatchStatusStyle(
          foreground: AppSemanticColors.statusSuccessText,
          background: AppSemanticColors.statusSuccessBackground,
          border: AppSemanticColors.statusSuccessBorder,
          icon: Icons.check_circle_outline,
          label: '정상',
        );
      case DispatchStatus.substitute:
        return const DispatchStatusStyle(
          foreground: AppSemanticColors.statusWarningText,
          background: AppSemanticColors.statusWarningBackground,
          border: AppSemanticColors.statusWarningBorder,
          icon: Icons.swap_horiz_rounded,
          label: '대체',
        );
      case DispatchStatus.noService:
        return const DispatchStatusStyle(
          foreground: AppSemanticColors.statusErrorText,
          background: AppSemanticColors.statusErrorBackground,
          border: AppSemanticColors.statusErrorBorder,
          icon: Icons.do_not_disturb_alt_rounded,
          label: '운행없음',
        );
      default:
        return const DispatchStatusStyle(
          foreground: AppSemanticColors.textTertiary,
          background: AppSemanticColors.backgroundTertiary,
          border: AppSemanticColors.borderSubtle,
          icon: Icons.weekend_outlined,
          label: '휴일',
        );
    }
  }
}
