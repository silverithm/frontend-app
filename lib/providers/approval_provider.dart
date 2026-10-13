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

  /// 이 문서가 지금 "내 차례"인지 — 결재선이 있으면 현재 단계의 결재자가 나인
  /// 대기 문서만, 결재선이 없는 legacy 문서는 관리자만 처리할 수 있으므로
  /// 관리자일 때만 그렇다고 본다.
  /// 결재선의 approverId는 직원이면 memberId, 관리자면 'admin_<id>' 형식이라
  /// 두 형태를 모두 내 id로 인정해야 관리자형 단계도 내 차례로 잡힌다.
  bool isMyTurn(ApprovalRequest r, {required String? myId, required bool isAdmin}) {
    if (myId == null || myId.isEmpty) return false;
    if (r.status != ApprovalStatus.pending) return false;
    final ids = <String>{myId, if (isAdmin) 'admin_$myId'};
    if (r.approvalLine.isEmpty) return isAdmin;
    final step = r.currentStep;
    return step != null && ids.contains(step.approverId);
  }

  /// "내 차례"인 결재 문서 개수 — 결재함(approvalRequests) 기준.
  int myTurnCount({required String? myId, required bool isAdmin}) {
    if (myId == null || myId.isEmpty) return 0;
    return _approvalRequests.where((r) {
      return isMyTurn(r, myId: myId, isAdmin: isAdmin);
    }).length;
  }

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

  /// 서버에 이미 없는 문서(웹에서 삭제됐거나 이미 처리된 뒤 지워진 문서)에 대한
  /// 요청인지 — 404 또는 백엔드가 500으로 감싸 보내는 "찾을 수 없습니다" 메시지
  /// 둘 다를 잡는다(서버가 상태 코드를 404로 고친 뒤에도 계속 동작하도록 문구
  /// 매칭을 함께 둔다). 2026-09-22 운영 사고: 삭제된 결재 777이 기기에 계속
  /// "내 차례"로 남아 반려 시도가 500으로 실패했다.
  bool _isGoneError(Object e) {
    if (e is ApiException) {
      return e.statusCode == 404 || e.message.contains('찾을 수 없습니다');
    }
    return e.toString().contains('찾을 수 없습니다');
  }

  /// 서버에서 사라진 문서를 로컬 캐시(결재함·내 결재)에서도 지운다 —
  /// 안 지우면 새로고침 전까지 개수(myTurnCount 등)에 계속 잡힌다.
  void _purgeStaleDocument(int approvalId) {
    _approvalRequests.removeWhere((r) => r.id == approvalId);
    _myApprovalRequests.removeWhere((r) => r.id == approvalId);
    if (_selectedApproval?.id == approvalId) {
      _selectedApproval = null;
    }
    notifyListeners();
  }

  static const String goneDocumentMessage = '이미 삭제되었거나 처리된 결재입니다';

  // ===================== 결재 요청 API =====================

  // 관리자용 결재 요청 목록 로드
  Future<void> loadApprovalRequests({
    required String companyId,
    bool refresh = false,
  }) async {
    // 앱을 막 켰거나 로그인 복원 중이면 사용자 정보에 기관 id가 아직 비어 있다.
    // 그대로 부르면 서버가 `companyId=`(빈 값)를 받아 500을 돌려주고, 화면엔 "데이터 로드 실패"가
    // 뜬다(운영 nginx 10/8·10/10). 기관 id가 채워진 뒤 다음 새로고침에서 다시 부르므로 여기선 건너뛴다.
    if (companyId.trim().isEmpty) {
      print('[ApprovalProvider] 기관 id가 비어 있어 결재 목록 요청을 건너뜀');
      return;
    }

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
      if (_isGoneError(e)) {
        // 목록에서 눌러 들어온 문서가 그새 삭제·처리됐다 — 목록에서도 지워
        // 뒤로 돌아갔을 때 또 나타나지 않게 한다.
        _purgeStaleDocument(approvalId);
        setError(goneDocumentMessage);
      } else {
        setError('결재 요청을 불러오는데 실패했습니다: ${e.toString()}');
      }
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
    Map<String, dynamic>? formData,
    List<Map<String, dynamic>>? approvalLine,
    // true면 상신하지 않고 임시저장만 한다
    bool draft = false,
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
        formData: formData,
        approvalLine: approvalLine,
        attachmentUrl: attachmentUrl,
        attachmentFileName: attachmentFileName,
        attachmentFileSize: attachmentFileSize,
        draft: draft,
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
  // force=true면 내 차례가 아니어도 남은 단계를 건너뛰고 직권 승인(전결)한다
  Future<bool> approveApprovalRequest({
    required int approvalId,
    required String companyId,
    required String processedBy,
    required String processedByName,
    String? signatureBase64,
    String? comment,
    bool force = false,
  }) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().approveApprovalRequest(
        approvalId: approvalId,
        processedBy: processedBy,
        processedByName: processedByName,
        signatureBase64: signatureBase64,
        comment: comment,
        force: force,
      );

      print('[ApprovalProvider] 결재 요청 승인 응답: $response');

      // 목록 새로고침
      await loadApprovalRequests(companyId: companyId, refresh: true);

      return true;
    } catch (e) {
      print('[ApprovalProvider] 결재 요청 승인 에러: $e');
      if (_isGoneError(e)) {
        // 이미 삭제되거나 다른 사람이 먼저 처리한 문서 — 로컬에서도 지워야
        // "내 차례" 개수가 다시 서버와 맞는다.
        _purgeStaleDocument(approvalId);
        setError(goneDocumentMessage);
      } else {
        setError('결재 승인에 실패했습니다: ${e.toString()}');
      }
      return false;
    } finally {
      setLoading(false);
    }
  }

  // 결재 요청 거절
  // force=true면 내 차례가 아니어도 남은 단계를 건너뛰고 직권 반려한다
  Future<bool> rejectApprovalRequest({
    required int approvalId,
    required String reason,
    required String companyId,
    required String processedBy,
    required String processedByName,
    bool force = false,
  }) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().rejectApprovalRequest(
        approvalId: approvalId,
        processedBy: processedBy,
        processedByName: processedByName,
        reason: reason,
        force: force,
      );

      print('[ApprovalProvider] 결재 요청 거절 응답: $response');

      // 목록 새로고침
      await loadApprovalRequests(companyId: companyId, refresh: true);

      return true;
    } catch (e) {
      print('[ApprovalProvider] 결재 요청 거절 에러: $e');
      if (_isGoneError(e)) {
        _purgeStaleDocument(approvalId);
        setError(goneDocumentMessage);
      } else {
        setError('결재 거절에 실패했습니다: ${e.toString()}');
      }
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
