/// 날짜로 이동(서버에 그 날짜의 첫 메시지 id를 물어보고, 목록에서 그 자리를
/// 찾아갈 때까지 옛 대화를 페이지 단위로 더 불러오는) 기능의 순수 로직.
///
/// 화면쪽(_jumpToMessage)과 공용으로 쓰되, 날짜 점프는 답장 인용문 점프보다
/// 훨씬 더 오래된 대화까지 거슬러 올라갈 수 있어(몇 달 전 특정 날짜) 시도
/// 횟수 상한을 넉넉하게 둔다. [ChatDateJump.maxLoadTries]에서 그 값을 관리한다.
library;

/// 'YYYY-MM-DD' — 서버 계약(GET .../first-on-date?date=YYYY-MM-DD)에 맞춘 형식.
/// intl의 DateFormat을 새로 끌어오지 않고 직접 0-패딩한다.
String formatChatDateQuery(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// 답장 인용문 점프(최대 5쪽)보다 훨씬 넉넉한 상한.
/// 날짜로 이동은 몇 달 전 대화를 목표로 삼는 일이 흔해, 페이지당 메시지 수가
/// 적은 방에서는 5쪽으로 턱없이 부족하다 — 대신 무한정 받지는 않도록 상한만 둔다.
const int chatDateJumpMaxLoadTries = 30;

/// 아직 화면에 자리가 없는 목표 메시지를 찾기 위해 옛 대화를 한 쪽 더
/// 불러와야 하는지 판단한다. (순수 함수 — 단위 테스트 대상)
bool shouldKeepLoadingForDateJump({
  required bool found,
  required bool hasMore,
  required int triesSoFar,
  int maxTries = chatDateJumpMaxLoadTries,
}) {
  if (found) return false;
  if (!hasMore) return false;
  return triesSoFar < maxTries;
}
