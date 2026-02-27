import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/notice.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'notice_priority_badge.dart';

class NoticeCard extends StatelessWidget {
  final Notice notice;
  final VoidCallback? onTap;
  final bool showStatus;
  final bool isAdmin;

  const NoticeCard({
    super.key,
    required this.notice,
    this.onTap,
    this.showStatus = false,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space2,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        side: BorderSide(
          color: notice.isPinned
              ? AppSemanticColors.statusWarningIcon.withValues(alpha: 0.5)
              : AppSemanticColors.borderDefault,
          width: notice.isPinned ? 2 : 1,
        ),
      ),
      color: notice.isPinned
          ? AppSemanticColors.statusWarningBackground.withValues(alpha: 0.3)
          : AppSemanticColors.surfaceDefault,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with badges
              Row(
                children: [
                  if (notice.isPinned) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space2,
                        vertical: AppSpacing.space0_5,
                      ),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.statusWarningIcon,
                        borderRadius: BorderRadius.circular(AppBorderRadius.base),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.push_pin,
                            size: 12,
                            color: AppSemanticColors.textInverse,
                          ),
                          const SizedBox(width: AppSpacing.space0_5),
                          Text(
                            '고정',
                            style: AppTypography.overline.copyWith(
                              color: AppSemanticColors.textInverse,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space2),
                  ],
                  NoticePriorityBadge(
                    priority: notice.priority,
                    small: true,
                  ),
                  if (showStatus) ...[
                    const SizedBox(width: AppSpacing.space2),
                    NoticeStatusBadge(
                      status: notice.status,
                      small: true,
                    ),
                  ],
                  const Spacer(),
                  Text(
                    _formatDate(notice.createdAt),
                    style: AppTypography.caption.copyWith(
                      color: AppSemanticColors.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space3),

              // Title
              Text(
                notice.title,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppSemanticColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.space2),

              // Content preview
              Text(
                notice.content,
                style: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.space3),

              // Footer
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: AppSemanticColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.space1),
                  Text(
                    notice.authorName,
                    style: AppTypography.caption.copyWith(
                      color: AppSemanticColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space4),
                  Icon(
                    Icons.visibility_outlined,
                    size: 14,
                    color: AppSemanticColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.space1),
                  Text(
                    '${notice.viewCount}',
                    style: AppTypography.caption.copyWith(
                      color: AppSemanticColors.textTertiary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppSemanticColors.textTertiary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}분 전';
      }
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return DateFormat('MM/dd').format(date);
    }
  }
}

class NoticeCardCompact extends StatelessWidget {
  final Notice notice;
  final VoidCallback? onTap;

  const NoticeCardCompact({
    super.key,
    required this.notice,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space3,
        ),
        child: Row(
          children: [
            // Priority indicator
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: _priorityColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.space3),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (notice.isPinned) ...[
                        Icon(
                          Icons.push_pin,
                          size: 14,
                          color: AppSemanticColors.statusWarningIcon,
                        ),
                        const SizedBox(width: AppSpacing.space1),
                      ],
                      Expanded(
                        child: Text(
                          notice.title,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppSemanticColors.textPrimary,
                            fontWeight: notice.isPinned ? FontWeight.w600 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space1),
                  Text(
                    _formatDate(notice.createdAt),
                    style: AppTypography.caption.copyWith(
                      color: AppSemanticColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            // Chevron
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppSemanticColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Color get _priorityColor {
    switch (notice.priority) {
      case NoticePriority.high:
        return AppSemanticColors.statusErrorIcon;
      case NoticePriority.normal:
        return AppSemanticColors.statusInfoIcon;
      case NoticePriority.low:
        return AppSemanticColors.statusSuccessIcon;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '오늘';
    } else if (difference.inDays == 1) {
      return '어제';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return DateFormat('MM/dd').format(date);
    }
  }
}
