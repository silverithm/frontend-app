import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/work_task.dart';
import '../providers/auth_provider.dart';
import '../providers/work_task_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_empty_state.dart';
import '../widgets/common/app_loading.dart';
import '../widgets/common/carev_app_bar.dart';
import '../widgets/work_task/work_task_edit_sheet.dart';
import '../widgets/work_task/work_task_row.dart';

/// 업무진행도 — 기관 전체가 같은 목록을 본다(웹 대시보드 오른쪽 패널과 같다).
/// 진행 중인 업무가 위, 끝낸 업무는 접어서 아래에 둔다.
class WorkTaskListScreen extends StatefulWidget {
  /// 알림을 눌러 들어온 경우 그 업무 창까지 바로 연다
  final int? openTaskId;

  const WorkTaskListScreen({super.key, this.openTaskId});

  @override
  State<WorkTaskListScreen> createState() => _WorkTaskListScreenState();
}

class _WorkTaskListScreenState extends State<WorkTaskListScreen> {
  bool _showDone = false;
  int? _highlightedId;

  @override
  void initState() {
    super.initState();
    _highlightedId = widget.openTaskId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<WorkTaskProvider>().load();
      if (!mounted) return;
      _openNotifiedTask();
    });
  }

  /// 알림이 가리킨 업무를 연다 — 그새 지워졌으면 목록만 보여 준다
  void _openNotifiedTask() {
    final id = widget.openTaskId;
    if (id == null) return;
    final task = context.read<WorkTaskProvider>().byId(id);
    if (task == null) return;
    if (task.isDone) setState(() => _showDone = true);
    _open(task);
  }

  ({String meId, String companyId})? get _session {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return null;
    return (meId: user.chatUserId, companyId: user.company?.id ?? '1');
  }

  Future<void> _open(WorkTask? task) async {
    final session = _session;
    if (session == null) return;
    await WorkTaskEditSheet.show(
      context,
      task: task,
      meId: session.meId,
      companyId: session.companyId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkTaskProvider>();
    final meId = context.watch<AuthProvider>().currentUser?.chatUserId;
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: const CareVAppBar(title: '업무진행도'),
      // 다른 목록 화면(공지 관리 등)과 같이 등록은 오른쪽 아래 단추로
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'work_task_fab',
        onPressed: () => _open(null),
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        foregroundColor: AppSemanticColors.textInverse,
        icon: const Icon(Icons.add),
        label: Text(
          '업무 등록',
          style: AppTypography.titleSmall.copyWith(
            color: AppSemanticColors.textInverse,
          ),
        ),
      ),
      body: switch (provider.status) {
        WorkTaskLoadStatus.idle ||
        WorkTaskLoadStatus.loading => const Center(child: AppLoading()),
        WorkTaskLoadStatus.error => AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: '업무를 불러오지 못했습니다',
          description: '잠시 후 다시 시도해 주세요.',
          actionLabel: '다시 시도',
          onAction: provider.load,
        ),
        WorkTaskLoadStatus.loaded => RefreshIndicator(
          onRefresh: provider.load,
          color: AppSemanticColors.brandDefault,
          child: provider.tasks.isEmpty
              ? AppEmptyState(
                  icon: Icons.checklist_rounded,
                  title: '진행 중인 업무가 없습니다',
                  description: '등록을 눌러 담당자·기한·중요도를 정해 올려 주세요.',
                  actionLabel: '업무 등록',
                  onAction: () => _open(null),
                )
              : _buildList(provider, meId, today),
        ),
      },
    );
  }

  Widget _buildList(WorkTaskProvider provider, String? meId, DateTime today) {
    final inProgress = provider.inProgress;
    final done = provider.done;
    final mine = provider.myInProgressCount(meId);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // 아래 여백 — 마지막 줄이 등록 단추에 가리지 않게
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        AppSpacing.space3,
        AppSpacing.space4,
        AppSpacing.space16 + AppSpacing.space8,
      ),
      children: [
        Text(
          mine > 0
              ? '진행 중 ${inProgress.length}건 · 내가 맡은 업무 $mine건'
              : '진행 중 ${inProgress.length}건',
          style: AppTypography.bodySmall.copyWith(
            color: AppSemanticColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.space1),
        if (inProgress.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.space4),
            child: Text(
              '진행 중인 업무를 모두 끝냈습니다',
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            ),
          ),
        ..._rows(inProgress, today),
        if (done.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.space2),
          InkWell(
            onTap: () => setState(() => _showDone = !_showDone),
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Icon(
                    _showDone ? Icons.expand_more : Icons.chevron_right,
                    size: 20,
                    color: AppSemanticColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.space1),
                  Text(
                    '끝낸 업무 ${done.length}건',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showDone) ..._rows(done, today),
        ],
      ],
    );
  }

  List<Widget> _rows(List<WorkTask> tasks, DateTime today) => [
    for (final entry in tasks.asMap().entries) ...[
      if (entry.key > 0)
        const Divider(height: 1, color: AppSemanticColors.borderSubtle),
      WorkTaskRow(
        task: entry.value,
        today: today,
        isHighlighted: entry.value.id == _highlightedId,
        onTap: () {
          setState(() => _highlightedId = null);
          _open(entry.value);
        },
      ),
    ],
  ];
}
