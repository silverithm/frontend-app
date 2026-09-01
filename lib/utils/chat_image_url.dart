import '../models/chat_message.dart';

/// 채팅 목록(버블·파일함 썸네일)에 그릴 이미지 URL을 고르는 단일 지점.
///
/// 서버가 축소본(thumbnailUrl)을 내려주면 그걸 우선 쓰고, 없으면(예전 메시지,
/// 아직 만들어지지 않은 경우) 원본(fileUrl)으로 물러난다. **전체화면 보기는
/// 이 함수를 쓰지 않고 항상 message.fileUrl(원본)을 직접 써야 한다** —
/// 확대해서 보는데 축소본이 뜨면 안 되기 때문이다.
String? resolveChatImageUrl(ChatMessage message) {
  final thumbnail = message.thumbnailUrl?.trim();
  if (thumbnail != null && thumbnail.isNotEmpty) return thumbnail;
  return message.fileUrl;
}
