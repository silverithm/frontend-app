import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/work_task_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_dialog.dart';
import '../common/app_loading.dart';
import '../seed/seed_avatar.dart';
import '../seed/seed_button.dart';
import '../seed/seed_list_cell.dart';

/// 업무 담당자 고르기 — 기관 사람(관리자 포함)을 여럿 고른다.
/// 지금 명단에 없는 사람(퇴사 등)이 담당자로 남아 있어도 목록에서 사라지지 않게 맨 아래에 둔다.
class WorkTaskAssigneePicker {
  /// 고른 담당자 id(채팅 식별자). 닫으면 null
  static Future<List<String>?> show(
    BuildContext context, {
    required String companyId,
    required String meId,
    required List<String> selected,
    Map<String, String> extraNames = const {},
  }) {
    return AppBottomSheet.show<List<String>>(
      context,
      title: '담당자 고르기',
      height: MediaQuery.of(context).size.height * 0.75,
      child: _AssigneeList(
        companyId: companyId,
        meId: meId,
        initial: selected,
        extraNames: extraNames,
      ),
    );
  }
}

class _AssigneeList extends StatefulWidget {
  final String companyId;
  final String meId;
  final List<String> initial;
  final Map<String, String> extraNames;

  const _AssigneeList({
    required this.companyId,
    required this.meId,
    required this.initial,
    required this.extraNames,
  });

  @override
  State<_AssigneeList> createState() => _AssigneeListState();
}

class _AssigneeListState extends State<_AssigneeList> {
  late final List<String> _selected = [...widget.initial];
  List<WorkTaskCandidate>? _people;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final people = await context.read<WorkTaskProvider>().loadPeople(
        widget.companyId,
      );
      if (mounted) setState(() => _people = people);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  /// 나를 맨 위에, 명단에 없는 담당자는 맨 아래에
  List<WorkTaskCandidate> _ordered(List<WorkTaskCandidate> people) {
    final me = people.where((p) => p.id == widget.meId);
    final others = people.where((p) => p.id != widget.meId);
    final known = people.map((p) => p.id).toSet();
    final missing = widget.initial
        .where((id) => !known.contains(id))
        .map(
          (id) => WorkTaskCandidate(
            id: id,
            name: widget.extraNames[id] ?? '알 수 없는 사람',
          ),
        );
    return [...me, ...others, ...missing];
  }

  @override
  Widget build(BuildContext context) {
    final people = _people;
    return Column(
      children: [
        Expanded(
          child: people == null
              ? (_failed
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '명단을 불러오지 못했습니다',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppSemanticColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.space3),
                            SeedButton(
                              label: '다시 시도',
                              variant: SeedButtonVariant.neutralOutline,
                              size: SeedButtonSize.small,
                              onPressed: _load,
                            ),
                          ],
                        ),
                      )
                    : const Center(child: AppLoading()))
              : ListView(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.space2,
                  ),
                  children: [
                    for (final person in _ordered(people))
                      SeedListCell(
                        leading: SeedAvatar(
                          name: person.name,
                          size: SeedAvatarSize.small,
                        ),
                        title: person.id == widget.meId
                            ? '${person.name} (나)'
                            : person.name,
                        description: person.position,
                        showChevron: false,
                        trailing: Checkbox(
                          value: _selected.contains(person.id),
                          onChanged: (_) => _toggle(person.id),
                          activeColor:
                              AppSemanticColors.interactivePrimaryDefault,
                        ),
                        onTap: () => _toggle(person.id),
                      ),
                  ],
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space4,
              AppSpacing.space2,
              AppSpacing.space4,
              AppSpacing.space3,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SeedButton(
                label: _selected.isEmpty
                    ? '담당자를 골라 주세요'
                    : '${_selected.length}명 고르기',
                isDisabled: _selected.isEmpty,
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(_selected),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
