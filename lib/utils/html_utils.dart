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

// ─────────────────────────────────────────────────────────────────────────────
// 서식 본문(HTML) 정규화 — 같은 글이 웹과 앱에서 다른 높이로 그려지는 문제를 막는다.
// ─────────────────────────────────────────────────────────────────────────────

/// 군더더기를 덜어낼 블록 태그. `<br>`이 끝에 붙어도 줄을 만들지 않는 것들이다.
final RegExp _blankLineBlock = RegExp(
  r'<(div|p|li|blockquote)\b[^>]*>\s*<br\s*/?>\s*</\1\s*>',
  caseSensitive: false,
);

/// 블록 닫는 태그 바로 앞의 `<br>` 하나. 브라우저는 이 줄바꿈을 그리지 않는다.
final RegExp _trailingBrInBlock = RegExp(
  r'\s*<br\s*/?>(?=\s*</(?:div|p|li|blockquote)\s*>)',
  caseSensitive: false,
);

/// 문서 맨 끝의 군더더기 하나 — 공백, 떠 있는 `<br>`, 빈 블록/빈 줄 블록.
final RegExp _trailingNoise = RegExp(
  r'(?:\s+|<br\s*/?>|<(div|p|li|blockquote)\b[^>]*>(?:\s|&nbsp;|<br\s*/?>)*</\1\s*>)$',
  caseSensitive: false,
);

/// 지우는 규칙이 건드리면 안 되는 조각을 잠시 치워 둘 자리표시자.
final RegExp _maskSlot = RegExp(r'\u0000(\d+)\u0000');

/// 웹 에디터가 남긴 HTML을 '브라우저가 그리는 모양'에 맞춰 정리한다.
///
/// 왜 필요한가 — flutter_html은 `<br>`을 언제나 하드 개행으로 그린다. 브라우저에는
/// "블록 끝에 붙은 `<br>`은 줄을 만들지 않는다"는 규칙이 있는데 그게 없다. 그래서
/// 크롬 contentEditable이 남기는 `<div>첫째<br></div><div>둘째<br></div>`가
/// 웹에서는 두 줄, 앱에서는 네 줄이 된다. "수정하면 세로로 길어진다"는 신고의 실체다.
/// 이미 DB에 쌓인 글까지 고쳐야 하므로 저장이 아니라 **그리기 직전**에 손본다.
///
/// 글자와 서식 태그는 건드리지 않고, 보이지 않는 군더더기만 덜어낸다.
/// 몇 번을 돌려도 결과가 같다(멱등) — 표시·편집 어느 쪽에 끼워 넣어도 안전하도록.
String normalizeNoticeHtml(String html) {
  if (html.isEmpty) return html;
  var out = html;
  // 상한 — 규칙끼리 서로를 되살리는 입력이 와도 멈춘다.
  for (var i = 0; i < 20; i++) {
    final next = _trimTrailingNoise(_stripTrailingBrInBlocks(out));
    if (next == out) break;
    out = next;
  }
  return out;
}

/// 블록 끝에 붙은 `<br>`을 변화가 없을 때까지 덜어낸다.
/// 단 내용이 `<br>` 하나뿐인 블록(`<div><br></div>`)은 일부러 넣은 빈 줄이라 남긴다 —
/// 그래서 `<div>글<br><br></div>`는 `<div>글</div>`로, `<div><br><br></div>`는
/// `<div><br></div>`로 수렴한다(고정점이 하나여야 멱등이 된다).
String _stripTrailingBrInBlocks(String html) {
  var out = html;
  for (var i = 0; i < 50; i++) {
    final kept = <String>[];
    final masked = out.replaceAllMapped(_blankLineBlock, (match) {
      kept.add(match[0]!);
      return '\u0000${kept.length - 1}\u0000';
    });
    final stripped = masked.replaceAll(_trailingBrInBlock, '');
    final restored = stripped.replaceAllMapped(
      _maskSlot,
      (match) => kept[int.parse(match[1]!)],
    );
    if (restored == out) return out;
    out = restored;
  }
  return out;
}

