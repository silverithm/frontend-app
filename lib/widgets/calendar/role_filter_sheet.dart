import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../utils/role_utils.dart';
import '../common/app_sheet_frame.dart';
import '../seed/seed_button.dart';
import '../seed/seed_chip.dart';

/// 근무조정 직종 거르기 시트(2026-11-15 시안) — 예전 달력 위 칩 줄을 그대로 옮겼다.
/// 칩을 누르면 바로 걸린다(달력이 뒤에서 바로 바뀐다). '전체'는 모두 해제.
Future<void> showRoleFilterSheet(
  BuildContext context, {
  required List<String> roles,
  required List<String> selected,
  required ValueChanged<List<String>> onChanged,
}) {
  return showAppSheet<void>(
    context,
    builder: (context) =>
        _RoleFilterSheet(roles: roles, initial: selected, onChanged: onChanged),
  );
}

/// 상단 바 단추 글자 — '직종 전체' / '요양보호사' / '요양보호사 외 1'
String roleFilterButtonLabel(List<String> selected) {
  if (selected.isEmpty) return '직종 전체';
  final first = RoleUtils.displayName(selected.first);
  return selected.length == 1 ? first : '$first 외 ${selected.length - 1}';
}

class _RoleFilterSheet extends StatefulWidget {
  const _RoleFilterSheet({
    required this.roles,
    required this.initial,
    required this.onChanged,
  });

  final List<String> roles;
  final List<String> initial;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_RoleFilterSheet> createState() => _RoleFilterSheetState();
}

class _RoleFilterSheetState extends State<_RoleFilterSheet> {
  late List<String> _values = List.of(widget.initial);

  void _toggle(String role) {
    final normalized = RoleUtils.normalize(role);
    final next = List<String>.from(_values);
    if (normalized == RoleUtils.allRole) {
      next.clear();
    } else if (!next.remove(normalized)) {
      next.add(normalized);
    }
    setState(() => _values = next);
    widget.onChanged(next);
  }

  Widget _chip(String role, String label) {
    final normalized = RoleUtils.normalize(role);
    final selected = normalized == RoleUtils.allRole
        ? _values.isEmpty
        : _values.contains(normalized);
    return SeedChip(
      label: label,
      selected: selected,
      onTap: () => _toggle(role),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetFrame(
      title: '직종으로 보기',
      message: '하나만 고르면 날짜마다 휴무 인원과 한도가 보입니다',
      actions: SeedButton(
        label: '확인',
        variant: SeedButtonVariant.brandSolid,
        size: SeedButtonSize.large,
        onPressed: () => Navigator.of(context).pop(),
      ),
      children: [
        Wrap(
          spacing: AppSpacing.space2,
          runSpacing: AppSpacing.space2,
          children: [
            _chip(RoleUtils.allRole, '전체'),
            for (final role in widget.roles)
              _chip(role, RoleUtils.displayName(role)),
          ],
        ),
      ],
    );
  }
}
