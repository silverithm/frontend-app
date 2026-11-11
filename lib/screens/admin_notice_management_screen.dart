import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../widgets/common/app_action_sheet.dart';
import '../providers/auth_provider.dart';
import '../providers/notice_provider.dart';
import '../models/notice.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_tag.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_fab.dart';
import '../widgets/common/app_loading.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/common/carev_app_bar.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_chip.dart';
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

  /// 목록을 아래로 내리면 FAB 글자를 접는다(B안 알약 FAB).
  bool _fabCollapsed = false;

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
    final direction = _scrollController.position.userScrollDirection;
    if (direction != ScrollDirection.idle) {
      final collapse = direction == ScrollDirection.reverse;
      if (collapse != _fabCollapsed) setState(() => _fabCollapsed = collapse);
    }
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

    await noticeProvider.loadNotices(companyId: companyId, refresh: refresh);
  }

  @override
  Widget build(BuildContext context) {
    // B안: 옅은 회색 바탕 위 흰 카드. 검색칸은 틸 상단 바 아래 띠 대신 본문 맨 위 흰 칸으로.
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundCanvas,
      appBar: widget.showAppBar
          ? CareVAppBar(
              title: '공지사항 관리',
              actions: [
                IconButton(
                  tooltip: '필터',
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilterBottomSheet,
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          _buildSearchBar(),
          if (!widget.showAppBar) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: '필터',
                  icon: Icon(
                    Icons.filter_list,
                    color: AppSemanticColors.textSecondary,
                  ),
                  onPressed: _showFilterBottomSheet,
                ),
              ],
            ),
          ],
          Expanded(
            child: Consumer<NoticeProvider>(
              builder: (context, noticeProvider, child) {
                if (noticeProvider.isLoading &&
                    noticeProvider.notices.isEmpty) {
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
                    // 떠 있는 + 버튼이 마지막 카드의 더보기(⋮)를 가리지 않게 — 배차 설정·휴무 달력과 같은 96
                    padding: const EdgeInsets.only(
                      top: AppSpacing.space1,
                      bottom: 96,
                    ),
                    itemCount:
                        noticeProvider.notices.length +
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
      // B안 알약 FAB — 글자는 예전 툴팁 그대로. 툴팁도 남겨 둔다(찾기용, 낭독은 AppFab이 한 번만)
      floatingActionButton: Tooltip(
        message: '새 공지 작성',
        excludeFromSemantics: true,
        child: AppFab(
          icon: Icons.add,
          label: '새 공지 작성',
          collapsed: _fabCollapsed,
          onPressed: _navigateToCreateNotice,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    // 회색 바탕 위 흰 입력칸(모서리 14, 테두리 없음) — 상단 바 안이든 화면 안이든 같은 모습
    final textColor = AppSemanticColors.textPrimary;
    final hintColor = AppSemanticColors.textTertiary;
    const fillColor = AppSemanticColors.surfaceCard;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.space3,
        AppSpacing.screenGutter,
        AppSpacing.space2,
      ),
      child: TextField(
        controller: _searchController,
        style: AppTypography.bodyMedium.copyWith(color: textColor),
        decoration: InputDecoration(
          hintText: '공지사항 검색...',
          hintStyle: AppTypography.bodyMedium.copyWith(color: hintColor),
          prefixIcon: Icon(Icons.search, color: hintColor),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  tooltip: '검색어 지우기',
                  icon: Icon(Icons.clear, color: hintColor),
                  onPressed: () {
                    _searchController.clear();
                    _loadNotices(refresh: true);
                  },
                )
              : null,
          filled: true,
          fillColor: fillColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.control),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.control),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.control),
            borderSide: const BorderSide(
              color: AppSemanticColors.borderFocus,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space3,
          ),
        ),
        // suffixIcon(지우기 버튼)이 _searchController.text를 참조하므로, 타이핑·클리어
        // 때마다 다시 그려야 즉시 나타나거나 사라진다 — 이 콜백이 없으면 다른 계기로
        // 화면이 리빌드될 때까지 지우기 버튼 표시가 실제 입력값을 따라가지 못했다.
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _loadNotices(refresh: true),
      ),
    );
  }

  Widget _buildNoticeItem(Notice notice) {
    return Dismissible(
      key: Key('notice_${notice.id}'),
      direction: DismissDirection.endToStart,
      // 스와이프 삭제 배경 — 파괴적 행위라 대면적 빨강 자체는 관례상 정당하지만(iOS/Android 공통 패턴),
      // 진한 solid red600 대신 옅은 배경톤(red50)+아이콘 색으로 절제해 화면이 과하게 촌스러워지지 않게 한다.
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.space4),
        color: AppSemanticColors.statusErrorBackground,
        child: Icon(Icons.delete, color: AppSemanticColors.statusErrorIcon),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmDialog(notice);
      },
      onDismissed: (direction) {
        _deleteNotice(notice);
      },
      // 직원 공지 목록(NoticeCard)과 같은 흰 카드·같은 꼬리표 — 예전엔 이 화면만 테마 기본의
      // 청록 회색 카드에, 모든 카드에 '게시됨'이 붙어 정작 다른 '임시저장'이 묻혔고 고정 핀만 갈색이었다.
      // 꼬리표 줄·제목·날짜 세 줄이던 것을 제목 + 날짜 두 줄로 줄이고, 꼬리표는 있을 때만 날짜 줄에 붙인다.
      // B안: 테두리 없는 흰 카드(모서리 20), 카드 사이 간격 12
      child: Card(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenGutter,
          vertical: AppSpacing.cardGap / 2,
        ),
        elevation: 0,
        color: AppSemanticColors.surfaceCard,
        surfaceTintColor: AppSemanticColors.surfaceCard,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.card),
        ),
        child: InkWell(
          onTap: () => _navigateToDetail(notice),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPadding,
              AppSpacing.space4,
              AppSpacing.space1,
              AppSpacing.space4,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notice.title,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppSemanticColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.space1_5),
                      Wrap(
                        spacing: AppSpacing.space2,
                        runSpacing: AppSpacing.space1,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (notice.isPinned)
                            const AppTag(label: '고정', icon: Icons.push_pin),
                          if (notice.priority == NoticePriority.high)
                            const AppTag(label: '긴급', tone: AppTagTone.error),
                          // 게시됨은 기본이라 말하지 않는다 — 임시저장·보관됨일 때만
                          if (notice.status != NoticeStatus.published)
                            AppTag(
                              label: _getStatusText(notice.status),
                              tone: notice.status == NoticeStatus.draft
                                  ? AppTagTone.warning
                                  : AppTagTone.neutral,
                            ),
                          Text(
                            DateFormat('yyyy.MM.dd HH:mm').format(notice.createdAt),
                            style: AppTypography.bodySmall.copyWith(
                              color: AppSemanticColors.textTertiary,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
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
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: AppSemanticColors.textTertiary,
                  ),
                  tooltip: '더보기',
                  onPressed: () => showAppActionSheet(
                    context,
                    title: notice.title,
                    actions: [
                      AppSheetAction(
                        icon: Icons.edit_outlined,
                        label: '수정',
                        onSelected: () => _navigateToEditNotice(notice),
                      ),
                      AppSheetAction(
                        icon: Icons.delete_outline,
                        label: '삭제',
                        isDestructive: true,
                        onSelected: () {
                          _showDeleteConfirmDialog(notice).then((confirmed) {
                            if (confirmed == true) {
                              _deleteNotice(notice);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    // AppEmptyState와 같은 모습(옅은 틸 원 56 + 19 제목 + 14 설명). 작성 단추는 틸 채움으로 남긴다 —
    // AppEmptyState의 단추는 회색이라 회색 바탕 위에서 묻힌다.
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: AppSpacing.space14,
            height: AppSpacing.space14,
            decoration: const BoxDecoration(
              color: AppSemanticColors.brandWeak,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.campaign_outlined,
              size: 26,
              color: AppSemanticColors.brandDefault,
            ),
          ),
          const SizedBox(height: AppSpacing.space3_5),
          Text(
            '공지사항이 없습니다',
            textAlign: TextAlign.center,
            style: AppTypography.heading6.copyWith(
              color: AppSemanticColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.space1_5),
          Text(
            '새로운 공지사항을 작성해보세요',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space5),
          SeedButton(
            label: '공지사항 작성',
            variant: SeedButtonVariant.brandSolid,
            prefixIcon: Icons.add,
            onPressed: _navigateToCreateNotice,
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
          SeedButton(
            label: '다시 시도',
            variant: SeedButtonVariant.neutralWeak,
            onPressed: () => _loadNotices(refresh: true),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    AppBottomSheet.show(
      context,
      child: StatefulBuilder(
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
                      SeedButton(
                        label: '초기화',
                        variant: SeedButtonVariant.neutralWeak,
                        size: SeedButtonSize.small,
                        onPressed: () {
                          setModalState(() {
                            _selectedStatus = null;
                            _selectedPriority = null;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space4),

                  // Status filter
                  Text(
                    '게시 상태',
                    style: AppTypography.titleSmall.copyWith(
                      color: AppSemanticColors.textPrimary,
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
                          selected:
                              _selectedStatus == status.name.toUpperCase(),
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
                    style: AppTypography.titleSmall.copyWith(
                      color: AppSemanticColors.textPrimary,
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
                          selected:
                              _selectedPriority == priority.name.toUpperCase(),
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
                    child: SeedButton(
                      label: '적용',
                      size: SeedButtonSize.large,
                      variant: SeedButtonVariant.brandSolid,
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                        _loadNotices(refresh: true);
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space4),
                ],
              ),
            );
          },
        ),
      );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return SeedChip(label: label, selected: selected, onTap: onSelected);
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
    return AppDialog.showConfirm(
      context,
      title: '공지사항 삭제',
      message: '\'${notice.title}\' 공지사항을 삭제하시겠습니까?\n삭제된 공지사항은 복구할 수 없습니다.',
      confirmText: '삭제',
      cancelText: '취소',
      confirmVariant: SeedButtonVariant.critical,
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
      MaterialPageRoute(builder: (_) => const AdminNoticeFormScreen()),
    );

    if (result == true) {
      _loadNotices(refresh: true);
    }
  }

  void _navigateToEditNotice(Notice notice) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdminNoticeFormScreen(notice: notice)),
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
