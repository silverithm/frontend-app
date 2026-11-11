import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/html_utils.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_refresh.dart';
import '../widgets/common/app_skeleton.dart';
import '../widgets/common/carev_app_bar.dart';
import '../widgets/plaza_html_body.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_text_field.dart';
import 'plaza_screen.dart'
    show plazaBoardLabel, plazaIsJobBoard, showPlazaPostEditor;
import '../widgets/common/app_tag.dart';

/// 광장 게시글 상세 + 댓글
class PlazaPostDetailScreen extends StatefulWidget {
  final int postId;

  const PlazaPostDetailScreen({super.key, required this.postId});

  @override
  State<PlazaPostDetailScreen> createState() => _PlazaPostDetailScreenState();
}

class _PlazaPostDetailScreenState extends State<PlazaPostDetailScreen> {
  final _commentController = TextEditingController();
  Map<String, dynamic>? _post;
  bool _isLoading = true;
  bool _commentAnonymous = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final response = await ApiService().getPlazaPostDetail(
        postId: widget.postId,
      );
      final raw = response['post'] ?? response;
      if (mounted && raw is Map) {
        setState(() {
          _post = Map<String, dynamic>.from(raw);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('게시글 상세 로드 실패: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    try {
      await ApiService().togglePlazaPostLike(postId: widget.postId);
      _load();
    } catch (e) {
      debugPrint('좋아요 실패: $e');
    }
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    final user = context.read<AuthProvider>().currentUser;
    try {
      await ApiService().addPlazaComment(
        postId: widget.postId,
        content: content,
        isAnonymous: _commentAnonymous,
        authorName: user?.name,
        companyName: user?.company?.name,
      );
      _commentController.clear();
      FocusScope.of(context).unfocus();
      _load();
    } catch (e) {
      debugPrint('댓글 작성 실패: $e');
    }
  }

  Future<void> _editPost() async {
    final updated = await showPlazaPostEditor(context, existingPost: _post);
    if (updated == true) _load();
  }

  Future<void> _deletePost() async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: '게시글 삭제',
      message: '이 게시글을 삭제하시겠습니까?',
      confirmText: '삭제',
      cancelText: '취소',
      confirmVariant: SeedButtonVariant.critical,
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService().deletePlazaPost(postId: widget.postId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('게시글 삭제 실패: $e');
    }
  }

  Future<void> _deleteComment(int commentId) async {
    try {
      await ApiService().deletePlazaComment(commentId: commentId);
      _load();
    } catch (e) {
      debugPrint('댓글 삭제 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final comments =
        (post?['comments'] as List?)
            ?.whereType<Map>()
            .map((c) => Map<String, dynamic>.from(c))
            .toList() ??
        [];
    final createdAt = DateTime.tryParse(post?['createdAt']?.toString() ?? '');

    return Scaffold(
      // B안: 옅은 회색 바탕 위 흰 카드 — 글 카드 / 댓글 카드(구분선·테두리 상자 없음)
      backgroundColor: AppSemanticColors.backgroundCanvas,
      appBar: CareVAppBar(
        title: '게시글',
        actions: [
          if (post?['isMine'] == true) ...[
            IconButton(
              tooltip: '수정',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editPost,
            ),
            IconButton(
              tooltip: '삭제',
              icon: const Icon(Icons.delete_outline),
              onPressed: _deletePost,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const _PostDetailSkeleton()
          : post == null
          ? const Center(child: Text('게시글을 불러올 수 없습니다'))
          : Column(
              children: [
                Expanded(
                  child: AppRefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.screenGutter),
                      children: [
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppTag(
                                label: plazaBoardLabel(
                                  post['board']?.toString(),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.space2),
                              Text(
                                post['title']?.toString() ?? '',
                                style: AppTypography.heading5.copyWith(
                                  color: AppSemanticColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.space2),
                              Text(
                                '${post['displayAuthor'] ?? ''}${createdAt != null ? ' · ${DateFormat('yyyy.MM.dd HH:mm').format(createdAt)}' : ''} · 조회 ${post['viewCount'] ?? 0}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppSemanticColors.textTertiary,
                                ),
                              ),
                              // 구분선 대신 간격
                              const SizedBox(height: AppSpacing.space6),
                              // 웹 리치텍스트 에디터로 쓴 글만 HTML로 그린다
                              // (예전에는 태그가 그대로 노출되는 표시 버그가 있었다).
                              // 앱에서 쓴 평문 글까지 HTML로 넘기면 flutter_html이 `\n`을
                              // 공백으로 바꿔 줄바꿈이 전멸한다 — 공지 상세와 같은 분기를 둔다.
                              if (containsHtmlTags(
                                post['content']?.toString() ?? '',
                              ))
                                PlazaHtmlBody(
                                  html: post['content']?.toString() ?? '',
                                )
                              else
                                Text(
                                  post['content']?.toString() ?? '',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppSemanticColors.textPrimary,
                                    height: 1.6,
                                  ),
                                ),
                              if (plazaIsJobBoard(
                                post['board']?.toString(),
                              )) ...[
                                const SizedBox(height: AppSpacing.space4),
                                _ContactInfoCard(post: post),
                              ],
                              const SizedBox(height: AppSpacing.space5),
                              _LikeChip(
                                liked: post['likedByMe'] == true,
                                count: post['likeCount'] ?? 0,
                                onTap: _toggleLike,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.cardGap),
                        AppCard(
                          padding: const EdgeInsets.all(AppSpacing.space2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.space3,
                                  AppSpacing.space3,
                                  AppSpacing.space3,
                                  AppSpacing.space2,
                                ),
                                child: Semantics(
                                  header: true,
                                  child: Text(
                                    '댓글 ${comments.length}',
                                    style: AppTypography.heading6.copyWith(
                                      color: AppSemanticColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              ...comments.map(
                                (comment) => _PlazaCommentItem(
                                  comment: comment,
                                  onDelete: () {
                                    final commentId = comment['id'];
                                    if (commentId is int) {
                                      _deleteComment(commentId);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(height: AppSpacing.space2),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space10),
                      ],
                    ),
                  ),
                ),

                // 댓글 입력 — 회색 바탕 위 흰 띠라 위 선 없이도 나뉜다.
                // 흰 띠가 홈 표시줄 자리까지 이어지게 SafeArea를 안쪽에 둔다.
                ColoredBox(
                  color: AppSemanticColors.surfaceCard,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.space3),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _commentAnonymous,
                            visualDensity: VisualDensity.compact,
                            activeColor: AppSemanticColors.brandDefault,
                            onChanged: (value) => setState(
                              () => _commentAnonymous = value ?? false,
                            ),
                          ),
                          Text(
                            '익명',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppSemanticColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.space2),
                          Expanded(
                            child: SeedTextField(
                              label: '댓글',
                              showLabel: false,
                              placeholder: '댓글을 입력하세요',
                              controller: _commentController,
                            ),
                          ),
                          IconButton(
                            tooltip: '댓글 등록',
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            icon: Icon(
                              Icons.send,
                              color:
                                  AppSemanticColors.interactivePrimaryDefault,
                            ),
                            onPressed: _addComment,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// 좋아요 단추 — B안: 테두리 없는 옅은 회색 알약(높이 44 이상). 누른 상태의 빨간 하트는 그대로.
class _LikeChip extends StatelessWidget {
  final bool liked;
  final Object count;
  final VoidCallback onTap;

  const _LikeChip({
    required this.liked,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space2,
        ),
        decoration: BoxDecoration(
          color: AppSemanticColors.fillDefault,
          borderRadius: BorderRadius.circular(AppBorderRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              liked ? Icons.favorite : Icons.favorite_border,
              size: 18,
              color: liked
                  ? AppSemanticColors.statusErrorIcon
                  : AppSemanticColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.space1_5),
            Text(
              '좋아요 $count',
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 댓글 한 개 — B안: 테두리 상자 없이 간격으로 나눈다.
/// Q&A 채택 댓글은 초록 테두리 대신 옅은 초록 바탕 + 초록 체크로 알린다(뜻은 그대로).
class _PlazaCommentItem extends StatelessWidget {
  final Map<String, dynamic> comment;
  final VoidCallback onDelete;

  const _PlazaCommentItem({required this.comment, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isAccepted = comment['isAccepted'] == true;
    final commentCreatedAt = DateTime.tryParse(
      comment['createdAt']?.toString() ?? '',
    );
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space1),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space3,
        AppSpacing.space2,
        AppSpacing.space1,
        AppSpacing.space3,
      ),
      decoration: isAccepted
          ? BoxDecoration(
              color: AppSemanticColors.statusSuccessBackground,
              borderRadius: BorderRadius.circular(AppBorderRadius.control),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 삭제 단추(48) 자리가 없어도 머리줄 높이가 같게 최소 높이를 둔다
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Row(
              children: [
                if (isAccepted) ...[
                  const Icon(
                    Icons.check_circle,
                    size: 18,
                    color: AppSemanticColors.statusSuccessIcon,
                  ),
                  const SizedBox(width: AppSpacing.space1),
                ],
                Expanded(
                  child: Text(
                    '${comment['displayAuthor'] ?? ''}${commentCreatedAt != null ? ' · ${DateFormat('MM.dd HH:mm').format(commentCreatedAt)}' : ''}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppSemanticColors.textTertiary,
                    ),
                  ),
                ),
                if (comment['isMine'] == true)
                  Semantics(
                    button: true,
                    label: '댓글 삭제',
                    child: GestureDetector(
                      onTap: onDelete,
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
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.space2),
            child: Text(
              comment['content']?.toString() ?? '',
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 구인·구직 글의 연락처 표시. 비공개(회원 전용)이면서 비로그인/서버가 감춘 경우
/// `contactInfo`가 null로 내려오므로 그 상태를 그대로 안내한다.
class _ContactInfoCard extends StatelessWidget {
  final Map<String, dynamic> post;

  const _ContactInfoCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final contactInfo = post['contactInfo']?.toString();
    final isPublic = post['contactPublic'] == true;
    final hasContact = contactInfo != null && contactInfo.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.space3_5),
      decoration: BoxDecoration(
        color: AppSemanticColors.brandWeak,
        borderRadius: BorderRadius.circular(AppBorderRadius.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.call_outlined,
            size: 18,
            color: AppSemanticColors.brandPressed,
          ),
          const SizedBox(width: AppSpacing.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '연락처',
                      style: AppTypography.labelStrong.copyWith(
                        color: AppSemanticColors.brandPressed,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space1_5),
                    Text(
                      isPublic ? '전체공개' : '회원공개',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppSemanticColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  hasContact ? contactInfo : '로그인 후 연락처를 볼 수 있어요',
                  style: AppTypography.bodyMedium.copyWith(
                    color: hasContact
                        ? AppSemanticColors.textPrimary
                        : AppSemanticColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 게시글 상세 첫 불러오기 뼈대 — 회색 바탕 위 흰 카드(본문 카드와 같은 여백)
class _PostDetailSkeleton extends StatelessWidget {
  const _PostDetailSkeleton();

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
