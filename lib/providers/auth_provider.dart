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

      // Spring Boot API 호출
      final response = await ApiService().signin(
        username: username,
        password: password,
      );

      print('[AuthProvider] 로그인 응답: $response');

      if (response['memberId'] != null) {
        // 실제 응답 데이터로 User 객체 생성
        _currentUser = User.fromJson(response);

        // 토큰 저장
        if (response['tokenInfo'] != null &&
            response['tokenInfo']['accessToken'] != null) {
          await StorageService().saveToken(
            response['tokenInfo']['accessToken'],
          );

          // refresh token도 저장
          if (response['tokenInfo']['refreshToken'] != null) {
            await StorageService().saveRefreshToken(
              response['tokenInfo']['refreshToken'],
            );
          }

          print('[AuthProvider] 토큰 저장 완료');
        }

        // 사용자 정보도 저장
        await StorageService().saveUserData(response);
        print('[AuthProvider] 사용자 정보 저장 완료');

        print('[AuthProvider] 로그인 성공 - 사용자: ${_currentUser!.name}');
        notifyListeners();
        return true;
      } else {
        final errorMsg = response['error'] ?? '로그인에 실패했습니다.';
        setError(errorMsg);
        return false;
      }
    } catch (e) {
      if (e.toString().contains('ApiException')) {
        final errorMsg = e.toString().replaceAll('ApiException: ', '');
        setError(errorMsg.split(' (Status:')[0]);
      } else {
        setError('로그인 중 오류가 발생했습니다: ${e.toString()}');
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
    required String companyId, // 필수로 변경
  }) async {
    try {
      setLoading(true);
      clearError();

      print("회원가입 요청을 처리 중...");
      print("이메일: $email, 이름: $name, 역할: $role, 회사 ID: $companyId");

      // companyId 유효성 검사
      if (companyId.isEmpty) {
        setError('회사를 선택해주세요.');
        return false;
      }

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
      await StorageService().removeAll(); // 모든 토큰과 사용자 정보 제거

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

      final token = StorageService().getToken();
      if (token != null) {
        // 토큰이 있으면 저장된 사용자 정보 복원 시도
        print('[AuthProvider] 토큰 발견 - 저장된 사용자 정보 복원 시도');

        // 저장된 사용자 정보 복원 (StorageService에서 사용자 정보를 저장/복원하는 메서드 필요)
        final savedUserData = StorageService().getSavedUserData();
        if (savedUserData != null) {
          _currentUser = User.fromJson(savedUserData);
          print('[AuthProvider] 저장된 사용자 정보 복원 성공: ${_currentUser!.name}');
        } else {
          print('[AuthProvider] 저장된 사용자 정보 없음 - 로그인 필요');
          _currentUser = null;
        }
      } else {
        print('[AuthProvider] 토큰 없음 - 로그인 필요');
        _currentUser = null;
      }

      notifyListeners();
    } catch (e) {
      print('[AuthProvider] 인증 상태 확인 중 오류: $e');
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
