import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/notice_provider.dart';
import '../providers/auth_provider.dart';
import '../models/notice.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_loading.dart';

class NoticeDetailScreen extends StatefulWidget {
  final int noticeId;

  const NoticeDetailScreen({
    super.key,
    required this.noticeId,
  });

  @override
  State<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _showReaders = false;
  bool _isSubmittingComment = false;

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

    setState(() => _isSubmittingComment = false);

    if (success) {
      _commentController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _deleteComment(int commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => shadcn.AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('이 댓글을 삭제하시겠습니까?'),
        actions: [
          shadcn.OutlineButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          shadcn.DestructiveButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
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
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: Text(
          '공지사항',
          style: AppTypography.heading6.copyWith(
            color: AppSemanticColors.textPrimary,
          ),
        ),
        backgroundColor: AppSemanticColors.backgroundPrimary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<NoticeProvider>(
        builder: (context, noticeProvider, child) {
          if (noticeProvider.isLoading && noticeProvider.selectedNotice == null) {
            return const Center(child: AppLoading());
          }

          final notice = noticeProvider.selectedNotice;

          if (notice == null) {
            return _buildErrorState();
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 제목
                      Text(
                        notice.title,
                        style: AppTypography.heading5.copyWith(
                          color: AppSemanticColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space4),

                      // 메타 정보
                      Row(
                        children: [
                          Text(
                            notice.authorName,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppSemanticColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.space3),
                          Text(
                            DateFormat('yyyy.MM.dd').format(notice.createdAt),
                            style: AppTypography.bodySmall.copyWith(
                              color: AppSemanticColors.textTertiary,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.visibility_outlined,
                            size: 14,
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
                      const SizedBox(height: AppSpacing.space4),

                      // 구분선
                      Divider(
                        color: AppSemanticColors.borderDefault,
                        height: 1,
                      ),
                      const SizedBox(height: AppSpacing.space4),

                      // 내용
                      Text(
                        notice.content,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppSemanticColors.textPrimary,
                          height: 1.6,
                        ),
                      ),

                      // 첨부파일 섹션
                      if (notice.attachments.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.space6),
                        _buildAttachmentsSection(notice.attachments),
                      ],

                      const SizedBox(height: AppSpacing.space6),

                      // 읽은 사람 섹션
                      _buildReadersSection(noticeProvider),

                      const SizedBox(height: AppSpacing.space4),

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

  Widget _buildReadersSection(NoticeProvider noticeProvider) {
    final readers = noticeProvider.readers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _showReaders = !_showReaders;
            });
          },
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.space3),
            decoration: BoxDecoration(
              color: AppSemanticColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 18,
                  color: AppSemanticColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.space2),
                Text(
                  '읽은 사람 ${readers.length}명',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Icon(
                  _showReaders ? Icons.expand_less : Icons.expand_more,
                  color: AppSemanticColors.textSecondary,
                ),
              ],
            ),
          ),
        ),

        if (_showReaders) ...[
          const SizedBox(height: AppSpacing.space3),
          if (readers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.space4),
              child: Text(
                '아직 읽은 사람이 없습니다',
                style: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.textTertiary,
                ),
              ),
            )
          else
            ...readers.map((reader) => _buildReaderItem(reader)),
        ],
      ],
    );
  }

  Widget _buildReaderItem(NoticeReader reader) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space2),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppSemanticColors.backgroundTertiary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                reader.userName.isNotEmpty ? reader.userName[0] : '?',
                style: AppTypography.labelSmall.copyWith(
                  color: AppSemanticColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Text(
              reader.userName,
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textPrimary,
              ),
            ),
          ),
          Text(
            DateFormat('MM.dd HH:mm').format(reader.readAt),
            style: AppTypography.caption.copyWith(
              color: AppSemanticColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(NoticeProvider noticeProvider) {
    final comments = noticeProvider.comments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.comment_outlined,
              size: 18,
              color: AppSemanticColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.space2),
            Text(
              '댓글 ${comments.length}',
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space3),

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

        const SizedBox(height: AppSpacing.space4),
      ],
    );
  }

  Widget _buildCommentItem(NoticeComment comment) {
    final authProvider = context.read<AuthProvider>();
    final isMyComment = authProvider.currentUser?.id == comment.authorId;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space3),
      padding: const EdgeInsets.all(AppSpacing.space3),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(
          color: AppSemanticColors.borderDefault,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppSemanticColors.backgroundTertiary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    comment.authorName.isNotEmpty ? comment.authorName[0] : '?',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppSemanticColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              Text(
                comment.authorName,
                style: AppTypography.labelMedium.copyWith(
                  color: AppSemanticColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              Text(
                DateFormat('MM.dd HH:mm').format(comment.createdAt),
                style: AppTypography.caption.copyWith(
                  color: AppSemanticColors.textTertiary,
                ),
              ),
              const Spacer(),
              if (isMyComment)
                GestureDetector(
                  onTap: () => _deleteComment(comment.id),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            comment.content,
            style: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.textPrimary,
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
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        border: Border(
          top: BorderSide(
            color: AppSemanticColors.borderDefault,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: '댓글을 입력하세요',
                hintStyle: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.textTertiary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  borderSide: BorderSide(
                    color: AppSemanticColors.borderDefault,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  borderSide: BorderSide(
                    color: AppSemanticColors.borderDefault,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  borderSide: BorderSide(
                    color: AppSemanticColors.interactivePrimaryDefault,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space4,
                  vertical: AppSpacing.space2,
                ),
                isDense: true,
              ),
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textPrimary,
              ),
              maxLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submitComment(),
            ),
          ),
          const SizedBox(width: AppSpacing.space2),
          GestureDetector(
            onTap: _isSubmittingComment ? null : _submitComment,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppSemanticColors.interactivePrimaryDefault,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: _isSubmittingComment
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppSemanticColors.textInverse,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.send,
                        size: 16,
                        color: AppSemanticColors.textInverse,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection(List<NoticeAttachment> attachments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.attach_file,
              size: 18,
              color: AppSemanticColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.space2),
            Text(
              '첨부파일 ${attachments.length}',
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space3),
        ...attachments.map((attachment) => _buildAttachmentItem(attachment)),
      ],
    );
  }

  Widget _buildAttachmentItem(NoticeAttachment attachment) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space2),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(
          color: AppSemanticColors.borderDefault,
        ),
      ),
      child: InkWell(
        onTap: () => _downloadFile(attachment),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space3),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getFileBackgroundColor(attachment),
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                ),
                child: Center(
                  child: Icon(
                    _getFileIcon(attachment.fileName),
                    size: 20,
                    color: _getFileIconColor(attachment),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.fileName,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppSemanticColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.space1),
                    Text(
                      attachment.fileSizeText,
                      style: AppTypography.caption.copyWith(
                        color: AppSemanticColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.download,
                size: 20,
                color: AppSemanticColors.interactivePrimaryDefault,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadFile(NoticeAttachment attachment) async {
    if (attachment.fileUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('파일 URL이 없습니다'),
            backgroundColor: AppSemanticColors.statusErrorIcon,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return;
    }

    try {
      final uri = Uri.parse(attachment.fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('파일을 열 수 없습니다'),
              backgroundColor: AppSemanticColors.statusErrorIcon,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('파일 다운로드 오류: $e'),
            backgroundColor: AppSemanticColors.statusErrorIcon,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
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
    } else if (ext.endsWith('.zip') || ext.endsWith('.rar') || ext.endsWith('.7z')) {
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
            size: 64,
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
          shadcn.PrimaryButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('돌아가기'),
          ),
        ],
      ),
    );
  }
}
