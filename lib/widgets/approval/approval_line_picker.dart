import 'package:flutter/material.dart';

import '../../models/approval.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 결재선 지정 위젯.
/// 후보(관리자 + 결재 권한 보유 직원)에서 순서대로 선택 — 마지막이 최종 결재자.
class ApprovalLinePicker extends StatefulWidget {
  final String companyId;
  final List<ApproverCandidate> selected;
  final VoidCallback? onChanged;
  final int maxSteps;

  const ApprovalLinePicker({
    super.key,
    required this.companyId,
    required this.selected,
    this.onChanged,
    this.maxSteps = 5,
  });

  @override
  State<ApprovalLinePicker> createState() => _ApprovalLinePickerState();
}

class _ApprovalLinePickerState extends State<ApprovalLinePicker> {
  List<ApproverCandidate> _candidates = [];
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  Future<void> _loadCandidates() async {
    try {
      final response =
          await ApiService().getApproverCandidates(companyId: widget.companyId);
      final list = (response['candidates'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _candidates = list
              .whereType<Map>()
              .map((c) => ApproverCandidate.fromJson(Map<String, dynamic>.from(c)))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('결재자 후보 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
      }
    }
  }

  void _notify() {
    setState(() {});
    widget.onChanged?.call();
  }

  void _showCandidateSheet() {
    final selectedKeys = widget.selected.map((c) => c.key).toSet();
    final available =
        _candidates.where((c) => !selectedKeys.contains(c.key)).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppSemanticColors.surfaceDefault,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.space4),
              child: Text('결재자 선택',
                  style: AppTypography.heading6
                      .copyWith(fontWeight: FontWeight.bold)),
            ),
            if (available.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.space4),
                child: Text('추가할 수 있는 결재자가 없습니다.',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppSemanticColors.textTertiary)),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: available.length,
                  itemBuilder: (context, index) {
                    final candidate = available[index];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            AppSemanticColors.interactivePrimaryDefault
                                .withValues(alpha: 0.1),
                        child: Text(
                          candidate.name.isNotEmpty ? candidate.name[0] : '?',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppSemanticColors.interactivePrimaryDefault,
                          ),
                        ),
                      ),
                      title: Text(candidate.name,
                          style: AppTypography.bodyMedium),
                      subtitle: Text(
                        candidate.position ??
                            (candidate.approverType == 'ADMIN' ? '관리자' : '직원'),
                        style: AppTypography.caption
                            .copyWith(color: AppSemanticColors.textTertiary),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        widget.selected.add(candidate);
                        _notify();
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('결재선',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppSemanticColors.textPrimary,
                  fontWeight: FontWeight.w700,
                )),
            Text(' *',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppSemanticColors.statusErrorIcon)),
            const Spacer(),
            if (!_isLoading && widget.selected.length < widget.maxSteps)
              TextButton.icon(
                onPressed: _showCandidateSheet,
                icon: const Icon(Icons.person_add_alt, size: 16),
                label: const Text('추가', style: TextStyle(fontSize: 13)),
              ),
          ],
        ),
        Text(
          '순서대로 승인이 진행됩니다. 마지막 사람이 최종 결재자입니다. (최대 ${widget.maxSteps}명)',
          style:
              AppTypography.caption.copyWith(color: AppSemanticColors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.space2),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_loadFailed)
          Text('결재자 목록을 불러오지 못했습니다.',
              style: AppTypography.caption
                  .copyWith(color: AppSemanticColors.statusErrorIcon))
        else if (widget.selected.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.space3),
            decoration: BoxDecoration(
              color: AppSemanticColors.statusWarningBackground,
              borderRadius: BorderRadius.circular(AppSpacing.space3),
            ),
            child: Text('결재자를 1명 이상 지정해주세요.',
                style: AppTypography.caption
                    .copyWith(color: AppSemanticColors.statusWarningIcon)),
          )
        else
          Column(
            children: List.generate(widget.selected.length, (index) {
              final candidate = widget.selected[index];
              final isLast = index == widget.selected.length - 1;
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.space1),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space3, vertical: AppSpacing.space1),
                decoration: BoxDecoration(
                  color: AppSemanticColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(AppSpacing.space3),
                  border: Border.all(color: AppSemanticColors.borderDefault),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isLast
                            ? AppSemanticColors.interactivePrimaryDefault
                            : AppSemanticColors.backgroundTertiary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${index + 1}. ${isLast ? '결재' : '검토'}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isLast
                              ? AppSemanticColors.textInverse
                              : AppSemanticColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    Expanded(
                      child: Text(
                        '${candidate.name}${candidate.position != null ? ' · ${candidate.position}' : ''}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppSemanticColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.arrow_upward, size: 15),
                      onPressed: index == 0
                          ? null
                          : () {
                              final item = widget.selected.removeAt(index);
                              widget.selected.insert(index - 1, item);
                              _notify();
                            },
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.arrow_downward, size: 15),
                      onPressed: isLast
                          ? null
                          : () {
                              final item = widget.selected.removeAt(index);
                              widget.selected.insert(index + 1, item);
                              _notify();
                            },
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 15),
                      onPressed: () {
                        widget.selected.removeAt(index);
                        _notify();
                      },
                    ),
                  ],
                ),
              );
            }),
          ),
      ],
    );
  }
}
