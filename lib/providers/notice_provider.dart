import 'package:flutter/material.dart';
import '../models/notice.dart';
import '../services/api_service.dart';

class NoticeProvider with ChangeNotifier {
  List<Notice> _notices = [];
  List<Notice> _publishedNotices = [];
  Notice? _selectedNotice;
  List<NoticeComment> _comments = [];
  List<NoticeReader> _readers = [];
  int _unreadNoticeCount = 0;
  bool _isLoading = false;
  String _errorMessage = '';

  // Pagination
  int _currentPage = 0;
  int _totalPages = 0;
  bool _hasMore = true;

  // Filters
  String? _statusFilter;
  String? _priorityFilter;
  String? _searchQuery;

  // Getters
  List<Notice> get notices => _notices;
  List<Notice> get publishedNotices => _publishedNotices;
  Notice? get selectedNotice => _selectedNotice;
  List<NoticeComment> get comments => _comments;
  List<NoticeReader> get readers => _readers;
  int get unreadNoticeCount => _unreadNoticeCount;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get hasMore => _hasMore;
  String? get statusFilter => _statusFilter;
  String? get priorityFilter => _priorityFilter;
  String? get searchQuery => _searchQuery;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  void setFilters({String? status, String? priority, String? search}) {
    _statusFilter = status;
    _priorityFilter = priority;
    _searchQuery = search;
    notifyListeners();
  }

  void clearFilters() {
    _statusFilter = null;
    _priorityFilter = null;
    _searchQuery = null;
    notifyListeners();
  }

  // 관리자용 공지사항 목록 로드
  Future<void> loadNotices({
    required String companyId,
    bool refresh = false,
  }) async {
    try {
      if (refresh) {
        _currentPage = 0;
        _notices.clear();
        _hasMore = true;
      }

      if (!_hasMore && !refresh) return;

      setLoading(true);
      clearError();

      final response = await ApiService().getNotices(
        companyId: companyId,
        status: _statusFilter,
        priority: _priorityFilter,
        search: _searchQuery,
        page: _currentPage,
      );

      print('[NoticeProvider] 공지사항 목록 응답: $response');

      if (response['content'] != null) {
        final List<dynamic> content = response['content'] as List<dynamic>;
        final List<Notice> newNotices = content
            .map((json) => Notice.fromJson(json as Map<String, dynamic>))
            .toList();

        if (refresh) {
          _notices = newNotices;
        } else {
          _notices.addAll(newNotices);
        }

        _totalPages = response['totalPages'] as int? ?? 1;
        _hasMore = _currentPage < _totalPages - 1;
        _currentPage++;
      } else if (response['notices'] != null) {
        // 대체 응답 형식 지원
        final List<dynamic> content = response['notices'] as List<dynamic>;
        _notices = content
            .map((json) => Notice.fromJson(json as Map<String, dynamic>))
            .toList();
        _hasMore = false;
      } else {
        // 빈 응답
        if (refresh) {
          _notices = [];
        }
        _hasMore = false;
      }

      print('[NoticeProvider] 로드된 공지사항 수: ${_notices.length}');
      notifyListeners();
    } catch (e) {
      print('[NoticeProvider] 공지사항 목록 로드 에러: $e');
      setError('공지사항을 불러오는데 실패했습니다: ${e.toString()}');
    } finally {
      setLoading(false);
    }
  }

  // 직원용 게시된 공지사항 목록 로드
  Future<void> loadPublishedNotices({
    required String companyId,
    bool refresh = false,
  }) async {
    try {
      if (refresh) {
        _currentPage = 0;
        _publishedNotices.clear();
        _hasMore = true;
      }

      if (!_hasMore && !refresh) return;

      setLoading(true);
      clearError();

      final response = await ApiService().getPublishedNotices(
        companyId: companyId,
        page: _currentPage,
      );

      print('[NoticeProvider] 게시된 공지사항 목록 응답: $response');

      if (response['content'] != null) {
        final List<dynamic> content = response['content'] as List<dynamic>;
        final List<Notice> newNotices = content
            .map((json) => Notice.fromJson(json as Map<String, dynamic>))
            .toList();

        if (refresh) {
          _publishedNotices = newNotices;
        } else {
          _publishedNotices.addAll(newNotices);
        }

        _totalPages = response['totalPages'] as int? ?? 1;
        _hasMore = _currentPage < _totalPages - 1;
        _currentPage++;
      } else if (response['notices'] != null) {
        final List<dynamic> content = response['notices'] as List<dynamic>;
        _publishedNotices = content
            .map((json) => Notice.fromJson(json as Map<String, dynamic>))
            .toList();
        _hasMore = false;
      } else {
        if (refresh) {
          _publishedNotices = [];
        }
        _hasMore = false;
      }

      // 고정 공지를 상단으로 정렬
      _publishedNotices.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        // 같은 경우 최신순 정렬
        return b.createdAt.compareTo(a.createdAt);
      });

