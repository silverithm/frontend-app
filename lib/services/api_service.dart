import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';
import '../screens/login_screen.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String _baseUrl = Constants.baseUrl;
  BuildContext? _globalContext; // 글로벌 context 저장

  // 글로벌 context 설정 (main.dart에서 호출)
  void setGlobalContext(BuildContext context) {
    _globalContext = context;
  }

  // 공통 헤더 생성
  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = StorageService().getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // 토큰 refresh 요청
  Future<RefreshTokenResult> _refreshToken() async {
    try {
      final refreshToken = StorageService().getRefreshToken();
      if (refreshToken == null) {
        print('[API] Refresh token이 없음');
        return RefreshTokenResult.noRefreshToken();
      }

      final response = await http.post(
        Uri.parse('$_baseUrl${Constants.refreshTokenEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'refreshToken': refreshToken}),
      );

      print('[API] Refresh token 응답 상태: ${response.statusCode}');
      print('[API] Refresh token 응답: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;

        // 새로운 access token 저장
        if (responseData['accessToken'] != null) {
          await StorageService().saveToken(responseData['accessToken']);

          // refresh token도 새로 받았다면 업데이트
          if (responseData['refreshToken'] != null) {
            await StorageService().saveRefreshToken(
              responseData['refreshToken'],
            );
          }

          print('[API] 새로운 토큰 저장 완료');
          return RefreshTokenResult.success();
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Refresh token 만료됨
        print('[API] Refresh token 만료됨 - 모든 토큰 제거');
        await StorageService().removeAllTokens();
        return RefreshTokenResult.expired();
      } else {
        // 기타 에러 (네트워크 오류 등)
        print('[API] Refresh token 요청 실패: ${response.statusCode}');
        return RefreshTokenResult.failed();
      }

      return RefreshTokenResult.failed();
    } catch (e) {
      print('[API] Refresh token 에러: $e');
      return RefreshTokenResult.failed();
    }
  }

  // 로그인 화면으로 이동
  void _navigateToLogin() {
    try {
      final context = _globalContext;
      if (context != null && context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        print('[API] 로그인 화면으로 이동 완료');
      } else {
        print('[API] Context가 없거나 유효하지 않아 화면 이동 불가');
      }
    } catch (e) {
      print('[API] 로그인 화면 이동 중 오류: $e');
    }
  }

  // 글로벌 로그아웃 처리 (토큰 제거 + 화면 이동)
  Future<void> _performGlobalLogout() async {
    try {
      print('[API] === 글로벌 로그아웃 시작 ===');
      print('[API] 호출 스택: ${StackTrace.current}');
      
      // 모든 토큰 제거
      await StorageService().removeAll();
      await StorageService().clear(); // 추가 보안
      print('[API] 글로벌 로그아웃 - 모든 데이터 제거 완료');

      // 로그인 화면으로 이동
      _navigateToLogin();
    } catch (e) {
      print('[API] 글로벌 로그아웃 처리 중 오류: $e');
      // 에러가 발생해도 화면은 이동
      _navigateToLogin();
    }
  }

  // 토큰 만료 처리를 포함한 공통 요청 처리
  Future<Map<String, dynamic>> _makeAuthenticatedRequest(
    Future<http.Response> Function() requestFunction,
  ) async {
    try {
      // 첫 번째 요청 시도
      final response = await requestFunction();

      // 401 Unauthorized 확인
      if (response.statusCode == 401 || response.statusCode == 403) {
        print('[API] 토큰 만료 감지 - refresh 시도');

        // refresh token으로 새 토큰 획득 시도
        final refreshResult = await _refreshToken();

        if (refreshResult.isSuccess) {
          print('[API] 토큰 refresh 성공 - 요청 재시도');
          // 새 토큰으로 재요청
          final retryResponse = await requestFunction();
          return _handleResponse(retryResponse);
        } else {
          print('[API] 토큰 refresh 실패 - 로그아웃 처리');

          // refresh token이 만료되었거나 없는 경우 강제 로그아웃
          print('[API] Refresh token 만료 또는 없음 - 강제 로그아웃');
          // AuthProvider를 통한 일관된 로그아웃 처리를 위해 콜백 호출
          await _performGlobalLogout();

          throw ApiException('로그인이 필요합니다', 401);
        }
      }

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw Exception('API 요청 실패: $e');
    }
  }

  // 회원가입 요청
  Future<Map<String, dynamic>> submitJoinRequest({
    required String username,
    required String email,
    required String name,
    required String role,
    required String password,
    required String companyId,
  }) async {
    try {
      final requestBody = {
        'username': username,
        'email': email,
        'name': name,
        'role': role,
        'password': password,
        'companyId': int.parse(companyId),
      };

      print('회원가입 요청 URL: $_baseUrl${Constants.joinRequestEndpoint}');
      print('회원가입 요청 데이터: $requestBody');

      final response = await http.post(
        Uri.parse('$_baseUrl${Constants.joinRequestEndpoint}'),
        headers: await _getHeaders(includeAuth: false),
        body: json.encode(requestBody),
      );

      print('회원가입 응답 상태 코드: ${response.statusCode}');
      print('회원가입 응답 본문: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      print('회원가입 요청 중 예외 발생: $e');
      // ApiException은 그대로 전파하여 서버의 실제 에러 메시지 보존
      if (e is ApiException) {
        rethrow;
      }
      // 네트워크 오류 등만 generic 메시지로 wrapping
      throw Exception('네트워크 오류가 발생했습니다: $e');
    }
  }

  // 로그인 (새로운 signin 엔드포인트)
  Future<Map<String, dynamic>> signin({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl${Constants.signinEndpoint}'),
        headers: await _getHeaders(includeAuth: false),
        body: json.encode({'username': username, 'password': password}),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('로그인 실패: $e');
    }
  }

  // 관리자 로그인
  Future<Map<String, dynamic>> adminSignin({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl${Constants.adminSigninEndpoint}'),
        headers: await _getHeaders(includeAuth: false),
        body: json.encode({'email': username, 'password': password}),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('관리자 로그인 실패: $e');
    }
  }

  // 토큰 검증 (서버에 토큰 유효성 확인)
  Future<Map<String, dynamic>?> validateToken() async {
    try {
      final token = StorageService().getToken();
      if (token == null) {
        print('[API] 토큰이 없어서 검증 불가');
        return null;
      }

      print('[API] 토큰 검증 시작');

      // POST 방식으로 Request Body에 토큰 포함해서 전송
      final response = await http.post(
        Uri.parse('$_baseUrl${Constants.validateTokenEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'token': token}),
      );

      print('[API] 토큰 검증 응답 상태: ${response.statusCode}');
      print('[API] 토큰 검증 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        // 성공 응답 파싱
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        print('[API] 토큰 검증 성공 - 사용자: ${responseData['username']}');
        return responseData;
      } else if (response.statusCode == 400) {
        // 토큰 무효 (서버에서 400 Bad Request 반환)
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        print('[API] 토큰 무효: ${responseData['message']}');
        return null;
      } else {
        print('[API] 토큰 검증 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('[API] 토큰 검증 중 오류: $e');
      return null;
    }
  }

  // 토큰 갱신 시도 (public으로 변경)
  Future<RefreshTokenResult> refreshToken() async {
    return await _refreshToken();
  }

  // 회원탈퇴
  Future<Map<String, dynamic>> withdrawMember() async {
    return await _makeAuthenticatedRequest(() async {
      final response = await http.post(
        Uri.parse('$_baseUrl${Constants.withdrawalEndpoint}'),
        headers: await _getHeaders(includeAuth: true),
      );

      return response;
    });
  }

  // 휴가 캘린더 조회
  Future<Map<String, dynamic>> getVacationCalendar({
    required String startDate,
    required String endDate,
    required String companyId,
    String roleFilter = 'all',
    String? nameFilter,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final queryParams = {
        'startDate': startDate,
        'endDate': endDate,
        'roleFilter': roleFilter,
        'companyId': companyId,
      };

      if (nameFilter != null && nameFilter.isNotEmpty) {
        queryParams['nameFilter'] = nameFilter;
      }

      final uri = Uri.parse(
        '$_baseUrl${Constants.vacationCalendarEndpoint}',
      ).replace(queryParameters: queryParams);

      print('[API] 휴가 캘린더 조회 요청: $uri');
      print('[API] 요청 파라미터: $queryParams');

      final response = await http.get(uri, headers: await _getHeaders());

      print('[API] 휴가 캘린더 응답 상태: ${response.statusCode}');
      print('[API] 휴가 캘린더 응답 본문: ${response.body}');

      return response;
    });
  }

  // 특정 날짜 휴가 조회
  Future<Map<String, dynamic>> getVacationForDate({
    required String date,
    required String companyId,
    String role = 'CAREGIVER',
    String? nameFilter,
  }) async {
    try {
      final queryParams = {'role': role, 'companyId': companyId};

      if (nameFilter != null && nameFilter.isNotEmpty) {
        queryParams['nameFilter'] = nameFilter;
      }

      final uri = Uri.parse(
        '$_baseUrl${Constants.vacationDateEndpoint}/$date',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse(response);
    } catch (e) {
      throw Exception('날짜별 휴가 조회 실패: $e');
    }
  }

  // 휴가 신청 생성
  Future<Map<String, dynamic>> createVacationRequest({
    required String userName,
    required String date,
    required String type,
    required String reason,
    required String role,
    required String password,
    required String companyId,
    String? userId,
    String? duration,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final queryParams = {'companyId': companyId};

      final uri = Uri.parse(
        '$_baseUrl${Constants.vacationSubmitEndpoint}',
      ).replace(queryParameters: queryParams);

      final requestBody = {
        'userName': userName,
        'date': date,
        'type': type,
        'reason': reason,
        'role': role,
        'password': password,
        'userId': userId,
      };

      if (duration != null) {
        requestBody['duration'] = duration;
      }

      return await http.post(
        uri,
        headers: await _getHeaders(),
        body: json.encode(requestBody),
      );
    });
  }

  // 기존 일반적인 메서드들
  Future<Map<String, dynamic>> get(String endpoint, {bool includeAuth = true}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: await _getHeaders(includeAuth: includeAuth),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('GET 요청 실패: $e');
    }
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: await _getHeaders(),
        body: json.encode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('POST 요청 실패: $e');
    }
  }

  // 휴가 제한 조회
  Future<Map<String, dynamic>> getVacationLimits({
    required String start,
    required String end,
    required String companyId,
    String? role,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final queryParams = {'start': start, 'end': end, 'companyId': companyId};

      if (role != null && role != 'all') {
        queryParams['role'] = role;
      }

      final uri = Uri.parse(
        '$_baseUrl${Constants.vacationLimitsEndpoint}',
      ).replace(queryParameters: queryParams);

      print('[API] 휴가 제한 조회 요청: $uri');
      print('[API] 요청 파라미터: $queryParams');

      final response = await http.get(uri, headers: await _getHeaders());

      print('[API] 휴가 제한 응답 상태: ${response.statusCode}');
      print('[API] 휴가 제한 응답 본문: ${response.body}');

      return response;
    });
  }

  // 회사 목록 조회
  Future<Map<String, dynamic>> getCompanies() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl${Constants.companiesEndpoint}'),
        headers: await _getHeaders(includeAuth: false),
      );

      print('회사 목록 조회 URL: $_baseUrl${Constants.companiesEndpoint}');
      print('회사 목록 조회 응답: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      throw Exception('회사 목록 조회 실패: $e');
    }
  }

  // FCM 토큰 업데이트
  Future<Map<String, dynamic>> updateAdminFcmToken({
    required String userId,
    required String fcmToken,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl${Constants.adminFcmTokenEndpoint}/$userId/fcm-token'),
        headers: await _getHeaders(),
        body: json.encode({'fcmToken': fcmToken}),
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('FCM 토큰 업데이트 실패: $e');
    }
  }

  // FCM 토큰 업데이트
  Future<Map<String, dynamic>> updateFcmToken({
    required String memberId,
    required String fcmToken,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl${Constants.fcmTokenEndpoint}/$memberId/fcm-token'),
        headers: await _getHeaders(),
        body: json.encode({'fcmToken': fcmToken}),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('FCM 토큰 업데이트 실패: $e');
    }
  }

  // 내 휴무 신청 전체 조회
  Future<Map<String, dynamic>> getMyVacationRequests({
    required String companyId,
    required String userName,
    required String userId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final queryParams = {
        'companyId': companyId,
        'userName': userName,
        'userId': userId,
      };

      final uri = Uri.parse(
        '$_baseUrl${Constants.myVacationRequestsEndpoint}',
      ).replace(queryParameters: queryParams);

      print('내 휴무 신청 조회 URL: $uri');

      return await http.get(uri, headers: await _getHeaders());
    });
  }

  // 내 휴무 신청 삭제
  Future<Map<String, dynamic>> deleteMyVacationRequest({
    required String vacationId,
    required String userName,
    required String userId,
    required String password,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final queryParams = {
        'userName': userName,
        'userId': userId,
        'password': password,
      };

      final uri = Uri.parse(
        '$_baseUrl${Constants.myVacationRequestsEndpoint}/$vacationId',
      ).replace(queryParameters: queryParams);

      print('내 휴무 신청 삭제 URL: $uri');

      return await http.delete(uri, headers: await _getHeaders());
    });
  }

  // 사용자 알림 조회
  Future<Map<String, dynamic>> getNotifications({
    required String userId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl${Constants.notificationsEndpoint}/$userId',
      );

      print('[API] 알림 조회 요청: $uri');

      return await http.get(uri, headers: await _getHeaders());
    });
  }

  // 비밀번호 찾기 (임시 비밀번호 발송) - 직원용 - 인증 불필요
  Future<Map<String, dynamic>> findPassword({required String email}) async {
    try {
      final uri = Uri.parse('$_baseUrl${Constants.findPasswordEndpoint}').replace(
        queryParameters: {'email': email},
      );

      final response = await http.post(
        uri,
        headers: await _getHeaders(includeAuth: false),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('비밀번호 찾기 실패: $e');
    }
  }

  // 관리자 비밀번호 찾기 (임시 비밀번호 발송) - 인증 불필요
  Future<Map<String, dynamic>> findAdminPassword({required String email}) async {
    try {
      final uri = Uri.parse('$_baseUrl/v1/find/password').replace(
        queryParameters: {'email': email},
      );

      print('[API] 관리자 비밀번호 찾기: $uri');

      final response = await http.post(
        uri,
        headers: await _getHeaders(includeAuth: false),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('관리자 비밀번호 찾기 실패: $e');
    }
  }

  // 비밀번호 변경
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final response = await http.post(
        Uri.parse('$_baseUrl${Constants.changePasswordEndpoint}'),
        headers: await _getHeaders(),
        body: json.encode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      return response;
    });
  }

  // 회원 역할 변경
  Future<Map<String, dynamic>> updateMemberRole({required String role}) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl${Constants.updateRoleEndpoint}').replace(
        queryParameters: {'role': role},
      );

      print('[API] 역할 변경 요청 URI: $uri');
      final response = await http.put(
        uri,
        headers: await _getHeaders(),
      );
      print('[API] 역할 변경 응답 상태: ${response.statusCode}');
      print('[API] 역할 변경 응답 본문: ${response.body}');

      return response;
    });
  }

  // ===================== 관리자 기능 API =====================

  // 승인 대기 중인 가입 요청 조회
  Future<Map<String, dynamic>> getPendingJoinRequests({
    required String companyId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/members/join-requests/pending',
      ).replace(queryParameters: {'companyId': companyId});

      print('[API] 승인 대기 요청 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 회사 전체 회원 조회
  Future<Map<String, dynamic>> getCompanyMembers({
    required String companyId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/members',
      ).replace(queryParameters: {'companyId': companyId});

      print('[API] 회사 회원 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 가입 요청 승인
  Future<Map<String, dynamic>> approveJoinRequest({
    required String userId,
    required String adminId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/members/join-requests/$userId/approve',
      ).replace(queryParameters: {'adminId': adminId});

      print('[API] 가입 요청 승인: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.put(uri, headers: headers);
    });
  }

  // 가입 요청 거부
  Future<Map<String, dynamic>> rejectJoinRequest({
    required String userId,
    required String adminId,
    required String rejectReason,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/members/join-requests/$userId/reject',
      ).replace(queryParameters: {'adminId': adminId});

      print('[API] 가입 요청 거부: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.put(
        uri,
        headers: headers,
        body: json.encode({'rejectReason': rejectReason}),
      );
    });
  }

  // 회원 상태 변경 (활성/비활성)
  Future<Map<String, dynamic>> updateMemberStatus({
    required String userId,
    required String status, // 'active' or 'inactive'
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/members/$userId');

      print('[API] 회원 상태 변경: $uri, status: $status');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.put(
        uri,
        headers: headers,
        body: json.encode({'status': status}),
      );
    });
  }

  // 회원 삭제
  Future<Map<String, dynamic>> deleteMember({
    required String userId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/members/$userId');

      print('[API] 회원 삭제: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.delete(uri, headers: headers);
    });
  }

  // 휴가 요청 목록 조회 (관리자용)
  Future<Map<String, dynamic>> getVacationRequests({
    required String companyId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/vacation/requests',
      ).replace(queryParameters: {'companyId': companyId});

      print('[API] 휴가 요청 목록 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 휴가 요청 승인
  Future<Map<String, dynamic>> approveVacationRequest({
    required String vacationId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/vacation/approve/$vacationId');

      print('[API] 휴가 요청 승인: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.put(uri, headers: headers);
    });
  }

  // 휴가 요청 거부
  Future<Map<String, dynamic>> rejectVacationRequest({
    required String vacationId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/vacation/reject/$vacationId');

      print('[API] 휴가 요청 거부: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.put(uri, headers: headers);
    });
  }


  // 휴가 한도 저장
  Future<Map<String, dynamic>> saveVacationLimits({
    required String companyId,
    required List<Map<String, dynamic>> limits,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/vacation/limits',
      ).replace(queryParameters: {'companyId': companyId});

      print('[API] 휴가 한도 저장: $uri');
      print('[API] 한도 데이터: $limits');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.post(
        uri,
        headers: headers,
        body: json.encode({'limits': limits}),
      );
    });
  }

  // 회사 프로필 조회
  Future<Map<String, dynamic>> getCompanyProfile() async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/company/profile');

      print('[API] 회사 프로필 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 회사 프로필 업데이트
  Future<Map<String, dynamic>> updateCompanyProfile({
    String? name,
    String? address,
    String? contactEmail,
    String? contactPhone,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/company/profile');

      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (address != null) body['address'] = address;
      if (contactEmail != null) body['contactEmail'] = contactEmail;
      if (contactPhone != null) body['contactPhone'] = contactPhone;

      print('[API] 회사 프로필 업데이트: $uri');
      print('[API] 업데이트 데이터: $body');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.put(
        uri,
        headers: headers,
        body: json.encode(body),
      );
    });
  }

  // ===================== 사용자 정보 API =====================

  // 사용자 정보 조회 (구독 정보 포함)
  Future<Map<String, dynamic>> getUserInfo() async {
    return await _makeAuthenticatedRequest(() async {
      // 1차: 일반 사용자 정보 조회 시도
      final uri = Uri.parse('$_baseUrl/v1/users/info');

      print('[API] 사용자 정보 조회 시작: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';
      
      print('[API] 요청 헤더: $headers');

      var response = await http.get(uri, headers: headers);
      
      print('[API] 사용자 정보 조회 응답 상태코드: ${response.statusCode}');
      print('[API] 사용자 정보 조회 응답 본문: ${response.body}');
      
      // 404 에러인 경우 관리자용 엔드포인트 시도
      if (response.statusCode == 404) {
        print('[API] 일반 사용자 정보 조회 실패 (404) - 관리자용 엔드포인트 시도');
        
        // 관리자용 엔드포인트들 시도
        final adminEndpoints = [
          '$_baseUrl/v1/admin/users/info',
          '$_baseUrl/v1/users/admin/info',
          '$_baseUrl/v1/admin/info',
        ];
        
        for (final endpoint in adminEndpoints) {
          try {
            final adminUri = Uri.parse(endpoint);
            print('[API] 관리자 정보 조회 시도: $adminUri');
            
            final adminResponse = await http.get(adminUri, headers: headers);
            print('[API] 관리자 정보 조회 응답 상태코드: ${adminResponse.statusCode}');
            print('[API] 관리자 정보 조회 응답 본문: ${adminResponse.body}');
            
            if (adminResponse.statusCode == 200) {
              print('[API] 관리자 정보 조회 성공: $endpoint');
              response = adminResponse;
              break;
            }
          } catch (e) {
            print('[API] 관리자 엔드포인트 $endpoint 실패: $e');
            continue;
          }
        }
        
        // 모든 엔드포인트 실패 시 저장된 정보로 fallback
        if (response.statusCode == 404) {
          print('[API] 모든 사용자 정보 조회 실패 - 저장된 정보로 fallback');
          final userData = StorageService().getSavedUserData();
          
          if (userData != null) {
            // 저장된 데이터를 API 응답 형태로 변환
            final mockResponse = {
              'userEmail': userData['userEmail'] ?? userData['email'] ?? '',
              'userName': userData['userName'] ?? userData['name'] ?? '',
              'customerKey': userData['customerKey'] ?? 'customer_${DateTime.now().millisecondsSinceEpoch}',
            };
            
            print('[API] 저장된 정보로 응답 생성: $mockResponse');
            
            // 성공 응답으로 가장하기 위해 Response 객체 생성
            return http.Response(
              json.encode(mockResponse),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else {
            // 저장된 정보도 없으면 에러
            throw Exception('사용자 정보를 찾을 수 없습니다. 다시 로그인해주세요.');
          }
        }
      }
      
      return response;
    });
  }

  // ===================== 구독 관련 API =====================

  // 내 구독 정보 조회
  Future<Map<String, dynamic>> getMySubscription() async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/subscriptions');

      print('[API] 구독 정보 조회 시작: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';
      
      print('[API] 요청 헤더: $headers');

      final response = await http.get(uri, headers: headers);
      
      print('[API] 구독 정보 조회 응답 상태코드: ${response.statusCode}');
      print('[API] 구독 정보 조회 응답 본문: ${response.body}');
      
      return response;
    });
  }

  // 무료 구독 생성
  Future<Map<String, dynamic>> createFreeSubscription() async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/subscriptions/free');

      // getUserInfo API로 사용자 정보 가져오기
      final userInfoResponse = await getUserInfo();
      print('[API] getUserInfo 전체 응답: $userInfoResponse');
      final userEmail = userInfoResponse['userEmail']?.toString() ?? '';
      final customerName = userInfoResponse['userName']?.toString() ?? '';
      final customerKey = userInfoResponse['customerKey']?.toString() ?? 
                         (userEmail.isNotEmpty ? 'customer_${userEmail.hashCode.abs()}' : '');
      print('[API] getUserInfo API로 이메일 조회 성공: $userEmail');
      
      print('[API] 무료 구독 생성: $uri');
      print('[API] 최종 사용자 이메일: $userEmail');
      print('[API] 최종 사용자 이름: $customerName');
      print('[API] 최종 customerKey: $customerKey');

      final body = {
        'planName': 'FREE', // SubscriptionType
        'billingType': 'FREE', // SubscriptionBillingType  
        'amount': 0, // 무료 구독은 금액 0
        'customerKey': customerKey, // 생성된 customerKey
        'authKey': '', // 무료 구독은 authKey 불필요
        'orderName': '무료 체험 구독', // 주문명
        'customerEmail': userEmail, // 올바른 필드명
        'customerName': customerName, // 사용자 이름
        'taxFreeAmount': 0, // 비과세 금액
      };
      
      final jsonBody = json.encode(body);
      print('[API] JSON 인코딩된 본문: $jsonBody');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';
      
      print('[API] 요청 헤더: $headers');

      return await http.post(
        uri, 
        headers: headers,
        body: jsonBody,
      );
    });
  }

  // 유료 구독 생성
  Future<Map<String, dynamic>> createSubscription({
    required String planType,
    required String paymentType,
    required String authKey,
    required int amount,
    required String planName,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/subscriptions');

      // 사용자 이메일 가져오기 (getUserInfo API 사용)
      final userInfoResponse = await getUserInfo();
      print('[API] getUserInfo 전체 응답: $userInfoResponse');
      final userEmail = userInfoResponse['userEmail']?.toString() ?? '';
      print('[API] getUserInfo API로 이메일 조회 성공: $userEmail');
      
      print('[API] 최종 사용자 이메일: $userEmail');

      final body = {
        'planName': planType, // SubscriptionType
        'billingType': paymentType, // SubscriptionBillingType  
        'amount': amount, // 실제 결제 금액
        'customerKey': userInfoResponse['customerKey']?.toString() ?? '', // userInfo에서 받아온 customerKey
        'authKey': authKey,
        'orderName': '$planName 구독', // 주문명
        'customerEmail': userEmail, // 올바른 필드명
        'customerName': userInfoResponse['userName']?.toString() ?? '', // 사용자 이름
        'taxFreeAmount': 0, // 비과세 금액
      };

      print('[API] 유료 구독 생성: $uri');
      print('[API] 구독 데이터: $body');
      
      final jsonBody = json.encode(body);
      print('[API] JSON 인코딩된 본문: $jsonBody');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';
      
      print('[API] 요청 헤더: $headers');

      return await http.post(
        uri,
        headers: headers,
        body: jsonBody,
      );
    });
  }

  // 구독 취소
  Future<Map<String, dynamic>> cancelSubscription() async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/subscriptions/cancel');

      print('[API] 구독 취소: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.put(uri, headers: headers);
    });
  }

  // 구독 활성화
  Future<Map<String, dynamic>> activateSubscription() async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/subscriptions/activate');

      print('[API] 구독 활성화: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.put(uri, headers: headers);
    });
  }

  // 구독 결제 실패 정보 조회
  Future<Map<String, dynamic>> getPaymentFailures({
    int page = 0,
    int size = 10,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final queryParams = {
        'page': page.toString(),
        'size': size.toString(),
      };

      final uri = Uri.parse('$_baseUrl/v1/subscriptions/payment-failures')
          .replace(queryParameters: queryParams);

      print('[API] 결제 실패 정보 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 관리자 회원가입
  Future<Map<String, dynamic>> signupAdmin({
    required String name,
    required String email,
    required String password,
    required String companyName,
    required String companyAddress,
  }) async {
    try {
      final headers = await _getHeaders(includeAuth: false);
      
      final body = {
        'name': name,
        'email': email,
        'password': password,
        'role': 'ROLE_ADMIN',
        'companyName': companyName,
        'companyAddress': companyAddress,
      };

      print('[API] 관리자 회원가입 요청: https://silverithm.site/api/v1/signup');
      print('[API] 요청 본문: $body');

      final response = await http.post(
        Uri.parse('https://silverithm.site/api/v1/signup'),
        headers: headers,
        body: json.encode(body),
      );

      print('[API] 관리자 회원가입 응답 상태: ${response.statusCode}');
      print('[API] 관리자 회원가입 응답: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw ApiException(
          errorData['message'] ?? errorData['error'] ?? '관리자 회원가입에 실패했습니다',
          response.statusCode,
        );
      }
    } catch (e) {
      print('[API] 관리자 회원가입 오류: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('관리자 회원가입 중 오류가 발생했습니다: ${e.toString()}', 500);
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    print('API 응답 상태 코드: ${response.statusCode}');
    print('API 응답 본문 길이: ${response.body.length}');
    print('API 응답 본문: "${response.body}"');

    // 빈 응답 처리
    if (response.body.isEmpty) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('빈 응답이지만 성공 상태 코드 - 빈 맵 반환');
        return {};
      } else {
        print('빈 응답이고 에러 상태 코드');
        _throwMeaningfulError(response.statusCode, '서버에서 빈 응답을 반환했습니다');
      }
    }

    try {
      final responseData = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('API 요청 성공 - 응답 데이터 반환');
        return responseData;
      } else {
        print('API 요청 실패 - 에러 처리');
        // frontend-admin과 동일한 에러 처리 방식
        final errorMessage = responseData['error'] ?? 
                           responseData['message'] ?? 
                           _getDefaultErrorMessage(response.statusCode);
        throw ApiException(errorMessage, response.statusCode);
      }
    } catch (e) {
      print('JSON 파싱 에러: $e');
      if (e is ApiException) {
        rethrow;
      }
      if (e is FormatException) {
        // JSON 파싱 실패 시 응답 내용에 따라 적절한 에러 메시지 생성
        if (response.body.contains('error')) {
          try {
            // 단순한 에러 텍스트인 경우
            final simpleError = response.body.replaceAll('"', '').replaceAll('{', '').replaceAll('}', '');
            if (simpleError.contains('error:')) {
              final errorMsg = simpleError.split('error:')[1].trim();
              throw ApiException(errorMsg, response.statusCode);
            }
          } catch (_) {
            // 파싱 실패 시 기본 에러
          }
        }
        _throwMeaningfulError(response.statusCode, '서버 응답을 파싱할 수 없습니다');
      } else {
        _throwMeaningfulError(response.statusCode, 'API 요청 처리 중 오류가 발생했습니다');
      }
    }
    
    // 도달하지 않아야 하는 코드, 안전을 위해 예외 throw
    throw ApiException('예상치 못한 오류가 발생했습니다', 500);
  }
  
  void _throwMeaningfulError(int statusCode, String fallbackMessage) {


    final errorMessage = _getDefaultErrorMessage(statusCode, fallbackMessage);
    throw ApiException(errorMessage, statusCode);
  }
  
  String _getDefaultErrorMessage(int statusCode, [String? fallbackMessage]) {
    switch (statusCode) {
      case 400:
        return '잘못된 요청입니다. 입력 정보를 다시 확인해 주세요';
      case 401:
        return '인증이 필요합니다. 다시 로그인해 주세요';
      case 403:
        return '접근 권한이 없습니다';
      case 404:
        return '요청한 리소스를 찾을 수 없습니다';
      case 500:
        return '서버 내부 오류가 발생했습니다. 잠시 후 다시 시도해 주세요';
      case 502:
        return '서버가 일시적으로 사용할 수 없습니다';
      case 503:
        return '서비스를 일시적으로 사용할 수 없습니다';
      default:
        return fallbackMessage ?? 'API 요청 실패 (${statusCode})';
    }
  }
}

