/// 채팅 첨부가 사진인지 동영상인지 그냥 파일인지 가리는 단일 지점.
///
/// 서버는 저장된 메시지 타입(`type`)에 VIDEO를 두지 않는다. 이유는 두 가지다.
///  - 이미 배포된 앱의 `_parseMessageType`은 모르는 값을 `default:`에서 **text**로
///    떨어뜨린다(file이 아니다). 서버가 "VIDEO"를 내보내는 순간 구버전 앱에서
///    동영상은 첨부가 아니라 파일명만 적힌 맹탕 글이 되어 링크 자체가 사라진다.
///  - `chat_messages.type`이 MySQL ENUM이라 새 값을 쓰려면 마이그레이션이 먼저 돌아야 한다.
///
/// 그래서 서버는 응답에 **파생 필드 `mediaType`**(IMAGE/VIDEO/FILE)만 얹는다.
/// 이 파일은 그 값을 받되, 아직 새 서버가 안 올라간 경우와 옛 메시지를 위해
/// mimeType·확장자까지 순서대로 짚는다.
library;

/// 우리가 동영상으로 취급하는 확장자.
/// webm은 앱에서 예전부터 동영상으로 봐 왔으므로 그대로 둔다.
const Set<String> kVideoExtensions = {
  'mp4', 'mov', 'm4v', 'avi', 'mkv', 'webm', '3gp',
};

/// 파일명에서 확장자만 소문자로 뽑는다. 없으면 빈 문자열.
String fileExtensionOf(String fileName) {
  final idx = fileName.lastIndexOf('.');
  return idx >= 0 ? fileName.substring(idx + 1).toLowerCase() : '';
}

/// 파일명 확장자가 동영상인지.
bool isVideoFileName(String? fileName) {
  if (fileName == null || fileName.isEmpty) return false;
  return kVideoExtensions.contains(fileExtensionOf(fileName));
}
