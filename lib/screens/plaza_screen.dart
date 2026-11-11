import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:provider/provider.dart';
import 'package:dio/dio.dart' as dio;
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/external_notice.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/korean_keep_all.dart';
import '../utils/html_utils.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_callout.dart';
import '../widgets/seed/seed_chip.dart';
import '../widgets/seed/seed_text_field.dart';
import 'plaza_post_detail_screen.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_empty_state.dart';
import '../widgets/common/app_fab.dart';
import '../widgets/common/app_list_entrance.dart';
import '../widgets/common/app_refresh.dart';
import '../widgets/common/app_skeleton.dart';
import '../widgets/common/app_segmented_tabs.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/common/app_tag.dart';
import '../widgets/common/carev_app_bar.dart';

/// 게시판 key → 화면 표시 라벨. 목록·상세·글쓰기 시트가 공통으로 쓴다.
String plazaBoardLabel(String? key) {
  switch (key) {
    case 'qna':
      return 'Q&A';
    case 'review':
      return '후기';
    case 'job_offer':
      return '구인';
    case 'job_seek':
      return '구직';
    default:
      return '자유';
  }
}

bool plazaIsJobBoard(String? key) => key == 'job_offer' || key == 'job_seek';

/// 게시글 작성/수정 바텀시트. [existingPost]를 주면 수정 모드(제목·내용·연락처를
/// 채워서 열고 저장 시 PUT), 생략하면 [initialBoard]로 새 글을 작성한다(POST).
/// 게시판 탭(작성)과 게시글 상세 화면(수정)이 함께 쓴다.
Future<bool?> showPlazaPostEditor(
  BuildContext context, {
  Map<String, dynamic>? existingPost,
  String initialBoard = 'free',
}) async {
  final isEdit = existingPost != null;
  final titleController =
      TextEditingController(text: existingPost?['title']?.toString() ?? '');
  // 웹 서식 편집기로 쓴 글은 본문이 HTML이다. 평문 TextField에 원문을 그대로 넣으면
  // <p>·<br>이 날것으로 보이고, 그 상태로 저장하면 본문이 망가진다. 그래서 읽을 수
  // 있는 평문으로 풀어서 채우고, 저장할 때 들어온 모양(HTML)으로 다시 올린다.
  // 주의: 굵게·색 같은 서식은 이 과정에서 사라진다. 앱에 서식 편집기가 없는 동안에는
  // 태그가 날것으로 보이는 것보다 낫다는 판단이다 (서식을 지키려면 웹에서 수정할 것).
  final rawContent = existingPost?['content']?.toString() ?? '';
  final contentWasHtml = containsHtmlTags(rawContent);
  final contentController = TextEditingController(
      text: contentWasHtml ? htmlToEditableText(rawContent) : rawContent);
  final contactController = TextEditingController(
      text: existingPost?['contactInfo']?.toString() ?? '');
  String board = existingPost?['board']?.toString() ?? initialBoard;
  bool isAnonymous = existingPost?['isAnonymous'] == true;
  bool contactPublic = existingPost?['contactPublic'] == true;
  final user = context.read<AuthProvider>().currentUser;

  final saved = await AppBottomSheet.show<bool>(
    context,
    title: isEdit ? '글 수정' : '글 쓰기',
    isScrollControlled: true,
    child: StatefulBuilder(
      builder: (context, setSheetState) {
        final isJobBoard = plazaIsJobBoard(board);
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.space4,
            right: AppSpacing.space4,
            top: AppSpacing.space4,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.space4,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: board,
                  // 테두리·라벨색 등은 AppTheme.inputDecorationTheme(토큰 기반)을
                  // 그대로 물려받는다 — 필드마다 다른 radius로 손조립하지 않는다.
                  decoration: const InputDecoration(labelText: '게시판'),
                  items: const [
                    DropdownMenuItem(value: 'free', child: Text('자유')),
                    DropdownMenuItem(value: 'qna', child: Text('Q&A')),
                    DropdownMenuItem(value: 'review', child: Text('후기')),
                    DropdownMenuItem(value: 'job_offer', child: Text('구인')),
                    DropdownMenuItem(value: 'job_seek', child: Text('구직')),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => board = value ?? 'free'),
                ),
                const SizedBox(height: AppSpacing.space3),
                SeedTextField(
                  label: '제목',
                  controller: titleController,
                ),
                const SizedBox(height: AppSpacing.space3),
                SeedTextField(
                  label: '내용',
                  controller: contentController,
                  maxLines: 6,
                ),
                if (isJobBoard) ...[
                  const SizedBox(height: AppSpacing.space3),
                  SeedTextField(
                    label: '연락처',
                    placeholder: '전화번호·이메일 등',
                    controller: contactController,
                  ),
                  const SizedBox(height: AppSpacing.space1),
                  Row(
                    children: [
                      Checkbox(
                        value: contactPublic,
                        activeColor: AppSemanticColors.brandDefault,
                        onChanged: (value) => setSheetState(
                            () => contactPublic = value ?? false),
                      ),
                      Expanded(
                        child: Text(
                          '연락처 전체 공개 (끄면 로그인 회원에게만 보여요)',
                          style: AppTypography.bodySmall.copyWith(
                              color: AppSemanticColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
                Row(
                  children: [
                    Checkbox(
                      value: isAnonymous,
                      activeColor: AppSemanticColors.brandDefault,
                      onChanged: (value) =>
                          setSheetState(() => isAnonymous = value ?? false),
                    ),
                    Text(
                      '익명으로 작성',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppSemanticColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space2),
                SizedBox(
                  width: double.infinity,
                  child: SeedButton(
                    label: isEdit ? '수정' : '등록',
                    variant: SeedButtonVariant.brandSolid,
                    onPressed: () async {
                      if (titleController.text.trim().isEmpty ||
                          contentController.text.trim().isEmpty) {
                        return;
                      }
                      // 들어온 모양대로 돌려놓는다 — HTML이던 글은 줄바꿈을 <br>로
                      // 되살려 저장해야 웹에서 한 줄로 뭉치지 않는다.
                      // 원래 평문이던 글은 평문 그대로 둔다.
                      final content = contentWasHtml
                          ? plainTextToHtml(contentController.text.trim())
                          : contentController.text.trim();
                      try {
                        if (isEdit) {
                          await ApiService().updatePlazaPost(
                            postId: existingPost['id'] as int,
                            board: board,
                            title: titleController.text.trim(),
                            content: content,
                            isAnonymous: isAnonymous,
                            authorName: user?.name,
                            companyName: user?.company?.name,
                            contactInfo:
                                isJobBoard ? contactController.text.trim() : null,
                            contactPublic: isJobBoard && contactPublic,
                          );
                        } else {
                          await ApiService().createPlazaPost(
                            board: board,
                            title: titleController.text.trim(),
                            content: content,
                            isAnonymous: isAnonymous,
                            authorName: user?.name,
                            companyName: user?.company?.name,
                            contactInfo:
                                isJobBoard ? contactController.text.trim() : null,
                            contactPublic: isJobBoard && contactPublic,
                          );
                        }
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (e) {
                        debugPrint('게시글 ${isEdit ? '수정' : '작성'} 실패: $e');
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  return saved;
}

/// 케어브이 커뮤니티: 요양 소식(언론 보도 + 장기요양보험공단 자료) · 게시판 · 자료실
class PlazaScreen extends StatefulWidget {
  const PlazaScreen({super.key});

  @override
  State<PlazaScreen> createState() => _PlazaScreenState();
}

class _PlazaScreenState extends State<PlazaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // B안: 옅은 회색 바탕, 상단 바 안 TabBar 대신 본문 맨 위 나눔 조절(같은 TabController)
      backgroundColor: AppSemanticColors.backgroundCanvas,
      appBar: const CareVAppBar(title: '케어브이 커뮤니티'),
      body: Column(
        children: [
          AppSegmentedTabs(
            controller: _tabController,
            tabs: const [
              AppSegmentedTab('요양 소식'),
              AppSegmentedTab('게시판'),
              AppSegmentedTab('자료실'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const _NewsTab(),
                const _BoardTab(),
                _LibraryTab(onGoToFreeBoard: () => _tabController.animateTo(1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 공통: 거르기 칩 줄 · 목록 여백 · FAB 접힘 ───

/// 탭마다 맨 위에 놓이는 거르기 칩 줄 — B안: 회색 바탕 위 흰 칩(44), 높이를 못 박지 않아
/// 글자를 키워도 칩이 잘리지 않는다.
class _PlazaFilterChips extends StatelessWidget {
  final List<Map<String, String>> options;
  final String selectedKey;
  final ValueChanged<String> onSelected;

  const _PlazaFilterChips({
    required this.options,
    required this.selectedKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.space1,
        AppSpacing.screenGutter,
        AppSpacing.space1,
      ),
      child: Row(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.space2),
              child: SeedChip(
                label: option['label']!,
                selected: selectedKey == option['key'],
                onCanvas: true,
                onTap: () => onSelected(option['key']!),
              ),
            ),
        ],
      ),
    );
  }
}

/// 카드 목록 여백 — 좌우 16, 카드 사이 12. FAB가 있는 탭은 마지막 카드가 가려지지 않게 아래를 더 띄운다.
EdgeInsets _plazaListPadding({bool hasFab = false}) => EdgeInsets.fromLTRB(
      AppSpacing.screenGutter,
      AppSpacing.space2,
      AppSpacing.screenGutter,
      hasFab ? AppSpacing.space20 + AppSpacing.space4 : AppSpacing.space4,
    );

/// 카드 목록 첫 불러오기 뼈대 — 회색 바탕 위 흰 카드([_plazaListPadding]과 같은 여백·간격).
/// [withChipRow]면 위에 거르기 칩 줄 자리를 비워 둔다(칩 줄까지 통째로 불러오는 자료실).
class _PlazaCardListSkeleton extends StatelessWidget {
  final bool hasFab;
  final bool withChipRow;

  const _PlazaCardListSkeleton({this.hasFab = false, this.withChipRow = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (withChipRow)
          // _PlazaFilterChips와 같은 높이(위아래 4 + 칩 44)
          const SizedBox(height: AppSpacing.space1 * 2 + 44),
        Expanded(
          child: AppSkeleton(
            baseColor: AppSemanticColors.skeletonBaseOnCard,
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: _plazaListPadding(hasFab: hasFab),
              children: List.generate(
                5,
                (_) => const AppSkeletonCard(
                  standalone: false,
                  margin: EdgeInsets.only(bottom: AppSpacing.cardGap),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 목록을 아래로 내리면 FAB 글자를 접고, 위로 올리면 편다(PLAN: 스크롤하면 글자 접힘).
bool? _fabCollapsedFor(UserScrollNotification notification) {
  if (notification.metrics.axis != Axis.vertical) return null;
  switch (notification.direction) {
    case ScrollDirection.reverse:
      return true;
    case ScrollDirection.forward:
      return false;
    case ScrollDirection.idle:
      return null;
  }
}

// ─── 공통: 에러 상태 (빈 상태와 구분) ───

class _PlazaErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _PlazaErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: AppSemanticColors.statusErrorIcon,
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            '불러오지 못했습니다',
            style: AppTypography.bodyMedium
                .copyWith(color: AppSemanticColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.space4),
          SeedButton(
            label: '다시 시도',
            variant: SeedButtonVariant.neutralWeak,
            size: SeedButtonSize.small,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

// ─── 요양 소식: 언론 보도(뉴스 크롤링) + 장기요양보험공단 자료(공지·법령·평가·교육) 병합 ───

/// 요양 소식에 올라오는 항목 — 언론 기사([ApiService.getCareNews], GET /api/v1/news)와
/// 장기요양보험공단 자료([ApiService.getExternalNotices], GET /api/v1/external-notices)를
/// 같은 모양으로 맞춰 날짜순으로 함께 보여주기 위한 화면 전용 모델.
class _FeedItem {
  final String title;
  final String url;
  final String badgeLabel;
  final String filterKey; // '' 사용 안 함. 'PRESS' | notice.source(LTC_*)
  final DateTime? date;

  const _FeedItem({
    required this.title,
    required this.url,
    required this.badgeLabel,
    required this.filterKey,
    required this.date,
  });
}

class _NewsTab extends StatefulWidget {
  const _NewsTab();

  @override
  State<_NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<_NewsTab> {
  static const _filters = [
    {'key': '', 'label': '전체'},
    {'key': 'LTC_NOTICE', 'label': '공단 공지'},
    {'key': 'LTC_LAW', 'label': '법령'},
    {'key': 'LTC_EVAL', 'label': '평가'},
    {'key': 'LTC_EDU', 'label': '교육'},
    {'key': 'PRESS', 'label': '언론 보도'},
  ];

  static const int _noticePageSize = 50;

  String _filter = '';
  final ScrollController _scrollController = ScrollController();

  // 언론 보도 — 한 번에 불러온다(기존 동작 유지, 페이지네이션 없음).
  List<Map<String, dynamic>> _newsArticles = [];
  bool _newsLoading = true;
  bool _newsError = false;

  // 장기요양보험공단 자료 — 무한스크롤로 점진 로드.
  final List<ExternalNotice> _notices = [];
  int _noticePage = 0;
  bool _noticeHasMore = true;
  bool _noticeLoadingMore = false;
  bool _noticeInitialLoading = true;
  bool _noticeError = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNews();
    _loadNotices(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_noticeHasMore || _noticeLoadingMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadNotices();
    }
  }

  Future<void> _loadNews() async {
    setState(() {
      _newsLoading = true;
      _newsError = false;
    });
    try {
      final response = await ApiService().getCareNews(size: 30);
      final content = (response['content'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _newsArticles = content
            .whereType<Map>()
            .map((a) => Map<String, dynamic>.from(a))
            .toList();
        _newsLoading = false;
      });
    } catch (e) {
      debugPrint('언론 보도 로드 실패: $e');
      if (!mounted) return;
      setState(() {
        _newsLoading = false;
        _newsError = true;
      });
    }
  }

  Future<void> _loadNotices({bool refresh = false}) async {
    if (_noticeLoadingMore) return;
    setState(() {
      _noticeLoadingMore = true;
      if (refresh) {
        _noticePage = 0;
        _noticeHasMore = true;
        _noticeError = false;
        _noticeInitialLoading = true;
      }
    });
    try {
      final response = await ApiService().getExternalNotices(
        page: refresh ? 0 : _noticePage,
        size: _noticePageSize,
      );
      final content = response['content'];
      final list = content is List ? content : <dynamic>[];
      final notices = list
          .whereType<Map<String, dynamic>>()
          .map(ExternalNotice.fromJson)
          .toList();

      final last = response['last'] == true;
      final totalPages = response['totalPages'];
      final nextPage = (refresh ? 0 : _noticePage) + 1;
      final hasMore = !last && (totalPages is! int || nextPage < totalPages);

      if (!mounted) return;
      setState(() {
        if (refresh) _notices.clear();
        _notices.addAll(notices);
        _noticePage = nextPage;
        _noticeHasMore = hasMore;
        _noticeLoadingMore = false;
        _noticeInitialLoading = false;
      });
    } catch (e) {
      debugPrint('장기요양보험공단 자료 로드 실패: $e');
      if (!mounted) return;
      setState(() {
        _noticeLoadingMore = false;
        _noticeInitialLoading = false;
        if (refresh || _notices.isEmpty) _noticeError = true;
      });
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadNews(), _loadNotices(refresh: true)]);
  }

  List<_FeedItem> get _mergedItems {
    final items = <_FeedItem>[
      for (final article in _newsArticles)
        _FeedItem(
          title: article['title']?.toString() ?? '',
          url: article['url']?.toString() ?? '',
          badgeLabel: article['source']?.toString() ?? '언론',
          filterKey: 'PRESS',
          date: DateTime.tryParse(article['publishedAt']?.toString() ?? ''),
        ),
      for (final notice in _notices)
        _FeedItem(
          title: notice.title,
          url: notice.url,
          badgeLabel: notice.sourceLabel,
          filterKey: notice.source,
          date: notice.postedDate,
        ),
    ];
    items.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });
    if (_filter.isEmpty) return items;
    return items.where((item) => item.filterKey == _filter).toList();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('yyyy.MM.dd').format(date);
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        AppSnackBar.showError(context, message: '링크를 열 수 없습니다');
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.showError(context, message: '링크를 여는 중 오류가 발생했습니다');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyData = _newsArticles.isNotEmpty || _notices.isNotEmpty;
    final isInitialLoading =
        (_newsLoading || _noticeInitialLoading) && !hasAnyData;
    final bothFailed = _newsError && _noticeError && !hasAnyData;
    // 한쪽만 실패했을 때는 목록은 정상 표시하고, 상단에 짧은 안내만 덧붙인다.
    final onlyOneFailed = !bothFailed &&
        ((_newsError && _newsArticles.isEmpty) ||
            (_noticeError && _notices.isEmpty));

    return Column(
      children: [
        if (onlyOneFailed)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screenGutter,
                AppSpacing.space1, AppSpacing.screenGutter, AppSpacing.space1),
            child: SeedCallout(
              variant: SeedCalloutVariant.warning,
              icon: Icons.warning_amber_outlined,
              title: _newsError
                  ? '언론 보도를 불러오지 못했어요'
                  : '장기요양보험공단 자료를 불러오지 못했어요',
              description: '나머지 소식은 정상적으로 표시하고 있어요.',
            ),
          ),
        _PlazaFilterChips(
          options: _filters,
          selectedKey: _filter,
          onSelected: (key) => setState(() => _filter = key),
        ),
        Expanded(
          // 카드 등장 연출은 처음 한 번만 — 거르기·새로고침으로 다시 그려도 다시 떠오르지 않게 바깥에 둔다
          child: AppListEntrance(
          child: isInitialLoading
              ? const _PlazaCardListSkeleton()
              : bothFailed
                  ? _PlazaErrorState(onRetry: _refreshAll)
                  : Builder(builder: (context) {
                      final items = _mergedItems;
                      if (items.isEmpty) {
                        return const AppEmptyState(
                          icon: Icons.newspaper_outlined,
                          title: '아직 소식이 없어요',
                          topSpacing: AppSpacing.space10,
                        );
                      }
                      return AppRefreshIndicator(
                        onRefresh: _refreshAll,
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: _plazaListPadding(),
                          itemCount: items.length + (_noticeHasMore ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.cardGap),
                          itemBuilder: (context, index) {
                            if (index == items.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(
                                    vertical: AppSpacing.space4),
                                child: Center(
                                    child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))),
                              );
                            }
                            final item = items[index];
                            // B안: 테두리 없는 흰 카드(모서리 20·여백 20)
                            return AppListEntranceItem(
                              index: index,
                              child: AppCard(
                              onTap: () => _openUrl(item.url),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: AppSpacing.space2,
                                    runSpacing: AppSpacing.space1,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      AppTag(label: item.badgeLabel),
                                      if (item.date != null)
                                        Text(
                                          _formatDate(item.date),
                                          style: AppTypography.bodySmall
                                              .copyWith(
                                                  color: AppSemanticColors
                                                      .textTertiary),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.space2),
                                  Text(
                                    item.title,
                                    style: AppTypography.titleMedium.copyWith(
                                      color: AppSemanticColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
          ),
        ),
      ],
    );
  }
}

// ─── 게시판 ───

class _BoardTab extends StatefulWidget {
  const _BoardTab();

  @override
  State<_BoardTab> createState() => _BoardTabState();
}

class _BoardTabState extends State<_BoardTab> {
  static const _boards = [
    {'key': '', 'label': '전체'},
    {'key': 'free', 'label': '자유'},
    {'key': 'qna', 'label': 'Q&A'},
    {'key': 'review', 'label': '후기'},
    {'key': 'job_offer', 'label': '구인'},
    {'key': 'job_seek', 'label': '구직'},
  ];

  String _board = '';
  bool _fabCollapsed = false;

  /// 조회·좋아요·댓글 수 — 아이콘 + 숫자로 오른쪽 끝에 모은다
  Widget _countStat(IconData icon, Object? count, String semanticLabel) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.space3),
      child: Semantics(
        label: '$semanticLabel ${count ?? 0}',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppSemanticColors.textTertiary),
            const SizedBox(width: AppSpacing.space0_5),
            Text(
              '${count ?? 0}',
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final response = await ApiService()
          .getPlazaPosts(board: _board.isEmpty ? null : _board, size: 30);
      final content = (response['content'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _posts = content
              .whereType<Map>()
              .map((p) => Map<String, dynamic>.from(p))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('게시글 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _showWriteSheet() async {
    final created = await showPlazaPostEditor(
      context,
      initialBoard: _board.isEmpty ? 'free' : _board,
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundCanvas,
      // B안 알약 FAB — 글자는 이 버튼이 여는 시트 제목 그대로
      floatingActionButton: AppFab(
        icon: Icons.edit,
        label: '글 쓰기',
        collapsed: _fabCollapsed,
        onPressed: _showWriteSheet,
      ),
      body: Column(
        children: [
          _PlazaFilterChips(
            options: _boards,
            selectedKey: _board,
            onSelected: (key) {
              setState(() => _board = key);
              _load();
            },
          ),
          Expanded(
            // 카드 등장 연출은 처음 한 번만 — 거르기·새로고침으로 다시 불러와도 다시 떠오르지 않게 바깥에 둔다
            child: AppListEntrance(
            // 처음 불러올 때(아직 보일 글이 없을 때)만 뼈대 — 글이 있는 채로 다시 불러올 때는 예전 스피너
            child: _isLoading && _posts.isEmpty
                ? const _PlazaCardListSkeleton(hasFab: true)
                : _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_hasError && _posts.isEmpty)
                    ? _PlazaErrorState(onRetry: _load)
                    : _posts.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.forum_outlined,
                        title: '아직 게시글이 없어요',
                        description: '+ 버튼으로 첫 글을 남겨보세요',
                        topSpacing: AppSpacing.space10,
                      )
                    : NotificationListener<UserScrollNotification>(
                        onNotification: (notification) {
                          final collapsed = _fabCollapsedFor(notification);
                          if (collapsed != null &&
                              collapsed != _fabCollapsed) {
                            setState(() => _fabCollapsed = collapsed);
                          }
                          return false;
                        },
                        child: AppRefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: _plazaListPadding(hasFab: true),
                          itemCount: _posts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.cardGap),
                          itemBuilder: (context, index) {
                            final post = _posts[index];
                            final createdAt = DateTime.tryParse(
                                post['createdAt']?.toString() ?? '');
                            // B안: 테두리 없는 흰 카드(모서리 20·여백 20)
                            return AppListEntranceItem(
                              index: index,
                              child: AppCard(
                              onTap: () async {
                                final postId = post['id'];
                                if (postId is! int) return;
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        PlazaPostDetailScreen(postId: postId),
                                  ),
                                );
                                _load();
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      AppTag(
                                        label: plazaBoardLabel(
                                            post['board']?.toString()),
                                      ),
                                      if (post['isPinned'] == true) ...[
                                        const SizedBox(
                                            width: AppSpacing.space1_5),
                                        const Icon(Icons.push_pin,
                                            size: 16,
                                            color: AppSemanticColors
                                                .statusWarningIcon),
                                      ],
                                      if (post['hasAccepted'] == true) ...[
                                        const SizedBox(
                                            width: AppSpacing.space1_5),
                                        const Icon(Icons.check_circle,
                                            size: 16,
                                            color: AppSemanticColors
                                                .statusSuccessIcon),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.space2),
                                  Text(
                                    post['title']?.toString() ?? '',
                                    style: AppTypography.titleMedium.copyWith(
                                      color: AppSemanticColors.textPrimary,
                                    ),
                                  ),
                                  if ((post['preview']?.toString() ?? '')
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: AppSpacing.space1),
                                    Text(
                                      // 서버가 내려주는 preview는 HTML 원문 일부라 태그를 제거해 보여준다
                                      htmlToPreviewText(
                                          post['preview'].toString(),
                                          maxLength: 60),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodySmall.copyWith(
                                          color:
                                              AppSemanticColors.textSecondary),
                                    ),
                                  ],
                                  const SizedBox(height: AppSpacing.space2),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${post['displayAuthor'] ?? ''}${createdAt != null ? ' · ${DateFormat('MM.dd').format(createdAt)}' : ''}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              AppTypography.bodySmall.copyWith(
                                            color:
                                                AppSemanticColors.textTertiary,
                                          ),
                                        ),
                                      ),
                                      _countStat(Icons.visibility_outlined,
                                          post['viewCount'], '조회'),
                                      _countStat(Icons.favorite_border,
                                          post['likeCount'], '좋아요'),
                                      _countStat(Icons.chat_bubble_outline,
                                          post['commentCount'], '댓글'),
                                    ],
                                  ),
                                ],
                              ),
                              ),
                            );
                          },
                        ),
                      ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 자료실 ───

/// 자료 업로드/수정 바텀시트. [existingItem]을 주면 수정 모드(파일은 그대로 두고
/// 제목·분류·설명만 PUT), 생략하면 새 파일을 선택해 업로드한다(POST).
Future<bool?> showPlazaLibraryEditor(
  BuildContext context, {
  Map<String, dynamic>? existingItem,
}) async {
  final isEdit = existingItem != null;
  final titleController =
      TextEditingController(text: existingItem?['title']?.toString() ?? '');
  final descriptionController = TextEditingController(
      text: existingItem?['description']?.toString() ?? '');
  String category = existingItem?['category']?.toString() ?? 'form';
  XFile? pickedFile;
  bool isSaving = false;
  final user = context.read<AuthProvider>().currentUser;

  final saved = await AppBottomSheet.show<bool>(
    context,
    title: isEdit ? '자료 정보 수정' : '자료 올리기',
    isScrollControlled: true,
    child: StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.space4,
          right: AppSpacing.space4,
          top: AppSpacing.space4,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.space4,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                // 테두리·라벨색 등은 AppTheme.inputDecorationTheme(토큰 기반)을
                // 그대로 물려받는다 — 필드마다 다른 radius로 손조립하지 않는다.
                decoration: const InputDecoration(labelText: '분류'),
                items: const [
                  DropdownMenuItem(value: 'form', child: Text('서식')),
                  DropdownMenuItem(value: 'eval', child: Text('평가')),
                  DropdownMenuItem(value: 'program', child: Text('프로그램')),
                  DropdownMenuItem(value: 'etc', child: Text('기타')),
                ],
                onChanged: (value) =>
                    setSheetState(() => category = value ?? 'form'),
              ),
              const SizedBox(height: AppSpacing.space3),
              SeedTextField(
                label: '제목',
                controller: titleController,
              ),
              const SizedBox(height: AppSpacing.space3),
              SeedTextField(
                label: '설명 (선택)',
                controller: descriptionController,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.space3),
              if (isEdit)
                // 수정은 파일을 바꾸지 않는다 — 재업로드하면 다운로드 수 등 이력이 초기화된다
                Text(
                  '파일: ${existingItem['fileName'] ?? ''} (파일 자체는 변경할 수 없어요)',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppSemanticColors.textTertiary),
                )
              else
                OutlinedButton.icon(
                  onPressed: () async {
                    final file = await openFile();
                    if (file != null) {
                      setSheetState(() => pickedFile = file);
                    }
                  },
                  icon: const Icon(Icons.attach_file, size: 16),
                  label: Text(pickedFile?.name ?? '파일 선택',
                      style: AppTypography.bodySmall,
                      overflow: TextOverflow.ellipsis),
                ),
              const SizedBox(height: AppSpacing.space3),
              SizedBox(
                width: double.infinity,
                child: SeedButton(
                  label: isSaving ? '저장 중...' : (isEdit ? '수정' : '업로드'),
                  variant: SeedButtonVariant.brandSolid,
                  isLoading: isSaving,
                  isDisabled: isSaving,
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty ||
                        (!isEdit && pickedFile == null)) {
                      return;
                    }
                    setSheetState(() => isSaving = true);
                    try {
                      if (isEdit) {
                        await ApiService().updatePlazaLibraryItem(
                          itemId: existingItem['id'] as int,
                          category: category,
                          title: titleController.text.trim(),
                          description: descriptionController.text.trim(),
                        );
                      } else {
                        await ApiService().uploadPlazaLibraryItem(
                          filePath: pickedFile!.path,
                          category: category,
                          title: titleController.text.trim(),
                          description: descriptionController.text.trim(),
                          uploaderName: user?.name,
                          companyName: user?.company?.name,
                        );
                      }
                      if (context.mounted) {
                        Navigator.pop(context, true);
                      }
                    } catch (e) {
                      debugPrint('자료 ${isEdit ? '수정' : '업로드'} 실패: $e');
                      setSheetState(() => isSaving = false);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  return saved;
}

class _LibraryTab extends StatefulWidget {
  /// 이용 조건 안내에서 "자유게시판에 글쓰기"를 눌렀을 때 게시판 탭으로 이동시키는 콜백.
  final VoidCallback? onGoToFreeBoard;

  const _LibraryTab({this.onGoToFreeBoard});

  @override
  State<_LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<_LibraryTab> {
  static const _categories = [
    {'key': '', 'label': '전체'},
    {'key': 'form', 'label': '서식'},
    {'key': 'eval', 'label': '평가'},
    {'key': 'program', 'label': '프로그램'},
    {'key': 'etc', 'label': '기타'},
  ];

  String _category = '';
  bool _fabCollapsed = false;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _hasError = false;

  // 자료실 이용 자격 — 자유게시판 글 1개 이상 필요. null이면 아직 확인 전(허용으로 간주하지 않는다).
  bool _accessAllowed = false;
  String? _accessReason; // 'LOGIN_REQUIRED' | 'FREE_POST_REQUIRED'

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  Future<void> _checkAccessAndLoad() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final access = await ApiService().getPlazaLibraryAccess();
      final allowed = access['allowed'] == true;
      if (!mounted) return;
      setState(() {
        _accessAllowed = allowed;
        _accessReason = access['reason']?.toString();
        _isLoading = allowed; // 허용이면 이어서 목록을 불러오는 동안 로딩 유지
      });
      if (allowed) {
        await _load();
      }
    } catch (e) {
      debugPrint('자료실 이용 조건 확인 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final response = await ApiService().getPlazaLibrary(
          category: _category.isEmpty ? null : _category, size: 30);
      final content = (response['content'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _items = content
              .whereType<Map>()
              .map((i) => Map<String, dynamic>.from(i))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('자료실 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  Future<void> _download(Map<String, dynamic> item) async {
    final itemId = item['id'];
    if (itemId is! int) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = item['fileName']?.toString() ?? 'file_$itemId';
      final savePath = '${directory.path}/$fileName';
      final token = StorageService().getToken();

      final dioClient = dio.Dio();
      await dioClient.download(
        ApiService().plazaLibraryDownloadUrl(itemId),
        savePath,
        options: dio.Options(headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        }),
      );

      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done && mounted) {
        AppSnackBar.showSuccess(context, message: '다운로드 완료: $fileName');
      }
      _load(); // 다운로드 수 갱신
    } catch (e) {
      debugPrint('자료 다운로드 실패: $e');
      if (mounted) {
        // 403(이용 조건 미충족)이면 원시 에러 대신 원인을 알려준다 — 대개 목록 진입 시
        // 이미 자격을 확인하지만, 확인 이후 자격이 바뀌는 경합 상황을 대비한다
        final is403 = e is dio.DioException && e.response?.statusCode == 403;
        if (is403) {
          AppSnackBar.showWarning(context,
              message: '자료실은 자유게시판에 글을 1개 이상 작성한 회원만 이용할 수 있습니다');
        } else {
          AppSnackBar.showError(context, message: '다운로드에 실패했습니다');
        }
      }
    }
  }

  Future<void> _showUploadSheet() async {
    final uploaded = await showPlazaLibraryEditor(context);
    if (uploaded == true) _load();
  }

  Future<void> _showEditSheet(Map<String, dynamic> item) async {
    final updated = await showPlazaLibraryEditor(context, existingItem: item);
    if (updated == true) _load();
  }

  Widget _buildAccessGuard() {
    final isLoginRequired = _accessReason == 'LOGIN_REQUIRED';
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.space4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SeedCallout(
            variant: SeedCalloutVariant.info,
            icon: Icons.lock_outline,
            title: isLoginRequired ? '로그인이 필요해요' : '자유게시판 글쓰기가 필요해요',
            description: isLoginRequired
                ? '자료실은 로그인 후 이용할 수 있어요.'
                : '자료실은 자유게시판에 글을 1개 이상 작성한 회원만 이용할 수 있어요. '
                    '나누는 만큼 받을 수 있도록 만든 조건이에요.',
          ),
          const SizedBox(height: AppSpacing.space4),
          if (!isLoginRequired && widget.onGoToFreeBoard != null)
            SizedBox(
              width: double.infinity,
              child: SeedButton(
                label: '자유게시판에 글쓰기',
                variant: SeedButtonVariant.brandSolid,
                onPressed: widget.onGoToFreeBoard,
              ),
            ),
          const SizedBox(height: AppSpacing.space2),
          SizedBox(
            width: double.infinity,
            child: SeedButton(
              label: '다시 확인',
              variant: SeedButtonVariant.neutralOutline,
              onPressed: _checkAccessAndLoad,
            ),
          ),
        ],
      ),
    );
  }

  /// 자료 한 건 — B안: 테두리 없는 흰 카드, 옅은 틸 둥근 아이콘(44) + 글 + 단추.
  /// 카드 본문을 눌러도 내려받게 — 오른쪽 아이콘만 살아 있으면 죽은 카드처럼 느껴진다
  Widget _buildItemCard(Map<String, dynamic> item) {
    final description = (item['description'] ?? '').toString().trim();
    return AppCard(
      onTap: () => _download(item),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.cardPadding,
        AppSpacing.space4,
        AppSpacing.space2,
        AppSpacing.space4,
      ),
      child: Row(
        children: [
          Container(
            width: AppSpacing.iconCircle,
            height: AppSpacing.iconCircle,
            decoration: const BoxDecoration(
              color: AppSemanticColors.brandWeak,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 22,
              color: AppSemanticColors.brandDefault,
            ),
          ),
          const SizedBox(width: AppSpacing.space3_5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title']?.toString() ?? '',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppSemanticColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space0_5),
                Text(
                  // 낱말 단위로만 줄을 바꾸고 '다운로드 96'은 한 덩어리로 —
                  // 수정 단추가 붙어 폭이 좁아지면 '다운로드 / 96', '다운로 / 드'로 갈렸다
                  keepAll(
                      '${item['fileName'] ?? ''} · ${_formatSize(item['fileSize'] is int ? item['fileSize'] : 0)} · 다운로드\u00A0${item['downloadCount'] ?? 0}'),
                  style: AppTypography.bodySmall
                      .copyWith(color: AppSemanticColors.textTertiary),
                ),
                // 업로드할 때 적은 설명 — 안 보여주면 적을 이유가 없다 (회사 자료실과 동일)
                if (description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.space1),
                    child: Text(
                      item['description'].toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppSemanticColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          if (item['isMine'] == true)
            IconButton(
              tooltip: '수정',
              icon: const Icon(Icons.edit_outlined,
                  color: AppSemanticColors.textSecondary),
              onPressed: () => _showEditSheet(item),
            ),
          IconButton(
            tooltip: '다운로드',
            icon: const Icon(Icons.download,
                color: AppSemanticColors.interactivePrimaryDefault),
            onPressed: () => _download(item),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundCanvas,
      // B안 알약 FAB — 글자는 이 버튼이 여는 시트 제목 그대로
      floatingActionButton: _accessAllowed
          ? AppFab(
              icon: Icons.upload_file,
              label: '자료 올리기',
              collapsed: _fabCollapsed,
              onPressed: _showUploadSheet,
            )
          : null,
      // 카드 등장 연출은 처음 한 번만 — 분류·새로고침으로 다시 불러와도 다시 떠오르지 않게 바깥에 둔다
      body: AppListEntrance(
      // 처음 불러올 때(아직 보일 자료가 없을 때)만 뼈대 — 자료가 있는 채로 다시 불러올 때는 예전 스피너
      child: _isLoading && _items.isEmpty
          ? const _PlazaCardListSkeleton(hasFab: true, withChipRow: true)
          : _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_accessAllowed
              ? (_hasError
                  ? _PlazaErrorState(onRetry: _checkAccessAndLoad)
                  : Center(child: SingleChildScrollView(child: _buildAccessGuard())))
              : Column(
                      children: [
                        _PlazaFilterChips(
                          options: _categories,
                          selectedKey: _category,
                          onSelected: (key) {
                            setState(() => _category = key);
                            _load();
                          },
                        ),
                        Expanded(
                          child: (_hasError && _items.isEmpty)
                              ? _PlazaErrorState(onRetry: _load)
                              : _items.isEmpty
                                  ? const AppEmptyState(
                                      icon: Icons.folder_open_outlined,
                                      title: '아직 등록된 자료가 없어요',
                                      description: '+ 버튼으로 첫 자료를 올려보세요',
                                      topSpacing: AppSpacing.space10,
                                    )
                                  : NotificationListener<
                                      UserScrollNotification>(
                                      onNotification: (notification) {
                                        final collapsed =
                                            _fabCollapsedFor(notification);
                                        if (collapsed != null &&
                                            collapsed != _fabCollapsed) {
                                          setState(() =>
                                              _fabCollapsed = collapsed);
                                        }
                                        return false;
                                      },
                                      child: AppRefreshIndicator(
                                      onRefresh: _load,
                                      child: ListView.separated(
                                        padding:
                                            _plazaListPadding(hasFab: true),
                                        itemCount: _items.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(
                                                height: AppSpacing.cardGap),
                                        itemBuilder: (context, index) =>
                                            AppListEntranceItem(
                                              index: index,
                                              child:
                                                  _buildItemCard(_items[index]),
                                            ),
                                      ),
                                    ),
                                    ),
                        ),
      ],
                    ),
      ),
    );
  }
}
