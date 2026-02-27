import 'package:flutter/material.dart';
import '../../models/notice.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class NoticePriorityBadge extends StatelessWidget {
  final NoticePriority priority;
  final bool small;

  const NoticePriorityBadge({
    super.key,
    required this.priority,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? AppSpacing.space2 : AppSpacing.space3,
        vertical: small ? AppSpacing.space0_5 : AppSpacing.space1,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.base),
        border: Border.all(
          color: _borderColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _icon,
            size: small ? 12 : 14,
            color: _textColor,
          ),
          SizedBox(width: small ? AppSpacing.space0_5 : AppSpacing.space1),
          Text(
            _text,
            style: (small ? AppTypography.overline : AppTypography.labelSmall).copyWith(
              color: _textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color get _backgroundColor {
    switch (priority) {
      case NoticePriority.high:
        return AppSemanticColors.statusErrorBackground;
      case NoticePriority.normal:
        return AppSemanticColors.statusInfoBackground;
      case NoticePriority.low:
        return AppSemanticColors.statusSuccessBackground;
    }
  }

  Color get _borderColor {
    switch (priority) {
      case NoticePriority.high:
        return AppSemanticColors.statusErrorIcon.withValues(alpha: 0.3);
      case NoticePriority.normal:
        return AppSemanticColors.statusInfoIcon.withValues(alpha: 0.3);
      case NoticePriority.low:
        return AppSemanticColors.statusSuccessIcon.withValues(alpha: 0.3);
    }
  }

  Color get _textColor {
    switch (priority) {
      case NoticePriority.high:
        return AppSemanticColors.statusErrorText;
      case NoticePriority.normal:
        return AppSemanticColors.statusInfoText;
      case NoticePriority.low:
        return AppSemanticColors.statusSuccessText;
    }
  }

  IconData get _icon {
    switch (priority) {
      case NoticePriority.high:
        return Icons.priority_high;
      case NoticePriority.normal:
        return Icons.info_outline;
      case NoticePriority.low:
        return Icons.arrow_downward;
    }
  }

  String get _text {
    switch (priority) {
      case NoticePriority.high:
        return '긴급';
      case NoticePriority.normal:
        return '일반';
      case NoticePriority.low:
        return '낮음';
    }
  }
}

class NoticeStatusBadge extends StatelessWidget {
  final NoticeStatus status;
  final bool small;

  const NoticeStatusBadge({
    super.key,
    required this.status,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? AppSpacing.space2 : AppSpacing.space3,
        vertical: small ? AppSpacing.space0_5 : AppSpacing.space1,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.base),
        border: Border.all(
          color: _borderColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _icon,
            size: small ? 12 : 14,
            color: _textColor,
          ),
          SizedBox(width: small ? AppSpacing.space0_5 : AppSpacing.space1),
          Text(
            _text,
            style: (small ? AppTypography.overline : AppTypography.labelSmall).copyWith(
              color: _textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color get _backgroundColor {
    switch (status) {
      case NoticeStatus.draft:
        return AppSemanticColors.backgroundTertiary;
      case NoticeStatus.published:
        return AppSemanticColors.statusSuccessBackground;
      case NoticeStatus.archived:
        return AppSemanticColors.statusWarningBackground;
    }
  }

  Color get _borderColor {
    switch (status) {
      case NoticeStatus.draft:
        return AppSemanticColors.borderDefault;
      case NoticeStatus.published:
        return AppSemanticColors.statusSuccessIcon.withValues(alpha: 0.3);
      case NoticeStatus.archived:
        return AppSemanticColors.statusWarningIcon.withValues(alpha: 0.3);
    }
  }

  Color get _textColor {
    switch (status) {
      case NoticeStatus.draft:
        return AppSemanticColors.textSecondary;
      case NoticeStatus.published:
        return AppSemanticColors.statusSuccessText;
      case NoticeStatus.archived:
        return AppSemanticColors.statusWarningText;
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
