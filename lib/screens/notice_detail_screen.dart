import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/html_utils.dart';
import '../widgets/plaza_html_body.dart';
import '../providers/notice_provider.dart';
import '../providers/auth_provider.dart';
import '../models/notice.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_tag.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_skeleton.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/common/carev_app_bar.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_list_cell.dart';
import '../widgets/seed/seed_text_field.dart';

class NoticeDetailScreen extends StatefulWidget {
  final int noticeId;

  const NoticeDetailScreen({super.key, required this.noticeId});

  @override
  State<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _showReaders = false;
  bool _isSubmittingComment = false;

  /// 이 글의 첫 불러오기가 끝났는지. 조회수·읽음 기록을 먼저 보내는 동안에는 provider의
  /// isLoading이 아직 false라, 이 값이 없으면 그 사이 '찾을 수 없습니다'(또는 앞서 본 다른 글)가 먼저 보인다.
  bool _initialLoadDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNoticeDetail();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadNoticeDetail() async {
    final noticeProvider = context.read<NoticeProvider>();
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;

    // 조회수 증가
    await noticeProvider.incrementViewCount(noticeId: widget.noticeId);

    // 읽음 기록 (로그인된 사용자만)
    if (currentUser != null) {
      await noticeProvider.markAsRead(
        noticeId: widget.noticeId,
        userId: currentUser.id,
        userName: currentUser.name,
      );
    }

    // 상세 조회
    await noticeProvider.loadNoticeDetail(noticeId: widget.noticeId);
    if (mounted) setState(() => _initialLoadDone = true);

    // 댓글 로드
    await noticeProvider.loadComments(noticeId: widget.noticeId);

    // 읽은 사람 목록 로드
    await noticeProvider.loadReaders(noticeId: widget.noticeId);
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    final noticeProvider = context.read<NoticeProvider>();
    final currentUser = authProvider.currentUser;

    if (currentUser == null) return;

    setState(() => _isSubmittingComment = true);

    final success = await noticeProvider.createComment(
      noticeId: widget.noticeId,
      authorId: currentUser.id,
      authorName: currentUser.name,
      content: _commentController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmittingComment = false);

    if (success) {
      _commentController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _deleteComment(int commentId) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: '댓글 삭제',
      message: '이 댓글을 삭제하시겠습니까?',
      confirmText: '삭제',
      cancelText: '취소',
      confirmVariant: SeedButtonVariant.critical,
    );

    if (confirmed == true && mounted) {
      final noticeProvider = context.read<NoticeProvider>();
      await noticeProvider.deleteComment(
        noticeId: widget.noticeId,
        commentId: commentId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // B안: 옅은 회색 바탕 위 흰 카드 — 제목·본문 / 첨부 / 읽은 사람 / 댓글을 카드로 나눈다(구분선 없음)
      backgroundColor: AppSemanticColors.backgroundCanvas,
      appBar: const CareVAppBar(title: '공지사항', centerTitle: true),
      body: Consumer<NoticeProvider>(
        builder: (context, noticeProvider, child) {
          final notice = noticeProvider.selectedNotice;
          // 아직 이 글을 받지 못했다(비었거나, 앞서 본 다른 글이 남아 있다) — 뼈대
          final waitingFirstLoad =
              !_initialLoadDone &&
              (notice == null || notice.id != widget.noticeId);
          if (waitingFirstLoad ||
              (noticeProvider.isLoading && notice == null)) {
            return const _NoticeDetailSkeleton();
          }

          if (notice == null) {
            return _buildErrorState();
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.screenGutter),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 제목
                            Text(
                              notice.title,
                              style: AppTypography.heading5.copyWith(
                                color: AppSemanticColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.space3),

                            // 메타 정보 — 이름이 길어도 조회수를 밀어내지 않게 줄임표
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    notice.authorName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppSemanticColors.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.space3),
                                Text(
                                  DateFormat(
                                    'yyyy.MM.dd',
                                  ).format(notice.createdAt),
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppSemanticColors.textTertiary,
                                  ),
                                ),
                                const Spacer(),
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
                            // 구분선 대신 간격
                            const SizedBox(height: AppSpacing.space6),

                            // 내용 — 웹에서 서식을 넣어 쓴 공지는 HTML로 그린다.
                            // 평문으로 쌓여 온 옛 공지는 그대로 둬야 줄바꿈이 살아 있다.
                            if (containsHtmlTags(notice.content))
                              PlazaHtmlBody(html: notice.content)
                            else
                              Text(
                                notice.content,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppSemanticColors.textPrimary,
                                  height: 1.6,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // 첨부파일 섹션
                      if (notice.attachments.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.cardGap),
                        _buildAttachmentsSection(notice.attachments),
                      ],

                      const SizedBox(height: AppSpacing.cardGap),

                      // 읽은 사람 섹션
                      _buildReadersSection(noticeProvider),

                      const SizedBox(height: AppSpacing.cardGap),

                      // 댓글 섹션
                      _buildCommentsSection(noticeProvider),
                    ],
                  ),
                ),
              ),

