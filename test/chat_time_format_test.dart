import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/utils/chat_time_format.dart';

void main() {
  final now = DateTime(2026, 10, 9, 18, 0);

  group('formatChatDateTime', () {
    test('오늘이면 시각만', () {
      expect(formatChatDateTime(DateTime(2026, 10, 9, 14, 21), now: now), '오후 2:21');
    });
    test('다른 날은 M월 d일을 붙인다', () {
      expect(formatChatDateTime(DateTime(2026, 10, 3, 14, 21), now: now), '10월 3일 오후 2:21');
    });
    test('자정과 정오', () {
      expect(formatChatClock(DateTime(2026, 1, 1, 0, 5)), '오전 12:05');
      expect(formatChatClock(DateTime(2026, 1, 1, 12, 0)), '오후 12:00');
    });
    test('작년 이전은 연도를 붙인다', () {
      expect(formatChatDateTime(DateTime(2025, 12, 31, 9, 0), now: now), '2025년 12월 31일 오전 9:00');
    });
  });
}
