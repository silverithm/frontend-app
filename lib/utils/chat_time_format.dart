/// 채팅 화면의 시각·날짜 표기 (순수 로직 — 단위 테스트 대상).
library;

/// '오전 9:05' / '오후 2:21' — 말풍선 옆 시각 표기.
String formatChatClock(DateTime time) {
  final hour = time.hour;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = hour < 12 ? '오전' : '오후';
  final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
  return '$period $displayHour:$minute';
}

/// 검색 결과·파일 목록처럼 날짜가 함께 필요한 곳의 표기.
/// 오늘이면 시각만('오후 2:21'), 아니면 '10월 3일 오후 2:21'.
/// 올해가 아니면 연도를 붙여 '2025년 10월 3일 오후 2:21'.
String formatChatDateTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final clock = formatChatClock(time);
  final sameDay = time.year == current.year &&
      time.month == current.month &&
      time.day == current.day;
  if (sameDay) return clock;
  final date = time.year == current.year
      ? '${time.month}월 ${time.day}일'
      : '${time.year}년 ${time.month}월 ${time.day}일';
  return '$date $clock';
}
