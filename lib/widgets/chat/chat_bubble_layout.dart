import '../../models/chat_message.dart';
import '../../theme/app_spacing.dart';
import '../../utils/chat_message_grouping.dart';

/// 말풍선 사이 간격·시각 표시 규칙(2026-10-27 채팅 2차 점검, R1-03).
///
/// 메시지 목록은 reverse 순서(index 0 = 최신)다. `messages[index + 1]`이 바로 위(더 오래된) 메시지,
/// `messages[index - 1]`이 바로 아래(더 새로운) 메시지다. 위젯과 분리해 규칙만 단위 테스트한다.

/// 같은 사람의 같은 분 안 연속 메시지 사이 — 한 덩어리로 읽히게 바짝 붙인다.
const double chatGapSameMinute = 2;

/// 같은 사람이지만 분이 바뀐 연속 메시지 사이.
const double chatGapSameSender = AppSpacing.space1;

/// 사람이 바뀌거나 시스템 안내·날짜 뒤에서 새 묶음이 시작될 때.
const double chatGapNewRun = AppSpacing.space4;

/// 시스템 안내 바로 아래 첫 메시지 — 안내 알약이 이미 아래 12px 여백을 가지고 있어 더하지 않는다.
const double chatGapAfterSystem = 0;

bool isSameMinute(DateTime a, DateTime b) =>
    isSameDate(a, b) && a.hour == b.hour && a.minute == b.minute;

/// [index] 메시지 위쪽 간격. 날짜 구분선이 위에 있으면 구분선 자신의 여백만 쓰므로 0.
double chatBubbleTopGap(List<ChatMessage> messages, int index) {
  if (index < 0 || index >= messages.length - 1) return 0;
  if (shouldShowDateSeparatorAbove(messages, index)) return 0;

  final current = messages[index];
  final previous = messages[index + 1];

  if (previous.type == MessageType.system) return chatGapAfterSystem;
  if (isSenderGroupStart(messages, index)) return chatGapNewRun;
  if (isSameMinute(current.createdAt, previous.createdAt)) {
    return chatGapSameMinute;
  }
  return chatGapSameSender;
}

/// 같은 사람의 같은 분 묶음에서 **마지막** 메시지인지 — 시각·안 읽은 수는 여기에만 붙인다.
bool isMinuteRunEnd(List<ChatMessage> messages, int index) {
  if (index <= 0 || index >= messages.length) return true;
  final current = messages[index];
  final next = messages[index - 1];
  if (next.type == MessageType.system) return true;
  if (next.senderId != current.senderId) return true;
  return !isSameMinute(current.createdAt, next.createdAt);
}

/// 남의 말풍선을 옅은 테두리로 그리는 대안(시안 비교 캡처 전용).
/// 기본은 false — 대화 바탕을 한 단계 낮추고 테두리 없이 그린다.
// ignore: prefer_const_declarations
bool chatOtherBubbleOutlined = false;
