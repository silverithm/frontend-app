import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../services/api_service.dart';
import '../utils/chat_files_browse.dart';

/// '주고받은 파일' 한 쪽을 받아 오는 함수 — 테스트에서 가짜로 바꿔 끼운다.
typedef ChatFilesFetcher = Future<Map<String, dynamic>> Function({
  required int roomId,
  required String kind,
  String? query,
  int? beforeId,
  String? month,
  int size,
});

/// 채팅방 '주고받은 파일' 화면 상태 — 종류 탭·검색어·달로 이동·이어 받기.
///
/// 화면마다 하나씩 만든다(방 사이에 섞이지 않게). 요청이 겹치면 마지막 것만 반영한다 —
/// 검색어를 빠르게 바꾸는 동안 늦게 온 옛 응답이 목록을 덮지 않게.
class ChatFilesController extends ChangeNotifier {
  ChatFilesController({
    required this.roomId,
    ChatFilesFetcher? fetch,
    this.pageSize = 60,
    ChatFilesKind initialKind = ChatFilesKind.photo,
  })  : _fetch = fetch ?? ApiService().getChatFilesPage,
        _kind = initialKind;

  final int roomId;
  final int pageSize;
  final ChatFilesFetcher _fetch;

  ChatFilesKind _kind;
  String _query = '';
  String? _month;
  List<ChatMessage> _items = const [];
  bool _hasMore = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasError = false;
  Map<ChatFilesKind, int> _counts = {for (final k in ChatFilesKind.values) k: 0};
  List<ChatFilesMonth> _months = const [];

  /// 옛 서버가 통째로 준 목록 — 있으면 앱 안에서 거른다
  List<ChatMessage>? _legacyAll;
  int _generation = 0;
  bool _disposed = false;

  ChatFilesKind get kind => _kind;
  String get query => _query;
  String? get month => _month;
  List<ChatMessage> get items => _items;
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasError => _hasError;
  Map<ChatFilesKind, int> get counts => _counts;
  List<ChatFilesMonth> get months => _months;

  /// [hopToResults] — 고른 탭이 비었는데 다른 탭에 있으면 그 탭으로 옮긴다.
  /// 처음 열 때(파일만 주고받는 방)와 검색할 때('근무표'를 사진 탭에서 찾음)만 켠다.
  /// 사람이 직접 탭을 고른 때는 옮기지 않는다 — 고른 탭이 비었다는 것도 답이다.
  Future<void> load({bool hopToResults = false}) async {
    final gen = ++_generation;
    _isLoading = true;
    _hasError = false;
    _items = const [];
    _hasMore = false;
    _notify();
    try {
      final page = await _page();
      if (gen != _generation || _disposed) return;
      _apply(page, append: false);
      if (hopToResults && page.items.isEmpty) {
        ChatFilesKind? firstNonEmpty;
        for (final k in ChatFilesKind.values) {
          if ((_counts[k] ?? 0) > 0) {
            firstNonEmpty = k;
            break;
          }
        }
        if (firstNonEmpty != null && firstNonEmpty != _kind) {
          _kind = firstNonEmpty;
          _month = null;
          await load();
          return;
        }
      }
    } catch (e) {
      if (gen != _generation || _disposed) return;
      debugPrint('[ChatFiles] 불러오기 실패: $e');
      _hasError = true;
    }
    if (gen == _generation && !_disposed) {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoading || _isLoadingMore || _items.isEmpty) return;
    final gen = _generation;
    _isLoadingMore = true;
    _notify();
    try {
      final page = await _page(beforeId: _items.last.id);
      if (gen != _generation || _disposed) return;
      _apply(page, append: true);
    } catch (e) {
      if (gen != _generation || _disposed) return;
      debugPrint('[ChatFiles] 더 불러오기 실패: $e');
      // 더 불러오기 실패는 목록을 지우지 않는다 — 끝까지 내리면 다시 시도한다
    }
    if (gen == _generation && !_disposed) {
      _isLoadingMore = false;
      _notify();
    }
  }

  void setKind(ChatFilesKind kind) {
    if (kind == _kind) return;
    _kind = kind;
    _month = null;
    load();
  }

  void setQuery(String query) {
    final q = query.trim();
    if (q == _query) return;
    _query = q;
    _month = null;
    load(hopToResults: q.isNotEmpty);
  }

  /// null이면 최신부터
  void jumpToMonth(String? month) {
    if (month == _month) return;
    _month = month;
    load();
  }

  Future<ChatFilesPage> _page({int? beforeId}) async {
    final legacy = _legacyAll;
    if (legacy != null) return _local(legacy, beforeId);
    final json = await _fetch(
      roomId: roomId,
      kind: _kind.apiValue,
      query: _query.isEmpty ? null : _query,
      beforeId: beforeId,
      month: beforeId == null ? _month : null,
      size: pageSize,
    );
    if (!isPagedChatFilesResponse(json)) {
      // 옛 서버 — 통째로 왔다. 이후로는 서버를 다시 부르지 않고 앱 안에서 거른다
      final all = parseChatFilesList(json['files']);
      _legacyAll = all;
      return _local(all, beforeId);
    }
    return parseChatFilesPage(json);
  }

  ChatFilesPage _local(List<ChatMessage> all, int? beforeId) => browseChatFilesLocally(
        all,
        kind: _kind,
        query: _query,
        month: beforeId == null ? _month : null,
        beforeId: beforeId,
        size: pageSize,
      );

  void _apply(ChatFilesPage page, {required bool append}) {
    _items = append ? [..._items, ...page.items] : page.items;
    _hasMore = page.hasMore;
    _counts = page.counts;
    // 이어 받는 쪽의 달 목록도 같다 — 처음 쪽 것을 그대로 둔다
    if (!append) _months = page.months;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
