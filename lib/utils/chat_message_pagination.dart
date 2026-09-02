import '../models/chat_message.dart';

/// 과거 메시지 페이지를 현재 목록(최신이 index 0인 reverse 순서)의 뒤,
/// 즉 더 오래된 쪽에 이어 붙인다.
///
/// 서버 페이지네이션은 "최신에서 N번째"를 기준으로 자르기 때문에, 목록을
/// 보고 있는 동안 새 메시지가 들어오면 페이지 경계가 그만큼 밀려 이미 갖고
/// 있는 메시지가 다음 페이지에 다시 내려온다. 그대로 이어 붙이면
///
///  - 같은 메시지가 두 번 보이고,
///  - ListView가 쓰는 ValueKey(id)가 중복돼 목록 자체가 깨진다
///    (= "옛날 기록으로 안 올라가진다"의 실제 모습).
///
/// 그래서 이미 갖고 있는 id는 버리고 새 것만 이어 붙인다.
/// 화면에 떠 있는 전송 중(local) 메시지는 아직 서버 id가 없으므로
/// 여기서 걸러지지 않고 그대로 남는다.
void appendOlderMessages(
  List<ChatMessage> messages,
  List<ChatMessage> older,
) {
  final knownIds = messages.map((m) => m.id).toSet();
  for (final message in older) {
    if (knownIds.add(message.id)) {
      messages.add(message);
    }
  }
}

/// 지금 스크롤 위치에서 옛 대화 한 페이지를 더 불러와야 하는지 판단한다.
///
/// 메시지 목록은 `reverse: true`라서 **maxScrollExtent 쪽이 가장 오래된 끝**이다
/// (pixels 0 = 맨 아래 = 최신). 그래서 "위로 올렸다"는 pixels가 maxScrollExtent에
/// 가까워지는 것으로 나타난다 — 보통의 목록과 반대라 헷갈리기 쉬운 지점이고,
/// 실제로 이 판단이 뒤집히면 아무리 올려도 옛 대화가 안 붙는다.
///
/// [threshold]만큼 미리 당겨서 부르는 이유는 사용자가 끝에 닿기 전에 다음 장이
/// 준비되게 하기 위해서다.
bool shouldLoadOlderMessages({
  required double pixels,
  required double maxScrollExtent,
  required bool hasMore,
  required bool isLoadingOlder,
  double threshold = 200,
}) {
  if (!hasMore || isLoadingOlder) return false;
  return pixels >= maxScrollExtent - threshold;
}
