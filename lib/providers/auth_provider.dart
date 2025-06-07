import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String _errorMessage = '';

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;

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

  Future<bool> login(String username, String password) async {
    try {
      setLoading(true);
      clearError();

      // Spring Boot signin API 호출
      final response = await ApiService().signin(
        username: username,
        password: password,
      );

      // MemberSigninResponseDTO 응답 처리
      if (response['memberId'] != null) {
        _currentUser = User.fromJson(response);

        // 토큰 저장
        if (_currentUser!.tokenInfo?.accessToken != null) {
          await StorageService().saveToken(
            _currentUser!.tokenInfo!.accessToken,
          );
        }

        notifyListeners();
        return true;
      } else {
        setError('로그인에 실패했습니다.');
        return false;
      }
    } catch (e) {
      if (e.toString().contains('ApiException')) {
        final errorMsg = e.toString().replaceAll('ApiException: ', '');
        setError(errorMsg.split(' (Status:')[0]);
      } else {
        setError('로그인에 실패했습니다: ${e.toString()}');
      }
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<bool> register(
    String email,
    String password,
    String name,
    String role, {
    String? companyId, // 회사 ID 추가
  }) async {
    try {
      setLoading(true);
      clearError();

      print("회원가입 요청을 처리 중...");
      print("이메일: $email, 이름: $name, 역할: $role, 회사 ID: $companyId");

      // 회원가입 요청 API 호출 (관리자 승인 대기)
      final response = await ApiService().submitJoinRequest(
        username: email, // username으로 email 사용
        email: email,
        name: name,
        role: role,
        password: password,
        companyId: companyId,
      );

      // Spring Boot API 응답에서 id 필드가 있으면 성공
      if (response['id'] != null) {
        print('회원가입 요청 성공 - ID: ${response['id']}, 상태: ${response['status']}');
        return true;
      } else {
        setError(
          response['error'] ?? response['message'] ?? '회원가입 요청에 실패했습니다.',
        );
        return false;
      }
    } catch (e) {
      if (e.toString().contains('ApiException')) {
        // API 에러 메시지 그대로 사용
        final errorMsg = e.toString().replaceAll('ApiException: ', '');
        setError(errorMsg.split(' (Status:')[0]);
      } else {
        setError('회원가입 요청에 실패했습니다: ${e.toString()}');
      }
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<void> logout() async {
    try {
      setLoading(true);

      // TODO: 로그아웃 API 호출 (필요시)
      await StorageService().removeToken();

      _currentUser = null;
      notifyListeners();
    } catch (e) {
      setError('로그아웃에 실패했습니다: ${e.toString()}');
    } finally {
      setLoading(false);
    }
  }

  Future<void> checkAuthStatus() async {
    try {
      setLoading(true);

      final token = await StorageService().getToken();
      if (token != null) {
        // TODO: 토큰 검증 API 호출 (현재는 임시로 토큰이 있으면 로그인 상태로 처리)

        // 임시 사용자 데이터 - 실제로는 토큰으로 사용자 정보를 가져와야 함
        _currentUser = User(
          id: '1',
          username: 'user@example.com',
          email: 'user@example.com',
          name: '김직원',
          role: 'CAREGIVER',
          createdAt: DateTime.now(),
        );
      }

      notifyListeners();
    } catch (e) {
      // 토큰이 유효하지 않으면 제거
      await StorageService().removeToken();
      _currentUser = null;
      notifyListeners();
    } finally {
      setLoading(false);
    }
  }

  void updateUser(User user) {
    _currentUser = user;
    notifyListeners();
  }
}
