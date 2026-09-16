import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_app/utils/api_response_parser.dart';

void main() {
  group('parseApiResponseBody', () {
    test('2xx + 빈 본문 → 빈 맵', () {
      final result = parseApiResponseBody(statusCode: 200, body: '');
      expect(result, <String, dynamic>{});
    });

    test('2xx + JSON 객체 → 그 객체', () {
      final result = parseApiResponseBody(
        statusCode: 200,
        body: '{"id": 1, "name": "test"}',
      );
      expect(result, {'id': 1, 'name': 'test'});
    });

    test('2xx + 순수 텍스트(비 JSON) 본문 → 빈 맵(성공)', () {
      final result = parseApiResponseBody(statusCode: 200, body: 'Success');
      expect(result, <String, dynamic>{});
    });

    test('2xx + JSON이지만 객체가 아닌 본문(문자열 리터럴) → 빈 맵(성공)', () {
      final result = parseApiResponseBody(statusCode: 201, body: '"OK"');
      expect(result, <String, dynamic>{});
    });

    test('에러 상태코드 + JSON 에러 메시지 → 예외', () {
      expect(
        () => parseApiResponseBody(
          statusCode: 400,
          body: '{"message": "잘못된 요청"}',
        ),
        throwsA(
          isA<ApiParseException>()
              .having((e) => e.message, 'message', '잘못된 요청')
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });

    test('에러 상태코드 + 빈 본문 → 기본 메시지로 예외', () {
      expect(
        () => parseApiResponseBody(statusCode: 500, body: ''),
        throwsA(isA<ApiParseException>().having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('에러 상태코드 + 비 JSON 본문 → 예외', () {
      expect(
        () => parseApiResponseBody(statusCode: 500, body: 'Internal Server Error'),
        throwsA(isA<ApiParseException>()),
      );
    });
  });
}
