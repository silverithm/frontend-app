import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/chat_message.dart';
import '../../providers/chat_files_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/chat_files_browse.dart';
import '../../utils/chat_image_url.dart';
import '../../utils/chat_time_format.dart';
import '../common/app_empty_state.dart';
import '../common/app_loading.dart';
import '../seed/seed_chip.dart';
import '../seed/seed_list_cell.dart';
import '../seed/seed_text_field.dart';
import 'chat_photo.dart';

/// 채팅방 '주고받은 파일' — 검색 · 사진/동영상/파일 · 달로 이동 · 날짜별 묶음 · 이어 받기.
///
/// 예전에는 방의 사진·파일 5천여 건이 썸네일 44px 한 줄씩 쭉 나왔다(사용자 "검색도 날짜별도
/// 안 되고 한 줄로만 쭉 나온다"). 사진·동영상은 날짜별 바둑판, 파일은 날짜별 목록으로 보이고
/// 끝까지 내리면 다음 쪽을 받는다. 채팅방 메뉴의 '주고받은 파일'과 방 정보의 '미디어' 탭이 같이 쓴다.
class ChatFilesBrowser extends StatefulWidget {
  const ChatFilesBrowser({
    super.key,
    required this.roomId,
    required this.onOpen,
    this.controller,
    this.initialKind = ChatFilesKind.photo,
  });

  final int roomId;

  /// 처음 열 탭 — 방 정보 미디어 탭에서 '동영상 30'을 누르고 들어온 경우 등
  final ChatFilesKind initialKind;

  /// 사진·동영상·파일을 눌렀을 때 — 여는 방식은 띄운 화면이 정한다(말풍선과 같게)
  final void Function(ChatMessage message) onOpen;

  /// 테스트에서 가짜 응답을 끼울 때만 — 없으면 스스로 만든다
  final ChatFilesController? controller;

  @override
  State<ChatFilesBrowser> createState() => _ChatFilesBrowserState();
}

