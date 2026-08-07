import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/seed/seed_button.dart';

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
      final response =
          await ApiService().getPlazaPostDetail(postId: widget.postId);
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
    final comments = (post?['comments'] as List?)
            ?.whereType<Map>()
            .map((c) => Map<String, dynamic>.from(c))
            .toList() ??
        [];
    final createdAt =
        DateTime.tryParse(post?['createdAt']?.toString() ?? '');

    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: Text('게시글',
            style: AppTypography.heading6
                .copyWith(color: AppSemanticColors.textInverse)),
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        foregroundColor: AppSemanticColors.textInverse,
        actions: [
          if (post?['isMine'] == true)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deletePost,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : post == null
              ? const Center(child: Text('게시글을 불러올 수 없습니다'))
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.all(AppSpacing.space4),
                          children: [
                            Text(
                              post['title']?.toString() ?? '',
                              style: AppTypography.heading5.copyWith(
                                color: AppSemanticColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.space2),
                            Text(
                              '${post['displayAuthor'] ?? ''}${createdAt != null ? ' · ${DateFormat('yyyy.MM.dd HH:mm').format(createdAt)}' : ''} · 조회 ${post['viewCount'] ?? 0}',
                              style: AppTypography.caption.copyWith(
                                  color: AppSemanticColors.textTertiary),
                            ),
                            const Divider(height: AppSpacing.space6),
                            Text(
                              post['content']?.toString() ?? '',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppSemanticColors.textPrimary,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.space4),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: _toggleLike,
                                  child: Container(
                                    height: AppSpacing.space9,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.space3_5,
                                      vertical: AppSpacing.space2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.transparent,
                                      borderRadius: BorderRadius.circular(
                                        AppBorderRadius.lg,
                                      ),
                                      border: Border.all(
                                        color: AppSemanticColors.borderDefault,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          post['likedByMe'] == true
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          size: 16,
                                          color: post['likedByMe'] == true
                                              ? AppSemanticColors
                                                  .statusErrorIcon
                                              : AppSemanticColors
                                                  .textSecondary,
                                        ),
                                        const SizedBox(
                                          width: AppSpacing.space1,
                                        ),
                                        Text(
                                          '좋아요 ${post['likeCount'] ?? 0}',
                                          style: AppTypography.bodySmall
                                              .copyWith(
                                            color:
                                                AppSemanticColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: AppSpacing.space6),
                            Text(
                              '댓글 ${comments.length}',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppSemanticColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.space2),
                            ...comments.map((comment) {
                              final commentCreatedAt = DateTime.tryParse(
                                  comment['createdAt']?.toString() ?? '');
                              return Container(
                                margin: const EdgeInsets.only(
                                    bottom: AppSpacing.space2),
                                padding:
                                    const EdgeInsets.all(AppSpacing.space3),
                                decoration: BoxDecoration(
                                  color: AppSemanticColors.surfaceDefault,
                                  borderRadius: BorderRadius.circular(
                                      AppBorderRadius.xl),
                                  border: Border.all(
                                      color: comment['isAccepted'] == true
                                          ? AppSemanticColors.statusSuccessIcon
                                          : AppSemanticColors.borderDefault),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (comment['isAccepted'] == true) ...[
                                          Icon(Icons.check_circle,
                                              size: 14,
                                              color: AppSemanticColors
                                                  .statusSuccessIcon),
                                          const SizedBox(
                                              width: AppSpacing.space1),
                                        ],
                                        Expanded(
                                          child: Text(
                                            '${comment['displayAuthor'] ?? ''}${commentCreatedAt != null ? ' · ${DateFormat('MM.dd HH:mm').format(commentCreatedAt)}' : ''}',
                                            style: AppTypography.caption
                                                .copyWith(
                                                    color: AppSemanticColors
                                                        .textTertiary),
                                          ),
                                        ),
                                        if (comment['isMine'] == true)
                                          GestureDetector(
                                            onTap: () {
                                              final commentId = comment['id'];
                                              if (commentId is int) {
                                                _deleteComment(commentId);
                                              }
                                            },
                                            child: Icon(Icons.close,
                                                size: 14,
                                                color: AppSemanticColors
                                                    .textTertiary),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.space1),
                                    Text(
                                      comment['content']?.toString() ?? '',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppSemanticColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: AppSpacing.space10),
                          ],
                        ),
                      ),
                    ),

                    // 댓글 입력
                    SafeArea(
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.space3),
                        decoration: BoxDecoration(
                          color: AppSemanticColors.surfaceDefault,
                          border: Border(
                            top: BorderSide(
                                color: AppSemanticColors.borderDefault),
                          ),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _commentAnonymous,
                              visualDensity: VisualDensity.compact,
                              activeColor: AppSemanticColors.brandDefault,
                              onChanged: (value) => setState(
                                  () => _commentAnonymous = value ?? false),
                            ),
                            Text(
                              '익명',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppSemanticColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.space2),
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppSemanticColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: '댓글을 입력하세요',
                                  hintStyle: AppTypography.bodySmall.copyWith(
                                    color: AppSemanticColors.textTertiary,
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.space3,
                                    vertical: AppSpacing.space2,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppBorderRadius.xl),
                                    borderSide: BorderSide(
                                      color: AppSemanticColors.borderDefault,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppBorderRadius.xl),
                                    borderSide: BorderSide(
                                      color: AppSemanticColors.borderDefault,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppBorderRadius.xl),
                                    borderSide: BorderSide(
                                      color: AppSemanticColors
                                          .interactivePrimaryDefault,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.send,
                                  color: AppSemanticColors
                                      .interactivePrimaryDefault),
                              onPressed: _addComment,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
