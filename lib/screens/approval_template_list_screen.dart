import 'package:flutter/material.dart';

import '../models/approval.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/approval/template_card.dart';
import '../widgets/seed/seed_chip.dart';
import 'approval_template_preview_screen.dart';

/// 분류 없는 양식(category 미지정)을 묶어 표시할 때 쓰는 라벨
const String _uncategorizedLabel = '기타';

/// 결재 양식 선택 화면.
///
/// 카드 목록에서 양식을 탭하면 미리보기(문서 모양 또는 첨부 원본)로 이동하고,
/// 미리보기에서 "이 양식으로 작성"을 누르면 그 양식을 들고 결재 작성 화면으로 돌아간다.
/// 양식 대분류(category)가 둘 이상 섞여 있으면 상단에 분류 필터 칩을 보여준다 —
/// 분류가 하나뿐이거나 없으면 불필요한 위계이므로 필터를 만들지 않는다.
class ApprovalTemplateListScreen extends StatefulWidget {
  final List<ApprovalTemplate> templates;
  final ApprovalTemplate? selected;

  const ApprovalTemplateListScreen({
    super.key,
    required this.templates,
    this.selected,
  });

  @override
  State<ApprovalTemplateListScreen> createState() =>
      _ApprovalTemplateListScreenState();
}

class _ApprovalTemplateListScreenState
    extends State<ApprovalTemplateListScreen> {
  /// 선택된 분류 필터 (null = 전체)
  String? _categoryFilter;

  String _categoryOf(ApprovalTemplate template) {
    final category = template.category?.trim();
    return (category == null || category.isEmpty) ? _uncategorizedLabel : category;
  }

  /// 목록에 실제로 등장하는 분류 (등록 순서를 따름)
  List<String> get _categories {
    final seen = <String>[];
    for (final template in widget.templates) {
      final category = _categoryOf(template);
      if (!seen.contains(category)) seen.add(category);
    }
    return seen;
  }

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
    final categories = _categories;
    // 분류가 하나 이하면 필터를 만들지 않는다 (불필요한 위계 금지)
    final showCategoryFilter = categories.length > 1;
    final filteredTemplates = _categoryFilter == null
        ? widget.templates
        : widget.templates.where((t) => _categoryOf(t) == _categoryFilter).toList();

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
      body: widget.templates.isEmpty
          ? Center(
              child: Text(
                '사용 가능한 결재 양식이 없습니다',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppSemanticColors.textTertiary),
              ),
            )
          : Column(
              children: [
                if (showCategoryFilter) _buildCategoryFilterBar(categories),
                Expanded(
                  child: filteredTemplates.isEmpty
                      ? Center(
                          child: Text(
                            "'$_categoryFilter' 분류의 결재 양식이 없습니다",
                            style: AppTypography.bodyMedium
                                .copyWith(color: AppSemanticColors.textTertiary),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.space4),
                          itemCount: filteredTemplates.length,
                          itemBuilder: (context, index) {
                            final template = filteredTemplates[index];
                            return TemplateSelectionCard(
                              template: template,
                              isSelected: widget.selected?.id == template.id,
                              onTap: () => _openPreview(context, template),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildCategoryFilterBar(List<String> categories) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        border: Border(
          bottom: BorderSide(color: AppSemanticColors.borderSubtle, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SeedChip(
              label: '전체',
              selected: _categoryFilter == null,
              size: SeedChipSize.small,
              onTap: () => setState(() => _categoryFilter = null),
            ),
            for (final category in categories) ...[
              const SizedBox(width: AppSpacing.space2),
              SeedChip(
                label: category,
                selected: _categoryFilter == category,
                size: SeedChipSize.small,
                onTap: () => setState(() => _categoryFilter = category),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