// API 예외 클래스
class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

// Refresh Token 결과 클래스
class RefreshTokenResult {
  final bool isSuccess;
  final bool isExpired;
  final bool hasRefreshToken;

  RefreshTokenResult._({
    required this.isSuccess,
    required this.isExpired,
    required this.hasRefreshToken,
  });

  // 성공
  factory RefreshTokenResult.success() {
    return RefreshTokenResult._(
      isSuccess: true,
      isExpired: false,
      hasRefreshToken: true,
    );
  }

  // Refresh token 만료
  factory RefreshTokenResult.expired() {
    return RefreshTokenResult._(
      isSuccess: false,
      isExpired: true,
      hasRefreshToken: true,
    );
  }

  // Refresh token 없음
  factory RefreshTokenResult.noRefreshToken() {
    return RefreshTokenResult._(
      isSuccess: false,
      isExpired: false,
      hasRefreshToken: false,
    );
  }

  // 기타 실패 (네트워크 오류 등)
  factory RefreshTokenResult.failed() {
    return RefreshTokenResult._(
      isSuccess: false,
      isExpired: false,
      hasRefreshToken: true,
    );
  }

  // 로그아웃이 필요한 경우 (토큰이 없거나 만료됨)
  bool get shouldLogout => !hasRefreshToken || isExpired;
}
