import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart' as dio;
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
    String? companyId,
    String? companyCode,
    String? position,
    String? positionId,
  }) async {
    try {
      final normalizedCompanyCode = companyCode
          ?.trim()
          .toUpperCase()
          .replaceAll(RegExp(r'[^A-Z0-9]'), '');

      final requestBody = {
        'username': username,
        'email': email,
        'name': name,
        'role': role,
        'password': password,
        if (position != null && position.trim().isNotEmpty)
          'position': position.trim(),
        if (positionId != null && positionId.isNotEmpty)
          'positionId': int.parse(positionId),
        if (companyId != null && companyId.isNotEmpty)
          'companyId': int.parse(companyId),
        if (normalizedCompanyCode != null && normalizedCompanyCode.isNotEmpty)
          'companyCode': normalizedCompanyCode,
      };

      if (!requestBody.containsKey('companyId') &&
          !requestBody.containsKey('companyCode')) {
        throw Exception('회사 코드 또는 회사 선택이 필요합니다.');
      }

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

  Future<Map<String, dynamic>> getPositions({
    String? companyId,
    String? companyCode,
  }) async {
    try {
      final queryParameters = <String, String>{};

      if (companyId != null && companyId.isNotEmpty) {
        queryParameters['companyId'] = companyId;
      }

      final normalizedCompanyCode = companyCode
          ?.trim()
          .toUpperCase()
          .replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (normalizedCompanyCode != null && normalizedCompanyCode.isNotEmpty) {
        queryParameters['companyCode'] = normalizedCompanyCode;
      }

      if (queryParameters.isEmpty) {
        throw Exception('companyId 또는 companyCode가 필요합니다.');
      }

      final uri = Uri.parse(
        '$_baseUrl${Constants.positionsEndpoint}',
      ).replace(queryParameters: queryParameters);

      final response = await http.get(
        uri,
        headers: await _getHeaders(includeAuth: false),
      );

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw Exception('역할 목록을 불러오지 못했습니다: $e');
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

  // 휴무 캘린더 조회
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

      print('[API] 휴무 캘린더 조회 요청: $uri');
      print('[API] 요청 파라미터: $queryParams');

      final response = await http.get(uri, headers: await _getHeaders());

      print('[API] 휴무 캘린더 응답 상태: ${response.statusCode}');
      print('[API] 휴무 캘린더 응답 본문: ${response.body}');

      return response;
    });
  }

  // 특정 날짜 휴무 조회
  Future<Map<String, dynamic>> getVacationForDate({
    required String date,
    required String companyId,
    String role = 'all',
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
      throw Exception('날짜별 휴무 조회 실패: $e');
    }
  }

  // 휴무 신청 생성
  /// 특정 직원이 어느 노선의 무슨 운전자인지 조회한다.
  /// 같은 노선의 주·부운전자가 같은 날 함께 쉬면 그날 차량을 몰 사람이 없으므로
  /// 휴무 신청 전에 이 정보로 충돌을 판정한다. 배차 설정은 회사 공용(서버 저장)이다.
  Future<List<Map<String, dynamic>>> getDriverRoles({
    required String memberName,
    required String companyId,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/dispatch-settings/driver-roles').replace(
        queryParameters: {'companyId': companyId, 'memberName': memberName},
      );

      final response = await http.get(uri, headers: await _getHeaders());
      if (response.statusCode != 200) return [];

      final data = json.decode(utf8.decode(response.bodyBytes));
      final roles = data is Map ? data['roles'] : null;
      if (roles is! List) return [];
      return roles
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      // 배차는 보조 규칙이라 조회 실패로 신청을 막지는 않는다
      print('[API] 운전자 역할 조회 실패: $e');
      return [];
    }
  }

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
    String?
    vacationType, // 연차 미사용 세부 유형 (personal/sick/emergency/family/other/substitute)
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
      if (vacationType != null && vacationType.isNotEmpty) {
        requestBody['vacationType'] = vacationType;
      }

      return await http.post(
        uri,
        headers: await _getHeaders(),
        body: json.encode(requestBody),
      );
    });
  }

  // 기존 일반적인 메서드들
  Future<Map<String, dynamic>> get(
    String endpoint, {
    bool includeAuth = true,
  }) async {
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

  // 휴무 제한 조회
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

      print('[API] 휴무 제한 조회 요청: $uri');
      print('[API] 요청 파라미터: $queryParams');

      final response = await http.get(uri, headers: await _getHeaders());

      print('[API] 휴무 제한 응답 상태: ${response.statusCode}');
      print('[API] 휴무 제한 응답 본문: ${response.body}');

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
        Uri.parse(
          '$_baseUrl${Constants.adminFcmTokenEndpoint}/$userId/fcm-token',
        ),
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

  // FCM 토큰 삭제 (로그아웃 시 — 관리자).
  // fcmToken을 함께 보내면 이 기기만 해제된다. 안 보내면 서버가 모든 기기를 해제한다.
  Future<void> deleteAdminFcmToken({
    required String userId,
    String? fcmToken,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl${Constants.adminFcmTokenEndpoint}/$userId/fcm-token',
    ).replace(queryParameters: fcmToken != null ? {'fcmToken': fcmToken} : null);
    final response = await http.delete(uri, headers: await _getHeaders());
    _handleResponse(response);
  }

  // FCM 토큰 삭제 (로그아웃 시 — 직원)
  Future<void> deleteFcmToken({
    required String memberId,
    String? fcmToken,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl${Constants.fcmTokenEndpoint}/$memberId/fcm-token',
    ).replace(queryParameters: fcmToken != null ? {'fcmToken': fcmToken} : null);
    final response = await http.delete(uri, headers: await _getHeaders());
    _handleResponse(response);
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

  // 관리자용 휴무 삭제
  Future<Map<String, dynamic>> deleteVacationByAdmin({
    required String vacationId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        'https://silverithm.site/api/vacation/delete/$vacationId',
      );

      print('[API] 관리자 휴무 삭제 요청: $uri');

      final requestBody = {'isAdmin': true};

      print('[API] 관리자 휴무 삭제 요청 body: $requestBody');

      final headers = await _getHeaders();

      return await http.delete(
        uri,
        headers: headers,
        body: json.encode(requestBody),
      );
    });
  }

  // 휴무 입력 마감일 설정 조회 (다음 달만 받기 nextMonthOnly 포함)
  Future<Map<String, dynamic>> getVacationDeadlineSetting({
    required String companyId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/vacation/deadline-setting',
      ).replace(queryParameters: {'companyId': companyId});

      print('[API] 휴무 마감일 설정 조회 요청: $uri');

      return await http.get(uri, headers: await _getHeaders());
    });
  }

  // 월별 마감일 지정 조회 — {"dates": {"2026-08": "2026-08-16", ...}}
  Future<Map<String, dynamic>> getVacationDeadlineDates({
    required String companyId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/vacation/deadline-dates',
      ).replace(queryParameters: {'companyId': companyId});

      print('[API] 월별 마감일 지정 조회 요청: $uri');

      return await http.get(uri, headers: await _getHeaders());
    });
  }

  // 근무조정 중요 행사 조회 — {"events": [{id,title,description,startDate,endDate,warnOnRequest}, ...]}
  Future<Map<String, dynamic>> getVacationEvents({
    required String companyId,
    required String startDate,
    required String endDate,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/vacation/events').replace(
        queryParameters: {
          'companyId': companyId,
          'startDate': startDate,
          'endDate': endDate,
        },
      );

      print('[API] 근무조정 중요 행사 조회 요청: $uri');

      return await http.get(uri, headers: await _getHeaders());
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

  // 알림 읽음 처리
  Future<Map<String, dynamic>> markNotificationAsRead({
    required String notificationId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl${Constants.notificationsEndpoint.replaceFirst('/user', '')}/$notificationId/read',
      );

      print('[API] 알림 읽음 처리 요청: $uri');

      return await http.put(uri, headers: await _getHeaders());
    });
  }

  // 전체 알림 읽음 처리
  Future<Map<String, dynamic>> markAllNotificationsAsRead({
    required String userId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl${Constants.notificationsEndpoint}/$userId/read-all',
      );

      print('[API] 전체 알림 읽음 처리 요청: $uri');

      return await http.put(uri, headers: await _getHeaders());
    });
  }

  // 비밀번호 찾기 (임시 비밀번호 발송) - 직원용 - 인증 불필요
  Future<Map<String, dynamic>> findPassword({required String email}) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl${Constants.findPasswordEndpoint}',
      ).replace(queryParameters: {'email': email});

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
  Future<Map<String, dynamic>> findAdminPassword({
    required String email,
  }) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/v1/find/password',
      ).replace(queryParameters: {'email': email});

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
      final uri = Uri.parse(
        '$_baseUrl${Constants.updateRoleEndpoint}',
      ).replace(queryParameters: {'role': role});

      print('[API] 역할 변경 요청 URI: $uri');
      final response = await http.put(uri, headers: await _getHeaders());
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

  // ================== 배차 설정 ==================

  /// 회사의 배차 설정 한 벌을 통째로 받는다.
  /// 서버가 원본이고 관리자 웹과 같은 JSON을 본다 — 한쪽에서 고치면 다른 쪽에도 보인다.
  Future<Map<String, dynamic>> getDispatchSettings({
    required String companyId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/dispatch-settings',
      ).replace(queryParameters: {'companyId': companyId});

      print('[API] 배차 설정 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  /// 배차 설정 전체 저장. 서버가 회사당 한 벌로 덮어쓴다.
  Future<Map<String, dynamic>> saveDispatchSettings({
    required String companyId,
    required Map<String, dynamic> settings,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/dispatch-settings',
      ).replace(queryParameters: {'companyId': companyId});

      print('[API] 배차 설정 저장: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.put(uri, headers: headers, body: json.encode(settings));
    });
  }

  /// 기관에 등록된 어르신 목록 (배차에 태울 대상 고르기용)
  Future<Map<String, dynamic>> getCompanyElders({
    required String companyId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/elders/company',
      ).replace(queryParameters: {'companyId': companyId});

      print('[API] 어르신 목록 조회: $uri');

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
  Future<Map<String, dynamic>> deleteMember({required String userId}) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/members/$userId');

      print('[API] 회원 삭제: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.delete(uri, headers: headers);
    });
  }

  // 휴무 요청 목록 조회 (관리자용)
  Future<Map<String, dynamic>> getVacationRequests({
    required String companyId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/vacation/requests',
      ).replace(queryParameters: {'companyId': companyId});

      print('[API] 휴무 요청 목록 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 휴무 요청 승인
  Future<Map<String, dynamic>> approveVacationRequest({
    required String vacationId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/vacation/approve/$vacationId');

      print('[API] 휴무 요청 승인: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.put(uri, headers: headers);
    });
  }

  // 휴무 요청 거부
  Future<Map<String, dynamic>> rejectVacationRequest({
    required String vacationId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/vacation/reject/$vacationId');

      print('[API] 휴무 요청 거부: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.put(uri, headers: headers);
    });
  }

  // 휴무 일괄 승인
  Future<Map<String, dynamic>> bulkApproveVacations({
    required List<String> vacationIds,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/vacation/bulk-approve');

      print('[API] 휴무 일괄 승인: $uri');
      print('[API] 요청 ID 목록: $vacationIds');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.put(
        uri,
        headers: headers,
        body: json.encode({
          'vacationIds': vacationIds.map((id) => int.parse(id)).toList(),
        }),
      );
    });
  }

  // 휴무 일괄 거절
  Future<Map<String, dynamic>> bulkRejectVacations({
    required List<String> vacationIds,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/vacation/bulk-reject');

      print('[API] 휴무 일괄 거절: $uri');
      print('[API] 요청 ID 목록: $vacationIds');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.put(
        uri,
        headers: headers,
        body: json.encode({
          'vacationIds': vacationIds.map((id) => int.parse(id)).toList(),
        }),
      );
    });
  }

  // 관리자가 직원 대신 휴무 신청
  Future<Map<String, dynamic>> createVacationByAdmin({
    required String companyId,
    required int memberId,
    required String date,
    required String duration,
    String? reason,
    String? type,
    /// false면 서버가 duration을 UNUSED로 고정한다 (일반·필수·대체휴무)
    bool useAnnualLeave = true,
    bool reasonRequired = false,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/vacation/admin/submit-for-member?companyId=$companyId',
      );

      print('[API] 관리자가 직원 대신 휴무 신청: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      // duration은 서버에서 @NotNull이라 미사용이어도 값을 채워 보낸다
      // (useAnnualLeave=false면 서버가 UNUSED로 바꾼다)
      final body = {
        'memberId': memberId,
        'date': date,
        'duration': duration == 'UNUSED' ? 'FULL_DAY' : duration,
        'useAnnualLeave': useAnnualLeave,
        'reasonRequired': reasonRequired,
      };

      if (reason != null && reason.isNotEmpty) {
        body['reason'] = reason;
      }
      if (type != null && type.isNotEmpty) {
        body['type'] = type;
      }

      return await http.post(uri, headers: headers, body: json.encode(body));
    });
  }

  // 휴무 한도 저장
  Future<Map<String, dynamic>> saveVacationLimits({
    required String companyId,
    required List<Map<String, dynamic>> limits,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/vacation/limits',
      ).replace(queryParameters: {'companyId': companyId});

      print('[API] 휴무 한도 저장: $uri');
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

      return await http.put(uri, headers: headers, body: json.encode(body));
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
              'customerKey':
                  userData['customerKey'] ??
                  'customer_${DateTime.now().millisecondsSinceEpoch}',
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
      final customerKey =
          userInfoResponse['customerKey']?.toString() ??
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

      return await http.post(uri, headers: headers, body: jsonBody);
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
        'customerKey':
            userInfoResponse['customerKey']?.toString() ??
            '', // userInfo에서 받아온 customerKey
        'authKey': authKey,
        'orderName': '$planName 구독', // 주문명
        'customerEmail': userEmail, // 올바른 필드명
        'customerName':
            userInfoResponse['userName']?.toString() ?? '', // 사용자 이름
        'taxFreeAmount': 0, // 비과세 금액
      };

      print('[API] 유료 구독 생성: $uri');
      print('[API] 구독 데이터: $body');

      final jsonBody = json.encode(body);
      print('[API] JSON 인코딩된 본문: $jsonBody');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      print('[API] 요청 헤더: $headers');

      return await http.post(uri, headers: headers, body: jsonBody);
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
      final queryParams = {'page': page.toString(), 'size': size.toString()};

      final uri = Uri.parse(
        '$_baseUrl/v1/subscriptions/payment-failures',
      ).replace(queryParameters: queryParams);

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
        final errorMessage =
            responseData['error'] ??
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
            final simpleError = response.body
                .replaceAll('"', '')
                .replaceAll('{', '')
                .replaceAll('}', '');
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

  // ===================== 공지사항 API =====================

  // 관리자용 공지사항 목록 조회 (필터링 지원)
  Future<Map<String, dynamic>> getNotices({
    required String companyId,
    String? status,
    String? priority,
    String? search,
    int page = 0,
    int size = 20,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final queryParams = {
        'companyId': companyId,
        'page': page.toString(),
        'size': size.toString(),
      };

      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (priority != null && priority.isNotEmpty) {
        queryParams['priority'] = priority;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse(
        '$_baseUrl/v1/notices',
      ).replace(queryParameters: queryParams);

      print('[API] 공지사항 목록 조회 (관리자): $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 직원용 게시된 공지사항 목록 조회
  Future<Map<String, dynamic>> getPublishedNotices({
    required String companyId,
    int page = 0,
    int size = 20,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final queryParams = {
        'companyId': companyId,
        'page': page.toString(),
        'size': size.toString(),
      };

      final uri = Uri.parse(
        '$_baseUrl/v1/notices/published',
      ).replace(queryParameters: queryParams);

      print('[API] 공지사항 목록 조회 (직원용): $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 읽지 않은 공지사항 수 조회
  Future<Map<String, dynamic>> getUnreadNoticeCount({
    required String companyId,
    required String userId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final queryParams = {'companyId': companyId, 'userId': userId};

      final uri = Uri.parse(
        '$_baseUrl/v1/notices/unread-count',
      ).replace(queryParameters: queryParams);

      print('[API] 읽지 않은 공지사항 수 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 공지사항 상세 조회
  Future<Map<String, dynamic>> getNoticeDetail({required int noticeId}) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/notices/$noticeId');

      print('[API] 공지사항 상세 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 공지사항 등록
  Future<Map<String, dynamic>> createNotice({
    required String companyId,
    required String title,
    required String content,
    String priority = 'NORMAL',
    String status = 'DRAFT',
    bool isPinned = false,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/notices',
      ).replace(queryParameters: {'companyId': companyId});

      final body = {
        'title': title,
        'content': content,
        'priority': priority,
        'status': status,
        'isPinned': isPinned,
      };

      print('[API] 공지사항 등록: $uri');
      print('[API] 요청 데이터: $body');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.post(uri, headers: headers, body: json.encode(body));
    });
  }

  // 공지사항 수정
  Future<Map<String, dynamic>> updateNotice({
    required int noticeId,
    required String title,
    required String content,
    String priority = 'NORMAL',
    String status = 'DRAFT',
    bool isPinned = false,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/notices/$noticeId');

      final body = {
        'title': title,
        'content': content,
        'priority': priority,
        'status': status,
        'isPinned': isPinned,
      };

      print('[API] 공지사항 수정: $uri');
      print('[API] 요청 데이터: $body');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.put(uri, headers: headers, body: json.encode(body));
    });
  }

  // 공지사항 삭제
  Future<Map<String, dynamic>> deleteNotice({required int noticeId}) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/notices/$noticeId');

      print('[API] 공지사항 삭제: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.delete(uri, headers: headers);
    });
  }

  // 공지사항 조회수 증가
  Future<Map<String, dynamic>> incrementNoticeViewCount({
    required int noticeId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/notices/$noticeId/view');

      print('[API] 공지사항 조회수 증가: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.post(uri, headers: headers);
    });
  }

  // 공지사항 댓글 목록 조회
  Future<Map<String, dynamic>> getNoticeComments({
    required int noticeId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/notices/$noticeId/comments');

      print('[API] 공지사항 댓글 목록 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 공지사항 댓글 생성
  Future<Map<String, dynamic>> createNoticeComment({
    required int noticeId,
    required String authorId,
    required String authorName,
    required String content,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/notices/$noticeId/comments');

      final body = {
        'authorId': authorId,
        'authorName': authorName,
        'content': content,
      };

      print('[API] 공지사항 댓글 생성: $uri');
      print('[API] 요청 데이터: $body');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.post(uri, headers: headers, body: json.encode(body));
    });
  }

  // 공지사항 댓글 삭제
  Future<Map<String, dynamic>> deleteNoticeComment({
    required int noticeId,
    required int commentId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/notices/$noticeId/comments/$commentId',
      );

      print('[API] 공지사항 댓글 삭제: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.delete(uri, headers: headers);
    });
  }

  // 공지사항 읽은 사용자 목록 조회
  Future<Map<String, dynamic>> getNoticeReaders({required int noticeId}) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/notices/$noticeId/readers');

      print('[API] 공지사항 읽은 사용자 목록 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 공지사항 읽음 기록
  Future<Map<String, dynamic>> markNoticeAsRead({
    required int noticeId,
    required String userId,
    required String userName,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/notices/$noticeId/readers');

      print('[API] 공지사항 읽음 기록: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.post(
        uri,
        headers: headers,
        body: json.encode({'userId': userId, 'userName': userName}),
      );
    });
  }

  // ===================== 전자결재 API =====================

  // 결재 요청 목록 조회 (관리자용)
  Future<Map<String, dynamic>> getApprovalRequests({
    required String companyId,
    String? status,
    int page = 0,
    int size = 20,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final queryParams = {
        'companyId': companyId,
        'page': page.toString(),
        'size': size.toString(),
      };

      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final uri = Uri.parse(
        '$_baseUrl/v1/approvals',
      ).replace(queryParameters: queryParams);

      print('[API] 결재 요청 목록 조회 (관리자): $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 내 결재 요청 목록 조회 (직원용)
  Future<Map<String, dynamic>> getMyApprovalRequests({
    required String requesterId,
    String? status,
    int page = 0,
    int size = 20,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final queryParams = {
        'requesterId': requesterId,
        'page': page.toString(),
        'size': size.toString(),
      };

      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final uri = Uri.parse(
        '$_baseUrl/v1/approvals/my',
      ).replace(queryParameters: queryParams);

      print('[API] 내 결재 요청 목록 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 결재 요청 상세 조회
  Future<Map<String, dynamic>> getApprovalRequestDetail({
    required int approvalId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/approvals/$approvalId');

      print('[API] 결재 요청 상세 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 결재 첨부파일 업로드 (S3)
  Future<Map<String, dynamic>> uploadApprovalFile({
    required dynamic file,
  }) async {
    try {
      final url = '$_baseUrl/v1/approvals/files';
      print('[API] 결재 파일 업로드: $url');

      final token = StorageService().getToken();

      // 파일 경로 얻기
      String filePath;
      if (file is String) {
        filePath = file;
      } else if (file is File) {
        filePath = file.path;
      } else {
        filePath = file.path;
      }

      // 파일 크기 확인
      final fileObj = File(filePath);
      final fileSize = await fileObj.length();
      final fileName = filePath.split('/').last;

      print(
        '[API] 업로드 파일명: $fileName, 크기: $fileSize bytes (${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB)',
      );

      // dio FormData 생성
      final formData = dio.FormData.fromMap({
        'file': await dio.MultipartFile.fromFile(filePath, filename: fileName),
      });

      // dio 인스턴스 생성
      final dioClient = dio.Dio();
      dioClient.options.connectTimeout = const Duration(seconds: 30);
      dioClient.options.receiveTimeout = const Duration(seconds: 60);
      dioClient.options.sendTimeout = const Duration(seconds: 60);

      final response = await dioClient.post(
        url,
        data: formData,
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
            'ngrok-skip-browser-warning': 'true',
          },
        ),
        onSendProgress: (sent, total) {
          final progress = (sent / total * 100).toStringAsFixed(1);
          print('[API] 업로드 진행률: $progress% ($sent / $total)');
        },
      );

      print('[API] 결재 파일 업로드 응답 상태: ${response.statusCode}');
      print('[API] 결재 파일 업로드 응답: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data is Map<String, dynamic>) {
          return response.data;
        } else if (response.data is String) {
          return json.decode(response.data);
        } else {
          return {'success': true, 'data': response.data};
        }
      } else {
        final errorMsg = response.data is Map
            ? (response.data['error'] ?? '파일 업로드 실패')
            : '파일 업로드 실패';
        throw ApiException(errorMsg, response.statusCode ?? 500);
      }
    } on dio.DioException catch (e) {
      print('[API] 결재 파일 업로드 Dio 에러: ${e.message}');
      print('[API] 에러 응답: ${e.response?.data}');

      String errorMessage = '파일 업로드 실패';
      if (e.response?.data != null) {
        if (e.response!.data is Map) {
          errorMessage = e.response!.data['error'] ?? errorMessage;
        } else if (e.response!.data is String) {
          try {
            final errorJson = json.decode(e.response!.data);
            errorMessage = errorJson['error'] ?? errorMessage;
          } catch (_) {
            errorMessage = e.response!.data;
          }
        }
      }
      throw ApiException(errorMessage, e.response?.statusCode ?? 500);
    } catch (e) {
      print('[API] 결재 파일 업로드 에러: $e');
      throw Exception('파일 업로드 실패: $e');
    }
  }

  // 결재 요청 생성
  Future<Map<String, dynamic>> createApprovalRequest({
    required String companyId,
    required String requesterId,
    required String requesterName,
    required int templateId,
    required String title,
    String? attachmentUrl,
    String? attachmentFileName,
    int? attachmentFileSize,
    Map<String, dynamic>? formData,
    List<Map<String, dynamic>>?
    approvalLine, // [{approverType, approverId}] 순서=결재 순서
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/approvals').replace(
        queryParameters: {
          'companyId': companyId,
          'requesterId': requesterId,
          'requesterName': requesterName,
        },
      );

      final body = <String, dynamic>{'templateId': templateId, 'title': title};

      if (attachmentUrl != null) body['attachmentUrl'] = attachmentUrl;
      if (attachmentFileName != null)
        body['attachmentFileName'] = attachmentFileName;
      if (attachmentFileSize != null)
        body['attachmentFileSize'] = attachmentFileSize;
      // 백엔드 DTO의 formData는 String(JSON) 타입
      if (formData != null && formData.isNotEmpty) {
        body['formData'] = json.encode(formData);
      }
      if (approvalLine != null && approvalLine.isNotEmpty) {
        body['approvalLine'] = approvalLine;
      }

      print('[API] 결재 요청 생성: $uri');
      print('[API] 요청 데이터: $body');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.post(uri, headers: headers, body: json.encode(body));
    });
  }

  // 결재 요청 승인 — signatureBase64가 있으면 즉석 서명 날인, 없으면 등록 서명 자동 사용
  // force=true면 내 차례가 아니어도 남은 결재 단계를 건너뛰고 직권 승인(전결)한다 (서버가 권한 재검증)
  Future<Map<String, dynamic>> approveApprovalRequest({
    required int approvalId,
    required String processedBy,
    required String processedByName,
    String? signatureBase64,
    bool force = false,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/approvals/$approvalId/approve')
          .replace(
            queryParameters: {
              'processedBy': processedBy,
              'processedByName': processedByName,
              if (force) 'force': 'true',
            },
          );

      print('[API] 결재 요청 승인: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      if (signatureBase64 != null && signatureBase64.isNotEmpty) {
        return await http.put(
          uri,
          headers: headers,
          body: json.encode({'signatureBase64': signatureBase64}),
        );
      }
      return await http.put(uri, headers: headers);
    });
  }

  // 결재선 지정 가능 결재자 후보 목록
  Future<Map<String, dynamic>> getApproverCandidates({
    required String companyId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/approvals/approver-candidates',
      ).replace(queryParameters: {'companyId': companyId});
      final headers = await _getHeaders();
      return await http.get(uri, headers: headers);
    });
  }

  // ── 푸시 알림 수신 설정 ──
  // 직원(Member)과 관리자 가입 계정(AppUser)이 서로 다른 테이블이라 경로가 나뉜다.

  Future<Map<String, dynamic>> getPushEnabled({
    required String userId,
    required bool isAdmin,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = isAdmin
          ? Uri.parse('$_baseUrl/v1/users/push-enabled')
          : Uri.parse(
              '$_baseUrl${Constants.fcmTokenEndpoint}/$userId/push-enabled',
            );
      return await http.get(uri, headers: await _getHeaders());
    });
  }

  Future<Map<String, dynamic>> updatePushEnabled({
    required String userId,
    required bool isAdmin,
    required bool enabled,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = isAdmin
          ? Uri.parse('$_baseUrl/v1/users/push-enabled')
          : Uri.parse(
              '$_baseUrl${Constants.fcmTokenEndpoint}/$userId/push-enabled',
            );
      return await http.put(
        uri,
        headers: await _getHeaders(),
        body: json.encode({'pushEnabled': enabled}),
      );
    });
  }

  // 내 결재 서명 조회 ({signatureUrl})
  Future<Map<String, dynamic>> getMySignature() async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/signatures/me');
      final headers = await _getHeaders();
      return await http.get(uri, headers: headers);
    });
  }

  // 내 결재 서명 등록 (base64 PNG data URL 허용)
  Future<Map<String, dynamic>> registerMySignature({
    required String imageBase64,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/signatures');
      final headers = await _getHeaders();
      return await http.post(
        uri,
        headers: headers,
        body: json.encode({'imageBase64': imageBase64}),
      );
    });
  }

  // 내 결재 서명 삭제
  Future<Map<String, dynamic>> deleteMySignature() async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/signatures');
      final headers = await _getHeaders();
      return await http.delete(uri, headers: headers);
    });
  }

  // 결재 요청 거절
  // force=true면 내 차례가 아니어도 남은 결재 단계를 건너뛰고 직권 반려한다 (서버가 권한 재검증)
  Future<Map<String, dynamic>> rejectApprovalRequest({
    required int approvalId,
    required String processedBy,
    required String processedByName,
    required String reason,
    bool force = false,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/approvals/$approvalId/reject')
          .replace(
            queryParameters: {
              'processedBy': processedBy,
              'processedByName': processedByName,
              if (force) 'force': 'true',
            },
          );

      print('[API] 결재 요청 거절: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.put(
        uri,
        headers: headers,
        body: json.encode({'reason': reason}),
      );
    });
  }

  // 결재 요청 일괄 승인
  Future<Map<String, dynamic>> bulkApproveApprovalRequests({
    required List<int> approvalIds,
    required String processedBy,
    required String processedByName,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/approvals/bulk-approve').replace(
        queryParameters: {
          'processedBy': processedBy,
          'processedByName': processedByName,
        },
      );

      print('[API] 결재 요청 일괄 승인: $uri');
      print('[API] 요청 ID 목록: $approvalIds');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.put(
        uri,
        headers: headers,
        body: json.encode({'ids': approvalIds}),
      );
    });
  }

  // 결재 요청 일괄 거절
  Future<Map<String, dynamic>> bulkRejectApprovalRequests({
    required List<int> approvalIds,
    required String processedBy,
    required String processedByName,
    required String reason,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/approvals/bulk-reject').replace(
        queryParameters: {
          'processedBy': processedBy,
          'processedByName': processedByName,
        },
      );

      print('[API] 결재 요청 일괄 거절: $uri');
      print('[API] 요청 ID 목록: $approvalIds');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.put(
        uri,
        headers: headers,
        body: json.encode({'ids': approvalIds, 'reason': reason}),
      );
    });
  }

  // 결재 요청 취소 (삭제)
  Future<Map<String, dynamic>> deleteApprovalRequest({
    required int approvalId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/approvals/$approvalId');

      print('[API] 결재 요청 취소: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.delete(uri, headers: headers);
    });
  }

  // ===================== 결재 양식 API =====================

  // 결재 양식 목록 조회 (관리자용)
  Future<Map<String, dynamic>> getApprovalTemplates({
    required String companyId,
    int page = 0,
    int size = 20,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final queryParams = {
        'companyId': companyId,
        'page': page.toString(),
        'size': size.toString(),
      };

      final uri = Uri.parse(
        '$_baseUrl/v1/approval-templates',
      ).replace(queryParameters: queryParams);

      print('[API] 결재 양식 목록 조회 (관리자): $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 활성 결재 양식 목록 조회 (직원용)
  Future<Map<String, dynamic>> getActiveApprovalTemplates({
    required String companyId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final queryParams = {'companyId': companyId};

      final uri = Uri.parse(
        '$_baseUrl/v1/approval-templates/active',
      ).replace(queryParameters: queryParams);

      print('[API] 활성 결재 양식 목록 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 결재 양식 상세 조회
  Future<Map<String, dynamic>> getApprovalTemplateDetail({
    required int templateId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/approval-templates/$templateId');

      print('[API] 결재 양식 상세 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 결재 양식 생성
  Future<Map<String, dynamic>> createApprovalTemplate({
    required String companyId,
    required String name,
    String? description,
    String? fileUrl,
    String? fileName,
    int? fileSize,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/approval-templates',
      ).replace(queryParameters: {'companyId': companyId});

      final body = <String, dynamic>{'name': name};

      if (description != null) body['description'] = description;
      if (fileUrl != null) body['fileUrl'] = fileUrl;
      if (fileName != null) body['fileName'] = fileName;
      if (fileSize != null) body['fileSize'] = fileSize;

      print('[API] 결재 양식 생성: $uri');
      print('[API] 요청 데이터: $body');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.post(uri, headers: headers, body: json.encode(body));
    });
  }

  // 결재 양식 수정
  Future<Map<String, dynamic>> updateApprovalTemplate({
    required int templateId,
    required String name,
    String? description,
    String? fileUrl,
    String? fileName,
    int? fileSize,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/approval-templates/$templateId');

      final body = <String, dynamic>{'name': name};

      if (description != null) body['description'] = description;
      if (fileUrl != null) body['fileUrl'] = fileUrl;
      if (fileName != null) body['fileName'] = fileName;
      if (fileSize != null) body['fileSize'] = fileSize;

      print('[API] 결재 양식 수정: $uri');
      print('[API] 요청 데이터: $body');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.put(uri, headers: headers, body: json.encode(body));
    });
  }

  // 결재 양식 활성화 토글
  Future<Map<String, dynamic>> toggleApprovalTemplateActive({
    required int templateId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/approval-templates/$templateId/toggle-active',
      );

      print('[API] 결재 양식 활성화 토글: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.put(uri, headers: headers);
    });
  }

  // 결재 양식 삭제
  Future<Map<String, dynamic>> deleteApprovalTemplate({
    required int templateId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/approval-templates/$templateId');

      print('[API] 결재 양식 삭제: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.delete(uri, headers: headers);
    });
  }

  // ===================== 채팅 API =====================

  // 채팅방 목록 조회
  Future<Map<String, dynamic>> getChatRooms({
    required String companyId,
    required String userId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final queryParams = {'companyId': companyId, 'userId': userId};

      final uri = Uri.parse(
        '$_baseUrl/v1/chat/rooms',
      ).replace(queryParameters: queryParams);

      print('[API] 채팅방 목록 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 채팅방 생성
  Future<Map<String, dynamic>> createChatRoom({
    required String companyId,
    required String name,
    String? description,
    required String createdBy,
    required String createdByName,
    required List<String> participantIds,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/chat/rooms',
      ).replace(queryParameters: {'companyId': companyId});

      final body = {
        'name': name,
        'description': description,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'participantIds': participantIds,
      };

      print('[API] 채팅방 생성: $uri');
      print('[API] 요청 데이터: $body');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.post(uri, headers: headers, body: json.encode(body));
    });
  }

  // 채팅방 상세 조회
  Future<Map<String, dynamic>> getChatRoomDetail({required int roomId}) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/chat/rooms/$roomId');

      print('[API] 채팅방 상세 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 채팅방 수정
  Future<Map<String, dynamic>> updateChatRoom({
    required int roomId,
    required String name,
    String? description,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/chat/rooms/$roomId');

      final body = <String, dynamic>{'name': name};
      if (description != null) body['description'] = description;

      print('[API] 채팅방 수정: $uri');
      print('[API] 요청 데이터: $body');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.put(uri, headers: headers, body: json.encode(body));
    });
  }

  // 채팅방 나가기
  Future<Map<String, dynamic>> leaveChatRoom({
    required int roomId,
    required String userId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/chat/rooms/$roomId/leave',
      ).replace(queryParameters: {'userId': userId});

      print('[API] 채팅방 나가기: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.post(uri, headers: headers);
    });
  }

  // 채팅방 삭제
  Future<Map<String, dynamic>> deleteChatRoom({required int roomId}) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/chat/rooms/$roomId');

      print('[API] 채팅방 삭제: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.delete(uri, headers: headers);
    });
  }

  // 채팅방 참가자 목록 조회
  Future<Map<String, dynamic>> getChatParticipants({
    required int roomId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/chat/rooms/$roomId/participants');

      print('[API] 채팅방 참가자 목록 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 채팅방 참가자 추가
  Future<Map<String, dynamic>> addChatParticipants({
    required int roomId,
    required List<String> userIds,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/chat/rooms/$roomId/participants');

      final body = {'userIds': userIds};

      print('[API] 채팅방 참가자 추가: $uri');
      print('[API] 요청 데이터: $body');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.post(uri, headers: headers, body: json.encode(body));
    });
  }

  // 채팅방 참가자 제거/강퇴
  Future<Map<String, dynamic>> removeChatParticipant({
    required int roomId,
    required String userId,
    bool isKicked = false,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/chat/rooms/$roomId/participants/$userId',
      ).replace(queryParameters: {'isKicked': isKicked.toString()});

      print('[API] 채팅방 참가자 제거: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.delete(uri, headers: headers);
    });
  }

  // 메시지 목록 조회
  Future<Map<String, dynamic>> getChatMessages({
    required int roomId,
    int page = 0,
    int size = 50,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final queryParams = {'page': page.toString(), 'size': size.toString()};

      final uri = Uri.parse(
        '$_baseUrl/v1/chat/rooms/$roomId/messages',
      ).replace(queryParameters: queryParams);

      print('[API] 채팅 메시지 목록 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 메시지 전송
  Future<Map<String, dynamic>> sendChatMessage({
    required int roomId,
    required String content,
    required String type,
    required String senderId,
    required String senderName,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/chat/rooms/$roomId/messages');

      final body = {
        'content': content,
        'type': type,
        'senderId': senderId,
        'senderName': senderName,
      };

      print('[API] 메시지 전송: $uri');
      print('[API] 요청 데이터: $body');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.post(uri, headers: headers, body: json.encode(body));
    });
  }

  // 메시지 삭제
  Future<Map<String, dynamic>> deleteChatMessage({
    required int roomId,
    required int messageId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/chat/rooms/$roomId/messages/$messageId',
      );

      print('[API] 메시지 삭제: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.delete(uri, headers: headers);
    });
  }

  // 읽음 처리
  Future<Map<String, dynamic>> markChatAsRead({
    required int roomId,
    required int lastMessageId,
    required String userId,
    required String userName,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/chat/rooms/$roomId/read');

      final body = {
        'lastMessageId': lastMessageId,
        'userId': userId,
        'userName': userName,
      };

      print('[API] 채팅 읽음 처리: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.post(uri, headers: headers, body: json.encode(body));
    });
  }

  // 메시지 읽은 사람 목록 조회
  Future<Map<String, dynamic>> getChatMessageReaders({
    required int roomId,
    required int messageId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/chat/rooms/$roomId/messages/$messageId/readers',
      );

      print('[API] 메시지 읽은 사람 목록 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 공유 파일 목록 조회
  Future<Map<String, dynamic>> getChatSharedMedia({
    required int roomId,
    String? type,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final queryParams = <String, String>{};
      if (type != null) queryParams['type'] = type;

      final uri = Uri.parse(
        '$_baseUrl/v1/chat/rooms/$roomId/files',
      ).replace(queryParameters: queryParams);

      print('[API] 공유 파일 목록 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 대화 내용 검색
  Future<Map<String, dynamic>> searchChatMessages({
    required int roomId,
    required String keyword,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/chat/rooms/$roomId/messages/search',
      ).replace(queryParameters: {'keyword': keyword});

      print('[API] 대화 검색: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 공지 등록 — 기존 메시지를 방 상단에 고정한다
  Future<Map<String, dynamic>> setChatRoomNotice({
    required int roomId,
    required int messageId,
    required String setByName,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/chat/rooms/$roomId/notice');

      print('[API] 채팅 공지 등록: $uri (messageId=$messageId)');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.put(
        uri,
        headers: headers,
        body: json.encode({'messageId': messageId, 'setByName': setByName}),
      );
    });
  }

  // 공지 내리기 — messageId 없이 보내면 서버가 해제로 처리한다
  Future<Map<String, dynamic>> clearChatRoomNotice({
    required int roomId,
    required String setByName,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/chat/rooms/$roomId/notice');

      print('[API] 채팅 공지 해제: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.put(
        uri,
        headers: headers,
        body: json.encode({'setByName': setByName}),
      );
    });
  }

  // 현재 접속 중인 사람 (첫 렌더용 — 이후 변화는 WebSocket으로 받는다)
  Future<Map<String, dynamic>> getOnlineUsers({
    required String companyId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/presence',
      ).replace(queryParameters: {'companyId': companyId});

      print('[API] 접속 상태 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 파일 업로드 (dio 사용 - 더 안정적인 multipart 처리)
  Future<Map<String, dynamic>> uploadChatFile({
    required int roomId,
    required dynamic file,
    required String senderId,
    required String senderName,
  }) async {
    try {
      final url = '$_baseUrl/v1/chat/rooms/$roomId/files';
      print('[API] 채팅 파일 업로드: $url');

      final token = StorageService().getToken();

      // 파일 경로 얻기
      String filePath;
      if (file is String) {
        filePath = file;
      } else if (file is File) {
        filePath = file.path;
      } else {
        filePath = file.path;
      }

      // 파일 크기 확인
      final fileObj = File(filePath);
      final fileSize = await fileObj.length();
      final fileName = filePath.split('/').last;

      print(
        '[API] 업로드 파일명: $fileName, 크기: $fileSize bytes (${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB)',
      );

      // dio FormData 생성
      final formData = dio.FormData.fromMap({
        'file': await dio.MultipartFile.fromFile(filePath, filename: fileName),
        'senderId': senderId,
        'senderName': senderName,
      });

      // dio 인스턴스 생성
      final dioClient = dio.Dio();
      dioClient.options.connectTimeout = const Duration(seconds: 30);
      dioClient.options.receiveTimeout = const Duration(seconds: 60);
      dioClient.options.sendTimeout = const Duration(seconds: 60);

      final response = await dioClient.post(
        url,
        data: formData,
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $token',
            'ngrok-skip-browser-warning': 'true',
          },
        ),
        onSendProgress: (sent, total) {
          final progress = (sent / total * 100).toStringAsFixed(1);
          print('[API] 업로드 진행률: $progress% ($sent / $total)');
        },
      );

      print('[API] 파일 업로드 응답 상태: ${response.statusCode}');
      print('[API] 파일 업로드 응답: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data is Map<String, dynamic>) {
          return response.data;
        } else if (response.data is String) {
          return json.decode(response.data);
        } else {
          return {'success': true, 'data': response.data};
        }
      } else {
        final errorMsg = response.data is Map
            ? (response.data['error'] ?? '파일 업로드 실패')
            : '파일 업로드 실패';
        throw ApiException(errorMsg, response.statusCode ?? 500);
      }
    } on dio.DioException catch (e) {
      print('[API] 파일 업로드 Dio 에러: ${e.message}');
      print('[API] 에러 응답: ${e.response?.data}');

      String errorMessage = '파일 업로드 실패';
      if (e.response?.data != null) {
        if (e.response!.data is Map) {
          errorMessage = e.response!.data['error'] ?? errorMessage;
        } else if (e.response!.data is String) {
          try {
            final errorJson = json.decode(e.response!.data);
            errorMessage = errorJson['error'] ?? errorMessage;
          } catch (_) {
            errorMessage = e.response!.data;
          }
        }
      }
      throw ApiException(errorMessage, e.response?.statusCode ?? 500);
    } catch (e) {
      print('[API] 파일 업로드 에러: $e');
      throw Exception('파일 업로드 실패: $e');
    }
  }

  // 채팅 메시지 리액션 토글 (추가/삭제)
  Future<Map<String, dynamic>> toggleChatReaction({
    required int roomId,
    required int messageId,
    required String userId,
    required String userName,
    required String emoji,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/chat/rooms/$roomId/messages/$messageId/reactions',
      );

      print('[API] 리액션 토글: roomId=$roomId, messageId=$messageId, emoji=$emoji');

      return await http.post(
        uri,
        headers: await _getHeaders(),
        body: json.encode({
          'userId': userId,
          'userName': userName,
          'emoji': emoji,
        }),
      );
    });
  }

  // 채팅 메시지 리액션 조회
  Future<Map<String, dynamic>> getChatReactions({
    required int roomId,
    required int messageId,
    String? userId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      var uri = Uri.parse(
        '$_baseUrl/v1/chat/rooms/$roomId/messages/$messageId/reactions',
      );
      if (userId != null) {
        uri = uri.replace(queryParameters: {'userId': userId});
      }

      return await http.get(uri, headers: await _getHeaders());
    });
  }

  // 관리자 회원탈퇴
  Future<Map<String, dynamic>> deleteAdminAccount() async {
    try {
      final headers = await _getHeaders(includeAuth: true);
      final response = await http.delete(
        Uri.parse('https://silverithm.site/api/v1/users'),
        headers: headers,
      );

      print('[API] 관리자 회원탈퇴 응답 상태: ${response.statusCode}');
      print('[API] 관리자 회원탈퇴 응답 본문: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // 성공적인 응답 처리
        if (response.body == 'success' || response.body.trim() == 'success') {
          // 문자열 "success" 응답 처리
          return {'success': true, 'message': '회원탈퇴가 완료되었습니다'};
        } else {
          // JSON 응답일 경우 파싱 시도
          try {
            return json.decode(response.body);
          } catch (e) {
            // JSON 파싱 실패시에도 성공으로 처리 (상태코드가 2xx이므로)
            return {'success': true, 'message': '회원탈퇴가 완료되었습니다'};
          }
        }
      } else {
        // 실패 응답 처리
        try {
          final errorData = json.decode(response.body);
          throw ApiException(
            errorData['message'] ?? '회원탈퇴에 실패했습니다',
            response.statusCode,
          );
        } catch (e) {
          throw ApiException('회원탈퇴에 실패했습니다', response.statusCode);
        }
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      print('[API] 관리자 회원탈퇴 오류: $e');
      throw ApiException('네트워크 오류가 발생했습니다', 0);
    }
  }

  // ===================== 일정 API =====================

  // 일정 목록 조회
  Future<Map<String, dynamic>> getSchedules({
    required String companyId,
    String? startDate,
    String? endDate,
    String? category,
    int? labelId,
    String? searchQuery,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final queryParams = <String, String>{'companyId': companyId};

      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (category != null) queryParams['category'] = category;
      if (labelId != null) queryParams['labelId'] = labelId.toString();
      if (searchQuery != null) queryParams['searchQuery'] = searchQuery;

      final uri = Uri.parse(
        '$_baseUrl/v1/schedules',
      ).replace(queryParameters: queryParams);

      print('[API] 일정 목록 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // 일정 상세 조회
  Future<Map<String, dynamic>> getScheduleDetail({
    required int scheduleId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/schedules/$scheduleId');

      print('[API] 일정 상세 조회: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  // ================== 기본 일정 구분 설정 API ==================
  // 기본 구분(회의·행사·교육·기타)의 기관별 이름·색·숨김. 삭제는 없다(기존 일정이 물고 있음).

  // 기본 구분 설정 조회 — 응답: { categories: [{category,name,color,hidden,customized,...}] }
  Future<Map<String, dynamic>> getScheduleCategorySettings({
    required String companyId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/schedule-categories?companyId=$companyId',
      );
      final headers = await _getHeaders();
      return await http.get(uri, headers: headers);
    });
  }

  // 기본 구분 이름·색·숨김 변경 (null 필드는 유지)
  Future<Map<String, dynamic>> updateScheduleCategorySetting({
    required String companyId,
    required String category,
    String? name,
    String? color,
    bool? hidden,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/schedule-categories/$category?companyId=$companyId',
      );
      final headers = await _getHeaders();
      return await http.put(
        uri,
        headers: headers,
        body: json.encode({
          if (name != null) 'name': name,
          if (color != null) 'color': color,
          if (hidden != null) 'hidden': hidden,
        }),
      );
    });
  }

  // 기본 구분 설정을 기본값으로 되돌리기
  Future<Map<String, dynamic>> resetScheduleCategorySetting({
    required String companyId,
    required String category,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/schedule-categories/$category?companyId=$companyId',
      );
      final headers = await _getHeaders();
      return await http.delete(uri, headers: headers);
    });
  }

  // ================== 일정 구분(라벨) API ==================
  // 기관이 직접 만드는 일정 구분(이름+색). 웹 관리자와 같은 schedule-labels API를 쓴다.

  // 일정 구분 목록 조회 — 응답: { labels: [...] }
  Future<Map<String, dynamic>> getScheduleLabels({
    required String companyId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/schedule-labels?companyId=$companyId',
      );
      final headers = await _getHeaders();
      return await http.get(uri, headers: headers);
    });
  }

  // 일정 구분 생성
  Future<Map<String, dynamic>> createScheduleLabel({
    required String companyId,
    required String name,
    required String color,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/schedule-labels?companyId=$companyId',
      );
      final headers = await _getHeaders();
      return await http.post(
        uri,
        headers: headers,
        body: json.encode({'name': name, 'color': color}),
      );
    });
  }

  // 일정 구분 수정
  Future<Map<String, dynamic>> updateScheduleLabel({
    required String companyId,
    required int labelId,
    required String name,
    required String color,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/schedule-labels/$labelId?companyId=$companyId',
      );
      final headers = await _getHeaders();
      return await http.put(
        uri,
        headers: headers,
        body: json.encode({'name': name, 'color': color}),
      );
    });
  }

  // 일정 구분 삭제 — 이 구분을 쓰던 일정은 서버가 구분만 떼어낸다
  Future<Map<String, dynamic>> deleteScheduleLabel({
    required String companyId,
    required int labelId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/schedule-labels/$labelId?companyId=$companyId',
      );
      final headers = await _getHeaders();
      return await http.delete(uri, headers: headers);
    });
  }

  // 일정 등록
  Future<Map<String, dynamic>> createSchedule({
    required String companyId,
    required Map<String, dynamic> scheduleData,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/schedules?companyId=$companyId');

      print('[API] 일정 등록: $uri');
      print('[API] 일정 데이터: $scheduleData');

      final headers = await _getHeaders();
      return await http.post(
        uri,
        headers: headers,
        body: json.encode(scheduleData),
      );
    });
  }

  // 일정 수정
  Future<Map<String, dynamic>> updateSchedule({
    required int scheduleId,
    required Map<String, dynamic> scheduleData,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/schedules/$scheduleId');

      print('[API] 일정 수정: $uri');
      print('[API] 일정 데이터: $scheduleData');

      final headers = await _getHeaders();
      return await http.put(
        uri,
        headers: headers,
        body: json.encode(scheduleData),
      );
    });
  }

  // 일정 삭제
  Future<Map<String, dynamic>> deleteSchedule({required int scheduleId}) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/schedules/$scheduleId');

      print('[API] 일정 삭제: $uri');

      final headers = await _getHeaders();
      return await http.delete(uri, headers: headers);
    });
  }

  // 일정 수행완료 처리/해제
  Future<Map<String, dynamic>> updateScheduleCompletion({
    required int scheduleId,
    required bool completed,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/schedules/$scheduleId/completion');
      final headers = await _getHeaders();
      return await http.put(
        uri,
        headers: headers,
        body: json.encode({'completed': completed}),
      );
    });
  }

  // 일정 할 일 목록
  Future<Map<String, dynamic>> getScheduleTasks({
    required int scheduleId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/schedules/$scheduleId/tasks');
      final headers = await _getHeaders();
      return await http.get(uri, headers: headers);
    });
  }

  // 일정 할 일 추가
  Future<Map<String, dynamic>> createScheduleTask({
    required int scheduleId,
    required String content,
    int? assigneeMemberId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/schedules/$scheduleId/tasks');
      final headers = await _getHeaders();
      return await http.post(
        uri,
        headers: headers,
        body: json.encode({
          'content': content,
          if (assigneeMemberId != null) 'assigneeMemberId': assigneeMemberId,
        }),
      );
    });
  }

  // 일정 할 일 완료 처리/해제
  Future<Map<String, dynamic>> updateScheduleTaskCompletion({
    required int scheduleId,
    required int taskId,
    required bool completed,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/schedules/$scheduleId/tasks/$taskId/completion',
      );
      final headers = await _getHeaders();
      return await http.put(
        uri,
        headers: headers,
        body: json.encode({'completed': completed}),
      );
    });
  }

  // 일정 할 일 삭제
  Future<Map<String, dynamic>> deleteScheduleTask({
    required int scheduleId,
    required int taskId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/schedules/$scheduleId/tasks/$taskId');
      final headers = await _getHeaders();
      return await http.delete(uri, headers: headers);
    });
  }

  // 내 할 일 목록 (기간 내)
  Future<Map<String, dynamic>> getMyScheduleTasks({
    required String companyId,
    String? startDate,
    String? endDate,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/schedules/my-tasks').replace(
        queryParameters: {
          'companyId': companyId,
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
        },
      );
      final headers = await _getHeaders();
      return await http.get(uri, headers: headers);
    });
  }

  // ================== 케어브이 광장 (뉴스/게시판/자료실) ==================

  // 요양 소식 (네이버 뉴스) — 비로그인 공개 API
  Future<Map<String, dynamic>> getCareNews({
    String? category,
    int page = 0,
    int size = 20,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/news').replace(
        queryParameters: {
          if (category != null && category.isNotEmpty) 'category': category,
          'page': page.toString(),
          'size': size.toString(),
        },
      );
      final headers = await _getHeaders();
      return await http.get(uri, headers: headers);
    });
  }

  // 광장 게시글 목록
  Future<Map<String, dynamic>> getPlazaPosts({
    String? board,
    String sort = 'latest',
    String? search,
    int page = 0,
    int size = 20,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/plaza/posts').replace(
        queryParameters: {
          if (board != null && board.isNotEmpty) 'board': board,
          'sort': sort,
          if (search != null && search.isNotEmpty) 'search': search,
          'page': page.toString(),
          'size': size.toString(),
        },
      );
      final headers = await _getHeaders();
      return await http.get(uri, headers: headers);
    });
  }

  // 광장 게시글 상세 (댓글 포함)
  Future<Map<String, dynamic>> getPlazaPostDetail({required int postId}) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/plaza/posts/$postId');
      final headers = await _getHeaders();
      return await http.get(uri, headers: headers);
    });
  }

  // 광장 게시글 작성
  // contactInfo/contactPublic: 구인·구직(job_offer/job_seek) 게시판 전용 연락처 필드.
  // 서버가 board에 따라 무시/정규화하므로 다른 게시판이어도 그대로 보내도 안전하다.
  Future<Map<String, dynamic>> createPlazaPost({
    required String board,
    required String title,
    required String content,
    required bool isAnonymous,
    String? authorName,
    String? companyName,
    String? contactInfo,
    bool contactPublic = false,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/plaza/posts');
      final headers = await _getHeaders();
      return await http.post(
        uri,
        headers: headers,
        body: json.encode({
          'board': board,
          'title': title,
          'content': content,
          'isAnonymous': isAnonymous,
          if (authorName != null) 'authorName': authorName,
          if (companyName != null) 'companyName': companyName,
          if (contactInfo != null && contactInfo.isNotEmpty)
            'contactInfo': contactInfo,
          'contactPublic': contactPublic,
        }),
      );
    });
  }

  // 광장 게시글 수정 (본인 글) — 구인·구직 연락처 포함
  Future<Map<String, dynamic>> updatePlazaPost({
    required int postId,
    required String board,
    required String title,
    required String content,
    required bool isAnonymous,
    String? authorName,
    String? companyName,
    String? contactInfo,
    bool contactPublic = false,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/plaza/posts/$postId');
      final headers = await _getHeaders();
      return await http.put(
        uri,
        headers: headers,
        body: json.encode({
          'board': board,
          'title': title,
          'content': content,
          'isAnonymous': isAnonymous,
          if (authorName != null) 'authorName': authorName,
          if (companyName != null) 'companyName': companyName,
          if (contactInfo != null && contactInfo.isNotEmpty)
            'contactInfo': contactInfo,
          'contactPublic': contactPublic,
        }),
      );
    });
  }

  // 광장 게시글 삭제 (본인 글)
  Future<Map<String, dynamic>> deletePlazaPost({required int postId}) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/plaza/posts/$postId');
      final headers = await _getHeaders();
      return await http.delete(uri, headers: headers);
    });
  }

  // 광장 게시글 좋아요 토글
  Future<Map<String, dynamic>> togglePlazaPostLike({
    required int postId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/plaza/posts/$postId/like');
      final headers = await _getHeaders();
      return await http.post(uri, headers: headers);
    });
  }

  // 광장 댓글 작성
  Future<Map<String, dynamic>> addPlazaComment({
    required int postId,
    required String content,
    required bool isAnonymous,
    int? parentId,
    String? authorName,
    String? companyName,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/plaza/posts/$postId/comments');
      final headers = await _getHeaders();
      return await http.post(
        uri,
        headers: headers,
        body: json.encode({
          'content': content,
          'isAnonymous': isAnonymous,
          if (parentId != null) 'parentId': parentId,
          if (authorName != null) 'authorName': authorName,
          if (companyName != null) 'companyName': companyName,
        }),
      );
    });
  }

  // 광장 댓글 삭제 (본인 댓글)
  Future<Map<String, dynamic>> deletePlazaComment({
    required int commentId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/plaza/comments/$commentId');
      final headers = await _getHeaders();
      return await http.delete(uri, headers: headers);
    });
  }

  // 광장 자료실 이용 자격 확인 — 자유게시판 글 1개 이상 필요.
  // 비로그인이면 { allowed:false, reason:'LOGIN_REQUIRED' }, 조건 미충족이면
  // { allowed:false, reason:'FREE_POST_REQUIRED' } (둘 다 200 OK로 내려온다).
  Future<Map<String, dynamic>> getPlazaLibraryAccess() async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/plaza/library/access');
      final headers = await _getHeaders();
      return await http.get(uri, headers: headers);
    });
  }

  // 광장 자료실 목록
  Future<Map<String, dynamic>> getPlazaLibrary({
    String? category,
    String? search,
    int page = 0,
    int size = 20,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/plaza/library').replace(
        queryParameters: {
          if (category != null && category.isNotEmpty) 'category': category,
          if (search != null && search.isNotEmpty) 'search': search,
          'page': page.toString(),
          'size': size.toString(),
        },
      );
      final headers = await _getHeaders();
      return await http.get(uri, headers: headers);
    });
  }

  // 광장 자료 업로드 (multipart)
  Future<Map<String, dynamic>> uploadPlazaLibraryItem({
    required String filePath,
    required String category,
    required String title,
    String? description,
    String? uploaderName,
    String? companyName,
  }) async {
    final token = StorageService().getToken();
    final fileName = filePath.split('/').last;

    final formData = dio.FormData.fromMap({
      'file': await dio.MultipartFile.fromFile(filePath, filename: fileName),
      'category': category,
      'title': title,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (uploaderName != null) 'uploaderName': uploaderName,
      if (companyName != null) 'companyName': companyName,
    });

    final dioClient = dio.Dio();
    dioClient.options.connectTimeout = const Duration(seconds: 30);
    dioClient.options.sendTimeout = const Duration(seconds: 120);
    dioClient.options.receiveTimeout = const Duration(seconds: 60);

    final response = await dioClient.post(
      '$_baseUrl/v1/plaza/library',
      data: formData,
      options: dio.Options(
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      ),
    );

    if (response.statusCode == 200 && response.data is Map) {
      return Map<String, dynamic>.from(response.data);
    }
    throw ApiException('자료 업로드 실패', response.statusCode ?? 500);
  }

  // 광장 자료 다운로드 URL (dio로 직접 저장할 때 사용)
  String plazaLibraryDownloadUrl(int itemId) =>
      '$_baseUrl/v1/plaza/library/$itemId/download';

  // 광장 자료 수정 (본인 자료) — 파일은 그대로, 제목/분류/설명만 변경
  Future<Map<String, dynamic>> updatePlazaLibraryItem({
    required int itemId,
    required String category,
    required String title,
    String? description,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/plaza/library/$itemId');
      final headers = await _getHeaders();
      return await http.put(
        uri,
        headers: headers,
        body: json.encode({
          'category': category,
          'title': title,
          'description': description ?? '',
        }),
      );
    });
  }

  // ===== 기관 전용 자료실 =====
  // 광장 자료실과 달리 우리 기관 사람만 보고 올린다.

  Future<Map<String, dynamic>> getCompanyLibrary({
    required String companyId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/company-library',
      ).replace(queryParameters: {'companyId': companyId});

      print('[API] 기관 자료실 목록: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.get(uri, headers: headers);
    });
  }

  /// 자료 등록 — 파일을 먼저 [uploadFileToServer]로 올리고 그 결과를 넘긴다.
  Future<Map<String, dynamic>> createCompanyLibraryItem({
    required String companyId,
    required String title,
    String? description,
    String? category,
    required String fileName,
    required int fileSize,
    required String filePath,
    required String uploaderId,
    required String uploaderName,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/company-library',
      ).replace(queryParameters: {'companyId': companyId});

      print('[API] 기관 자료 등록: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.post(
        uri,
        headers: headers,
        body: json.encode({
          'title': title,
          'description': description ?? '',
          'category': category ?? '',
          'fileName': fileName,
          'fileSize': fileSize,
          'filePath': filePath,
          'uploaderId': uploaderId,
          'uploaderName': uploaderName,
        }),
      );
    });
  }

  Future<Map<String, dynamic>> deleteCompanyLibraryItem({
    required int itemId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/company-library/$itemId');

      print('[API] 기관 자료 삭제: $uri');

      final headers = await _getHeaders();
      headers['ngrok-skip-browser-warning'] = 'true';

      return await http.delete(uri, headers: headers);
    });
  }

  /// 범용 파일 업로드 — 저장 경로(filePath)만 돌려준다. 자료실처럼
  /// 파일과 정보를 따로 저장하는 곳에서 1단계로 쓴다.
  Future<Map<String, dynamic>> uploadFileToServer({
    required String filePath,
    String category = 'attachments',
  }) async {
    final token = StorageService().getToken();
    final fileName = filePath.split('/').last;

    final formData = dio.FormData.fromMap({
      'file': await dio.MultipartFile.fromFile(filePath, filename: fileName),
    });

    final dioClient = dio.Dio();
    dioClient.options.connectTimeout = const Duration(seconds: 30);
    dioClient.options.sendTimeout = const Duration(seconds: 120);
    dioClient.options.receiveTimeout = const Duration(seconds: 60);

    final response = await dioClient.post(
      '$_baseUrl/v1/files/upload',
      queryParameters: {'category': category},
      data: formData,
      options: dio.Options(
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      ),
    );

    if (response.statusCode == 200 && response.data is Map) {
      return Map<String, dynamic>.from(response.data);
    }
    throw ApiException('파일 업로드 실패', response.statusCode ?? 500);
  }

  /// 저장 경로로 내려받을 주소 (dio download에 그대로 넘긴다)
  String fileDownloadUrl(String path, String fileName) {
    final query = Uri(
      queryParameters: {'path': path, 'fileName': fileName},
    ).query;
    return '$_baseUrl/v1/files/download?$query';
  }

  // ===== 고충·신고 / 건의함 (VoiceBox) =====

  // 고충·신고 또는 건의 제출 (익명 여부 포함) — 같은 기관 인증 사용자 누구나 가능
  Future<Map<String, dynamic>> submitVoiceBoxMessage({
    required String type, // 'GRIEVANCE' | 'SUGGESTION'
    required String title,
    required String content,
    required bool isAnonymous,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/voice-box');
      final headers = await _getHeaders();
      return await http.post(
        uri,
        headers: headers,
        body: json.encode({
          'type': type,
          'title': title,
          'content': content,
          'isAnonymous': isAnonymous,
        }),
      );
    });
  }

  // 본인이 제출한 고충·신고/건의 내역 (상태·답변 포함)
  Future<Map<String, dynamic>> getMyVoiceBoxMessages() async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
        '$_baseUrl/v1/voice-box',
      ).replace(queryParameters: {'scope': 'mine'});
      final headers = await _getHeaders();
      return await http.get(uri, headers: headers);
    });
  }

  // ===== 장기요양 소식 (외부 공지) =====

  // 노인장기요양보험 공지·법령·평가·교육 자료 목록 (전 기관 공용, 인증 필요)
  Future<Map<String, dynamic>> getExternalNotices({
    String? source,
    int page = 0,
    int size = 20,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/external-notices').replace(
        queryParameters: {
          if (source != null && source.isNotEmpty) 'source': source,
          'page': page.toString(),
          'size': size.toString(),
        },
      );
      final headers = await _getHeaders();
      return await http.get(uri, headers: headers);
    });
  }

  // ===== 회원 프로필 사진 =====

  // 프로필 사진 업로드 (multipart, jpg/png/webp, 5MB 제한 — 최종 검증은 서버에서)
  Future<Map<String, dynamic>> uploadMemberProfileImage({
    required String memberId,
    required String filePath,
  }) async {
    final token = StorageService().getToken();
    final fileName = filePath.split('/').last;

    final formData = dio.FormData.fromMap({
      'file': await dio.MultipartFile.fromFile(filePath, filename: fileName),
    });

    final dioClient = dio.Dio();
    dioClient.options.connectTimeout = const Duration(seconds: 30);
    dioClient.options.sendTimeout = const Duration(seconds: 60);
    dioClient.options.receiveTimeout = const Duration(seconds: 30);

    try {
      final response = await dioClient.post(
        '$_baseUrl/v1/members/$memberId/profile-image',
        data: formData,
        options: dio.Options(
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        ),
      );

      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data);
      }
      throw ApiException('프로필 사진 업로드 실패', response.statusCode ?? 500);
    } on dio.DioException catch (e) {
      final data = e.response?.data;
      final message = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : '프로필 사진 업로드에 실패했습니다';
      throw ApiException(message, e.response?.statusCode ?? 500);
    }
  }

  // 프로필 사진 삭제
  Future<Map<String, dynamic>> deleteMemberProfileImage({
    required String memberId,
  }) async {
    return await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/members/$memberId/profile-image');
      final headers = await _getHeaders();
      return await http.delete(uri, headers: headers);
    });
  }

  // ================== 회의록 ==================

  /// 회의록 목록 — 관리자는 기관 전체, 직원은 본인이 작성·참석한 것만 온다
  Future<List<dynamic>> getMeetingMinutesList({required String companyId}) async {
    final data = await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/meeting-minutes')
          .replace(queryParameters: {'companyId': companyId});
      final headers = await _getHeaders();
      return await http.get(uri, headers: headers);
    });
    return data['items'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> getMeetingMinutesDetail({required int minutesId}) async {
    final data = await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse('$_baseUrl/v1/meeting-minutes/$minutesId');
      final headers = await _getHeaders();
      return await http.get(uri, headers: headers);
    });
    return data['minutes'] as Map<String, dynamic>? ?? {};
  }

  /// 회의록 서명 — signatureBase64가 있으면 즉석 서명, 없으면 등록 서명 자동 사용
  /// (결재 승인과 같은 계약)
  Future<Map<String, dynamic>> signMeetingMinutes({
    required int minutesId,
    required int attendeeId,
    String? signatureBase64,
  }) async {
    final data = await _makeAuthenticatedRequest(() async {
      final uri = Uri.parse(
          '$_baseUrl/v1/meeting-minutes/$minutesId/attendees/$attendeeId/sign');
      final headers = await _getHeaders();
      final body = signatureBase64 != null && signatureBase64.isNotEmpty
          ? json.encode({'signatureBase64': signatureBase64})
          : json.encode({});
      return await http.post(uri, headers: headers, body: body);
    });
    return data['minutes'] as Map<String, dynamic>? ?? {};
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
