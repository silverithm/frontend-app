import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/approval.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../common/app_card.dart';
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
    // B안: 회색 바탕 위 테두리 없는 흰 카드(모서리 16·여백 16). 고른 카드만 옅은 틸 바탕 + 틸 테두리.
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      backgroundColor: isSelected
          ? AppSemanticColors.surfaceSelected
          : AppSemanticColors.surfaceCard,
      hasBorder: isSelected,
      borderColor: AppSemanticColors.borderFocus,
      onTap: onTap,
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
                  const SizedBox(height: AppSpacing.space3),
                  _buildRejectReason(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            approval.title,
            style: AppTypography.titleMedium.copyWith(
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
            // 글자를 크게 해도 한 줄을 넘치지 않게 — 이름이 먼저 줄어든다
            Flexible(
              child: Text(
                approval.requesterName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.space4),
            Icon(
              Icons.access_time,
              size: 16,
              color: AppSemanticColors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.space1),
            Flexible(
              flex: 2,
              child: Text(
                dateFormat.format(approval.createdAt),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.textTertiary,
                ),
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
              Expanded(
                child: Text(
                  '${approval.processedByName}님이 ${dateFormat.format(approval.processedAt!)}에 처리',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
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
      // B안: 테두리 없이 옅은 빨강 바탕만
      decoration: BoxDecoration(
        color: AppSemanticColors.statusErrorBackground,
        borderRadius: BorderRadius.circular(AppBorderRadius.control),
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
                  '반려 사유',
                  style: AppTypography.labelStrong.copyWith(
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
