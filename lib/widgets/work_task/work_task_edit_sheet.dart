import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/work_task.dart';
import '../../providers/work_task_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_dialog.dart';
import '../common/app_snackbar.dart';
import '../seed/seed_button.dart';
import '../seed/seed_callout.dart';
import '../seed/seed_chip.dart';
import '../seed/seed_text_field.dart';
import 'work_task_assignee_picker.dart';

/// 업무 등록·수정 — 담당자, 기한, 업무 내용, 중요도, 수행도(원장 그림의 "등록 시 기본정보 입력").
/// 고칠 수 없는 사람(관리자·등록한 사람·담당자가 아님)에게는 같은 창을 읽기 전용으로 보여 준다.
/// 웹 WorkTaskDialog와 같은 규칙이다.
class WorkTaskEditSheet {
  /// 저장하거나 지웠으면 true
  static Future<bool> show(
    BuildContext context, {
    WorkTask? task,
    required String meId,
    required String companyId,
  }) async {
    final isNew = task == null;
    final readOnly = !isNew && !task.canEdit;
    final changed = await AppBottomSheet.show<bool>(
      context,
      title: isNew ? '업무 등록' : (readOnly ? '업무 보기' : '업무 수정'),
      isScrollControlled: true,
      child: _WorkTaskForm(task: task, meId: meId, companyId: companyId),
    );
    return changed == true;
  }
}

class _WorkTaskForm extends StatefulWidget {
  final WorkTask? task;
  final String meId;
  final String companyId;

  const _WorkTaskForm({
    required this.task,
    required this.meId,
    required this.companyId,
  });

  @override
  State<_WorkTaskForm> createState() => _WorkTaskFormState();
}

class _WorkTaskFormState extends State<_WorkTaskForm> {
  late final TextEditingController _content;
  late WorkTaskImportance _importance;
  late int _progress;
  DateTime? _dueDate;
  late List<String> _assigneeIds;

  /// 담당자 이름 — 명단에서 받고, 명단에 없는 사람(퇴사 등)은 업무에 적힌 이름으로
  final Map<String, String> _names = {};
  bool _isSaving = false;

