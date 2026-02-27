import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notice_provider.dart';
import '../models/notice.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_snackbar.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

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
          style: AppTypography.heading6.copyWith(
            color: AppSemanticColors.textInverse,
          ),
        ),
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        foregroundColor: AppSemanticColors.textInverse,
        elevation: 0,
        actions: [
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.space4),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              ),
            )
          else
            shadcn.GhostButton(
              onPressed: _handleSubmit,
              child: Text(
                '저장',
                style: AppTypography.labelLarge.copyWith(
                  color: AppSemanticColors.textInverse,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.space4),
          children: [
            // Title field
            _buildSectionTitle('제목'),
            const SizedBox(height: AppSpacing.space2),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: '공지사항 제목을 입력하세요',
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppSemanticColors.textTertiary,
                ),
                filled: true,
                fillColor: AppSemanticColors.surfaceDefault,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  borderSide: BorderSide(color: AppSemanticColors.borderDefault),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  borderSide: BorderSide(color: AppSemanticColors.borderDefault),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  borderSide: BorderSide(
                    color: AppSemanticColors.borderFocus,
                    width: 2,
                  ),
                ),
              ),
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
            TextFormField(
              controller: _contentController,
              maxLines: 10,
              decoration: InputDecoration(
                hintText: '공지사항 내용을 입력하세요',
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppSemanticColors.textTertiary,
                ),
                filled: true,
                fillColor: AppSemanticColors.surfaceDefault,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  borderSide: BorderSide(color: AppSemanticColors.borderDefault),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  borderSide: BorderSide(color: AppSemanticColors.borderDefault),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  borderSide: BorderSide(
                    color: AppSemanticColors.borderFocus,
                    width: 2,
                  ),
                ),
              ),
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
                        ? AppSemanticColors.statusWarningIcon
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
                    activeTrackColor: AppSemanticColors.statusWarningIcon.withValues(alpha: 0.5),
                    activeThumbColor: AppSemanticColors.statusWarningIcon,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space8),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTypography.labelLarge.copyWith(
        color: AppSemanticColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildPrioritySelector() {
    return Row(
      children: NoticePriority.values.map((priority) {
        final isSelected = _selectedPriority == priority;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: priority != NoticePriority.values.last ? AppSpacing.space2 : 0,
            ),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedPriority = priority;
                });
              },
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.space3,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _getPriorityColor(priority).withValues(alpha: 0.1)
                      : AppSemanticColors.surfaceDefault,
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  border: Border.all(
                    color: isSelected
                        ? _getPriorityColor(priority)
                        : AppSemanticColors.borderDefault,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _getPriorityIcon(priority),
                      color: isSelected
                          ? _getPriorityColor(priority)
                          : AppSemanticColors.textTertiary,
                      size: 20,
                    ),
                    const SizedBox(height: AppSpacing.space1),
                    Text(
                      _getPriorityText(priority),
                      style: AppTypography.labelSmall.copyWith(
                        color: isSelected
                            ? _getPriorityColor(priority)
                            : AppSemanticColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusSelector() {
    return Row(
      children: NoticeStatus.values.map((status) {
        final isSelected = _selectedStatus == status;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: status != NoticeStatus.values.last ? AppSpacing.space2 : 0,
            ),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedStatus = status;
                });
              },
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.space3,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _getStatusColor(status).withValues(alpha: 0.1)
                      : AppSemanticColors.surfaceDefault,
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  border: Border.all(
                    color: isSelected
                        ? _getStatusColor(status)
                        : AppSemanticColors.borderDefault,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _getStatusIcon(status),
                      color: isSelected
                          ? _getStatusColor(status)
                          : AppSemanticColors.textTertiary,
                      size: 20,
                    ),
                    const SizedBox(height: AppSpacing.space1),
                    Text(
                      _getStatusText(status),
                      style: AppTypography.labelSmall.copyWith(
                        color: isSelected
                            ? _getStatusColor(status)
                            : AppSemanticColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getPriorityColor(NoticePriority priority) {
    switch (priority) {
      case NoticePriority.high:
        return AppSemanticColors.statusErrorIcon;
      case NoticePriority.normal:
        return AppSemanticColors.statusInfoIcon;
      case NoticePriority.low:
        return AppSemanticColors.statusSuccessIcon;
    }
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

  Color _getStatusColor(NoticeStatus status) {
    switch (status) {
      case NoticeStatus.draft:
        return AppSemanticColors.textSecondary;
      case NoticeStatus.published:
        return AppSemanticColors.statusSuccessIcon;
      case NoticeStatus.archived:
        return AppSemanticColors.statusWarningIcon;
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
