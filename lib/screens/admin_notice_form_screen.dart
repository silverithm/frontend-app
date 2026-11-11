import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notice_provider.dart';
import '../models/notice.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_choice_tile.dart';
import '../utils/html_utils.dart';
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

  /// 열었을 때 본문이 HTML이었는가. 저장할 때 들어온 모양 그대로 돌려놓기 위해 기억한다.
  bool _contentWasHtml = false;

  bool get isEditing => widget.notice != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _titleController.text = widget.notice!.title;
      // 웹 서식 편집기로 쓴 공지는 본문이 HTML이다. 평문 TextField에 원문을 그대로
      // 넣으면 <p>·<br>이 날것으로 보이고, 그 상태로 저장하면 본문이 망가진다.
      // 그래서 읽을 수 있는 평문으로 풀어서 채우고, 저장할 때 다시 HTML로 올린다.
      // 주의: 굵게·색 같은 서식은 이 과정에서 사라진다. 앱에 서식 편집기가 없는 동안에는
      // 태그가 날것으로 보이는 것보다 낫다는 판단이다 (서식을 지키려면 웹에서 수정할 것).
      _contentWasHtml = containsHtmlTags(widget.notice!.content);
      _contentController.text = _contentWasHtml
          ? htmlToEditableText(widget.notice!.content)
          : widget.notice!.content;
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
    // B안: 옅은 회색 바탕 위 흰 카드 세 장(제목·내용 / 우선순위·게시 상태 / 상단 고정) + 맨 아래 큰 단추
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundCanvas,
      appBar: AppBar(
        title: Text(
          isEditing ? '공지사항 수정' : '공지사항 작성',
          style: AppTypography.appBarTitle,
        ),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            AppSpacing.space3,
            AppSpacing.screenGutter,
            AppSpacing.space6,
          ),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const SizedBox(height: AppSpacing.space5),

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
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Priority selection
                  _buildSectionTitle('우선순위'),
                  const SizedBox(height: AppSpacing.space2),
                  _buildPrioritySelector(),
                  const SizedBox(height: AppSpacing.space5),

                  // Status selection
                  _buildSectionTitle('게시 상태'),
                  const SizedBox(height: AppSpacing.space2),
                  _buildStatusSelector(),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),

            // Pin toggle — 테두리 상자 대신 흰 카드 한 줄
            AppCard(
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
                      color: _isPinned
                          ? AppSemanticColors.brandWeak
                          : AppSemanticColors.fillDefault,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.push_pin,
                      size: 22,
                      color: _isPinned
                          ? AppSemanticColors.interactivePrimaryDefault
                          : AppSemanticColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3_5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '상단 고정',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppSemanticColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space0_5),
                        Text(
                          '공지사항 목록 최상단에 고정됩니다',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppSemanticColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
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
            const SizedBox(height: AppSpacing.space6),

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

      // 들어온 모양대로 돌려놓는다 — HTML이던 공지는 줄바꿈을 <br>로 되살려 저장해야
      // 웹 목록·상세에서 한 줄로 뭉치지 않는다. 원래 평문이던 공지는 평문 그대로 둔다.
      final content = _contentWasHtml
          ? plainTextToHtml(_contentController.text.trim())
          : _contentController.text.trim();

      bool success;
      if (isEditing) {
        success = await noticeProvider.updateNotice(
          noticeId: widget.notice!.id,
          companyId: companyId,
          title: _titleController.text.trim(),
          content: content,
          priority: _selectedPriority.name.toUpperCase(),
          status: _selectedStatus.name.toUpperCase(),
          isPinned: _isPinned,
        );
      } else {
        success = await noticeProvider.createNotice(
          companyId: companyId,
          title: _titleController.text.trim(),
          content: content,
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