  bool get _isNew => widget.task == null;
  bool get _readOnly => !_isNew && !widget.task!.canEdit;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    final input = task == null ? null : WorkTaskInput.of(task);
    _content = TextEditingController(text: input?.content ?? '');
    _importance = input?.importance ?? WorkTaskImportance.normal;
    _progress = input?.progress ?? 0;
    _dueDate = input?.dueDate;
    // 새 업무의 기본 담당자는 나 — 웹과 같다
    _assigneeIds = input?.assigneeIds ?? [widget.meId];
    for (final person in task?.assignees ?? const <WorkTaskPerson>[]) {
      if (person.name != null) _names[person.id] = person.name!;
    }
    _content.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNames());
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _loadNames() async {
    try {
      final people = await context.read<WorkTaskProvider>().loadPeople(
        widget.companyId,
      );
      if (!mounted) return;
      setState(() {
        for (final person in people) {
          _names[person.id] = person.name;
        }
      });
    } catch (_) {
      // 이름을 못 받아도 업무에 적힌 이름으로 보이고, 고르기를 누르면 다시 받는다
    }
  }

  bool get _canSubmit =>
      !_readOnly &&
      !_isSaving &&
      _content.text.trim().isNotEmpty &&
      _assigneeIds.isNotEmpty;

  String _nameOf(String id) {
    final name = _names[id] ?? '알 수 없는 사람';
    return id == widget.meId ? '$name (나)' : name;
  }

  Future<void> _pickAssignees() async {
    final picked = await WorkTaskAssigneePicker.show(
      context,
      companyId: widget.companyId,
      meId: widget.meId,
      selected: _assigneeIds,
      extraNames: _names,
    );
    if (picked == null || !mounted) return;
    setState(() => _assigneeIds = picked);
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final initial = _dueDate ?? DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      helpText: '기한',
    );
    if (picked != null && mounted) setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSaving = true);
    final provider = context.read<WorkTaskProvider>();
    final input = WorkTaskInput(
      content: _content.text.trim(),
      importance: _importance,
      progress: _progress,
      dueDate: _dueDate,
      assigneeIds: _assigneeIds,
    );
    try {
      if (_isNew) {
        await provider.create(input);
      } else {
        await provider.update(widget.task!.id, input);
      }
      if (!mounted) return;
      AppSnackBar.showSuccess(
        context,
        message: _isNew ? '업무를 등록했습니다' : '업무를 저장했습니다',
      );
      Navigator.of(context).pop(true);
    } on WorkTaskException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppSnackBar.showError(context, message: e.message);
    }
  }

  Future<void> _delete() async {
    final task = widget.task;
    if (task == null) return;
    final confirmed = await AppDialog.showConfirm(
      context,
      title: '업무 지우기',
      message: '"${task.content}" 업무를 지울까요? 지우면 되돌릴 수 없습니다.',
      confirmText: '지우기',
      confirmVariant: SeedButtonVariant.critical,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSaving = true);
    try {
      await context.read<WorkTaskProvider>().delete(task.id);
      if (!mounted) return;
      AppSnackBar.showSuccess(context, message: '업무를 지웠습니다');
      Navigator.of(context).pop(true);
    } on WorkTaskException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppSnackBar.showError(context, message: e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.space4,
        right: AppSpacing.space4,
        top: AppSpacing.space4,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.space4,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isNew
                  ? '담당자에게 알림이 가고, 다 끝날 때까지 매일 아침 알려 줍니다'
                  : '등록 ${task!.createdBy.name ?? ''}'
                        '${task.createdAt != null ? ' · ${task.createdAt!.month}/${task.createdAt!.day}' : ''}',
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textSecondary,
              ),
            ),
            if (_readOnly) ...[
              const SizedBox(height: AppSpacing.space3),
              const SeedCallout(
                variant: SeedCalloutVariant.info,
                title: '관리자·등록한 사람·담당자만 고칠 수 있습니다',
                icon: Icons.lock_outline,
              ),
            ],
            const SizedBox(height: AppSpacing.space4),
            SeedTextField(
              label: '업무 내용',
              placeholder: '예: 10월 사업계획서 작성',
              controller: _content,
              maxLines: 3,
              maxLength: workTaskContentMax,
              isReadOnly: _readOnly,
            ),
            const SizedBox(height: AppSpacing.space4),
            _Label('담당자'),
            const SizedBox(height: AppSpacing.space2),
            Wrap(
              spacing: AppSpacing.space2,
              runSpacing: AppSpacing.space2,
              children: [
                for (final id in _assigneeIds)
                  SeedChip(
                    label: _nameOf(id),
                    selected: true,
                    size: SeedChipSize.small,
                  ),
                if (!_readOnly)
                  SeedChip(
                    label: _assigneeIds.isEmpty ? '담당자 고르기' : '바꾸기',
                    prefixIcon: Icons.person_add_alt_1_outlined,
                    size: SeedChipSize.small,
                    onTap: _pickAssignees,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.space4),
            _Label('기한 (선택)'),
            const SizedBox(height: AppSpacing.space2),
            Row(
              children: [
                SeedChip(
                  label: _dueDate == null
                      ? (_readOnly ? '기한 없음' : '날짜 고르기')
                      : '${_dueDate!.year}. ${_dueDate!.month}. ${_dueDate!.day}.',
                  prefixIcon: Icons.event_outlined,
                  selected: _dueDate != null,
                  size: SeedChipSize.small,
                  onTap: _readOnly ? null : _pickDueDate,
                ),
                if (_dueDate != null && !_readOnly) ...[
                  const SizedBox(width: AppSpacing.space1),
                  IconButton(
                    tooltip: '기한 지우기',
                    icon: const Icon(Icons.close, size: 18),
                    color: AppSemanticColors.textTertiary,
                    onPressed: () => setState(() => _dueDate = null),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.space4),
            _Label('중요도'),
            const SizedBox(height: AppSpacing.space2),
            Row(
              children: [
                for (final importance in WorkTaskImportance.values) ...[
                  SeedChip(
                    label: importance.label,
                    selected: _importance == importance,
                    isDisabled: _readOnly && _importance != importance,
                    onTap: _readOnly
                        ? null
                        : () => setState(() => _importance = importance),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.space4),
            Row(
              children: [
                const _Label('수행도'),
                const Spacer(),
                Text(
                  _progress >= 100 ? '완료' : '$_progress%',
                  style: AppTypography.titleSmall.copyWith(
                    color: _progress >= 100
                        ? AppSemanticColors.statusSuccessText
                        : AppSemanticColors.textPrimary,
                  ),
                ),
              ],
            ),
            Slider(
              value: _progress.toDouble(),
              min: 0,
              max: 100,
              divisions: 100 ~/ workTaskProgressStep,
              label: _progress >= 100 ? '완료' : '$_progress%',
              activeColor: AppSemanticColors.brandDefault,
              semanticFormatterCallback: (value) =>
                  value >= 100 ? '완료' : '${value.round()}%',
              onChanged: _readOnly
                  ? null
                  : (value) => setState(
                      () => _progress = snapWorkTaskProgress(value),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final mark in const ['0%', '50%', '완료'])
                    Text(
                      mark,
                      style: AppTypography.caption.copyWith(
                        color: AppSemanticColors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space5),
            Row(
              children: [
                if (!_isNew && task!.canDelete)
                  SeedButton(
                    label: '지우기',
                    variant: SeedButtonVariant.neutralOutline,
                    onPressed: _isSaving ? null : _delete,
                    isDisabled: _isSaving,
                  ),
                const Spacer(),
                SeedButton(
                  label: _readOnly ? '닫기' : '취소',
                  variant: SeedButtonVariant.neutralWeak,
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  isDisabled: _isSaving,
                ),
                if (!_readOnly) ...[
                  const SizedBox(width: AppSpacing.space2),
                  SeedButton(
                    label: _isNew ? '등록' : '저장',
                    onPressed: _canSubmit ? _submit : null,
                    isDisabled: !_canSubmit,
                    isLoading: _isSaving,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.titleSmall.copyWith(
        color: AppSemanticColors.textPrimary,
      ),
    );
  }
}
