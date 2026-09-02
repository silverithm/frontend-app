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


// ---------------------------------------------------------------------------
// 사진 묶음 (카톡처럼 연속 사진을 한 칸에 격자로)
// ---------------------------------------------------------------------------

/// 연속으로 본다고 인정하는 최대 간격.
///
/// 사진을 여러 장 고르면 앱이 한 장씩 차례로 올린다(동시 3장, `_maxConcurrentUploads`).
/// 현장 회선에서 5장이면 20~30초까지 벌어지므로 그걸 넉넉히 덮는 값이 필요하다.
/// 반대로 1분을 넘겨 올라온 사진은 "이어 붙인 한 묶음"이 아니라 새로 꺼낸 이야기로 읽힌다.
const Duration photoGroupMaxGap = Duration(seconds: 60);

/// 한 묶음에 담는 최대 장수.
///
/// 3×3이면 말풍선 하나가 화면 한 칸을 넘지 않는다. 10장째는 "+N"으로 덮어 감추지 않고
/// **새 묶음을 시작한다** — 그래야 모든 사진이 눌러서 열 수 있는 상태로 남는다.
const int photoGroupMaxCount = 9;

/// 사진 묶음에 들어갈 수 있는 메시지인지.
/// 동영상은 재생 타일이 따로 필요하므로 묶지 않는다.
bool _isGroupablePhoto(ChatMessage m) {
  if (m.isDeleted) return false;
  if (!m.isPhotoMessage) return false;
  final url = m.fileUrl;
  return url != null && url.isNotEmpty;
}

/// 바로 이어지는 사진 [newer]를 [older] 뒤에 같은 묶음으로 이어붙일 수 있는지.
bool _canFollow(ChatMessage older, ChatMessage newer) {
  if (older.senderId != newer.senderId) return false;
  // 날짜 구분선을 절대 넘지 않는다. 60초 간격이어도 자정을 넘길 수 있다
  // (23:59:40 → 00:00:10은 30초 차이지만 다른 날이다).
  if (!isSameDate(older.createdAt, newer.createdAt)) return false;
  final gap = newer.createdAt.difference(older.createdAt);
  if (gap.isNegative) return false;
  return gap <= photoGroupMaxGap;
}

/// reverse 목록(0 = 최신)에서 사진 묶음을 찾아 **인덱스 → 그 묶음** 표로 돌려준다.
///
/// 묶음 안의 인덱스는 **오래된 것부터**(=인덱스가 큰 것부터) 담긴다. 즉 `group.first`가
/// 시간상 가장 이른 사진이고, 화면에서는 그 자리에 격자를 그린다. 날짜 구분선과
/// 발신자 헤더 판정이 모두 "그 묶음의 가장 오래된 메시지" 기준이라 이렇게 맞춰야
/// 기존 규칙과 어긋나지 않는다.
///
/// 두 장 미만이면 묶음이 아니므로 표에 넣지 않는다(그때는 지금처럼 한 장짜리 말풍선).
Map<int, List<int>> buildPhotoGroupMap(List<ChatMessage> messages) {
  final result = <int, List<int>>{};
  var current = <int>[];

  void flush() {
    if (current.length >= 2) {
      final group = List<int>.unmodifiable(current);
      for (final index in group) {
        result[index] = group;
      }
    }
    current = <int>[];
  }

  // 오래된 끝(인덱스가 큰 쪽)에서 최신 쪽으로 훑는다. 방향을 고정해야
  // 최대 장수에서 잘리는 지점이 항상 같은 자리로 정해진다.
  for (var i = messages.length - 1; i >= 0; i--) {
    final message = messages[i];
    if (!_isGroupablePhoto(message)) {
      flush();
      continue;
    }
    if (current.isEmpty) {
      current.add(i);
      continue;
    }
    final previous = messages[current.last];
    if (current.length >= photoGroupMaxCount || !_canFollow(previous, message)) {
      flush();
    }
    current.add(i);
  }
  flush();

  return result;
}
