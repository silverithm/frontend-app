import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/html_utils.dart';
import '../../models/notice.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_tag.dart';
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
      // 고정 공지도 같은 카드다 — 노란 바탕·굵은 테두리 대신 '고정' 꼬리표 하나로 알린다(웹 공지 목록과 같다)
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        side: const BorderSide(color: AppSemanticColors.borderDefault),
      ),
      color: AppSemanticColors.surfaceDefault,
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
                    const AppTag(label: '고정', icon: Icons.push_pin),
                    const SizedBox(width: AppSpacing.space2),
                  ],
                  // 일반 공지는 기본이라 꼬리표를 달지 않는다 — 긴급·낮음만 말한다
                  if (notice.priority == NoticePriority.high) ...[
                    const AppTag(label: '긴급', tone: AppTagTone.error),
                    const SizedBox(width: AppSpacing.space2),
                  ] else if (notice.priority == NoticePriority.low) ...[
                    const AppTag(label: '낮음'),
                    const SizedBox(width: AppSpacing.space2),
                  ],
                  if (showStatus) ...[
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
                style: AppTypography.titleMedium.copyWith(
                  color: AppSemanticColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.space2),

              // Content preview — 서식 공지만 태그를 걷어낸다 (평문의 꺾쇠 표기는 보존)
              Text(
                containsHtmlTags(notice.content)
                    ? stripHtmlToPlainText(notice.content)
                    : notice.content,
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
