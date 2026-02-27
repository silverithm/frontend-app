import 'package:flutter/material.dart';
import '../models/approval.dart';
import '../services/api_service.dart';

class ApprovalProvider with ChangeNotifier {
  // 결재 요청 목록
  List<ApprovalRequest> _approvalRequests = [];
  List<ApprovalRequest> _myApprovalRequests = [];
  ApprovalRequest? _selectedApproval;

  // 결재 양식 목록
  List<ApprovalTemplate> _templates = [];
  List<ApprovalTemplate> _activeTemplates = [];
  ApprovalTemplate? _selectedTemplate;

  // 상태
  bool _isLoading = false;
  String _errorMessage = '';

  // Pagination
  int _currentPage = 0;
  int _totalPages = 0;
  bool _hasMore = true;

  // Filters
  String? _statusFilter;

  // Getters
  List<ApprovalRequest> get approvalRequests => _approvalRequests;
  List<ApprovalRequest> get myApprovalRequests => _myApprovalRequests;
  ApprovalRequest? get selectedApproval => _selectedApproval;
  List<ApprovalTemplate> get templates => _templates;
  List<ApprovalTemplate> get activeTemplates => _activeTemplates;
  ApprovalTemplate? get selectedTemplate => _selectedTemplate;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get hasMore => _hasMore;
  String? get statusFilter => _statusFilter;

  // 대기중 결재 개수
  int get pendingCount => _approvalRequests
      .where((r) => r.status == ApprovalStatus.pending)
      .length;

  // 내 대기중 결재 개수
  int get myPendingCount => _myApprovalRequests
      .where((r) => r.status == ApprovalStatus.pending)
      .length;

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

