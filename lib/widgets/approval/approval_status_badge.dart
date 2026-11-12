import 'package:flutter/material.dart';
import '../../models/approval.dart';
import '../common/app_tag.dart';

/// 결재 상태 알약 — B안: 테두리 없는 옅은 알약([AppTag]), 12/w600.
/// 색의 뜻은 그대로: 임시저장 회색 · 진행중 노랑 · 승인됨 초록 · 반려됨 빨강.
class ApprovalStatusBadge extends StatelessWidget {
  final ApprovalStatus status;

  /// 예전 작은 알약 자리 — B안 꼬리표는 한 크기라 모양은 같다(쓰는 곳 호환용).
  final bool compact;

  const ApprovalStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final (tone, text) = _getStatusStyle();
    return AppTag(label: text, tone: tone);
  }

  (AppTagTone, String) _getStatusStyle() {
    switch (status) {
      case ApprovalStatus.draft:
        // 임시저장 — 아직 상신 전이라 승인/반려와 구분되는 중립 회색
        return (AppTagTone.neutral, '임시저장');
      case ApprovalStatus.pending:
        return (AppTagTone.warning, '진행중');
      case ApprovalStatus.approved:
        return (AppTagTone.success, '승인됨');
      case ApprovalStatus.rejected:
        return (AppTagTone.error, '반려됨');
    }
  }
}
