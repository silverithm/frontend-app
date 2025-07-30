import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/admin_signin_response.dart';
import '../models/member_signin_response.dart';
import '../models/subscription.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';
import '../utils/jwt_utils.dart';

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

      print('[AuthProvider] 일반 로그인 응답: $response');

      if (response['memberId'] != null) {
        // MemberSigninResponse로 파싱 후 User 객체로 변환
        final memberResponse = MemberSigninResponse.fromJson(response);
        _currentUser = memberResponse.toUser();

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

  // 관리자 로그인
  Future<bool> adminLogin(String username, String password) async {
    try {
      setLoading(true);
      clearError();

      // 관리자 로그인 API 호출
      final response = await ApiService().adminSignin(
        username: username,
        password: password,
      );

      print('[AuthProvider] 관리자 로그인 응답: $response');

      if (response['userId'] != null) {
        // AdminSigninResponse로 파싱 후 User 객체로 변환
        final adminResponse = AdminSigninResponse.fromJson(response);
        _currentUser = adminResponse.toUser();

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
        }

        // 사용자 정보 저장 (로그인 시 입력한 이메일 포함)
        final modifiedResponse = Map<String, dynamic>.from(response);
        modifiedResponse['userEmail'] = username; // 로그인 시 입력한 이메일 저장
        await StorageService().saveUserData(modifiedResponse);

        // Analytics 사용자 속성 설정
        await AnalyticsService().setUserProperties(
          userId: _currentUser!.id.toString(),
          userRole: _currentUser!.role,
          companyId: _currentUser!.company?.id,
        );

        print('[AuthProvider] 관리자 로그인 성공 - 사용자: ${_currentUser!.name}');
        print('[AuthProvider] 관리자 로그인 성공 - 역할: ${_currentUser!.role}');
        print('[AuthProvider] 관리자 로그인 성공 - 회사: ${_currentUser!.company?.name}');
        print('[AuthProvider] 관리자 로그인 성공 - 활성 상태: ${_currentUser!.isActive}');
        print('[AuthProvider] 관리자 로그인 성공 - 상태: ${_currentUser!.status}');
        
        // 구독 정보를 AdminSigninResponse 대신 실시간 API로 로드하도록 비워둠
        // SubscriptionProvider.loadSubscription()이 호출될 때 실시간으로 가져옴
        notifyListeners();
        return true;
      } else {
        final errorMsg = response['error'] ?? '관리자 로그인에 실패했습니다.';
        setError(errorMsg);
        return false;
      }
    } catch (e) {
      if (e.toString().contains('ApiException')) {
        final errorMsg = e
            .toString()
            .replaceAll('ApiException: ', '')
            .replaceAll('Exception: 관리자 로그인 실패:', '')
            .replaceAll('(Status: 400)', '');

        setError(errorMsg);
      } else {
        setError('관리자 로그인 중 오류가 발생했습니다');
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
    String? companyId, // optional로 변경
    String? companyName, // 관리자용
    String? companyAddress, // 관리자용
  }) async {
    try {
      setLoading(true);
      clearError();

      print("회원가입 요청을 처리 중...");
      print("이메일: $email, 이름: $name, 역할: $role, 회사 ID: $companyId");

      if (role == 'ADMIN') {
        // 관리자 회원가입은 별도 처리
        return await _registerAdmin(email, password, name,
            companyName: companyName, companyAddress: companyAddress);
      } else {
        // 직원 회원가입
        if (companyId == null || companyId.isEmpty) {
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
          // 서버에서 온 에러 메시지를 그대로 사용
          String errorMsg = response['error'] ?? response['message'] ?? '회원가입 요청에 실패했습니다.';
          setError(errorMsg);
          return false;
        }
      }
    } catch (e) {
      if (e.toString().contains('ApiException')) {
        // API 에러 메시지에서 불필요한 접두사만 제거하고 서버 메시지 보존
        final errorMsg = e.toString()
            .replaceAll('ApiException: ', '')
            .split(' (Status:')[0]; // 상태 코드 부분만 제거
        setError(errorMsg);
      } else {
        // 네트워크 오류 등의 경우만 추가 정보 제공
        String cleanMsg = e.toString().replaceAll('Exception: ', '');
        if (cleanMsg.startsWith('네트워크 오류가 발생했습니다')) {
          setError(cleanMsg);
        } else {
          setError('회원가입 요청 중 오류가 발생했습니다');
        }
      }
      return false;
    } finally {
      setLoading(false);
    }
  }

  // 관리자 회원가입 처리
  Future<bool> _registerAdmin(String email, String password, String name, 
      {String? companyName, String? companyAddress}) async {
    try {
      print("관리자 회원가입 요청을 처리 중...");
      print("이메일: $email, 이름: $name, 회사명: $companyName");

      // 필수 정보 확인
      if (companyName == null || companyName.isEmpty) {
        setError('회사명을 입력해주세요.');
        return false;
      }
      
      if (companyAddress == null || companyAddress.isEmpty) {
        setError('회사 주소를 입력해주세요.');
        return false;
      }

      // 관리자 회원가입 API 호출
      final response = await ApiService().signupAdmin(
        name: name,
        email: email,
        password: password,
        companyName: companyName,
        companyAddress: companyAddress,
      );

      print('[AuthProvider] 관리자 회원가입 응답: $response');
      
      // TokenInfo 반환 시 회원가입 성공으로 처리 (자동 로그인 안함)
      if (response['accessToken'] != null) {
        print('[AuthProvider] 관리자 회원가입 성공 - 토큰 정보 받음');
        print('[AuthProvider] 관리자 회원가입 완료 - 로그인 화면으로 이동');
        return true;
      }
      
      return true;
      
    } catch (e) {
      print('관리자 회원가입 중 오류: $e');
      if (e.toString().contains('ApiException')) {
        final errorMsg = e.toString().replaceAll('ApiException: ', '');
        setError(errorMsg.split(' (Status:')[0]);
      } else {
        final cleanMsg = e.toString()
            .replaceAll('Exception: 관리자 회원가입 실패: ', '')
            .replaceAll('Exception: ', '');
        setError('관리자 회원가입에 실패했습니다: $cleanMsg');
      }
      return false;
    }
  }

  Future<void> logout() async {
    try {
      setLoading(true);
      print('[AuthProvider] === 로그아웃 시작 ===');

      // Analytics 로그아웃 이벤트 기록
      await AnalyticsService().logLogout();
      print('[AuthProvider] Analytics 로그아웃 이벤트 기록 완료');

      // 이메일 기억하기 데이터 임시 저장
      final rememberedEmail = StorageService().getRememberedEmail();
      final rememberEmailEnabled = StorageService().getRememberEmailEnabled();
      print('[AuthProvider] 이메일 기억하기 데이터 백업 - 이메일: $rememberedEmail, 활성화: $rememberEmailEnabled');

      // 모든 토큰과 사용자 정보 제거
      await StorageService().removeAll();
      print('[AuthProvider] StorageService.removeAll() 완료');

      // SharedPreferences 전체 클리어 (추가 보안)
      await StorageService().clear();
      print('[AuthProvider] StorageService.clear() 완료');

      // 이메일 기억하기 데이터 복원
      if (rememberEmailEnabled && rememberedEmail != null) {
        await StorageService().saveRememberedEmail(rememberedEmail);
        await StorageService().saveRememberEmailEnabled(true);
        print('[AuthProvider] 이메일 기억하기 데이터 복원 완료');
      }

      // 현재 사용자 상태 완전 초기화
      _currentUser = null;
      _isInitialized = true; // 로그아웃 후에는 true로 설정하여 로그인 화면으로 이동 가능하게 함
      clearError();
      
      print('[AuthProvider] 로그아웃 완료 - 사용자 상태 초기화됨');
      notifyListeners();
    } catch (e) {
      print('[AuthProvider] 로그아웃 중 오류: $e');
      setError('로그아웃에 실패했습니다: ${e.toString()}');
    } finally {
      setLoading(false);
    }
  }

  // 직원 회원탈퇴
  Future<bool> withdrawMember() async {
    try {
      setLoading(true);
      clearError();

      print('[AuthProvider] 직원 회원탈퇴 요청 시작');

      // 직원 회원탈퇴 API 호출
      final response = await ApiService().withdrawMember();

      if (response['message'] != null) {
        print('[AuthProvider] 직원 회원탈퇴 성공: ${response['message']}');

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

  // 관리자 회원탈퇴
  Future<bool> deleteAdminAccount() async {
    try {
      setLoading(true);
      clearError();

      print('[AuthProvider] 관리자 회원탈퇴 요청 시작');

      // 관리자 회원탈퇴 API 호출
      final response = await ApiService().deleteAdminAccount();

      print('[AuthProvider] 관리자 회원탈퇴 API 응답: $response');

      // 성공 응답 확인
      if (response['success'] == true || response.containsKey('message')) {
        print('[AuthProvider] 관리자 회원탈퇴 성공');

        // 즉시 사용자 상태를 null로 설정하여 UI 업데이트
        _currentUser = null;
        _isInitialized = true;
        notifyListeners();

        // 모든 로컬 데이터 삭제
        await StorageService().removeAll();

        print('[AuthProvider] 관리자 회원탈퇴 완료 - 사용자 상태 초기화됨');
        return true;
      } else {
        final errorMsg = response['error'] ?? '관리자 회원탈퇴에 실패했습니다.';
        setError(errorMsg);
        return false;
      }
    } catch (e) {
      if (e.toString().contains('ApiException')) {
        final errorMsg = e.toString().replaceAll('ApiException: ', '');
        setError(errorMsg.split(' (Status:')[0]);
      } else {
        setError('관리자 회원탈퇴 중 오류가 발생했습니다: ${e.toString()}');
      }
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<void> checkAuthStatus() async {
    try {
      setLoading(true);
      print('[AuthProvider] === 인증 상태 확인 시작 ===');

      final token = StorageService().getToken();
      final savedUserData = StorageService().getSavedUserData();
      
      print('[AuthProvider] 토큰 존재: ${token != null}');
      print('[AuthProvider] 저장된 사용자 데이터 존재: ${savedUserData != null}');
      
      if (token == null || savedUserData == null) {
        print('[AuthProvider] 토큰 또는 사용자 데이터 없음 - 로그인 필요');
        _currentUser = null;
        _isInitialized = true;
        notifyListeners();
        return;
      }

      print('[AuthProvider] 토큰 발견 - 유효성 검증 시작');

      // 1단계: 저장된 사용자 정보 확인 (이미 위에서 확인했으므로 제거)

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
        print('[AuthProvider] 저장된 데이터 키들: ${savedUserData.keys.toList()}');
        
        // 저장된 데이터의 구조를 판단해서 올바른 방식으로 복원
        if (savedUserData['userId'] != null) {
          // 관리자 응답 구조
          print('[AuthProvider] 관리자 응답 구조 감지');
          final adminResponse = AdminSigninResponse.fromJson(savedUserData);
          _currentUser = adminResponse.toUser();
        } else if (savedUserData['memberId'] != null) {
          // 일반 직원 응답 구조
          print('[AuthProvider] 직원 응답 구조 감지');
          final memberResponse = MemberSigninResponse.fromJson(savedUserData);
          _currentUser = memberResponse.toUser();
        } else {
          // 기존 User 구조 (하위 호환성)
          print('[AuthProvider] 기존 User 구조 감지');
          _currentUser = User.fromJson(savedUserData);
        }
        
        print('[AuthProvider] 사용자 정보 복원 성공: ${_currentUser!.name}');
        print('[AuthProvider] 복원된 사용자 역할: ${_currentUser!.role}');
        print('[AuthProvider] 복원된 사용자 활성 상태: ${_currentUser!.isActive}');
        print('[AuthProvider] 복원된 사용자 상태: ${_currentUser!.status}');
        print('[AuthProvider] 복원된 사용자 회사: ${_currentUser!.company?.name}');

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
      print('[AuthProvider] === 내부 로그아웃 처리 시작 ===');
      
      // 이메일 기억하기 데이터 임시 저장
      final rememberedEmail = StorageService().getRememberedEmail();
      final rememberEmailEnabled = StorageService().getRememberEmailEnabled();
      print('[AuthProvider] 내부 로그아웃 - 이메일 기억하기 데이터 백업 - 이메일: $rememberedEmail, 활성화: $rememberEmailEnabled');
      
      // 모든 저장된 데이터 제거
      await StorageService().removeAll();
      await StorageService().clear(); // 추가 보안
      
      // 이메일 기억하기 데이터 복원
      if (rememberEmailEnabled && rememberedEmail != null) {
        await StorageService().saveRememberedEmail(rememberedEmail);
        await StorageService().saveRememberEmailEnabled(true);
        print('[AuthProvider] 내부 로그아웃 - 이메일 기억하기 데이터 복원 완료');
      }
      
      _currentUser = null;
      _isInitialized = true;
      clearError();
      
      print('[AuthProvider] 내부 로그아웃 처리 완료');
      notifyListeners();
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

  // 강제 로그아웃 - 디버깅 및 응급상황용
  Future<void> forceLogout() async {
    try {
      print('[AuthProvider] === 강제 로그아웃 시작 ===');
      
      // SharedPreferences 완전 초기화
      await StorageService().clear();
      
      // 모든 상태 초기화
      _currentUser = null;
      _isInitialized = true;
      _isLoading = false;
      _errorMessage = '';
      
      print('[AuthProvider] 강제 로그아웃 완료');
      notifyListeners();
    } catch (e) {
      print('[AuthProvider] 강제 로그아웃 중 오류: $e');
    }
  }

  // 비밀번호 찾기 (직원용)
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

  // 관리자 비밀번호 찾기
  Future<void> findAdminPassword(String email, BuildContext context) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().findAdminPassword(email: email);
      
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
            content: Text(response['error'] ?? '관리자 비밀번호 찾기에 실패했습니다.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      String errorMessage = '관리자 비밀번호 찾기 중 오류가 발생했습니다';
      
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
