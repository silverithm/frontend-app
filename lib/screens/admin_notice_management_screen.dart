import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../providers/auth_provider.dart';
import '../providers/notice_provider.dart';
import '../models/notice.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/notice/notice_priority_badge.dart';
import '../widgets/common/app_loading.dart';
import '../widgets/common/app_snackbar.dart';
import 'admin_notice_form_screen.dart';
import 'notice_detail_screen.dart';

class AdminNoticeManagementScreen extends StatefulWidget {
  final bool showAppBar;
  const AdminNoticeManagementScreen({super.key, this.showAppBar = true});

  @override
  State<AdminNoticeManagementScreen> createState() =>
      _AdminNoticeManagementScreenState();
}

class _AdminNoticeManagementScreenState
    extends State<AdminNoticeManagementScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  String? _selectedStatus;
  String? _selectedPriority;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotices(refresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadNotices();
    }
  }

  Future<void> _loadNotices({bool refresh = false}) async {
    final authProvider = context.read<AuthProvider>();
    final noticeProvider = context.read<NoticeProvider>();

    final companyId = authProvider.currentUser?.company?.id ?? '1';

    // 필터 적용
    noticeProvider.setFilters(
      status: _selectedStatus,
      priority: _selectedPriority,
      search: _searchController.text.isNotEmpty ? _searchController.text : null,
    );

    await noticeProvider.loadNotices(
      companyId: companyId,
      refresh: refresh,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(
                '공지사항 관리',
                style: AppTypography.heading6.copyWith(
                  color: AppSemanticColors.textInverse,
                ),
              ),
              backgroundColor: AppSemanticColors.interactivePrimaryDefault,
              foregroundColor: AppSemanticColors.textInverse,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilterBottomSheet,
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(70),
                child: _buildSearchBar(),
              ),
            )
          : null,
      body: Column(
        children: [
          if (!widget.showAppBar) ...[
            _buildSearchBar(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.filter_list, color: AppSemanticColors.textSecondary),
                  onPressed: _showFilterBottomSheet,
                ),
              ],
            ),
          ],
          Expanded(
            child: Consumer<NoticeProvider>(
              builder: (context, noticeProvider, child) {
                if (noticeProvider.isLoading && noticeProvider.notices.isEmpty) {
                  return const Center(child: AppLoading());
                }

                if (noticeProvider.errorMessage.isNotEmpty &&
                    noticeProvider.notices.isEmpty) {
                  return _buildErrorState(noticeProvider.errorMessage);
                }

                if (noticeProvider.notices.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () => _loadNotices(refresh: true),
                  color: AppSemanticColors.interactivePrimaryDefault,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
                    itemCount: noticeProvider.notices.length +
                        (noticeProvider.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == noticeProvider.notices.length) {
                        return const Padding(
                          padding: EdgeInsets.all(AppSpacing.space4),
                          child: Center(child: AppLoading(size: 24)),
                        );
                      }

                      final notice = noticeProvider.notices[index];
                      return _buildNoticeItem(notice);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'admin_notice_fab',
        onPressed: _navigateToCreateNotice,
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchBar() {
    final isEmbedded = !widget.showAppBar;
    final textColor = isEmbedded
        ? AppSemanticColors.textPrimary
        : AppSemanticColors.textInverse;
    final hintColor = isEmbedded
        ? AppSemanticColors.textTertiary
        : AppSemanticColors.textInverse.withValues(alpha: 0.6);
    final fillColor = isEmbedded
        ? AppSemanticColors.backgroundTertiary
        : AppSemanticColors.textInverse.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space2,
      ),
      child: TextField(
        controller: _searchController,
        style: AppTypography.bodyMedium.copyWith(
          color: textColor,
        ),
        decoration: InputDecoration(
          hintText: '공지사항 검색...',
          hintStyle: AppTypography.bodyMedium.copyWith(
            color: hintColor,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: hintColor,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: hintColor,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _loadNotices(refresh: true);
                  },
                )
              : null,
          filled: true,
          fillColor: fillColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space3,
          ),
        ),
        onSubmitted: (_) => _loadNotices(refresh: true),
      ),
    );
  }

  Widget _buildNoticeItem(Notice notice) {
    return Dismissible(
      key: Key('notice_${notice.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.space4),
        color: AppSemanticColors.statusErrorIcon,
        child: const Icon(
          Icons.delete,
          color: AppColors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmDialog(notice);
      },
      onDismissed: (direction) {
        _deleteNotice(notice);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space2,
        ),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          side: BorderSide(color: AppSemanticColors.borderDefault),
        ),
        child: InkWell(
          onTap: () => _navigateToDetail(notice),
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    if (notice.isPinned) ...[
                      Icon(
                        Icons.push_pin,
                        size: 16,
                        color: AppSemanticColors.statusWarningIcon,
                      ),
                      const SizedBox(width: AppSpacing.space1),
                    ],
                    NoticePriorityBadge(
                      priority: notice.priority,
                      small: true,
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    NoticeStatusBadge(
                      status: notice.status,
                      small: true,
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: AppSemanticColors.textTertiary,
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _navigateToEditNotice(notice);
                            break;
                          case 'delete':
                            _showDeleteConfirmDialog(notice).then((confirmed) {
                              if (confirmed == true) {
                                _deleteNotice(notice);
                              }
                            });
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              const SizedBox(width: AppSpacing.space2),
                              Text('수정'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete,
                                size: 20,
                                color: AppSemanticColors.statusErrorIcon,
                              ),
                              const SizedBox(width: AppSpacing.space2),
                              Text(
                                '삭제',
                                style: TextStyle(
                                  color: AppSemanticColors.statusErrorIcon,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space2),

                // Title
                Text(
                  notice.title,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppSemanticColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.space2),

                // Footer
                Row(
                  children: [
                    Text(
                      DateFormat('yyyy.MM.dd HH:mm').format(notice.createdAt),
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
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 64,
            color: AppSemanticColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            '공지사항이 없습니다',
            style: AppTypography.bodyLarge.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            '새로운 공지사항을 작성해보세요',
            style: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          shadcn.PrimaryButton(
            onPressed: _navigateToCreateNotice,
            leading: const Icon(Icons.add),
            child: const Text('공지사항 작성'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
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
            '오류가 발생했습니다',
            style: AppTypography.bodyLarge.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space8),
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          shadcn.PrimaryButton(
            onPressed: () => _loadNotices(refresh: true),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppBorderRadius.xl2),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.space4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '필터',
                        style: AppTypography.heading6.copyWith(
                          color: AppSemanticColors.textPrimary,
                        ),
                      ),
                      shadcn.GhostButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedStatus = null;
                            _selectedPriority = null;
                          });
                        },
                        child: Text(
                          '초기화',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppSemanticColors.interactivePrimaryDefault,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space4),

                  // Status filter
                  Text(
                    '게시 상태',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  Wrap(
                    spacing: AppSpacing.space2,
                    children: [
                      _buildFilterChip(
                        label: '전체',
                        selected: _selectedStatus == null,
                        onSelected: () {
                          setModalState(() => _selectedStatus = null);
                        },
                      ),
                      ...NoticeStatus.values.map((status) {
                        return _buildFilterChip(
                          label: _getStatusText(status),
                          selected: _selectedStatus == status.name.toUpperCase(),
                          onSelected: () {
                            setModalState(() {
                              _selectedStatus = status.name.toUpperCase();
                            });
                          },
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space4),

                  // Priority filter
                  Text(
                    '우선순위',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  Wrap(
                    spacing: AppSpacing.space2,
                    children: [
                      _buildFilterChip(
                        label: '전체',
                        selected: _selectedPriority == null,
                        onSelected: () {
                          setModalState(() => _selectedPriority = null);
                        },
                      ),
                      ...NoticePriority.values.map((priority) {
                        return _buildFilterChip(
                          label: _getPriorityText(priority),
                          selected: _selectedPriority == priority.name.toUpperCase(),
                          onSelected: () {
                            setModalState(() {
                              _selectedPriority = priority.name.toUpperCase();
                            });
                          },
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space6),

                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: shadcn.PrimaryButton(
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                        _loadNotices(refresh: true);
                      },
                      child: const Text('적용'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space4),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppSemanticColors.interactivePrimaryDefault.withValues(
        alpha: 0.1,
      ),
      checkmarkColor: AppSemanticColors.interactivePrimaryDefault,
      labelStyle: AppTypography.labelSmall.copyWith(
        color: selected
            ? AppSemanticColors.interactivePrimaryDefault
            : AppSemanticColors.textSecondary,
      ),
    );
  }

  String _getStatusText(NoticeStatus status) {
    switch (status) {
      case NoticeStatus.draft:
        return '임시저장';
      case NoticeStatus.published:
        return '게시됨';
      case NoticeStatus.archived:
        return '보관됨';
    }
  }

  String _getPriorityText(NoticePriority priority) {
    switch (priority) {
      case NoticePriority.high:
        return '긴급';
      case NoticePriority.normal:
        return '일반';
      case NoticePriority.low:
        return '낮음';
    }
  }

  Future<bool?> _showDeleteConfirmDialog(Notice notice) {
    return showDialog<bool>(
      context: context,
      builder: (context) => shadcn.AlertDialog(
        title: Text(
          '공지사항 삭제',
          style: AppTypography.heading6.copyWith(
            color: AppSemanticColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\'${notice.title}\' 공지사항을 삭제하시겠습니까?\n삭제된 공지사항은 복구할 수 없습니다.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textSecondary,
              ),
            ),
          ],
        ),
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
  }

  Future<void> _deleteNotice(Notice notice) async {
    final authProvider = context.read<AuthProvider>();
    final noticeProvider = context.read<NoticeProvider>();
    final companyId = authProvider.currentUser?.company?.id ?? '1';

    final success = await noticeProvider.deleteNotice(
      noticeId: notice.id,
      companyId: companyId,
    );

    if (mounted) {
      if (success) {
        AppSnackBar.showSuccess(context, message: '공지사항이 삭제되었습니다');
      } else {
        AppSnackBar.showError(
          context,
          message: noticeProvider.errorMessage.isNotEmpty
              ? noticeProvider.errorMessage
              : '삭제에 실패했습니다',
        );
        // 삭제 실패 시 목록 새로고침
        _loadNotices(refresh: true);
      }
    }
  }

  void _navigateToCreateNotice() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const AdminNoticeFormScreen(),
      ),
    );

    if (result == true) {
      _loadNotices(refresh: true);
    }
  }

  void _navigateToEditNotice(Notice notice) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminNoticeFormScreen(notice: notice),
      ),
    );

    if (result == true) {
      _loadNotices(refresh: true);
    }
  }

  void _navigateToDetail(Notice notice) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoticeDetailScreen(noticeId: notice.id),
      ),
    );
  }
}
