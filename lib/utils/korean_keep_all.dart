/// 한글을 낱말(띄어쓰기) 단위로만 줄바꿈하게 한다 — CSS `word-break: keep-all`과 같은 결과.
///
/// Flutter는 한글 음절 사이를 모두 줄을 바꿀 수 있는 자리로 봐서, 말풍선에서
/// "전 / 원 참석", "발송됩니 / 다."처럼 낱말이 쪼개졌다(2026-10-27 채팅 점검).
/// 낱말 안 한글 옆에 보이지 않는 U+2060(WORD JOINER)을 넣어 그 자리에서 끊지 않게 한다.
///
/// - 화면에 그리는 문자열에만 쓴다. 복사·검색·전송에는 원문을 쓴다.
/// - 한글 옆에만 넣는다 — 이모지 조합(❤️, 👨‍👩‍👧)·영숫자·URL 안쪽은 건드리지 않는다.
/// - 띄어쓰기·줄바꿈은 그대로 두고, 이미 넣은 문자열에 다시 돌려도 결과가 같다.
const String wordJoiner = '⁠';

const int _wordJoinerRune = 0x2060;

bool _isHangul(int rune) =>
    (rune >= 0xAC00 && rune <= 0xD7A3) || // 완성형 음절
    (rune >= 0x1100 && rune <= 0x11FF) || // 자모
    (rune >= 0x3130 && rune <= 0x318F) || // 호환 자모
    (rune >= 0xA960 && rune <= 0xA97F) ||
    (rune >= 0xD7B0 && rune <= 0xD7FF);

bool _isBreakable(int rune) =>
    rune == 0x20 || rune == 0x0A || rune == 0x0D || rune == 0x09 || rune == 0x3000;

String keepAll(String text) {
  if (text.isEmpty) return text;
  final runes = text.runes.toList();
  final out = StringBuffer();
  for (var i = 0; i < runes.length; i++) {
    final current = runes[i];
    out.writeCharCode(current);
    if (i + 1 >= runes.length) break;
    final next = runes[i + 1];
    if (current == _wordJoinerRune || next == _wordJoinerRune) continue;
    if (_isBreakable(current) || _isBreakable(next)) continue;
    if (_isHangul(current) || _isHangul(next)) out.write(wordJoiner);
  }
  return out.toString();
}
