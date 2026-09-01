import '../models/chat_message.dart';

/// 채팅 메시지 목록(최신이 index 0인 reverse 순서)에서
/// 날짜 구분선·발신자 그룹 경계를 계산하는 순수 함수 모음.
///
/// [chat_room_screen.dart]의 `ListView.builder`(reverse: true)가 그대로 사용한다.
/// 위젯 트리와 분리해 둔 이유는 로직만 따로 단위 테스트하기 위해서다.

/// 두 시각이 같은 날(연·월·일)인지 확인한다.
bool isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// [index]에 해당하는 메시지 "위"(화면상 더 오래된 쪽)에 날짜 구분선을
/// 넣어야 하는지 판정한다.
///
/// reverse: true 리스트이므로 messages[index + 1]이 시간상 더 이전 메시지다.
/// - 마지막 인덱스(가장 오래된 메시지)는 항상 구분선이 필요하다.
/// - 그 외에는 바로 이전(index+1) 메시지와 날짜가 다를 때 필요하다.
bool shouldShowDateSeparatorAbove(List<ChatMessage> messages, int index) {
  if (index < 0 || index >= messages.length) return false;
  if (index == messages.length - 1) return true;
  return !isSameDate(messages[index].createdAt, messages[index + 1].createdAt);
}

/// 오늘/어제/"YYYY년 M월 D일 (요일)" 형식의 날짜 구분선 문구를 만든다.
/// [now]는 테스트에서 "오늘"을 고정하기 위한 파라미터(기본값은 실제 현재 시각).
String formatDateSeparatorLabel(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final target = DateTime(date.year, date.month, date.day);
  final base = DateTime(today.year, today.month, today.day);
  final diffDays = base.difference(target).inDays;

  if (diffDays == 0) return '오늘';
  if (diffDays == 1) return '어제';

  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  final weekday = weekdays[date.weekday - 1];
  return '${date.year}년 ${date.month}월 ${date.day}일 ($weekday)';
}

/// [index] 메시지가 "발신자 헤더(아바타·이름·직종)"를 그려야 하는 그룹의
/// 첫 메시지(시간상 가장 이른 메시지)인지 판정한다.
///
/// 다음 중 하나라도 해당하면 그룹의 시작으로 본다:
/// - 가장 오래된 메시지(index가 마지막)
/// - 바로 이전(index+1, 시간상 더 이전) 메시지의 발신자가 다르다
/// - 바로 이전 메시지가 시스템 메시지다(또는 이 메시지가 시스템 메시지)
/// - 바로 이전 메시지와 날짜가 다르다(날짜 구분선이 그룹을 끊는다)
bool isSenderGroupStart(List<ChatMessage> messages, int index) {
  if (index < 0 || index >= messages.length) return false;
  if (index == messages.length - 1) return true;

  final message = messages[index];
  final previous = messages[index + 1]; // 시간상 더 이전 메시지

  if (message.type == MessageType.system ||
      previous.type == MessageType.system) {
    return true;
  }
  if (previous.senderId != message.senderId) return true;
  if (!isSameDate(message.createdAt, previous.createdAt)) return true;

  return false;
}
