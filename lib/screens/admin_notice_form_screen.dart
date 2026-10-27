import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notice_provider.dart';
import '../models/notice.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_choice_tile.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_text_field.dart';

class AdminNoticeFormScreen extends StatefulWidget {
  final Notice? notice; // null이면 새로 생성, 값이 있으면 수정

  const AdminNoticeFormScreen({
    super.key,
    this.notice,
  });

  @override
  State<AdminNoticeFormScreen> createState() => _AdminNoticeFormScreenState();
}

class _AdminNoticeFormScreenState extends State<AdminNoticeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  NoticePriority _selectedPriority = NoticePriority.normal;
  NoticeStatus _selectedStatus = NoticeStatus.draft;
  bool _isPinned = false;
  bool _isSubmitting = false;

  bool get isEditing => widget.notice != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _titleController.text = widget.notice!.title;
      _contentController.text = widget.notice!.content;
      _selectedPriority = widget.notice!.priority;
      _selectedStatus = widget.notice!.status;
      _isPinned = widget.notice!.isPinned;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: Text(
          isEditing ? '공지사항 수정' : '공지사항 작성',
          style: AppTypography.heading6,
        ),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.space4),
          children: [
            // Title field
            _buildSectionTitle('제목'),
            const SizedBox(height: AppSpacing.space2),
            SeedTextField(
              label: '제목',
              showLabel: false,
              controller: _titleController,
              placeholder: '공지사항 제목을 입력하세요',
              size: SeedTextFieldSize.large,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '제목을 입력해주세요';
                }
                if (value.length > 100) {
                  return '제목은 100자 이내로 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.space6),

            // Content field
            _buildSectionTitle('내용'),
            const SizedBox(height: AppSpacing.space2),
            SeedTextField(
              label: '내용',
              showLabel: false,
              controller: _contentController,
              maxLines: 10,
              placeholder: '공지사항 내용을 입력하세요',
              size: SeedTextFieldSize.large,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '내용을 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.space6),

            // Priority selection
            _buildSectionTitle('우선순위'),
            const SizedBox(height: AppSpacing.space2),
            _buildPrioritySelector(),
            const SizedBox(height: AppSpacing.space6),

            // Status selection
            _buildSectionTitle('게시 상태'),
            const SizedBox(height: AppSpacing.space2),
            _buildStatusSelector(),
            const SizedBox(height: AppSpacing.space6),

            // Pin toggle
            Container(
              padding: const EdgeInsets.all(AppSpacing.space4),
              decoration: BoxDecoration(
                color: AppSemanticColors.surfaceDefault,
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                border: Border.all(color: AppSemanticColors.borderDefault),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.push_pin,
                    color: _isPinned
                        ? AppSemanticColors.interactivePrimaryDefault
                        : AppSemanticColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '상단 고정',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppSemanticColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '공지사항 목록 최상단에 고정됩니다',
                          style: AppTypography.caption.copyWith(
                            color: AppSemanticColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isPinned,
                    onChanged: (value) {
                      setState(() {
                        _isPinned = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space8),

            // 제출 버튼 — approval_form_screen과 동일하게 본문 하단 풀와이드 배치
            SizedBox(
              width: double.infinity,
              child: SeedButton(
                label: '저장',
                variant: SeedButtonVariant.brandSolid,
                size: SeedButtonSize.large,
                isLoading: _isSubmitting,
                isDisabled: _isSubmitting,
                onPressed: _handleSubmit,
              ),
            ),
            const SizedBox(height: AppSpacing.space6),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTypography.titleSmall.copyWith(
        color: AppSemanticColors.textPrimary,
      ),
    );
  }

  Widget _buildPrioritySelector() {
    return _buildChoiceRow(
      NoticePriority.values.map((priority) {
        return AppChoiceTile(
          label: _getPriorityText(priority),
          icon: _getPriorityIcon(priority),
          selected: _selectedPriority == priority,
          // 긴급만 의미 색(빨강) — 아이콘·글자에만 쓴다
          accentColor: priority == NoticePriority.high
              ? AppSemanticColors.statusErrorIcon
              : null,
          onTap: () => setState(() => _selectedPriority = priority),
        );
      }).toList(),
    );
  }

  Widget _buildStatusSelector() {
    return _buildChoiceRow(
      NoticeStatus.values.map((status) {
        return AppChoiceTile(
          label: _getStatusText(status),
          icon: _getStatusIcon(status),
          selected: _selectedStatus == status,
          onTap: () => setState(() => _selectedStatus = status),
        );
      }).toList(),
    );
  }

  Widget _buildChoiceRow(List<Widget> tiles) {
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.space2),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }

  IconData _getPriorityIcon(NoticePriority priority) {
    switch (priority) {
      case NoticePriority.high:
        return Icons.priority_high;
      case NoticePriority.normal:
        return Icons.info_outline;
      case NoticePriority.low:
        return Icons.arrow_downward;
    }
  }

  String _getPriorityText(NoticePriority priority) {
    switch (priority) {
      case NoticePriority.high:
        return '긴급';
      case NoticePriority.normal:
        return '일반';
      case NoticePriority.low:
        return '낮음';
    }
  }

  IconData _getStatusIcon(NoticeStatus status) {
    switch (status) {
      case NoticeStatus.draft:
        return Icons.edit_outlined;
      case NoticeStatus.published:
        return Icons.check_circle_outline;
      case NoticeStatus.archived:
        return Icons.archive_outlined;
    }
  }

  String _getStatusText(NoticeStatus status) {
    switch (status) {
      case NoticeStatus.draft:
        return '임시저장';
      case NoticeStatus.published:
        return '게시';
      case NoticeStatus.archived:
        return '보관';
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final noticeProvider = context.read<NoticeProvider>();
      final companyId = authProvider.currentUser?.company?.id ?? '1';

      bool success;
      if (isEditing) {
        success = await noticeProvider.updateNotice(
          noticeId: widget.notice!.id,
          companyId: companyId,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          priority: _selectedPriority.name.toUpperCase(),
          status: _selectedStatus.name.toUpperCase(),
          isPinned: _isPinned,
        );
      } else {
        success = await noticeProvider.createNotice(
          companyId: companyId,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          priority: _selectedPriority.name.toUpperCase(),
          status: _selectedStatus.name.toUpperCase(),
          isPinned: _isPinned,
        );
      }

      if (success && mounted) {
        AppSnackBar.showSuccess(
          context,
          message: isEditing ? '공지사항이 수정되었습니다' : '공지사항이 등록되었습니다',
        );
        Navigator.of(context).pop(true);
      } else if (mounted) {
        AppSnackBar.showError(
          context,
          message: noticeProvider.errorMessage.isNotEmpty
              ? noticeProvider.errorMessage
              : '저장에 실패했습니다',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: '오류가 발생했습니다: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
