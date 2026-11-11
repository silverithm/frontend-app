import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:provider/provider.dart';

import '../models/work_task.dart';
import '../providers/auth_provider.dart';
import '../providers/work_task_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_empty_state.dart';
import '../widgets/common/app_fab.dart';
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

  /// 목록을 아래로 밀면 등록 단추의 글자를 접는다(B안 FAB)
  bool _fabCollapsed = false;

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
      backgroundColor: AppSemanticColors.backgroundCanvas,
      appBar: const CareVAppBar(title: '업무진행도'),
      // 다른 목록 화면(공지 관리 등)과 같이 등록은 오른쪽 아래 단추로 — B안 알약 FAB
      floatingActionButton: AppFab(
        icon: Icons.add,
        label: '업무 등록',
        collapsed: _fabCollapsed,
        onPressed: () => _open(null),
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

    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // 아래 여백 — 마지막 줄이 등록 단추에 가리지 않게
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.space4,
        AppSpacing.screenGutter,
        AppSpacing.space16 + AppSpacing.space8,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space1),
          child: Text(
            mine > 0
                ? '진행 중 ${inProgress.length}건 · 내가 맡은 업무 $mine건'
                : '진행 중 ${inProgress.length}건',
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.space2_5),
        if (inProgress.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space1,
              vertical: AppSpacing.space4,
            ),
            child: Text(
              '진행 중인 업무를 모두 끝냈습니다',
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            ),
          ),
        ..._rows(inProgress, today),
        if (done.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.space3),
          InkWell(
            onTap: () => setState(() => _showDone = !_showDone),
            borderRadius: BorderRadius.circular(AppBorderRadius.control),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.minTouchTarget,
              ),
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
                    style: AppTypography.titleSmall.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showDone) ...[
            const SizedBox(height: AppSpacing.space1),
            ..._rows(done, today),
          ],
        ],
      ],
    );

    // 아래로 밀면 FAB 글자를 접고, 위로 올리면 다시 편다
    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        final collapse = switch (notification.direction) {
          ScrollDirection.reverse => true,
          ScrollDirection.forward => false,
          ScrollDirection.idle => _fabCollapsed,
        };
        if (collapse != _fabCollapsed) {
          setState(() => _fabCollapsed = collapse);
        }
        return false;
      },
      child: list,
    );
  }

  // 다른 목록(홈·공지·결재)처럼 흰 카드 안에 행을 모은다 — B안: 테두리·구분선 없이 줄 여백으로 나눈다.
  // 카드 여백 8 + 줄 안쪽 12 = 글자는 카드 끝에서 20(SeedListSection 문법), 눌림 바탕은 둥글게 뜬다.
  List<Widget> _rows(List<WorkTask> tasks, DateTime today) => tasks.isEmpty
      ? const []
      : [
          Container(
            padding: const EdgeInsets.all(AppSpacing.space2),
            decoration: BoxDecoration(
              color: AppSemanticColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppBorderRadius.card),
            ),
            child: Column(
              children: [
                for (final task in tasks)
                  WorkTaskRow(
                    task: task,
                    today: today,
                    horizontalPadding: AppSpacing.space3,
                    isHighlighted: task.id == _highlightedId,
                    onTap: () {
                      setState(() => _highlightedId = null);
                      _open(task);
                    },
                  ),
              ],
            ),
          ),
        ];
}