  void setStatusFilter(String? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void clearFilters() {
    _statusFilter = null;
    notifyListeners();
  }

  // ===================== 결재 요청 API =====================

  // 관리자용 결재 요청 목록 로드
  Future<void> loadApprovalRequests({
    required String companyId,
    bool refresh = false,
  }) async {
    try {
      if (refresh) {
        _currentPage = 0;
        _approvalRequests.clear();
        _hasMore = true;
      }

      if (!_hasMore && !refresh) return;

      setLoading(true);
      clearError();

      final response = await ApiService().getApprovalRequests(
        companyId: companyId,
        status: _statusFilter,
        page: _currentPage,
      );

      print('[ApprovalProvider] 결재 요청 목록 응답: $response');

      if (response['content'] != null) {
        final List<dynamic> content = response['content'] as List<dynamic>;
        final List<ApprovalRequest> newRequests = content
            .map((json) => ApprovalRequest.fromJson(json as Map<String, dynamic>))
            .toList();

        if (refresh) {
          _approvalRequests = newRequests;
        } else {
          _approvalRequests.addAll(newRequests);
        }

        _totalPages = response['totalPages'] as int? ?? 1;
        _hasMore = _currentPage < _totalPages - 1;
        _currentPage++;
      } else if (response['approvals'] != null) {
        final List<dynamic> content = response['approvals'] as List<dynamic>;
        _approvalRequests = content
            .map((json) => ApprovalRequest.fromJson(json as Map<String, dynamic>))
            .toList();
        _hasMore = false;
      } else {
        if (refresh) {
          _approvalRequests = [];
        }
        _hasMore = false;
      }

      print('[ApprovalProvider] 로드된 결재 요청 수: ${_approvalRequests.length}');
      notifyListeners();
    } catch (e) {
      print('[ApprovalProvider] 결재 요청 목록 로드 에러: $e');
      setError('결재 요청을 불러오는데 실패했습니다: ${e.toString()}');
    } finally {
      setLoading(false);
    }
  }

  // 직원용 내 결재 요청 목록 로드
  Future<void> loadMyApprovalRequests({
    required String requesterId,
    bool refresh = false,
  }) async {
    try {
      if (refresh) {
        _currentPage = 0;
        _myApprovalRequests.clear();
        _hasMore = true;
      }

      if (!_hasMore && !refresh) return;

      setLoading(true);
      clearError();

      final response = await ApiService().getMyApprovalRequests(
        requesterId: requesterId,
        status: _statusFilter,
        page: _currentPage,
      );

      print('[ApprovalProvider] 내 결재 요청 목록 응답: $response');

      if (response['content'] != null) {
        final List<dynamic> content = response['content'] as List<dynamic>;
        final List<ApprovalRequest> newRequests = content
            .map((json) => ApprovalRequest.fromJson(json as Map<String, dynamic>))
            .toList();

        if (refresh) {
          _myApprovalRequests = newRequests;
        } else {
          _myApprovalRequests.addAll(newRequests);
        }

        _totalPages = response['totalPages'] as int? ?? 1;
        _hasMore = _currentPage < _totalPages - 1;
        _currentPage++;
      } else if (response['approvals'] != null) {
        final List<dynamic> content = response['approvals'] as List<dynamic>;
        _myApprovalRequests = content
            .map((json) => ApprovalRequest.fromJson(json as Map<String, dynamic>))
            .toList();
        _hasMore = false;
      } else {
        if (refresh) {
          _myApprovalRequests = [];
        }
        _hasMore = false;
      }

      // 최신순 정렬
      _myApprovalRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('[ApprovalProvider] 로드된 내 결재 요청 수: ${_myApprovalRequests.length}');
      // 디버깅: 각 요청의 ID 확인
      for (final req in _myApprovalRequests) {
        print('[ApprovalProvider] 결재 요청 - ID: ${req.id}, 제목: ${req.title}');
      }
      notifyListeners();
    } catch (e) {
      print('[ApprovalProvider] 내 결재 요청 목록 로드 에러: $e');
      setError('결재 요청을 불러오는데 실패했습니다: ${e.toString()}');
    } finally {
      setLoading(false);
    }
  }

  // 결재 요청 상세 조회
  Future<ApprovalRequest?> loadApprovalDetail({required int approvalId}) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().getApprovalRequestDetail(approvalId: approvalId);

      print('[ApprovalProvider] 결재 요청 상세 응답: $response');

      // 응답이 {approval: {...}} 형태로 중첩되어 있으면 내부 객체 추출
      final approvalData = response['approval'] ?? response;
      _selectedApproval = ApprovalRequest.fromJson(approvalData as Map<String, dynamic>);
      notifyListeners();
      return _selectedApproval;
    } catch (e) {
      print('[ApprovalProvider] 결재 요청 상세 로드 에러: $e');
      setError('결재 요청을 불러오는데 실패했습니다: ${e.toString()}');
      return null;
    } finally {
      setLoading(false);
    }
  }

  // 결재 요청 생성
  Future<bool> createApprovalRequest({
    required String companyId,
    required String requesterId,
    required String requesterName,
    required int templateId,
    required String title,
    String? attachmentUrl,
    String? attachmentFileName,
    int? attachmentFileSize,
  }) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().createApprovalRequest(
        companyId: companyId,
        requesterId: requesterId,
        requesterName: requesterName,
        templateId: templateId,
        title: title,
        attachmentUrl: attachmentUrl,
        attachmentFileName: attachmentFileName,
        attachmentFileSize: attachmentFileSize,
      );

      print('[ApprovalProvider] 결재 요청 생성 응답: $response');

      // 목록 새로고침
      await loadMyApprovalRequests(requesterId: requesterId, refresh: true);

      return true;
    } catch (e) {
      print('[ApprovalProvider] 결재 요청 생성 에러: $e');
      setError('결재 요청 생성에 실패했습니다: ${e.toString()}');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // 결재 요청 승인
  Future<bool> approveApprovalRequest({
    required int approvalId,
    required String companyId,
    required String processedBy,
    required String processedByName,
  }) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().approveApprovalRequest(
        approvalId: approvalId,
        processedBy: processedBy,
        processedByName: processedByName,
      );

      print('[ApprovalProvider] 결재 요청 승인 응답: $response');

      // 목록 새로고침
      await loadApprovalRequests(companyId: companyId, refresh: true);

      return true;
    } catch (e) {
      print('[ApprovalProvider] 결재 요청 승인 에러: $e');
      setError('결재 승인에 실패했습니다: ${e.toString()}');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // 결재 요청 거절
  Future<bool> rejectApprovalRequest({
    required int approvalId,
    required String reason,
    required String companyId,
    required String processedBy,
    required String processedByName,
  }) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().rejectApprovalRequest(
        approvalId: approvalId,
        processedBy: processedBy,
        processedByName: processedByName,
        reason: reason,
      );

      print('[ApprovalProvider] 결재 요청 거절 응답: $response');

      // 목록 새로고침
      await loadApprovalRequests(companyId: companyId, refresh: true);

      return true;
    } catch (e) {
      print('[ApprovalProvider] 결재 요청 거절 에러: $e');
      setError('결재 거절에 실패했습니다: ${e.toString()}');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // 결재 요청 일괄 승인
  Future<bool> bulkApproveApprovalRequests({
    required List<int> approvalIds,
    required String companyId,
    required String processedBy,
    required String processedByName,
  }) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().bulkApproveApprovalRequests(
        approvalIds: approvalIds,
        processedBy: processedBy,
        processedByName: processedByName,
      );

      print('[ApprovalProvider] 결재 요청 일괄 승인 응답: $response');

      // 목록 새로고침
      await loadApprovalRequests(companyId: companyId, refresh: true);

      return true;
    } catch (e) {
      print('[ApprovalProvider] 결재 요청 일괄 승인 에러: $e');
      setError('일괄 승인에 실패했습니다: ${e.toString()}');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // 결재 요청 일괄 거절
  Future<bool> bulkRejectApprovalRequests({
    required List<int> approvalIds,
    required String reason,
    required String companyId,
    required String processedBy,
    required String processedByName,
  }) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().bulkRejectApprovalRequests(
        approvalIds: approvalIds,
        processedBy: processedBy,
        processedByName: processedByName,
        reason: reason,
      );

      print('[ApprovalProvider] 결재 요청 일괄 거절 응답: $response');

      // 목록 새로고침
      await loadApprovalRequests(companyId: companyId, refresh: true);

      return true;
    } catch (e) {
      print('[ApprovalProvider] 결재 요청 일괄 거절 에러: $e');
      setError('일괄 거절에 실패했습니다: ${e.toString()}');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // 결재 요청 취소 (삭제)
  Future<bool> deleteApprovalRequest({
    required int approvalId,
    required String companyId,
  }) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().deleteApprovalRequest(approvalId: approvalId);

      print('[ApprovalProvider] 결재 요청 취소 응답: $response');

      // 목록에서 제거
      _myApprovalRequests.removeWhere((r) => r.id == approvalId);
      _approvalRequests.removeWhere((r) => r.id == approvalId);

      notifyListeners();
      return true;
    } catch (e) {
      print('[ApprovalProvider] 결재 요청 취소 에러: $e');
      setError('결재 요청 취소에 실패했습니다: ${e.toString()}');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // ===================== 결재 양식 API =====================

  // 관리자용 결재 양식 목록 로드
  Future<void> loadTemplates({
    required String companyId,
    bool refresh = false,
  }) async {
    try {
      if (refresh) {
        _templates.clear();
      }

      setLoading(true);
      clearError();

      final response = await ApiService().getApprovalTemplates(companyId: companyId);

      print('[ApprovalProvider] 결재 양식 목록 응답: $response');

      if (response['content'] != null) {
        final List<dynamic> content = response['content'] as List<dynamic>;
        _templates = content
            .map((json) => ApprovalTemplate.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response['templates'] != null) {
        final List<dynamic> content = response['templates'] as List<dynamic>;
        _templates = content
            .map((json) => ApprovalTemplate.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        _templates = [];
      }

      print('[ApprovalProvider] 로드된 결재 양식 수: ${_templates.length}');
      notifyListeners();
    } catch (e) {
      print('[ApprovalProvider] 결재 양식 목록 로드 에러: $e');
      setError('결재 양식을 불러오는데 실패했습니다: ${e.toString()}');
    } finally {
      setLoading(false);
    }
  }

  // 직원용 활성 결재 양식 목록 로드
  Future<void> loadActiveTemplates({
    required String companyId,
  }) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().getActiveApprovalTemplates(companyId: companyId);

      print('[ApprovalProvider] 활성 결재 양식 목록 응답: $response');

      if (response['content'] != null) {
        final List<dynamic> content = response['content'] as List<dynamic>;
        _activeTemplates = content
            .map((json) => ApprovalTemplate.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response['templates'] != null) {
        final List<dynamic> content = response['templates'] as List<dynamic>;
        _activeTemplates = content
            .map((json) => ApprovalTemplate.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        _activeTemplates = [];
      }

      print('[ApprovalProvider] 로드된 활성 결재 양식 수: ${_activeTemplates.length}');
      notifyListeners();
    } catch (e) {
      print('[ApprovalProvider] 활성 결재 양식 목록 로드 에러: $e');
      setError('결재 양식을 불러오는데 실패했습니다: ${e.toString()}');
    } finally {
      setLoading(false);
    }
  }

  // 결재 양식 상세 조회
  Future<ApprovalTemplate?> loadTemplateDetail({required int templateId}) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().getApprovalTemplateDetail(templateId: templateId);

      print('[ApprovalProvider] 결재 양식 상세 응답: $response');

      _selectedTemplate = ApprovalTemplate.fromJson(response);
      notifyListeners();
      return _selectedTemplate;
    } catch (e) {
      print('[ApprovalProvider] 결재 양식 상세 로드 에러: $e');
      setError('결재 양식을 불러오는데 실패했습니다: ${e.toString()}');
      return null;
    } finally {
      setLoading(false);
    }
  }

  // 결재 양식 생성
  Future<bool> createTemplate({
    required String companyId,
    required String name,
    String? description,
    String? fileUrl,
    String? fileName,
    int? fileSize,
  }) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().createApprovalTemplate(
        companyId: companyId,
        name: name,
        description: description,
        fileUrl: fileUrl,
        fileName: fileName,
        fileSize: fileSize,
      );

      print('[ApprovalProvider] 결재 양식 생성 응답: $response');

      // 목록 새로고침
      await loadTemplates(companyId: companyId, refresh: true);

      return true;
    } catch (e) {
      print('[ApprovalProvider] 결재 양식 생성 에러: $e');
      setError('결재 양식 생성에 실패했습니다: ${e.toString()}');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // 결재 양식 수정
  Future<bool> updateTemplate({
    required int templateId,
    required String companyId,
    required String name,
    String? description,
    String? fileUrl,
    String? fileName,
    int? fileSize,
  }) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().updateApprovalTemplate(
        templateId: templateId,
        name: name,
        description: description,
        fileUrl: fileUrl,
        fileName: fileName,
        fileSize: fileSize,
      );

      print('[ApprovalProvider] 결재 양식 수정 응답: $response');

      // 목록 새로고침
      await loadTemplates(companyId: companyId, refresh: true);

      return true;
    } catch (e) {
      print('[ApprovalProvider] 결재 양식 수정 에러: $e');
      setError('결재 양식 수정에 실패했습니다: ${e.toString()}');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // 결재 양식 활성화 토글
  Future<bool> toggleTemplateActive({
    required int templateId,
    required String companyId,
  }) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().toggleApprovalTemplateActive(templateId: templateId);

      print('[ApprovalProvider] 결재 양식 활성화 토글 응답: $response');

      // 목록 새로고침
      await loadTemplates(companyId: companyId, refresh: true);

      return true;
    } catch (e) {
      print('[ApprovalProvider] 결재 양식 활성화 토글 에러: $e');
      setError('양식 상태 변경에 실패했습니다: ${e.toString()}');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // 결재 양식 삭제
  Future<bool> deleteTemplate({
    required int templateId,
    required String companyId,
  }) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().deleteApprovalTemplate(templateId: templateId);

      print('[ApprovalProvider] 결재 양식 삭제 응답: $response');

      // 목록에서 제거
      _templates.removeWhere((t) => t.id == templateId);
      _activeTemplates.removeWhere((t) => t.id == templateId);

      notifyListeners();
      return true;
    } catch (e) {
      print('[ApprovalProvider] 결재 양식 삭제 에러: $e');
      setError('결재 양식 삭제에 실패했습니다: ${e.toString()}');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // 선택된 결재 요청 초기화
  void clearSelectedApproval() {
    _selectedApproval = null;
    notifyListeners();
  }

  // 선택된 양식 초기화
  void clearSelectedTemplate() {
    _selectedTemplate = null;
    notifyListeners();
  }

  // 전체 상태 초기화
  void reset() {
    _approvalRequests = [];
    _myApprovalRequests = [];
    _selectedApproval = null;
    _templates = [];
    _activeTemplates = [];
    _selectedTemplate = null;
    _isLoading = false;
    _errorMessage = '';
    _currentPage = 0;
    _totalPages = 0;
    _hasMore = true;
    _statusFilter = null;
    notifyListeners();
  }
}