              // 댓글 입력
              _buildCommentInput(),
            ],
          );
        },
      ),
    );
  }

  /// 카드 안 맨 위 제목(B안 카드·구역 제목 18/w700). 줄 목록 카드(안쪽 여백 8)에서는
  /// 줄 글자와 같은 자리(20)에서 시작하도록 좌우 12를 더한다.
  Widget _cardTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space3,
        AppSpacing.space3,
        AppSpacing.space3,
        AppSpacing.space2,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: AppTypography.heading6.copyWith(
            color: AppSemanticColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildReadersSection(NoticeProvider noticeProvider) {
    final readers = noticeProvider.readers;

    // B안: 흰 카드 안 한 줄(누르면 펼침) — 펼친 명단도 같은 카드 안에 이어 붙인다
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SeedListCell(
            leadingIcon: Icons.people_outline,
            title: '읽은 사람 ${readers.length}명',
            trailing: Icon(
              _showReaders ? Icons.expand_less : Icons.expand_more,
              color: AppSemanticColors.textSecondary,
            ),
            onTap: () {
              setState(() {
                _showReaders = !_showReaders;
              });
            },
          ),
          if (_showReaders) ...[
            const SizedBox(height: AppSpacing.space1),
            if (readers.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.space3),
                child: Text(
                  '아직 읽은 사람이 없습니다',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
              )
            else
              ...readers.map((reader) => _buildReaderItem(reader)),
            const SizedBox(height: AppSpacing.space2),
          ],
        ],
      ),
    );
  }

  Widget _buildReaderItem(NoticeReader reader) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space1_5,
      ),
      child: Row(
        children: [
          Container(
            width: AppSpacing.space8,
            height: AppSpacing.space8,
            decoration: BoxDecoration(
              color: AppSemanticColors.fillDefault,
              borderRadius: BorderRadius.circular(AppBorderRadius.full),
            ),
            child: Center(
              child: Text(
                reader.userName.isNotEmpty ? reader.userName[0] : '?',
                style: AppTag.labelStyle.copyWith(
                  color: AppSemanticColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Text(
              reader.userName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          Text(
            DateFormat('MM.dd HH:mm').format(reader.readAt),
            style: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(NoticeProvider noticeProvider) {
    final comments = noticeProvider.comments;

    // B안: 흰 카드 하나에 제목 + 댓글들. 댓글끼리는 테두리 상자 대신 간격으로 나눈다
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardTitle('댓글 ${comments.length}'),
          if (comments.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.space4),
              child: Center(
                child: Text(
                  '아직 댓글이 없습니다',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
              ),
            )
          else
            ...comments.map((comment) => _buildCommentItem(comment)),
          const SizedBox(height: AppSpacing.space2),
        ],
      ),
    );
  }

  Widget _buildCommentItem(NoticeComment comment) {
    final authProvider = context.read<AuthProvider>();
    final isMyComment = authProvider.currentUser?.id == comment.authorId;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space3,
        AppSpacing.space2,
        AppSpacing.space1,
        AppSpacing.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppSpacing.space7,
                height: AppSpacing.space7,
                decoration: BoxDecoration(
                  color: AppSemanticColors.fillDefault,
                  borderRadius: BorderRadius.circular(AppBorderRadius.full),
                ),
                child: Center(
                  child: Text(
                    comment.authorName.isNotEmpty ? comment.authorName[0] : '?',
                    style: AppTag.labelStyle.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              Flexible(
                child: Text(
                  comment.authorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppSemanticColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              Text(
                DateFormat('MM.dd HH:mm').format(comment.createdAt),
                style: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.textTertiary,
                ),
              ),
              const Spacer(),
              if (isMyComment)
                Semantics(
                  button: true,
                  label: '댓글 삭제',
                  child: GestureDetector(
                    onTap: () => _deleteComment(comment.id),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: AppSemanticColors.textTertiary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.space1),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.space2),
            child: Text(
              comment.content,
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.space4,
        right: AppSpacing.space4,
        top: AppSpacing.space3,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.space3,
      ),
      // B안: 회색 바탕 위 흰 띠라 위 선 없이도 나뉜다
      color: AppSemanticColors.surfaceCard,
      child: Row(
        children: [
          Expanded(
            child: SeedTextField(
              label: '댓글',
              showLabel: false,
              placeholder: '댓글을 입력하세요',
              controller: _commentController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submitComment(),
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          Semantics(
            button: true,
            enabled: !_isSubmittingComment,
            label: '댓글 등록',
            child: GestureDetector(
              onTap: _isSubmittingComment ? null : _submitComment,
              child: Container(
                // 채팅 전송 버튼(space10=40px)과 같은 터치 타깃 크기로 통일
                width: AppSpacing.space10,
                height: AppSpacing.space10,
                decoration: BoxDecoration(
                  color: AppSemanticColors.interactivePrimaryDefault,
                  borderRadius: BorderRadius.circular(AppBorderRadius.full),
                ),
                child: Center(
                  child: _isSubmittingComment
                      ? SizedBox(
                          width: AppSpacing.space4,
                          height: AppSpacing.space4,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppSemanticColors.textInverse,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.send,
                          size: AppSpacing.space4,
                          color: AppSemanticColors.textInverse,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection(List<NoticeAttachment> attachments) {
    // B안: 흰 카드 하나에 제목 + 파일 줄(SeedListCell). 줄마다 테두리 상자를 두르지 않는다
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardTitle('첨부파일 ${attachments.length}'),
          ...attachments.map((attachment) => _buildAttachmentItem(attachment)),
        ],
      ),
    );
  }

  Widget _buildAttachmentItem(NoticeAttachment attachment) {
    return SeedListCell(
      // 파일 종류 색(PDF 빨강·문서 파랑·표 초록·사진 노랑)은 그대로 — 모양만 둥근 44
      leading: Container(
        width: AppSpacing.iconCircle,
        height: AppSpacing.iconCircle,
        decoration: BoxDecoration(
          color: _getFileBackgroundColor(attachment),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            _getFileIcon(attachment.fileName),
            size: 22,
            color: _getFileIconColor(attachment),
          ),
        ),
      ),
      title: attachment.fileName,
      description: attachment.fileSizeText,
      trailing: const Icon(
        Icons.download,
        size: 22,
        color: AppSemanticColors.interactivePrimaryDefault,
      ),
      onTap: () => _downloadFile(attachment),
    );
  }

  Future<void> _downloadFile(NoticeAttachment attachment) async {
    if (attachment.fileUrl.isEmpty) {
      if (mounted) {
        AppSnackBar.showError(context, message: '파일 URL이 없습니다');
      }
      return;
    }

    try {
      final uri = Uri.parse(attachment.fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          AppSnackBar.showError(context, message: '파일을 열 수 없습니다');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: '파일 다운로드 오류: $e');
      }
    }
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.toLowerCase();
    if (ext.endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    } else if (ext.endsWith('.doc') || ext.endsWith('.docx')) {
      return Icons.description;
    } else if (ext.endsWith('.xls') || ext.endsWith('.xlsx')) {
      return Icons.table_chart;
    } else if (ext.endsWith('.ppt') || ext.endsWith('.pptx')) {
      return Icons.slideshow;
    } else if (ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.gif') ||
        ext.endsWith('.webp')) {
      return Icons.image;
    } else if (ext.endsWith('.zip') ||
        ext.endsWith('.rar') ||
        ext.endsWith('.7z')) {
      return Icons.folder_zip;
    } else {
      return Icons.insert_drive_file;
    }
  }

  Color _getFileBackgroundColor(NoticeAttachment attachment) {
    final ext = attachment.fileName.toLowerCase();
    if (ext.endsWith('.pdf')) {
      return AppSemanticColors.statusErrorBackground;
    } else if (ext.endsWith('.doc') || ext.endsWith('.docx')) {
      return AppSemanticColors.statusInfoBackground;
    } else if (ext.endsWith('.xls') || ext.endsWith('.xlsx')) {
      return AppSemanticColors.statusSuccessBackground;
    } else if (attachment.isImage) {
      return AppSemanticColors.statusWarningBackground;
    } else {
      return AppSemanticColors.backgroundTertiary;
    }
  }

  Color _getFileIconColor(NoticeAttachment attachment) {
    final ext = attachment.fileName.toLowerCase();
    if (ext.endsWith('.pdf')) {
      return AppSemanticColors.statusErrorIcon;
    } else if (ext.endsWith('.doc') || ext.endsWith('.docx')) {
      return AppSemanticColors.statusInfoIcon;
    } else if (ext.endsWith('.xls') || ext.endsWith('.xlsx')) {
      return AppSemanticColors.statusSuccessIcon;
    } else if (attachment.isImage) {
      return AppSemanticColors.statusWarningIcon;
    } else {
      return AppSemanticColors.textSecondary;
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: AppSpacing.space16,
            color: AppSemanticColors.statusErrorIcon,
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            '공지사항을 찾을 수 없습니다',
            style: AppTypography.bodyLarge.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          SeedButton(
            label: '돌아가기',
            variant: SeedButtonVariant.neutralWeak,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// 공지 상세 첫 불러오기 뼈대 — 회색 바탕 위 흰 카드(제목·본문 카드와 같은 바깥 여백)
class _NoticeDetailSkeleton extends StatelessWidget {
  const _NoticeDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppSkeleton(
      baseColor: AppSemanticColors.skeletonBaseOnCard,
      child: SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(AppSpacing.screenGutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSkeletonCard(
              standalone: false,
              margin: EdgeInsets.only(bottom: AppSpacing.cardGap),
            ),
            AppSkeletonCard(standalone: false, margin: EdgeInsets.zero),
          ],
        ),
      ),
    );
  }
}
