import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/html_utils.dart';
import '../../models/notice.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_card.dart';
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
    // B안: 회색 바탕 위 흰 카드, 테두리 없음, 모서리 20·안쪽 여백 20, 카드끼리는 간격 12.
    // 고정 공지도 같은 카드다 — 노란 바탕·굵은 테두리 대신 '고정' 꼬리표 하나로 알린다(웹 공지 목록과 같다)
    return AppCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenGutter,
        vertical: AppSpacing.cardGap / 2,
      ),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with badges — 꼬리표가 많아도 날짜를 밀어내지 않게 줄바꿈한다
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.space2,
                  runSpacing: AppSpacing.space1,
                  children: [
                    if (notice.isPinned)
                      const AppTag(label: '고정', icon: Icons.push_pin),
                    // 일반 공지는 기본이라 꼬리표를 달지 않는다 — 긴급·낮음만 말한다
                    if (notice.priority == NoticePriority.high)
                      const AppTag(label: '긴급', tone: AppTagTone.error)
                    else if (notice.priority == NoticePriority.low)
                      const AppTag(label: '낮음'),
                    if (showStatus)
                      NoticeStatusBadge(status: notice.status, small: true),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              Text(
                _formatDate(notice.createdAt),
                style: AppTypography.bodySmall.copyWith(
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

          // Footer — 이름이 길어도 줄 밖으로 넘치지 않게 줄임표
          Row(
            children: [
              // 왼쪽 묶음(작성자·조회수)이 남는 폭을 다 갖고, 꺾쇠는 오른쪽 끝에 붙는다
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 16,
                      color: AppSemanticColors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.space1),
                    Flexible(
                      child: Text(
                        notice.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppSemanticColors.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space4),
                    const Icon(
                      Icons.visibility_outlined,
                      size: 16,
                      color: AppSemanticColors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.space1),
                    Text(
                      '${notice.viewCount}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppSemanticColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppSemanticColors.iconSubtle,
              ),
            ],
          ),
        ],
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