class _ChatFilesBrowserState extends State<ChatFilesBrowser> {
  late final ChatFilesController _controller;
  late final bool _ownsController;
  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        ChatFilesController(roomId: widget.roomId, initialKind: widget.initialKind);
    _controller.addListener(_onChanged);
    _scroll.addListener(_onScroll);
    // 처음 고른 탭이 비었으면(파일만 주고받은 방) 있는 탭으로 옮긴다
    _controller.load(hopToResults: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onChanged);
    if (_ownsController) _controller.dispose();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    // 첫 쪽이 화면을 다 못 채우면 스크롤이 생기지 않아 다음 쪽을 부를 계기가 없다
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (_controller.hasMore && _scroll.position.maxScrollExtent < 240) {
        _controller.loadMore();
      }
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 800) _controller.loadMore();
  }

  void _onQueryChanged(String value) {
    setState(() {}); // 지우기 단추 보이기·숨기기
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _controller.setQuery(value);
    });
  }

  void _clearQuery() {
    _debounce?.cancel();
    _search.clear();
    setState(() {});
    _controller.setQuery('');
  }

  void _resetScroll() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildHeader() {
    final c = _controller;
    final hasQuery = _search.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.space2,
        AppSpacing.screenGutter,
        AppSpacing.space1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SeedTextField(
            // 화면 제목이 맥락을 주므로 라벨은 접근성용으로만
            label: '파일 검색',
            showLabel: false,
            controller: _search,
            onChanged: _onQueryChanged,
            placeholder: '파일 이름·보낸 사람으로 찾기',
            prefixIcon: Icons.search,
            suffixIcon: hasQuery ? Icons.clear : null,
            onSuffixIconTap: hasQuery ? _clearQuery : null,
            textInputAction: TextInputAction.search,
          ),
          const SizedBox(height: AppSpacing.space2),
          // 글자를 키워도 넘치지 않게 가로로 밀어 본다
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final k in ChatFilesKind.values) ...[
                  if (k != ChatFilesKind.values.first) const SizedBox(width: AppSpacing.space2),
                  SeedChip(
                    label: '${k.label} ${formatChatFilesCount(c.counts[k] ?? 0)}',
                    selected: c.kind == k,
                    onTap: () {
                      _resetScroll();
                      c.setKind(k);
                    },
                  ),
                ],
              ],
            ),
          ),
          if (c.months.length > 1) ...[
            const SizedBox(height: AppSpacing.space2),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SeedChip(
                    label: '최신',
                    size: SeedChipSize.small,
                    selected: c.month == null,
                    onTap: () {
                      _resetScroll();
                      c.jumpToMonth(null);
                    },
                  ),
                  for (final m in c.months) ...[
                    const SizedBox(width: AppSpacing.space1_5),
                    SeedChip(
                      label: '${formatChatFilesMonth(m.month)} (${formatChatFilesCount(m.count)})',
                      size: SeedChipSize.small,
                      selected: c.month == m.month,
                      onTap: () {
                        _resetScroll();
                        c.jumpToMonth(m.month);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    final c = _controller;
    if (c.isLoading && c.items.isEmpty) {
      return const Center(child: AppLoading());
    }
    if (c.hasError && c.items.isEmpty) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: '파일 목록을 불러오지 못했습니다',
        actionLabel: '다시 시도',
        onAction: c.load,
      );
    }
    if (c.items.isEmpty) {
      return AppEmptyState(
        icon: c.query.isEmpty ? Icons.photo_library_outlined : Icons.search_off,
        title: c.query.isEmpty
            ? '아직 주고받은 ${c.kind.label}이 없습니다'
            : "'${c.query}'에 맞는 ${c.kind.label}이 없습니다",
      );
    }

    final days = groupChatFilesByDay(c.items);
    final width = MediaQuery.sizeOf(context).width;
    // 폰은 4칸(한 칸 약 85dp), 태블릿은 더 촘촘히
    final columns = width >= 900 ? 8 : (width >= 600 ? 6 : 4);

    return CustomScrollView(
      controller: _scroll,
      slivers: [
        for (var i = 0; i < days.length; i++) ...[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              i == 0 ? AppSpacing.space2 : AppSpacing.space5,
              AppSpacing.screenGutter,
              AppSpacing.space2,
            ),
            sliver: SliverToBoxAdapter(
              child: Semantics(
                header: true,
                child: Text(
                  formatChatFilesDay(days[i].day),
                  style: AppTypography.labelStrong.copyWith(
                    color: AppSemanticColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          if (c.kind.isGrid)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _MediaTile(
                    message: days[i].items[index],
                    onTap: () => widget.onOpen(days[i].items[index]),
                  ),
                  childCount: days[i].items.length,
                ),
              ),
            )
          else
            SliverPadding(
              // 줄 좌우 12 + 8 = 글자가 화면 가장자리에서 20 (예전 파일함과 같다)
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final m = days[i].items[index];
                    return SeedListCell(
                      leadingIcon: _fileIcon(m.fileName),
                      title: m.fileName ?? '파일',
                      description: [
                        m.senderName,
                        formatChatFileSize(m.fileSize),
                        formatChatClock(m.createdAt),
                      ].where((s) => s.isNotEmpty).join(' · '),
                      showChevron: false,
                      onTap: () => widget.onOpen(m),
                    );
                  },
                  childCount: days[i].items.length,
                ),
              ),
            ),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.space5),
            child: c.hasMore || c.isLoadingMore
                ? const Center(child: AppInlineLoading())
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  static IconData _fileIcon(String? name) {
    final n = (name ?? '').toLowerCase();
    final dot = n.lastIndexOf('.');
    final ext = dot >= 0 ? n.substring(dot + 1) : '';
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'xls':
      case 'xlsx':
      case 'xlsm':
      case 'csv':
        return Icons.table_chart_outlined;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_outlined;
      case 'hwp':
      case 'hwpx':
      case 'doc':
      case 'docx':
      case 'txt':
        return Icons.description_outlined;
      case 'zip':
        return Icons.folder_zip_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}

/// 바둑판 한 칸 — 사진은 썸네일, 동영상은 미리보기 + 재생 표시
class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.message, required this.onTap});

  final ChatMessage message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isVideo = message.isVideoMessage;
    // 동영상은 서버가 만든 미리보기(thumbnailUrl)만 쓴다 — fileUrl은 영상 파일이라 그림이 아니다
    final thumb = isVideo
        ? (message.thumbnailUrl?.trim().isNotEmpty == true ? message.thumbnailUrl : null)
        : resolveChatImageUrl(message);
    final what = isVideo ? '동영상' : '사진';

    return Semantics(
      button: true,
      label: '$what, ${message.senderName}, ${formatChatDateTime(message.createdAt)}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppBorderRadius.base),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumb != null)
                ChatPhoto(
                  imageUrl: thumb,
                  fit: BoxFit.cover,
                  // 4칸 바둑판 한 칸(약 85dp)에 원본 해상도를 디코드하지 않게
                  memCacheWidth: 240,
                  brokenBuilder: (_) => _placeholder(isVideo),
                )
              else
                _placeholder(isVideo),
              if (isVideo)
                Positioned(
                  left: AppSpacing.space1,
                  bottom: AppSpacing.space1,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(AppBorderRadius.full),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, size: 16, color: AppColors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(bool isVideo) => Container(
        color: AppSemanticColors.fillDefault,
        alignment: Alignment.center,
        child: Icon(
          isVideo ? Icons.videocam_outlined : Icons.image_outlined,
          color: AppSemanticColors.textTertiary,
        ),
      );
}


/// 방 정보 '미디어' 탭 — 최근 사진 몇 장과 종류별 개수만. 누르면 전체 화면 '주고받은 파일'.
///
/// 정보 화면은 위에 방 카드, 아래에 '채팅방 나가기'가 있어 탭 안이 좁다. 검색·달 줄까지 다 넣으면
/// 사진이 한 줄도 제대로 안 보여서, 여기서는 미리 보기만 하고 찾기는 전체 화면에서 한다.
class ChatFilesPreview extends StatefulWidget {
  const ChatFilesPreview({
    super.key,
    required this.roomId,
    required this.onOpen,
    required this.onShowAll,
    this.controller,
  });

  final int roomId;
  final void Function(ChatMessage message) onOpen;

  /// 종류 줄을 누르면 그 탭으로 전체 화면을 연다
  final void Function(ChatFilesKind kind) onShowAll;

  final ChatFilesController? controller;

  @override
  State<ChatFilesPreview> createState() => _ChatFilesPreviewState();
}

class _ChatFilesPreviewState extends State<ChatFilesPreview> {
  late final ChatFilesController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    // 4칸 두 줄 — 미리 보기는 8장이면 된다
    _controller = widget.controller ?? ChatFilesController(roomId: widget.roomId, pageSize: 8);
    _controller.addListener(_onChanged);
    _controller.load(hopToResults: true);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c.isLoading && c.items.isEmpty) {
      return const Center(child: AppLoading());
    }
    if (c.hasError && c.items.isEmpty) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: '파일 목록을 불러오지 못했습니다',
        actionLabel: '다시 시도',
        onAction: () => c.load(hopToResults: true),
      );
    }
    final total = c.counts.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      return const AppEmptyState(
        icon: Icons.photo_library_outlined,
        title: '공유된 미디어가 없습니다',
      );
    }

    final thumbs = c.kind.isGrid ? c.items.take(8).toList() : const <ChatMessage>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.space2,
        AppSpacing.screenGutter,
        AppSpacing.space3,
      ),
      children: [
        if (thumbs.isNotEmpty) ...[
          GridView.count(
            crossAxisCount: 4,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final m in thumbs) _MediaTile(message: m, onTap: () => widget.onOpen(m)),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
        ],
        for (final k in ChatFilesKind.values)
          if ((c.counts[k] ?? 0) > 0)
            SeedListCell(
              leadingIcon: switch (k) {
                ChatFilesKind.photo => Icons.photo_library_outlined,
                ChatFilesKind.video => Icons.videocam_outlined,
                ChatFilesKind.file => Icons.insert_drive_file_outlined,
              },
              title: k.label,
              trailing: Text(
                formatChatFilesCount(c.counts[k] ?? 0),
                style: AppTypography.bodyMedium.copyWith(color: AppSemanticColors.textSecondary),
              ),
              onTap: () => widget.onShowAll(k),
            ),
      ],
    );
  }
}