/// 문서 맨 끝에 쌓인 빈 줄을 걷어낸다. 한 번에 하나씩 떼어 내며 더 뗄 게 없을 때 멈춘다.
String _trimTrailingNoise(String html) {
  var out = html;
  for (var i = 0; i < 200; i++) {
    final next = out.replaceFirst(_trailingNoise, '');
    if (next == out) return out;
    out = next;
  }
  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// 평문 편집창 ↔ HTML 본문 — 앱에는 서식 편집기가 없어서 평문으로 오가며 고친다.
// ─────────────────────────────────────────────────────────────────────────────

/// 블록 경계 표시. 여러 개가 붙어 있어도 줄바꿈 한 번으로 친다.
const String _blockBoundaryMark = '\u0001';

final RegExp _blockBoundaryTag = RegExp(
  r'</?(?:p|div|li|ul|ol|blockquote|h[1-6]|table|tr|section|article|pre|hr)\b[^>]*>',
  caseSensitive: false,
);
final RegExp _brTagOnly = RegExp(r'<br\s*/?>', caseSensitive: false);
final RegExp _boundaryRun = RegExp('[ \t\r\n$_blockBoundaryMark]*'
    '$_blockBoundaryMark'
    '[ \t\r\n$_blockBoundaryMark]*');

/// 엔티티 복원. `&amp;`를 **마지막에** 풀어야 `&amp;lt;`가 `<`로 잘못 풀리지 않는다.
String _decodeEntities(String text) {
  final decoded = text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");
  return decoded.replaceAll('&amp;', '&');
}

/// HTML 본문을 평문 TextField에 넣을 수 있는 글로 푼다 — **줄바꿈을 살려서**.
///
/// [stripHtmlToPlainText]는 미리보기용이라 줄바꿈까지 합쳐 버린다. 편집창은 다르다:
/// 웹에서 쓴 글을 앱에서 고칠 때 `<p>`·`<br>`이 날것으로 보이면 사용자가 그걸 지우거나
/// 같이 저장해 본문이 망가진다. 그래서 `<br>`과 블록 경계는 `\n`으로 살리고
/// 나머지 태그는 벗긴다.
///
/// **굵게·색 같은 서식은 이 변환에서 사라진다.** 앱에 서식 편집기가 없는 동안에는
/// 태그가 날것으로 보이는 것보다 낫다는 판단이다 (서식을 지키려면 웹에서 수정할 것).
String htmlToEditableText(String html) {
  if (html.isEmpty) return html;
  // 먼저 표시용과 같은 규칙으로 군더더기를 덜어낸다. 안 그러면 크롬이 남긴 블록 끝
  // `<br>`이 편집창에서 빈 줄로 되살아나, 열었다 저장할 때마다 글이 길어진다.
  var text = normalizeNoticeHtml(html);
  text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  text = text.replaceAll(_brTagOnly, '\n');
  text = text.replaceAll(_blockBoundaryTag, _blockBoundaryMark);
  text = text.replaceAll(_anyTag, '');
  text = _decodeEntities(text);
  // 블록 경계는 몇 개가 붙어 있든 줄바꿈 한 번. 다만 그 사이에 끼어 있던 `<br>`
  // (= 일부러 넣은 빈 줄)은 그만큼 줄 수를 늘려 준다.
  text = text.replaceAllMapped(_boundaryRun, (match) {
    final hardBreaks = '\n'.allMatches(match[0]!).length;
    return '\n' * (hardBreaks + 1);
  });
  return text.trim();
}

/// 평문을 본문 HTML로 되돌린다 — 웹 `src/lib/noticeContent.ts`의 `toEditorHtml`과
/// 같은 규칙(이스케이프한 뒤 줄바꿈을 `<br>`로).
///
/// 원래 HTML로 저장돼 있던 글을 앱의 평문 편집창에서 고쳤을 때, 평문 그대로 덮어쓰면
/// 웹 목록·상세가 한 줄로 뭉쳐 보인다. 그래서 들어온 모양(HTML)에 맞춰 돌려놓는다.
String plainTextToHtml(String text) {
  if (text.isEmpty) return text;
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\n', '<br>');
}
