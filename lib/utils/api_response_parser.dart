/// API 응답 본문 파싱 — ApiService._handleResponse의 순수 로직.
///
/// 네트워크 없이 단위 테스트하기 위해 분리했다.
library;

import 'dart:convert';

/// API 예외. api_service.dart의 ApiException과 같은 모양이라 그대로 던지고 받을 수 있다.
class ApiParseException implements Exception {
  final String message;
  final int statusCode;

  ApiParseException(this.message, this.statusCode);

  @override
  String toString() => 'ApiParseException: $message (Status: $statusCode)';
}

String defaultApiErrorMessage(int statusCode, [String? fallbackMessage]) {
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
      return fallbackMessage ?? 'API 요청 실패 ($statusCode)';
  }
}

/// [statusCode]/[body]를 파싱한다.
///
/// - 2xx + 빈 본문 → `{}`
/// - 2xx + JSON 객체 본문 → 그 객체
/// - 2xx + JSON이 아니거나 객체가 아닌 본문(예: 순수 텍스트 "Success") → `{}`
///   (백엔드가 가끔 상태 문자열만 돌려주는 엔드포인트가 있다 — 이걸 실패로
///   취급하면 실제로는 성공한 요청이 에러로 잘못 보고된다)
/// - 에러 상태코드 → ApiParseException을 던진다 (JSON 본문의 error/message를 우선 사용)
Map<String, dynamic> parseApiResponseBody({
  required int statusCode,
  required String body,
}) {
  final isSuccess = statusCode >= 200 && statusCode < 300;

  if (body.isEmpty) {
    if (isSuccess) return {};
    throw ApiParseException(
      defaultApiErrorMessage(statusCode, '서버에서 빈 응답을 반환했습니다'),
      statusCode,
    );
  }

  Object? decoded;
  try {
    decoded = json.decode(body);
  } on FormatException {
    if (isSuccess) return {};
    throw ApiParseException(
      defaultApiErrorMessage(statusCode, '서버 응답을 파싱할 수 없습니다'),
      statusCode,
    );
  }

  if (decoded is! Map) {
    // JSON이지만 객체가 아님(문자열/숫자/배열/불리언 등) — 2xx면 성공으로 본다.
    if (isSuccess) return {};
    throw ApiParseException(
      defaultApiErrorMessage(statusCode, 'API 요청 처리 중 오류가 발생했습니다'),
      statusCode,
    );
  }

  final map = Map<String, dynamic>.from(decoded);
  if (isSuccess) return map;

  final errorMessage =
      map['error'] ?? map['message'] ?? defaultApiErrorMessage(statusCode);
  throw ApiParseException(errorMessage.toString(), statusCode);
}
