import 'package:flutter/material.dart';

import '../../models/work_task.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_tag.dart';

/// 중요도 색 — 웹(빨강·노랑·회색)과 같다. 게이지도 같은 색으로 채운다.
({Color background, Color foreground, Color gauge}) workTaskImportanceColors(
  WorkTaskImportance importance,
) {
  switch (importance) {
    case WorkTaskImportance.high:
      return (
        background: AppSemanticColors.statusErrorBackground,
        foreground: AppSemanticColors.statusErrorText,
        gauge: AppSemanticColors.statusErrorIcon,
      );
    case WorkTaskImportance.normal:
      return (
        background: AppSemanticColors.statusWarningBackground,
        foreground: AppSemanticColors.statusWarningText,
        gauge: AppSemanticColors.statusWarningIcon,
      );
    case WorkTaskImportance.low:
      return (
        background: AppSemanticColors.backgroundTertiary,
        foreground: AppSemanticColors.textSecondary,
        gauge: AppSemanticColors.textTertiary,
      );
  }
}

/// 중요도 꼬리표 — "중요"·"보통"·"낮음"
class WorkTaskImportanceTag extends StatelessWidget {
  final WorkTaskImportance importance;

  const WorkTaskImportanceTag({super.key, required this.importance});

  @override
  Widget build(BuildContext context) {
    return AppTag(
      label: importance.label,
      tone: switch (importance) {
        WorkTaskImportance.high => AppTagTone.error,
        WorkTaskImportance.normal => AppTagTone.warning,
        WorkTaskImportance.low => AppTagTone.neutral,
      },
    );
  }
}

/// 수행도 게이지 — 끝낸 업무는 초록으로 꽉 찬다
class WorkTaskGauge extends StatelessWidget {
  final WorkTask task;

  const WorkTaskGauge({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final fill = task.isDone
        ? AppSemanticColors.statusSuccessIcon
        : workTaskImportanceColors(task.importance).gauge;
    final value = (task.isDone ? 100 : task.progress) / 100;
    return Semantics(
      label: '수행도',
      value: task.isDone ? '완료' : '${task.progress}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
        child: SizedBox(
          height: 6,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: AppSemanticColors.backgroundTertiary),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value.clamp(0, 1).toDouble(),
                child: ColoredBox(color: fill),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 업무 한 줄 — 원장 그림대로 [중요도] 업무 내용 · 기한, 아랫줄에 담당자 뒤 진행도 게이지.
class WorkTaskRow extends StatelessWidget {
  final WorkTask task;

  /// 기한 글자("오늘까지"·"D-3")를 세는 기준 날
  final DateTime today;
  final VoidCallback? onTap;

  /// 알림을 눌러 들어온 업무 — 잠깐 연한 틸로 표시한다
  final bool isHighlighted;

  const WorkTaskRow({
    super.key,
    required this.task,
    required this.today,
    this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final due = task.isDone ? null : workTaskDueLabel(task.dueDate, today);
    final who = workTaskAssigneeLabel(task.assignees);
    final dueColor = switch (due?.tone) {
      WorkTaskDueTone.overdue => AppSemanticColors.statusErrorText,
      WorkTaskDueTone.soon => AppSemanticColors.statusWarningText,
      _ => AppSemanticColors.textTertiary,
    };

    return Semantics(
      button: onTap != null,
      label:
          '${task.importance.label} · ${task.content} · $who · '
          '${task.isDone ? '완료' : '진행 ${task.progress}%'}'
          '${due != null ? ' · ${due.text}' : ''}',
      excludeSemantics: true,
      child: Material(
        color: isHighlighted
            ? AppSemanticColors.brandWeak
            : AppColors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: WorkTaskImportanceTag(
                          importance: task.importance,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space2),
                      Expanded(
                        child: Text(
                          task.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleSmall.copyWith(
                            color: task.isDone
                                ? AppSemanticColors.textTertiary
                                : AppSemanticColors.textPrimary,
                            decoration: task.isDone
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      if (due != null) ...[
                        const SizedBox(width: AppSpacing.space2),
                        Text(
                          due.text,
                          style: AppTypography.labelStrong.copyWith(
                            color: dueColor,
                            ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  Row(
                    children: [
                      // 담당자 칸 너비를 고정해 줄마다 게이지 시작점이 같다
                      SizedBox(
                        width: 84,
                        child: Text(
                          who,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppSemanticColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space2),
                      Expanded(child: WorkTaskGauge(task: task)),
                      const SizedBox(width: AppSpacing.space2),
                      SizedBox(
                        width: 36,
                        child: Text(
                          task.isDone ? '완료' : '${task.progress}%',
                          textAlign: TextAlign.end,
                          style: AppTypography.labelStrong.copyWith(
                            color: task.isDone
                                ? AppSemanticColors.statusSuccessText
                                : AppSemanticColors.textSecondary,
                            ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
