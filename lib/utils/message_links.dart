/// 메시지 글 속에서 링크를 찾아 낸다.
///
/// 채팅에 링크를 붙여 넣어도 그냥 글자였다 — 눌러도 아무 일이 없었다.
/// 웹과 앱이 **같은 규칙**으로 찾아야 한 쪽에서만 링크로 보이는 일이 없다.
/// (같은 정규식을 웹 `src/lib/messageLinks.ts`에도 둔다)
library;

/// 한 조각의 글 — 링크이거나 그냥 글자다.
class MessageSpan {
  final String text;
  final bool isLink;

  /// 실제로 열 주소. `www.`로 시작하면 https를 붙인다.
  final String? url;

  const MessageSpan(this.text, {this.isLink = false, this.url});
}

/// http(s):// 로 시작하거나 www. 로 시작하는 것을 링크로 본다.
///
/// 끝의 문장부호는 링크에서 뺀다 — "여기 봐: https://a.com." 에서 마침표까지
/// 링크에 넣으면 열리지 않는다. 괄호는 짝이 맞을 때만 남긴다.
final RegExp _linkPattern = RegExp(
  r'(https?://[^\s<>"]+|www\.[^\s<>"]+)',
  caseSensitive: false,
);

/// 링크 끝에서 떼어낼 문장부호
const String _trailing = '.,;:!?)]}\'"…';

String _trimTrailing(String raw) {
  var s = raw;
  while (s.isNotEmpty && _trailing.contains(s[s.length - 1])) {
    // 괄호는 짝이 맞으면 링크의 일부다 (위키 주소 등)
    final last = s[s.length - 1];
    if (last == ')' && '('.allMatches(s).length > ')'.allMatches(s).length - 1) break;
    if (last == ']' && '['.allMatches(s).length > ']'.allMatches(s).length - 1) break;
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// 글을 링크와 글자 조각으로 쪼갠다. 링크가 없으면 통짜 한 조각이다.
List<MessageSpan> splitMessageLinks(String text) {
  if (text.isEmpty) return const [];

  final spans = <MessageSpan>[];
  var cursor = 0;

  for (final m in _linkPattern.allMatches(text)) {
    final raw = m.group(0)!;
    final trimmed = _trimTrailing(raw);
    if (trimmed.isEmpty) continue;

    if (m.start > cursor) {
      spans.add(MessageSpan(text.substring(cursor, m.start)));
    }

    final url = trimmed.toLowerCase().startsWith('www.') ? 'https://$trimmed' : trimmed;
    spans.add(MessageSpan(trimmed, isLink: true, url: url));

    cursor = m.start + trimmed.length;
  }

  if (cursor < text.length) {
    spans.add(MessageSpan(text.substring(cursor)));
  }

  return spans.isEmpty ? [MessageSpan(text)] : spans;
}

/// 글에서 첫 번째 링크. 미리보기를 붙일 대상이다 (없으면 null).
String? firstLinkOf(String text) {
  for (final span in splitMessageLinks(text)) {
    if (span.isLink) return span.url;
  }
  return null;
}
