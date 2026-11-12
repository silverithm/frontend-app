import 'package:flutter/material.dart';
import '../../models/notice.dart';
import '../common/app_tag.dart';

/// 공지 게시 상태 꼬리표 — B안: 테두리 없는 옅은 알약([AppTag]).
/// 색의 뜻은 그대로다: 임시저장=회색, 게시됨=초록, 보관됨=노랑.
class NoticeStatusBadge extends StatelessWidget {
  final NoticeStatus status;

  /// 예전 작은 배지 자리 표시. B안 꼬리표는 크기가 하나라 모습은 같다(글자는 12 아래로 줄이지 않는다).
  final bool small;

  const NoticeStatusBadge({
    super.key,
    required this.status,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppTag(label: _text, tone: _tone, icon: _icon);
  }

  AppTagTone get _tone {
    switch (status) {
      case NoticeStatus.draft:
        return AppTagTone.neutral;
      case NoticeStatus.published:
        return AppTagTone.success;
      case NoticeStatus.archived:
        return AppTagTone.warning;
    }
  }

  IconData get _icon {
    switch (status) {
      case NoticeStatus.draft:
        return Icons.edit_outlined;
      case NoticeStatus.published:
        return Icons.check_circle_outline;
      case NoticeStatus.archived:
        return Icons.archive_outlined;
    }
  }

  String get _text {
    switch (status) {
      case NoticeStatus.draft:
        return '임시저장';
      case NoticeStatus.published:
        return '게시됨';
      case NoticeStatus.archived:
        return '보관됨';
    }
  }
}
