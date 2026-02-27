import 'package:flutter/material.dart';
import '../../models/approval.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';

class ApprovalStatusBadge extends StatelessWidget {
  final ApprovalStatus status;
  final bool compact;

  const ApprovalStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final (backgroundColor, textColor, text) = _getStatusStyle();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.space2 : AppSpacing.space3,
        vertical: compact ? AppSpacing.space1 : AppSpacing.space1_5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
      ),
      child: Text(
        text,
        style: (compact ? AppTypography.labelSmall : AppTypography.labelMedium).copyWith(
          color: textColor,
        ),
      ),
    );
  }

  (Color, Color, String) _getStatusStyle() {
    switch (status) {
      case ApprovalStatus.pending:
        return (
          AppSemanticColors.statusWarningBackground,
          AppSemanticColors.statusWarningText,
          '대기중',
        );
      case ApprovalStatus.approved:
        return (
          AppSemanticColors.statusSuccessBackground,
          AppSemanticColors.statusSuccessText,
          '승인됨',
        );
      case ApprovalStatus.rejected:
        return (
          AppSemanticColors.statusErrorBackground,
          AppSemanticColors.statusErrorText,
          '거절됨',
        );
    }
  }
}
