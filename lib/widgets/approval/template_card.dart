import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/approval.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../common/app_action_sheet.dart';
import '../common/app_card.dart';
import '../common/app_tag.dart';

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
    // B안: 회색 바탕 위 테두리 없는 흰 카드(모서리 16·여백 16)
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      onTap: onTap,
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // B안 목록 줄 아이콘 — 옅은 틸 둥근 바탕 40(비활성은 회색)
        Container(
          width: AppSpacing.iconCircle,
          height: AppSpacing.iconCircle,
          decoration: BoxDecoration(
            color: template.isActive
                ? AppSemanticColors.brandWeak
                : AppSemanticColors.fillDefault,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.description_outlined,
            size: 22,
            color: template.isActive
                ? AppSemanticColors.brandWeakForeground
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
                style: AppTypography.titleMedium.copyWith(
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
    // B안 꼬리표 — 활성 초록 / 비활성 회색(색 뜻 그대로)
    return AppTag(
      label: template.isActive ? '활성' : '비활성',
      tone: template.isActive ? AppTagTone.success : AppTagTone.neutral,
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
            size: 16,
            color: AppSemanticColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.space1),
          Expanded(
            child: Text(
              template.fileName!,
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textLink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
        ],
        // 좁은 폰·큰 글자에서는 파일 이름과 날짜가 자리를 나눠 갖고 말줄임한다.
        // 날짜는 늘 오른쪽 끝에 붙는다(Spacer+Flexible이면 가운데쯤에 뜬다).
        Expanded(
          child: Text(
            '생성: ${dateFormat.format(template.createdAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.textTertiary,
            ),
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
    // B안: 테두리 없는 흰 카드, 옅은 틸 둥근 아이콘 40 + 제목 16. 고른 양식만 옅은 틸 바탕 + 틸 테두리.
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      backgroundColor: isSelected
          ? AppSemanticColors.surfaceSelected
          : AppSemanticColors.surfaceCard,
      hasBorder: isSelected,
      borderColor: AppSemanticColors.borderFocus,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: AppSpacing.space4,
      ),
      child: Row(
        children: [
          Container(
            width: AppSpacing.iconCircle,
            height: AppSpacing.iconCircle,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppSemanticColors.brandDefault
                  : AppSemanticColors.brandWeak,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.description_outlined,
              size: 22,
              color: isSelected
                  ? AppSemanticColors.textInverse
                  : AppSemanticColors.brandWeakForeground,
            ),
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.name,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppSemanticColors.textPrimary,
                  ),
                ),
                if (template.description != null &&
                    template.description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.space0_5),
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
          if (isSelected) ...[
            const SizedBox(width: AppSpacing.space2),
            Icon(
              Icons.check_circle,
              color: AppSemanticColors.interactivePrimaryDefault,
            ),
          ] else ...[
            const SizedBox(width: AppSpacing.space2),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppSemanticColors.textTertiary,
            ),
          ],
        ],
      ),
    );
  }
}
