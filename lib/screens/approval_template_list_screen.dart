import 'package:flutter/material.dart';

import '../models/approval.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/approval/template_card.dart';
import 'approval_template_preview_screen.dart';

/// 결재 양식 선택 화면.
///
/// 카드 목록에서 양식을 탭하면 미리보기(문서 모양 또는 첨부 원본)로 이동하고,
/// 미리보기에서 "이 양식으로 작성"을 누르면 그 양식을 들고 결재 작성 화면으로 돌아간다.
class ApprovalTemplateListScreen extends StatelessWidget {
  final List<ApprovalTemplate> templates;
  final ApprovalTemplate? selected;

  const ApprovalTemplateListScreen({
    super.key,
    required this.templates,
    this.selected,
  });

  Future<void> _openPreview(BuildContext context, ApprovalTemplate template) async {
    final picked = await Navigator.of(context).push<ApprovalTemplate>(
      MaterialPageRoute(
        builder: (_) => ApprovalTemplatePreviewScreen(template: template),
      ),
    );
    if (picked != null && context.mounted) {
      Navigator.of(context).pop(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: Text(
          '결재 양식 선택',
          style: AppTypography.heading6.copyWith(color: AppSemanticColors.textInverse),
        ),
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        iconTheme: IconThemeData(color: AppSemanticColors.textInverse),
        elevation: 0,
        centerTitle: true,
      ),
      body: templates.isEmpty
          ? Center(
              child: Text(
                '사용 가능한 결재 양식이 없습니다',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppSemanticColors.textTertiary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.space4),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                return TemplateSelectionCard(
                  template: template,
                  isSelected: selected?.id == template.id,
                  onTap: () => _openPreview(context, template),
                );
              },
            ),
    );
  }
}
