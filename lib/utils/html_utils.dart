/// 커뮤니티 게시글 `content`는 웹 리치텍스트 에디터가 저장한 HTML 문자열이다.
/// 목록 화면 미리보기 등 태그 없는 평문이 필요한 곳에서 이 유틸로 태그를 제거한다.
/// (본문 전체 렌더링은 `PlazaHtmlBody`(flutter_html)를 쓴다 — 이 파일은 순수 텍스트 변환만 담당)
library;

/// 서식(HTML) 본문인지 — 공지는 오랫동안 평문으로 쌓여 와서, 태그가 있는 글만
/// HTML로 렌더링하고 나머지는 평문 그대로 둔다 (웹 isRichText와 같은 판정).
final RegExp _richTextTag = RegExp(
    r'<(p|div|br|span|font|b|strong|i|em|u|s|ul|ol|li|a|blockquote)\b',
    caseSensitive: false);

bool containsHtmlTags(String content) => _richTextTag.hasMatch(content);

final RegExp _blockBreakTag =
    RegExp(r'<(br|/p|/div|/li|/h[1-6])\s*/?>', caseSensitive: false);
final RegExp _anyTag = RegExp(r'<[^>]*>');
final RegExp _extraWhitespace = RegExp(r'[ \t]+');
final RegExp _extraNewlines = RegExp(r'\n{2,}');

const Map<String, String> _htmlEntities = {
  '&nbsp;': ' ',
  '&amp;': '&',
  '&lt;': '<',
  '&gt;': '>',
  '&quot;': '"',
  '&#39;': "'",
  '&apos;': "'",
};

/// HTML 문자열을 태그가 제거된 평문으로 변환한다. 블록 태그(`<p>`, `<br>` 등)는
/// 줄바꿈으로 치환해 문장 구분이 이어져 붙지 않게 한다.
String stripHtmlToPlainText(String html) {
  if (html.isEmpty) return html;
  var text = html.replaceAll(_blockBreakTag, '\n');
  text = text.replaceAll(_anyTag, '');
  _htmlEntities.forEach((entity, replacement) {
    text = text.replaceAll(entity, replacement);
  });
  text = text.replaceAll(_extraWhitespace, ' ');
  text = text.replaceAll(_extraNewlines, '\n');
  return text.trim();
}

/// 목록 카드용 한 줄(또는 두 줄) 미리보기 — 줄바꿈도 공백으로 합쳐 짧게 자른다.
String htmlToPreviewText(String html, {int maxLength = 80}) {
  final plain = stripHtmlToPlainText(html).replaceAll('\n', ' ').trim();
  if (plain.length <= maxLength) return plain;
  return '${plain.substring(0, maxLength)}…';
}
