import 'package:flutter/material.dart';

import '../../models/approval.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 결재선 단계 — 크로박스 단계 표시(1·2·3·4 동그라미를 선으로 잇는 것)를 결재에 옮긴 것(2026-11-14).
///
/// 기안 → 검토 → 결재를 동그라미로 잇고, 끝난 단계는 틸 동그라미에 체크, 지금 차례는 틸 동그라미에
/// 순번 + 옅은 틸 고리, 남은 단계는 회색 동그라미, 반려는 빨간 동그라미에 X.
/// 예전엔 '결재 차례 김관리 (1/2 승인)' 한 줄 글자로만 보여, 누가 끝냈고 누가 남았는지 한눈에 안 들어왔다.
class ApprovalLineStepper extends StatelessWidget {
  final String requesterName;
  final DateTime requestedAt;
  final List<ApprovalStepModel> steps;

  const ApprovalLineStepper({
    super.key,
    required this.requesterName,
    required this.requestedAt,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    final ordered = [...steps]
      ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
    final firstPending = ordered.indexWhere((s) => s.status == 'PENDING');
    final anyRejected = ordered.any((s) => s.status == 'REJECTED');

    final nodes = <_Node>[
      _Node(
        role: '기안',
        name: requesterName,
        note: _date(requestedAt),
        state: _StepState.done,
        number: 1,
      ),
      for (var i = 0; i < ordered.length; i++)
        _Node(
          role: ordered[i].roleLabel == 'FINAL' ? '결재' : '검토',
          name: ordered[i].approverName,
          note: _noteFor(
            ordered[i],
            isCurrent: !anyRejected && i == firstPending,
          ),
          state: _stateFor(
            ordered[i],
            isCurrent: !anyRejected && i == firstPending,
          ),
          number: i + 2,
        ),
    ];

    return Semantics(
      label:
          '결재 단계 ${nodes.map((n) => '${n.role} ${n.name} ${n.semantic}').join(', ')}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < nodes.length; i++)
            Expanded(
              child: _StepColumn(
                node: nodes[i],
                lineLeft: i == 0 ? null : nodes[i].reached,
                lineRight: i == nodes.length - 1 ? null : nodes[i + 1].reached,
              ),
            ),
        ],
      ),
    );
  }

  static String _date(DateTime d) => '${d.month}/${d.day}';

  static _StepState _stateFor(ApprovalStepModel s, {required bool isCurrent}) {
    switch (s.status) {
      case 'APPROVED':
        return _StepState.done;
      case 'REJECTED':
        return _StepState.rejected;
      case 'SKIPPED':
        return _StepState.skipped;
      default:
        return isCurrent ? _StepState.current : _StepState.waiting;
    }
  }

  static String _noteFor(ApprovalStepModel s, {required bool isCurrent}) {
    switch (s.status) {
      case 'APPROVED':
        return s.processedAt != null ? _date(s.processedAt!) : '승인';
      case 'REJECTED':
        return '반려';
      case 'SKIPPED':
        return '건너뜀';
      default:
        return isCurrent ? '지금 차례' : '대기';
    }
  }
}

enum _StepState { done, current, waiting, rejected, skipped }

class _Node {
  final String role;
  final String name;
  final String note;
  final _StepState state;
  final int number;

  const _Node({
    required this.role,
    required this.name,
    required this.note,
    required this.state,
    required this.number,
  });

  /// 이 단계까지 결재가 닿았는지 — 앞 선을 틸로 칠한다.
  bool get reached =>
      state != _StepState.waiting && state != _StepState.skipped;

  String get semantic {
    switch (state) {
      case _StepState.done:
        return '끝남';
      case _StepState.current:
        return '지금 차례';
      case _StepState.waiting:
        return '대기';
      case _StepState.rejected:
        return '반려';
      case _StepState.skipped:
        return '건너뜀';
    }
  }
}

class _StepColumn extends StatelessWidget {
  final _Node node;
  final bool? lineLeft;
  final bool? lineRight;

  const _StepColumn({required this.node, this.lineLeft, this.lineRight});

  static const double _dot = 32;
  static const double _ring = 4;

  Color _line(bool on) =>
      on ? AppSemanticColors.brandDefault : AppSemanticColors.borderDefault;

  @override
  Widget build(BuildContext context) {
    final isCurrent = node.state == _StepState.current;
    final Color fill;
    final Widget mark;
    switch (node.state) {
      case _StepState.done:
        fill = AppSemanticColors.brandDefault;
        mark = const Icon(
          Icons.check_rounded,
          size: 18,
          color: AppSemanticColors.textInverse,
        );
      case _StepState.current:
        fill = AppSemanticColors.brandDefault;
        mark = _number(AppSemanticColors.textInverse);
      case _StepState.rejected:
        fill = AppSemanticColors.statusErrorIcon;
        mark = const Icon(
          Icons.close_rounded,
          size: 18,
          color: AppSemanticColors.textInverse,
        );
      case _StepState.skipped:
        fill = AppSemanticColors.fillDefault;
        mark = const Icon(
          Icons.remove_rounded,
          size: 18,
          color: AppSemanticColors.textTertiary,
        );
      case _StepState.waiting:
        fill = AppSemanticColors.fillDefault;
        mark = _number(AppSemanticColors.textTertiary);
    }

    final noteColor = switch (node.state) {
      _StepState.current => AppSemanticColors.brandWeakForeground,
      _StepState.rejected => AppSemanticColors.statusErrorText,
      _ => AppSemanticColors.textTertiary,
    };

    return Column(
      children: [
        SizedBox(
          height: _dot + _ring * 2,
          child: Row(
            children: [
              Expanded(
                child: lineLeft == null
                    ? const SizedBox.shrink()
                    : Container(height: 2, color: _line(lineLeft!)),
              ),
              Container(
                width: _dot + _ring * 2,
                height: _dot + _ring * 2,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent ? AppSemanticColors.brandWeak : null,
                ),
                child: Container(
                  width: _dot,
                  height: _dot,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fill,
                  ),
                  child: mark,
                ),
              ),
              Expanded(
                child: lineRight == null
                    ? const SizedBox.shrink()
                    : Container(height: 2, color: _line(lineRight!)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space1_5),
        Text(
          node.role,
          textAlign: TextAlign.center,
          style: AppTypography.titleSmall.copyWith(
            color: isCurrent
                ? AppSemanticColors.brandWeakForeground
                : AppSemanticColors.textPrimary,
          ),
        ),
        Text(
          node.name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySmall.copyWith(
            color: AppSemanticColors.textSecondary,
          ),
        ),
        Text(
          node.note,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelStrong.copyWith(color: noteColor),
        ),
      ],
    );
  }

  Widget _number(Color color) => Text(
    '${node.number}',
    style: AppTypography.titleSmall.copyWith(
      color: color,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}
