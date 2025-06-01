import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/storage_service.dart';

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

  Future<bool> login(String email, String password) async {
    try {
      setLoading(true);
      clearError();

      // TODO: 실제 API 호출로 교체
      await Future.delayed(const Duration(seconds: 2));

      // 임시 사용자 데이터
      _currentUser = User(
        id: '1',
        email: email,
        name: '김직원',
        role: 'caregiver',
        createdAt: DateTime.now(),
      );

      // 토큰 저장 (임시)
      await StorageService().saveToken(
        'temp_token_${DateTime.now().millisecondsSinceEpoch}',
      );

      notifyListeners();
      return true;
    } catch (e) {
      setError('로그인에 실패했습니다: ${e.toString()}');
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<bool> register(
    String email,
    String password,
    String name,
    String role,
  ) async {
    try {
      setLoading(true);
      clearError();

      // TODO: 실제 API 호출로 교체
      await Future.delayed(const Duration(seconds: 2));

      // 임시 사용자 데이터
      _currentUser = User(
        id: '1',
        email: email,
        name: name,
        role: role,
        createdAt: DateTime.now(),
      );

      await StorageService().saveToken(
        'temp_token_${DateTime.now().millisecondsSinceEpoch}',
      );

      notifyListeners();
      return true;
    } catch (e) {
      setError('회원가입에 실패했습니다: ${e.toString()}');
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<void> logout() async {
    try {
      setLoading(true);

      // TODO: 실제 로그아웃 API 호출
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

      final token = StorageService().getToken();
      if (token != null) {
        // TODO: 토큰 검증 API 호출
        await Future.delayed(const Duration(seconds: 1));

        // 임시 사용자 데이터 복원
        _currentUser = User(
          id: '1',
          email: 'user@example.com',
          name: '김직원',
          role: 'caregiver',
          createdAt: DateTime.now(),
        );
      }

      notifyListeners();
    } catch (e) {
      setError('인증 상태 확인에 실패했습니다: ${e.toString()}');
    } finally {
      setLoading(false);
    }
  }

  void updateUser(User user) {
    _currentUser = user;
    notifyListeners();
  }
}
