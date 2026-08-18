import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/approval.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../common/app_action_sheet.dart';

class TemplateCard extends StatelessWidget {
  final ApprovalTemplate template;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleActive;

  const TemplateCard({
    super.key,
    required this.template,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.space3),
      elevation: 0,
      color: AppSemanticColors.surfaceDefault,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        side: BorderSide(
          color: AppSemanticColors.borderDefault,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              if (template.description != null &&
                  template.description!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space2),
                _buildDescription(),
              ],
              const SizedBox(height: AppSpacing.space3),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.space2),
          decoration: BoxDecoration(
            color: template.isActive
                ? AppSemanticColors.statusInfoBackground
                : AppSemanticColors.backgroundTertiary,
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          ),
          child: Icon(
            Icons.description_outlined,
            size: 20,
            color: template.isActive
                ? AppSemanticColors.statusInfoIcon
                : AppSemanticColors.textTertiary,
          ),
        ),
        const SizedBox(width: AppSpacing.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                template.name,
                style: AppTypography.heading6.copyWith(
                  color: AppSemanticColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.space1),
              _buildActiveStatus(),
            ],
          ),
        ),
        if (onEdit != null || onDelete != null || onToggleActive != null)
          _buildActionMenu(context),
      ],
    );
  }

  Widget _buildActiveStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space2,
        vertical: AppSpacing.space1,
      ),
      decoration: BoxDecoration(
        color: template.isActive
            ? AppSemanticColors.statusSuccessBackground
            : AppSemanticColors.backgroundTertiary,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
      ),
      child: Text(
        template.isActive ? '활성' : '비활성',
        style: AppTypography.labelSmall.copyWith(
          color: template.isActive
              ? AppSemanticColors.statusSuccessText
              : AppSemanticColors.textTertiary,
        ),
      ),
    );
  }

  Widget _buildDescription() {
    return Text(
      template.description!,
      style: AppTypography.bodySmall.copyWith(
        color: AppSemanticColors.textSecondary,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFooter() {
    final dateFormat = DateFormat('yyyy.MM.dd');

    return Row(
      children: [
        if (template.fileName != null) ...[
          Icon(
            Icons.attach_file,
            size: 14,
            color: AppSemanticColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.space1),
          Expanded(
            child: Text(
              template.fileName!,
              style: AppTypography.caption.copyWith(
                color: AppSemanticColors.textLink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else
          const Spacer(),
        Text(
          '생성: ${dateFormat.format(template.createdAt)}',
          style: AppTypography.caption.copyWith(
            color: AppSemanticColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionMenu(BuildContext context) {
    // 기본 Material 팝업 메뉴 대신 앱 공통 문법(둥근 상단 바텀시트 + 틴트 아이콘)을 쓴다
    return IconButton(
      icon: Icon(
        Icons.more_vert,
        color: AppSemanticColors.textSecondary,
      ),
      visualDensity: VisualDensity.compact,
      tooltip: '더보기',
      onPressed: () => _showActionSheet(context),
    );
  }

  void _showActionSheet(BuildContext context) {
    showAppActionSheet(
      context,
      title: template.name,
      actions: [
        if (onEdit != null)
          AppSheetAction(
            icon: Icons.edit_outlined,
            label: '수정',
            onSelected: onEdit!,
          ),
        if (onToggleActive != null)
          AppSheetAction(
            icon: template.isActive
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            label: template.isActive ? '비활성화' : '활성화',
            onSelected: onToggleActive!,
          ),
        if (onDelete != null)
          AppSheetAction(
            icon: Icons.delete_outline,
            label: '삭제',
            isDestructive: true,
            onSelected: onDelete!,
          ),
      ],
    );
  }
}

// Simplified template selection card for employees
class TemplateSelectionCard extends StatelessWidget {
  final ApprovalTemplate template;
  final bool isSelected;
  final VoidCallback? onTap;

  const TemplateSelectionCard({
    super.key,
    required this.template,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.space2),
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
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.space2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppSemanticColors.interactivePrimaryDefault
                      : AppSemanticColors.backgroundTertiary,
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                ),
                child: Icon(
                  Icons.description_outlined,
                  size: 20,
                  color: isSelected
                      ? AppSemanticColors.textInverse
                      : AppSemanticColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppSemanticColors.textPrimary,
                      ),
                    ),
                    if (template.description != null &&
                        template.description!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.space1),
                      Text(
                        template.description!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppSemanticColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: AppSemanticColors.interactivePrimaryDefault,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