      print('[NoticeProvider] 로드된 게시된 공지사항 수: ${_publishedNotices.length}');
      notifyListeners();
    } catch (e) {
      print('[NoticeProvider] 게시된 공지사항 목록 로드 에러: $e');
      setError('공지사항을 불러오는데 실패했습니다: ${e.toString()}');
    } finally {
      setLoading(false);
    }
  }

  // 공지사항 상세 조회
  Future<Notice?> loadNoticeDetail({required int noticeId}) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().getNoticeDetail(noticeId: noticeId);

      print('[NoticeProvider] 공지사항 상세 응답: $response');

      // API 응답이 {"notice": {...}} 형태로 오므로 notice 키로 접근
      final noticeData = response['notice'] ?? response;
      _selectedNotice = Notice.fromJson(noticeData as Map<String, dynamic>);
      notifyListeners();
      return _selectedNotice;
    } catch (e) {
      print('[NoticeProvider] 공지사항 상세 로드 에러: $e');
      setError('공지사항을 불러오는데 실패했습니다: ${e.toString()}');
      return null;
    } finally {
      setLoading(false);
    }
  }

  // 공지사항 등록
  Future<bool> createNotice({
    required String companyId,
    required String title,
    required String content,
    String priority = 'NORMAL',
    String status = 'DRAFT',
    bool isPinned = false,
  }) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().createNotice(
        companyId: companyId,
        title: title,
        content: content,
        priority: priority,
        status: status,
        isPinned: isPinned,
      );

      print('[NoticeProvider] 공지사항 등록 응답: $response');

      // 목록 새로고침
      await loadNotices(companyId: companyId, refresh: true);

      return true;
    } catch (e) {
      print('[NoticeProvider] 공지사항 등록 에러: $e');
      setError('공지사항 등록에 실패했습니다: ${e.toString()}');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // 공지사항 수정
  Future<bool> updateNotice({
    required int noticeId,
    required String companyId,
    required String title,
    required String content,
    String priority = 'NORMAL',
    String status = 'DRAFT',
    bool isPinned = false,
  }) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().updateNotice(
        noticeId: noticeId,
        title: title,
        content: content,
        priority: priority,
        status: status,
        isPinned: isPinned,
      );

      print('[NoticeProvider] 공지사항 수정 응답: $response');

      // 목록 새로고침
      await loadNotices(companyId: companyId, refresh: true);

      return true;
    } catch (e) {
      print('[NoticeProvider] 공지사항 수정 에러: $e');
      setError('공지사항 수정에 실패했습니다: ${e.toString()}');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // 공지사항 삭제
  Future<bool> deleteNotice({
    required int noticeId,
    required String companyId,
  }) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().deleteNotice(noticeId: noticeId);

      print('[NoticeProvider] 공지사항 삭제 응답: $response');

      // 목록에서 제거
      _notices.removeWhere((notice) => notice.id == noticeId);
      _publishedNotices.removeWhere((notice) => notice.id == noticeId);

      notifyListeners();
      return true;
    } catch (e) {
      print('[NoticeProvider] 공지사항 삭제 에러: $e');
      setError('공지사항 삭제에 실패했습니다: ${e.toString()}');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // 조회수 증가
  Future<void> incrementViewCount({required int noticeId}) async {
    try {
      await ApiService().incrementNoticeViewCount(noticeId: noticeId);

      // 로컬 상태 업데이트
      final index = _publishedNotices.indexWhere((n) => n.id == noticeId);
      if (index != -1) {
        _publishedNotices[index] = _publishedNotices[index].copyWith(
          viewCount: _publishedNotices[index].viewCount + 1,
        );
      }

      final adminIndex = _notices.indexWhere((n) => n.id == noticeId);
      if (adminIndex != -1) {
        _notices[adminIndex] = _notices[adminIndex].copyWith(
          viewCount: _notices[adminIndex].viewCount + 1,
        );
      }

      if (_selectedNotice?.id == noticeId) {
        _selectedNotice = _selectedNotice!.copyWith(
          viewCount: _selectedNotice!.viewCount + 1,
        );
      }

      notifyListeners();
    } catch (e) {
      print('[NoticeProvider] 조회수 증가 에러: $e');
      // 조회수 증가 실패는 사용자에게 표시하지 않음
    }
  }

  // 읽지 않은 공지사항 수 조회
  Future<void> loadUnreadNoticeCount({
    required String companyId,
    required String userId,
  }) async {
    try {
      final response = await ApiService().getUnreadNoticeCount(
        companyId: companyId,
        userId: userId,
      );

      _unreadNoticeCount = response['unreadCount'] as int? ?? 0;
      print('[NoticeProvider] 읽지 않은 공지사항 수: $_unreadNoticeCount');
      notifyListeners();
    } catch (e) {
      print('[NoticeProvider] 읽지 않은 공지사항 수 조회 에러: $e');
    }
  }

  // 읽음 기록
  Future<void> markAsRead({
    required int noticeId,
    required String userId,
    required String userName,
  }) async {
    try {
      await ApiService().markNoticeAsRead(
        noticeId: noticeId,
        userId: userId,
        userName: userName,
      );
      // 읽음 처리 후 unread count 감소
      if (_unreadNoticeCount > 0) {
        _unreadNoticeCount--;
        notifyListeners();
      }
      print('[NoticeProvider] 읽음 기록 완료');
    } catch (e) {
      print('[NoticeProvider] 읽음 기록 에러: $e');
    }
  }

  // ===================== 댓글 API =====================

  // 댓글 목록 로드
  Future<void> loadComments({required int noticeId}) async {
    try {
      final response = await ApiService().getNoticeComments(noticeId: noticeId);

      print('[NoticeProvider] 댓글 목록 응답: $response');

      if (response['comments'] != null) {
        final List<dynamic> content = response['comments'] as List<dynamic>;
        _comments = content
            .map((json) => NoticeComment.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        _comments = [];
      }

      // 최신순 정렬
      _comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('[NoticeProvider] 로드된 댓글 수: ${_comments.length}');
      notifyListeners();
    } catch (e) {
      print('[NoticeProvider] 댓글 목록 로드 에러: $e');
      _comments = [];
      notifyListeners();
    }
  }

  // 댓글 생성
  Future<bool> createComment({
    required int noticeId,
    required String authorId,
    required String authorName,
    required String content,
  }) async {
    try {
      final response = await ApiService().createNoticeComment(
        noticeId: noticeId,
        authorId: authorId,
        authorName: authorName,
        content: content,
      );

      print('[NoticeProvider] 댓글 생성 응답: $response');

      // 댓글 목록 새로고침
      await loadComments(noticeId: noticeId);

      return true;
    } catch (e) {
      print('[NoticeProvider] 댓글 생성 에러: $e');
      setError('댓글 등록에 실패했습니다: ${e.toString()}');
      return false;
    }
  }

  // 댓글 삭제
  Future<bool> deleteComment({
    required int noticeId,
    required int commentId,
  }) async {
    try {
      final response = await ApiService().deleteNoticeComment(
        noticeId: noticeId,
        commentId: commentId,
      );

      print('[NoticeProvider] 댓글 삭제 응답: $response');

      // 로컬에서 제거
      _comments.removeWhere((c) => c.id == commentId);
      notifyListeners();

      return true;
    } catch (e) {
      print('[NoticeProvider] 댓글 삭제 에러: $e');
      setError('댓글 삭제에 실패했습니다: ${e.toString()}');
      return false;
    }
  }

  // ===================== 읽음 확인 API =====================

  // 읽은 사용자 목록 로드
  Future<void> loadReaders({required int noticeId}) async {
    try {
      final response = await ApiService().getNoticeReaders(noticeId: noticeId);

      print('[NoticeProvider] 읽은 사용자 목록 응답: $response');

      if (response['readers'] != null) {
        final List<dynamic> content = response['readers'] as List<dynamic>;
        _readers = content
            .map((json) => NoticeReader.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        _readers = [];
      }

      // 최신순 정렬
      _readers.sort((a, b) => b.readAt.compareTo(a.readAt));

      print('[NoticeProvider] 읽은 사용자 수: ${_readers.length}');
      notifyListeners();
    } catch (e) {
      print('[NoticeProvider] 읽은 사용자 목록 로드 에러: $e');
      _readers = [];
      notifyListeners();
    }
  }

  // 댓글 초기화
  void clearComments() {
    _comments = [];
    notifyListeners();
  }

  // 읽은 사용자 초기화
  void clearReaders() {
    _readers = [];
    notifyListeners();
  }

  // 선택된 공지사항 초기화
  void clearSelectedNotice() {
    _selectedNotice = null;
    notifyListeners();
  }

  // 전체 상태 초기화
  void reset() {
    _notices = [];
    _publishedNotices = [];
    _selectedNotice = null;
    _comments = [];
    _readers = [];
    _unreadNoticeCount = 0;
    _isLoading = false;
    _errorMessage = '';
    _currentPage = 0;
    _totalPages = 0;
    _hasMore = true;
    _statusFilter = null;
    _priorityFilter = null;
    _searchQuery = null;
    notifyListeners();
  }
}
