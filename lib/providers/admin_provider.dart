import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AdminProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  // 상태 관리
  bool _isLoading = false;
  String _errorMessage = '';

  // 사용자 관리 데이터
  List<User> _pendingUsers = [];
  List<User> _companyMembers = [];

  // 휴가 관리 데이터
  List<VacationRequest> _vacationRequests = [];
  Map<String, VacationLimit> _vacationLimits = {};

  // Getters
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<User> get pendingUsers => _pendingUsers;
  List<User> get companyMembers => _companyMembers;
  List<VacationRequest> get vacationRequests => _vacationRequests;
  Map<String, VacationLimit> get vacationLimits => _vacationLimits;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  // =============== 사용자 관리 기능 ===============

  /// 승인 대기 중인 사용자 목록 로드
  Future<void> loadPendingUsers(String companyId) async {
    try {
      _setLoading(true);
      _clearError();

      print('[AdminProvider] 승인 대기 사용자 로드 시작 - companyId: $companyId');
      
      final response = await _apiService.getPendingJoinRequests(
        companyId: companyId,
      );

      print('[AdminProvider] API 응답 타입: ${response.runtimeType}');
      print('[AdminProvider] API 응답: $response');

      // frontend-admin과 동일한 응답 구조 처리
      if (response is Map<String, dynamic>) {
        if (response['data'] != null && response['data'] is List) {
          // 응답이 { data: [...] } 형태인 경우
          _pendingUsers = (response['data'] as List<dynamic>)
              .map((userData) => User.fromJson(userData as Map<String, dynamic>))
              .toList();
          print('[AdminProvider] {data: []} 형태 응답');
        } else if (response['requests'] != null && response['requests'] is List) {
          // 기존 처리 방식 유지
          _pendingUsers = (response['requests'] as List<dynamic>)
              .map((userData) => User.fromJson(userData as Map<String, dynamic>))
              .toList();
          print('[AdminProvider] {requests: []} 형태 응답');
        } else {
          print('[AdminProvider] 예상된 응답 구조가 아님: $response');
          _pendingUsers = [];
        }
      } else if (response is List) {
        // 응답이 직접 배열인 경우
        _pendingUsers = (response as List<dynamic>)
            .map((userData) => User.fromJson(userData as Map<String, dynamic>))
            .toList();
        print('[AdminProvider] 직접 배열 형태 응답');
      } else {
        print('[AdminProvider] 예상된 응답 구조가 아님 - 타입: ${response.runtimeType}');
        _pendingUsers = [];
      }

      print('[AdminProvider] 승인 대기 사용자 ${_pendingUsers.length}명 로드 완료');
      notifyListeners();
    } catch (e) {
      print('[AdminProvider] 승인 대기 사용자 로드 실패: $e');
      _setError('승인 대기 목록을 불러오는데 실패했습니다: ${e.toString()}');
      _pendingUsers = [];
    } finally {
      _setLoading(false);
    }
  }

  /// 회사 전체 회원 목록 로드
  Future<void> loadCompanyMembers(String companyId) async {
    try {
      _setLoading(true);
      _clearError();

      print('[AdminProvider] 회사 회원 로드 시작 - companyId: $companyId');

      final response = await _apiService.getCompanyMembers(
        companyId: companyId,
      );

      print('[AdminProvider] 회사 회원 API 응답 타입: ${response.runtimeType}');
      print('[AdminProvider] 회사 회원 API 응답: $response');

      // frontend-admin과 동일한 응답 구조 처리
      if (response is Map<String, dynamic>) {
        if (response['data'] != null && response['data'] is List) {
          // 응답이 { data: [...] } 형태인 경우
          _companyMembers = (response['data'] as List<dynamic>)
              .map((userData) => User.fromJson(userData as Map<String, dynamic>))
              .toList();
          print('[AdminProvider] {data: []} 형태 응답');
        } else if (response['members'] != null && response['members'] is List) {
          // 기존 처리 방식 유지
          _companyMembers = (response['members'] as List<dynamic>)
              .map((userData) => User.fromJson(userData as Map<String, dynamic>))
              .toList();
          print('[AdminProvider] {members: []} 형태 응답');
        } else {
          print('[AdminProvider] 예상된 응답 구조가 아님: $response');
          _companyMembers = [];
        }
      } else if (response is List) {
        // 응답이 직접 배열인 경우
        _companyMembers = (response as List<dynamic>)
            .map((userData) => User.fromJson(userData as Map<String, dynamic>))
            .toList();
        print('[AdminProvider] 직접 배열 형태 응답');
      } else {
        print('[AdminProvider] 예상된 응답 구조가 아님 - 타입: ${response.runtimeType}');
        _companyMembers = [];
      }

      print('[AdminProvider] 회사 회원 ${_companyMembers.length}명 로드 완료');
      notifyListeners();
    } catch (e) {
      print('[AdminProvider] 회사 회원 로드 실패: $e');
      _setError('회원 목록을 불러오는데 실패했습니다: ${e.toString()}');
      _companyMembers = [];
    } finally {
      _setLoading(false);
    }
  }

  /// 가입 요청 승인
  Future<bool> approveJoinRequest(String userId, String adminId) async {
    try {
      _clearError();

      await _apiService.approveJoinRequest(
        userId: userId,
        adminId: adminId,
      );

      // 성공하면 로컬 상태 업데이트
      _pendingUsers.removeWhere((user) => user.id == userId);
      notifyListeners();

      return true;
    } catch (e) {
      _setError('가입 요청 승인에 실패했습니다: ${e.toString()}');
      return false;
    }
  }

  /// 가입 요청 거부
  Future<bool> rejectJoinRequest(String userId, String adminId, String reason) async {
    try {
      _clearError();

      await _apiService.rejectJoinRequest(
        userId: userId,
        adminId: adminId,
        rejectReason: reason,
      );

      // 성공하면 로컬 상태 업데이트
      _pendingUsers.removeWhere((user) => user.id == userId);
      notifyListeners();

      return true;
    } catch (e) {
      _setError('가입 요청 거부에 실패했습니다: ${e.toString()}');
      return false;
    }
  }

  /// 회원 상태 변경
  Future<bool> updateMemberStatus(String userId, String status) async {
    try {
      _clearError();

      await _apiService.updateMemberStatus(
        userId: userId,
        status: status,
      );

      // 성공하면 로컬 상태 업데이트
      final memberIndex = _companyMembers.indexWhere((user) => user.id == userId);
      if (memberIndex != -1) {
        _companyMembers[memberIndex] = _companyMembers[memberIndex].copyWith(
          status: status,
          isActive: status == 'active',
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError('회원 상태 변경에 실패했습니다: ${e.toString()}');
      return false;
    }
  }

  /// 회원 삭제
  Future<bool> deleteMember(String userId) async {
    try {
      _clearError();

      await _apiService.deleteMember(userId: userId);

      // 성공하면 로컬 상태 업데이트
      _companyMembers.removeWhere((user) => user.id == userId);
      notifyListeners();

      return true;
    } catch (e) {
      _setError('회원 삭제에 실패했습니다: ${e.toString()}');
      return false;
    }
  }

  // =============== 휴가 관리 기능 ===============

  /// 휴가 요청 목록 로드
  Future<void> loadVacationRequests(String companyId) async {
    try {
      _setLoading(true);
      _clearError();

      final response = await _apiService.getVacationRequests(
        companyId: companyId,
      );

      if (response['requests'] != null) {
        _vacationRequests = (response['requests'] as List)
            .map((requestData) => VacationRequest.fromJson(requestData))
            .toList();
      } else {
        _vacationRequests = [];
      }

      notifyListeners();
    } catch (e) {
      _setError('휴가 요청 목록을 불러오는데 실패했습니다: ${e.toString()}');
      _vacationRequests = [];
    } finally {
      _setLoading(false);
    }
  }

  /// 휴가 요청 승인
  Future<bool> approveVacationRequest(String vacationId) async {
    try {
      _clearError();

      await _apiService.approveVacationRequest(vacationId: vacationId);

      // 성공하면 로컬 상태 업데이트
      final requestIndex = _vacationRequests.indexWhere((req) => req.id == vacationId);
      if (requestIndex != -1) {
        _vacationRequests[requestIndex] = _vacationRequests[requestIndex].copyWith(
          status: 'approved',
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError('휴가 요청 승인에 실패했습니다: ${e.toString()}');
      return false;
    }
  }

  /// 휴가 요청 거부
  Future<bool> rejectVacationRequest(String vacationId) async {
    try {
      _clearError();

      await _apiService.rejectVacationRequest(vacationId: vacationId);

      // 성공하면 로컬 상태 업데이트
      final requestIndex = _vacationRequests.indexWhere((req) => req.id == vacationId);
      if (requestIndex != -1) {
        _vacationRequests[requestIndex] = _vacationRequests[requestIndex].copyWith(
          status: 'rejected',
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError('휴가 요청 거부에 실패했습니다: ${e.toString()}');
      return false;
    }
  }

  /// 휴가 한도 로드
  Future<void> loadVacationLimits(String companyId, String startDate, String endDate) async {
    try {
      _setLoading(true);
      _clearError();

      final response = await _apiService.getVacationLimits(
        start: startDate,
        end: endDate,
        companyId: companyId,
      );

      if (response['limits'] != null) {
        _vacationLimits.clear();
        for (var limitData in response['limits']) {
          final limit = VacationLimit.fromJson(limitData);
          _vacationLimits['${limit.date}_${limit.role}'] = limit;
        }
      }

      notifyListeners();
    } catch (e) {
      _setError('휴가 한도를 불러오는데 실패했습니다: ${e.toString()}');
      _vacationLimits.clear();
    } finally {
      _setLoading(false);
    }
  }

  /// 휴가 한도 저장
  Future<bool> saveVacationLimits(String companyId, List<VacationLimit> limits) async {
    try {
      _clearError();

      final limitsData = limits.map((limit) => limit.toJson()).toList();

      await _apiService.saveVacationLimits(
        companyId: companyId,
        limits: limitsData,
      );

      // 성공하면 로컬 상태 업데이트
      _vacationLimits.clear();
      for (var limit in limits) {
        _vacationLimits['${limit.date}_${limit.role}'] = limit;
      }
      notifyListeners();

      return true;
    } catch (e) {
      _setError('휴가 한도 저장에 실패했습니다: ${e.toString()}');
      return false;
    }
  }

  /// 데이터 초기화
  void clearData() {
    _pendingUsers.clear();
    _companyMembers.clear();
    _vacationRequests.clear();
    _vacationLimits.clear();
    _clearError();
    notifyListeners();
  }
}

// 휴가 요청 모델
class VacationRequest {
  final String id;
  final String userId;
  final String userName;
  final String date;
  final String? reason;
  final String status;
  final String type;
  final String role;
  final String duration;
  final DateTime createdAt;
  final DateTime updatedAt;

  VacationRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.date,
    this.reason,
    required this.status,
    required this.type,
    required this.role,
    required this.duration,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VacationRequest.fromJson(Map<String, dynamic> json) {
    return VacationRequest(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      userName: json['userName'] ?? '',
      date: json['date'] ?? '',
      reason: json['reason'],
      status: json['status'] ?? 'pending',
      type: json['type'] ?? 'regular',
      role: json['role'] ?? 'all',
      duration: json['duration'] ?? 'FULL_DAY',
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.tryParse(json['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  VacationRequest copyWith({
    String? id,
    String? userId,
    String? userName,
    String? date,
    String? reason,
    String? status,
    String? type,
    String? role,
    String? duration,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VacationRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      date: date ?? this.date,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      type: type ?? this.type,
      role: role ?? this.role,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// 휴가 한도 모델
class VacationLimit {
  final String date;
  final int maxPeople;
  final String role;

  VacationLimit({
    required this.date,
    required this.maxPeople,
    required this.role,
  });

  factory VacationLimit.fromJson(Map<String, dynamic> json) {
    return VacationLimit(
      date: json['date'] ?? '',
      maxPeople: json['maxPeople'] ?? 0,
      role: json['role'] ?? 'caregiver',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'maxPeople': maxPeople,
      'role': role,
    };
  }
}