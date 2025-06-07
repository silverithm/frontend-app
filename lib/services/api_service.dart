import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/user.dart';
import '../models/vacation_request.dart';
import '../services/storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String _baseUrl = Constants.baseUrl;

  // 공통 헤더 생성
  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await StorageService().getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // 회원가입 요청
  Future<Map<String, dynamic>> submitJoinRequest({
    required String username,
    required String email,
    required String name,
    required String role,
    required String password,
    String? companyId,
  }) async {
    try {
      final requestBody = {
        'username': username,
        'email': email,
        'name': name,
        'role': role,
        'password': password,
      };

      if (companyId != null && companyId.isNotEmpty) {
        requestBody['companyId'] = companyId;
      }

      print('회원가입 요청 URL: $_baseUrl${Constants.joinRequestEndpoint}');

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
      throw Exception('회원가입 요청 실패: $e');
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

  // 휴가 캘린더 조회
  Future<Map<String, dynamic>> getVacationCalendar({
    required String startDate,
    required String endDate,
    String roleFilter = 'all',
    String? nameFilter,
  }) async {
    try {
      final queryParams = {
        'startDate': startDate,
        'endDate': endDate,
        'roleFilter': roleFilter,
      };

      if (nameFilter != null && nameFilter.isNotEmpty) {
        queryParams['nameFilter'] = nameFilter;
      }

      final uri = Uri.parse(
        '$_baseUrl${Constants.vacationCalendarEndpoint}',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse(response);
    } catch (e) {
      throw Exception('휴가 캘린더 조회 실패: $e');
    }
  }

  // 특정 날짜 휴가 조회
  Future<Map<String, dynamic>> getVacationForDate({
    required String date,
    String role = 'CAREGIVER',
    String? nameFilter,
  }) async {
    try {
      final queryParams = {'role': role};

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
    String? userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl${Constants.vacationSubmitEndpoint}'),
        headers: await _getHeaders(),
        body: json.encode({
          'userName': userName,
          'date': date,
          'type': type,
          'reason': reason,
          'role': role,
          'password': password,
          'userId': userId,
        }),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('휴가 신청 실패: $e');
    }
  }

  // 기존 일반적인 메서드들
  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: await _getHeaders(),
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
  }) async {
    try {
      final queryParams = {'start': start, 'end': end};

      final uri = Uri.parse(
        '$_baseUrl${Constants.vacationLimitsEndpoint}',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: await _getHeaders());

      return _handleResponse(response);
    } catch (e) {
      throw Exception('휴가 제한 조회 실패: $e');
    }
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

        // 특정 에러 상태에 대한 의미있는 메시지 제공
        String errorMessage;
        switch (response.statusCode) {
          case 400:
            errorMessage = '이미 가입 요청된 사용자이거나 잘못된 요청입니다.';
            break;
          case 401:
            errorMessage = '인증이 필요합니다.';
            break;
          case 403:
            errorMessage = '접근 권한이 없습니다.';
            break;
          case 404:
            errorMessage = '요청한 리소스를 찾을 수 없습니다.';
            break;
          case 500:
            errorMessage = '서버 내부 오류가 발생했습니다.';
            break;
          default:
            errorMessage = '서버에서 빈 응답을 반환했습니다';
        }

        throw ApiException(errorMessage, response.statusCode);
      }
    }

    try {
      final responseData = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('API 요청 성공 - 응답 데이터 반환');
        return responseData;
      } else {
        print('API 요청 실패 - 에러 처리');
        // Spring Boot API 에러 형식에 맞춰 에러 처리
        final errorMessage =
            responseData['error'] ?? responseData['message'] ?? 'API 요청 실패';
        throw ApiException(errorMessage, response.statusCode);
      }
    } catch (e) {
      print('JSON 파싱 에러: $e');
      if (e is FormatException) {
        throw ApiException(
          '서버 응답을 파싱할 수 없습니다: ${response.body}',
          response.statusCode,
        );
      } else {
        rethrow;
      }
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
