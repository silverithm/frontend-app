import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/approval.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import 'approval_status_badge.dart';

class ApprovalCard extends StatelessWidget {
  final ApprovalRequest approval;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool showCheckbox;
  final ValueChanged<bool?>? onCheckChanged;

  const ApprovalCard({
    super.key,
    required this.approval,
    this.onTap,
    this.isSelected = false,
    this.showCheckbox = false,
    this.onCheckChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.space3),
      elevation: 0,
      color: isSelected
          ? AppSemanticColors.surfaceSelected
          : AppSemanticColors.surfaceDefault,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        side: BorderSide(
          color: isSelected
              ? AppSemanticColors.borderFocus
              : AppSemanticColors.borderDefault,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showCheckbox) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: onCheckChanged,
                  activeColor: AppSemanticColors.interactivePrimaryDefault,
                ),
                const SizedBox(width: AppSpacing.space2),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: AppSpacing.space2),
                    _buildContent(),
                    if (approval.rejectReason != null &&
                        approval.status == ApprovalStatus.rejected) ...[
                      const SizedBox(height: AppSpacing.space2),
                      _buildRejectReason(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            approval.title,
            style: AppTypography.heading6.copyWith(
              color: AppSemanticColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.space2),
        ApprovalStatusBadge(status: approval.status),
      ],
    );
  }

  Widget _buildContent() {
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.person_outline,
              size: 16,
              color: AppSemanticColors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.space1),
            Text(
              approval.requesterName,
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.space4),
            Icon(
              Icons.access_time,
              size: 16,
              color: AppSemanticColors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.space1),
            Text(
              dateFormat.format(approval.createdAt),
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            ),
          ],
        ),
        if (approval.attachmentFileName != null) ...[
          const SizedBox(height: AppSpacing.space1),
          Row(
            children: [
              Icon(
                Icons.attach_file,
                size: 16,
                color: AppSemanticColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.space1),
              Expanded(
                child: Text(
                  approval.attachmentFileName!,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textLink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        if (approval.processedAt != null && approval.processedByName != null) ...[
          const SizedBox(height: AppSpacing.space1),
          Row(
            children: [
              Icon(
                approval.status == ApprovalStatus.approved
                    ? Icons.check_circle_outline
                    : Icons.cancel_outlined,
                size: 16,
                color: approval.status == ApprovalStatus.approved
                    ? AppSemanticColors.statusSuccessIcon
                    : AppSemanticColors.statusErrorIcon,
              ),
              const SizedBox(width: AppSpacing.space1),
              Text(
                '${approval.processedByName}님이 ${dateFormat.format(approval.processedAt!)}에 처리',
                style: AppTypography.caption.copyWith(
                  color: AppSemanticColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildRejectReason() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space3),
      decoration: BoxDecoration(
        color: AppSemanticColors.statusErrorBackground,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(
          color: AppSemanticColors.statusErrorBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: AppSemanticColors.statusErrorIcon,
          ),
          const SizedBox(width: AppSpacing.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '거절 사유',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppSemanticColors.statusErrorText,
                  ),
                ),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  approval.rejectReason!,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.statusErrorText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
