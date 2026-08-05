import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart' as dio;
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_chip.dart';
import '../widgets/seed/seed_text_field.dart';
import 'plaza_post_detail_screen.dart';

/// 케어브이 커뮤니티: 요양 소식(뉴스) · 게시판 · 자료실
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
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: Text('케어브이 커뮤니티',
            style: AppTypography.heading6
                .copyWith(color: AppSemanticColors.textInverse)),
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        foregroundColor: AppSemanticColors.textInverse,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppSemanticColors.textInverse,
          unselectedLabelColor:
              AppSemanticColors.textInverse.withValues(alpha: 0.6),
          indicatorColor: AppSemanticColors.textInverse,
          tabs: const [
            Tab(text: '요양 소식'),
            Tab(text: '게시판'),
            Tab(text: '자료실'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _NewsTab(),
          _BoardTab(),
          _LibraryTab(),
        ],
      ),
    );
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

// ─── 요양 소식 ───

class _NewsTab extends StatefulWidget {
  const _NewsTab();

  @override
  State<_NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<_NewsTab> {
  static const _categories = [
    {'key': '', 'label': '전체'},
    {'key': 'policy', 'label': '정책'},
    {'key': 'abuse', 'label': '학대예방'},
    {'key': 'eval', 'label': '평가'},
    {'key': 'field', 'label': '현장'},
  ];

  String _category = '';
  List<Map<String, dynamic>> _articles = [];
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
          .getCareNews(category: _category.isEmpty ? null : _category, size: 30);
      final content = (response['content'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _articles = content
              .whereType<Map>()
              .map((a) => Map<String, dynamic>.from(a))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('뉴스 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _openArticle(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space3, vertical: AppSpacing.space2),
            children: _categories.map((c) {
              final selected = _category == c['key'];
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.space2),
                child: SeedChip(
                  label: c['label']!,
                  selected: selected,
                  size: SeedChipSize.small,
                  onTap: () {
                    setState(() => _category = c['key']!);
                    _load();
                  },
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : (_hasError && _articles.isEmpty)
                  ? _PlazaErrorState(onRetry: _load)
                  : _articles.isEmpty
                  ? Center(
                      child: Text('아직 소식이 없어요',
                          style: AppTypography.bodyMedium
                              .copyWith(color: AppSemanticColors.textTertiary)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.space3),
                        itemCount: _articles.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.space2),
                        itemBuilder: (context, index) {
                          final article = _articles[index];
                          final publishedAt = DateTime.tryParse(
                              article['publishedAt']?.toString() ?? '');
                          return GestureDetector(
                            onTap: () => _openArticle(article['url']?.toString()),
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.space3),
                              decoration: BoxDecoration(
                                color: AppSemanticColors.surfaceDefault,
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.space3),
                                border: Border.all(
                                    color: AppSemanticColors.borderDefault),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    article['title']?.toString() ?? '',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppSemanticColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.space1),
                                  Text(
                                    '${article['source'] ?? ''}${publishedAt != null ? ' · ${DateFormat('MM.dd HH:mm').format(publishedAt)}' : ''}',
                                    style: AppTypography.caption.copyWith(
                                        color: AppSemanticColors.textTertiary),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
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
  ];

  String _board = '';
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

  String _boardLabel(String? key) {
    switch (key) {
      case 'qna':
        return 'Q&A';
      case 'review':
        return '후기';
      default:
        return '자유';
    }
  }

  Future<void> _showWriteSheet() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String board = _board.isEmpty ? 'free' : _board;
    bool isAnonymous = false;
    final user = context.read<AuthProvider>().currentUser;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppSemanticColors.surfaceDefault,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppBorderRadius.xl2)),
      ),
      builder: (sheetContext) => StatefulBuilder(
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
                Text('글 쓰기',
                    style: AppTypography.heading6
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.space3),
                DropdownButtonFormField<String>(
                  initialValue: board,
                  decoration: InputDecoration(
                    labelText: '게시판',
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppBorderRadius.xl)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'free', child: Text('자유')),
                    DropdownMenuItem(value: 'qna', child: Text('Q&A')),
                    DropdownMenuItem(value: 'review', child: Text('후기')),
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
                    label: '등록',
                    variant: SeedButtonVariant.brandSolid,
                    onPressed: () async {
                      if (titleController.text.trim().isEmpty ||
                          contentController.text.trim().isEmpty) {
                        return;
                      }
                      try {
                        await ApiService().createPlazaPost(
                          board: board,
                          title: titleController.text.trim(),
                          content: contentController.text.trim(),
                          isAnonymous: isAnonymous,
                          authorName: user?.name,
                          companyName: user?.company?.name,
                        );
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (e) {
                        debugPrint('게시글 작성 실패: $e');
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

    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      floatingActionButton: FloatingActionButton(
        onPressed: _showWriteSheet,
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        child: Icon(Icons.edit, color: AppSemanticColors.textInverse),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space3, vertical: AppSpacing.space2),
              children: _boards.map((b) {
                final selected = _board == b['key'];
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.space2),
                  child: SeedChip(
                    label: b['label']!,
                    selected: selected,
                    size: SeedChipSize.small,
                    onTap: () {
                      setState(() => _board = b['key']!);
                      _load();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_hasError && _posts.isEmpty)
                    ? _PlazaErrorState(onRetry: _load)
                    : _posts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('아직 게시글이 없어요',
                                style: AppTypography.bodyMedium.copyWith(
                                    color: AppSemanticColors.textSecondary,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: AppSpacing.space1_5),
                            Text('+ 버튼으로 첫 글을 남겨보세요',
                                style: AppTypography.bodySmall.copyWith(
                                    color: AppSemanticColors.textTertiary)),
                          ],
                        ))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.space3),
                          itemCount: _posts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.space2),
                          itemBuilder: (context, index) {
                            final post = _posts[index];
                            final createdAt = DateTime.tryParse(
                                post['createdAt']?.toString() ?? '');
                            return GestureDetector(
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
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.space3),
                                decoration: BoxDecoration(
                                  color: AppSemanticColors.surfaceDefault,
                                  borderRadius:
                                      BorderRadius.circular(AppSpacing.space3),
                                  border: Border.all(
                                      color: AppSemanticColors.borderDefault),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.space1_5,
                                              vertical: AppSpacing.space0_5),
                                          decoration: BoxDecoration(
                                            color: AppSemanticColors
                                                .backgroundTertiary,
                                            borderRadius: BorderRadius.circular(
                                                AppBorderRadius.md),
                                          ),
                                          child: Text(
                                            _boardLabel(
                                                post['board']?.toString()),
                                            style: AppTypography.caption
                                                .copyWith(
                                                    color: AppSemanticColors
                                                        .textSecondary),
                                          ),
                                        ),
                                        if (post['isPinned'] == true) ...[
                                          const SizedBox(width: 4),
                                          Icon(Icons.push_pin,
                                              size: 12,
                                              color: AppSemanticColors
                                                  .statusWarningIcon),
                                        ],
                                        if (post['hasAccepted'] == true) ...[
                                          const SizedBox(width: 4),
                                          Icon(Icons.check_circle,
                                              size: 12,
                                              color: AppSemanticColors
                                                  .statusSuccessIcon),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.space1),
                                    Text(
                                      post['title']?.toString() ?? '',
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: AppSemanticColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.space1),
                                    Text(
                                      '${post['displayAuthor'] ?? ''}${createdAt != null ? ' · ${DateFormat('MM.dd').format(createdAt)}' : ''}'
                                      ' · 조회 ${post['viewCount'] ?? 0} · 좋아요 ${post['likeCount'] ?? 0} · 댓글 ${post['commentCount'] ?? 0}',
                                      style: AppTypography.caption.copyWith(
                                          color:
                                              AppSemanticColors.textTertiary),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── 자료실 ───

class _LibraryTab extends StatefulWidget {
  const _LibraryTab();

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
  List<Map<String, dynamic>> _items = [];
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('다운로드 완료: $fileName')),
        );
      }
      _load(); // 다운로드 수 갱신
    } catch (e) {
      debugPrint('자료 다운로드 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('다운로드에 실패했습니다')),
        );
      }
    }
  }

  Future<void> _showUploadSheet() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String category = 'form';
    XFile? pickedFile;
    bool isUploading = false;
    final user = context.read<AuthProvider>().currentUser;

    final uploaded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppSemanticColors.surfaceDefault,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppBorderRadius.xl2)),
      ),
      builder: (sheetContext) => StatefulBuilder(
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
                Text('자료 올리기',
                    style: AppTypography.heading6
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.space3),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(
                    labelText: '분류',
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppBorderRadius.xl)),
                  ),
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
                    label: isUploading ? '업로드 중...' : '업로드',
                    variant: SeedButtonVariant.brandSolid,
                    isLoading: isUploading,
                    isDisabled: isUploading,
                    onPressed: () async {
                      if (titleController.text.trim().isEmpty ||
                          pickedFile == null) {
                        return;
                      }
                      setSheetState(() => isUploading = true);
                      try {
                        await ApiService().uploadPlazaLibraryItem(
                          filePath: pickedFile!.path,
                          category: category,
                          title: titleController.text.trim(),
                          description: descriptionController.text.trim(),
                          uploaderName: user?.name,
                          companyName: user?.company?.name,
                        );
                        if (context.mounted) {
                          Navigator.pop(context, true);
                        }
                      } catch (e) {
                        debugPrint('자료 업로드 실패: $e');
                        setSheetState(() => isUploading = false);
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

    if (uploaded == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      floatingActionButton: FloatingActionButton(
        onPressed: _showUploadSheet,
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        child: Icon(Icons.upload_file, color: AppSemanticColors.textInverse),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space3, vertical: AppSpacing.space2),
              children: _categories.map((c) {
                final selected = _category == c['key'];
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.space2),
                  child: SeedChip(
                    label: c['label']!,
                    selected: selected,
                    size: SeedChipSize.small,
                    onTap: () {
                      setState(() => _category = c['key']!);
                      _load();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_hasError && _items.isEmpty)
                    ? _PlazaErrorState(onRetry: _load)
                    : _items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('아직 등록된 자료가 없어요',
                                style: AppTypography.bodyMedium.copyWith(
                                    color: AppSemanticColors.textSecondary,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: AppSpacing.space1_5),
                            Text('+ 버튼으로 첫 자료를 올려보세요',
                                style: AppTypography.bodySmall.copyWith(
                                    color: AppSemanticColors.textTertiary)),
                          ],
                        ))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.space3),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.space2),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return Container(
                              padding: const EdgeInsets.all(AppSpacing.space3),
                              decoration: BoxDecoration(
                                color: AppSemanticColors.surfaceDefault,
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.space3),
                                border: Border.all(
                                    color: AppSemanticColors.borderDefault),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.description_outlined,
                                      color: AppSemanticColors.statusInfoIcon),
                                  const SizedBox(width: AppSpacing.space3),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['title']?.toString() ?? '',
                                          style: AppTypography.bodyMedium
                                              .copyWith(
                                            color:
                                                AppSemanticColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '${item['fileName'] ?? ''} · ${_formatSize(item['fileSize'] is int ? item['fileSize'] : 0)} · 다운로드 ${item['downloadCount'] ?? 0}',
                                          style: AppTypography.caption.copyWith(
                                              color: AppSemanticColors
                                                  .textTertiary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.download,
                                        color: AppSemanticColors
                                            .interactivePrimaryDefault),
                                    onPressed: () => _download(item),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
