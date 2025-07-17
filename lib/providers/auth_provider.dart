import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isInitialized = false;

  User? get currentUser => _currentUser;

  bool get isLoading => _isLoading;

  String get errorMessage => _errorMessage;

  bool get isLoggedIn => _currentUser != null;
  
  bool get isInitialized => _isInitialized;

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

        // Analytics 사용자 속성 설정
        await AnalyticsService().setUserProperties(
          userId: _currentUser!.id.toString(),
          userRole: _currentUser!.role,
          companyId: _currentUser!.company?.id,
        );

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
        final errorMsg = e
            .toString()
            .replaceAll('ApiException: ', '')
            .replaceAll('Exception: 로그인 실패:', '')
            .replaceAll('(Status: 400)', '');

        setError(errorMsg);
      } else {
        setError('로그인 중 오류가 발생했습니다');
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
        username: email,
        // username으로 email 사용
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

      // Analytics 로그아웃 이벤트 기록
      await AnalyticsService().logLogout();

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

  // 회원탈퇴
  Future<bool> withdrawMember() async {
    try {
      setLoading(true);
      clearError();

      print('[AuthProvider] 회원탈퇴 요청 시작');

      // 회원탈퇴 API 호출
      final response = await ApiService().withdrawMember();

      if (response['message'] != null) {
        print('[AuthProvider] 회원탈퇴 성공: ${response['message']}');

        // 모든 로컬 데이터 삭제
        await StorageService().removeAll();
        _currentUser = null;

        notifyListeners();
        return true;
      } else {
        final errorMsg = response['error'] ?? '회원탈퇴에 실패했습니다.';
        setError(errorMsg);
        return false;
      }
    } catch (e) {
      if (e.toString().contains('ApiException')) {
        final errorMsg = e.toString().replaceAll('ApiException: ', '');
        setError(errorMsg.split(' (Status:')[0]);
      } else {
        setError('회원탈퇴 중 오류가 발생했습니다: ${e.toString()}');
      }
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<void> checkAuthStatus() async {
    try {
      setLoading(true);

      final token = StorageService().getToken();
      if (token == null) {
        print('[AuthProvider] 토큰 없음 - 로그인 필요');
        _currentUser = null;
        _isInitialized = true;
        notifyListeners();
        return;
      }

      print('[AuthProvider] 토큰 발견 - 유효성 검증 시작');

      // 1단계: 저장된 사용자 정보 확인
      final savedUserData = StorageService().getSavedUserData();
      if (savedUserData == null) {
        print('[AuthProvider] 저장된 사용자 정보 없음 - 로그아웃');
        await _performLogout();
        return;
      }

      // 2단계: 서버에 토큰 유효성 검증
      print('[AuthProvider] 서버 토큰 검증 시작');
      var tokenValidationResult = await ApiService().validateToken();

      if (tokenValidationResult == null) {
        print('[AuthProvider] 서버 토큰 검증 실패 - refresh 시도');
        final refreshResult = await ApiService().refreshToken();

        if (refreshResult.isSuccess) {
          print('[AuthProvider] 토큰 갱신 성공 - 재검증');
          tokenValidationResult = await ApiService().validateToken();
          if (tokenValidationResult == null) {
            print('[AuthProvider] 재검증 실패 - 로그아웃');
            await _performLogout();
            return;
          }
        } else if (refreshResult.shouldLogout) {
          print('[AuthProvider] Refresh token 만료 또는 없음 - 로그아웃');
          await _performLogout();
          return;
        } else {
          print('[AuthProvider] 토큰 갱신 일시적 실패 - 로그아웃');
          await _performLogout();
          return;
        }
      }

      // 3단계: 서버에서 받은 토큰 정보로 로컬 정보 업데이트
      if (tokenValidationResult != null) {
        print('[AuthProvider] 토큰 검증 성공 - 토큰 정보 업데이트');

        // 서버에서 받은 최신 토큰 만료 시간 저장
        if (tokenValidationResult['expiresAt'] != null) {
          final expiresAt = tokenValidationResult['expiresAt'] as int;
          final expiresDateTime = DateTime.fromMillisecondsSinceEpoch(
            expiresAt,
          );

          // TokenInfo 업데이트
          final currentToken = StorageService().getToken();
          final updatedTokenInfo = {
            'accessToken': currentToken,
            'refreshToken': StorageService().getRefreshToken(),
            'expiresAt': expiresDateTime.toIso8601String(),
          };

          // 사용자 데이터에 업데이트된 토큰 정보 반영
          savedUserData['tokenInfo'] = updatedTokenInfo;
          await StorageService().saveUserData(savedUserData);

          print('[AuthProvider] 토큰 만료 시간 업데이트: $expiresDateTime');
        }
      }

      // 4단계: 모든 검증 통과 - 사용자 정보 복원
      try {
        _currentUser = User.fromJson(savedUserData);
        print('[AuthProvider] 사용자 정보 복원 성공: ${_currentUser!.name}');

        // Analytics 사용자 속성 설정
        await AnalyticsService().setUserProperties(
          userId: _currentUser!.id.toString(),
          userRole: _currentUser!.role,
          companyId: _currentUser!.company?.id,
        );

        _isInitialized = true;
        notifyListeners();
      } catch (e) {
        print('[AuthProvider] 사용자 정보 복원 실패: $e');
        await _performLogout();
      }
    } catch (e) {
      print('[AuthProvider] 인증 상태 확인 중 오류: $e');
      await _performLogout();
    } finally {
      _isInitialized = true;
      setLoading(false);
    }
  }

  // 로그아웃 처리 (내부 메서드)
  Future<void> _performLogout() async {
    try {
      await StorageService().removeAll();
      _currentUser = null;
      _isInitialized = true;
      clearError();
      notifyListeners();
      print('[AuthProvider] 로그아웃 처리 완료');
    } catch (e) {
      print('[AuthProvider] 로그아웃 처리 중 오류: $e');
      _currentUser = null;
      _isInitialized = true;
      notifyListeners();
    }
  }

  void updateUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  // 비밀번호 찾기
  Future<void> findPassword(String email, BuildContext context) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().findPassword(email: email);
      
      if (!context.mounted) return;

      if (response['message'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message']),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error'] ?? '비밀번호 찾기에 실패했습니다.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      String errorMessage = '비밀번호 찾기 중 오류가 발생했습니다';
      
      if (e.toString().contains('403')) {
        errorMessage = '임시로 비밀번호 찾기 기능이 제한되었습니다. 잠시 후 다시 시도해주세요.';
      } else if (e.toString().contains('ApiException')) {
        final msg = e.toString().replaceAll('ApiException: ', '').split(' (Status:')[0];
        errorMessage = msg;
      }
      
      setError(errorMessage);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setLoading(false);
    }
  }

  // 비밀번호 변경
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required BuildContext context,
  }) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (response['message'] != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message']),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return true;
      } else {
        final errorMsg = response['error'] ?? '비밀번호 변경에 실패했습니다.';
        setError(errorMsg);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return false;
      }
    } catch (e) {
      if (e.toString().contains('ApiException')) {
        final errorMsg = e.toString().replaceAll('ApiException: ', '');
        setError(errorMsg.split(' (Status:')[0]);
      } else {
        setError('비밀번호 변경 중 오류가 발생했습니다: ${e.toString()}');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return false;
    } finally {
      setLoading(false);
    }
  }

  // 회원 역할 변경
  Future<bool> updateMemberRole(String role) async {
    try {
      setLoading(true);
      clearError();

      print('[AuthProvider] 역할 변경 요청: $role');

      final response = await ApiService().updateMemberRole(role: role);
      print('[AuthProvider] 역할 변경 API 응답: $response');

      if (response['message'] != null) {
        print('[AuthProvider] 역할 변경 성공: ${response['message']}');

        // 현재 사용자 정보 업데이트
        if (_currentUser != null) {
          final updatedUser = User(
            id: _currentUser!.id,
            username: _currentUser!.username,
            email: _currentUser!.email,
            name: _currentUser!.name,
            role: role,
            company: _currentUser!.company,
            tokenInfo: _currentUser!.tokenInfo,
            createdAt: _currentUser!.createdAt,
            department: _currentUser!.department,
            position: _currentUser!.position,
          );

          _currentUser = updatedUser;

          // 저장된 사용자 데이터도 업데이트
          final userData = StorageService().getSavedUserData();
          if (userData != null) {
            userData['role'] = role;
            await StorageService().saveUserData(userData);
          }

          notifyListeners();
        }

        return true;
      } else {
        final errorMsg = response['error'] ?? '역할 변경에 실패했습니다.';
        setError(errorMsg);
        return false;
      }
    } catch (e) {
      if (e.toString().contains('ApiException')) {
        final errorMsg = e.toString().replaceAll('ApiException: ', '');
        setError(errorMsg.split(' (Status:')[0]);
      } else {
        setError('역할 변경 중 오류가 발생했습니다: ${e.toString()}');
      }
      return false;
    } finally {
      setLoading(false);
    }
  }
}
