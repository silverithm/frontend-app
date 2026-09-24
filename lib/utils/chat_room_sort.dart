import '../models/chat_room.dart';

/// 채팅방 목록 정렬 — 목록을 (다시) 정렬하는 곳은 전부 이 비교자 하나를 쓴다.
///
/// 규칙: 상단 고정 방이 먼저, 그 안에서는 기존 활동순(최근 메시지 우선).
/// 고정이 아닌 방도 마찬가지. 새 메시지가 오면 그 방은 "자기 그룹" 안에서만
/// 맨 위로 온다 — 고정 방에 새 메시지가 와도 고정 안 된 방보다 위인 건 그대로,
/// 고정 안 된 방에 새 메시지가 와도 고정 방들보다 위로 튀어 오르지 않는다.
int compareChatRooms(ChatRoom a, ChatRoom b) {
  if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
  final aTime = a.lastMessageAt ?? a.createdAt;
  final bTime = b.lastMessageAt ?? b.createdAt;
  return bTime.compareTo(aTime);
}

/// [rooms]를 제자리에서 정렬하고 그대로 돌려준다 — 호출부에서 체이닝하기 좋게.
List<ChatRoom> sortChatRooms(List<ChatRoom> rooms) {
  rooms.sort(compareChatRooms);
  return rooms;
}

/// 단일 방 조회·소켓 메시지 응답으로 받은 [incoming]에는 pinned/pinnedAt이
/// 실려 오지 않는다(서버 계약). 그대로 덮어쓰면 고정이 풀린 것처럼 보이므로
/// 기존에 갖고 있던 [current]의 값을 이어받는다.
ChatRoom mergeRoomPreservingPin(ChatRoom current, ChatRoom incoming) {
  return incoming.copyWith(
    pinned: current.pinned,
    pinnedAt: current.pinnedAt,
    clearPinnedAt: current.pinnedAt == null,
  );
}
