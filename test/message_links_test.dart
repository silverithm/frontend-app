import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/utils/message_links.dart';

/// 웹(src/lib/messageLinks.test.ts)과 **같은 경우를 같은 답으로** 봐야 한다.
/// 한 쪽에서만 링크로 보이면 "폰에선 눌리는데 컴퓨터에선 안 눌린다"가 된다.
void main() {
  List<String> links(String s) => splitMessageLinks(s)
      .where((x) => x.isLink)
      .map((x) => x.url!)
      .toList();

  test('http/https 링크를 찾는다', () {
    expect(links('여기 보세요 https://carev.kr/admin 감사합니다'), ['https://carev.kr/admin']);
    expect(links('http://example.com'), ['http://example.com']);
  });

  test('www.로 시작하면 https를 붙여 연다', () {
    expect(links('www.carev.kr 확인'), ['https://www.carev.kr']);
  });

  test('문장 끝 마침표는 링크에서 뺀다 — 안 그러면 안 열린다', () {
    expect(links('자료는 https://carev.kr/guide.'), ['https://carev.kr/guide']);
    expect(links('여기: https://carev.kr,'), ['https://carev.kr']);
    expect(links('진짜? https://carev.kr?'), ['https://carev.kr']);
  });

  test('주소 안의 물음표·슬래시는 남긴다', () {
    expect(links('https://carev.kr/s?q=1&p=2 확인'), ['https://carev.kr/s?q=1&p=2']);
  });

  test('한 메시지에 링크가 여럿이면 다 찾는다', () {
    expect(links('https://a.com 과 https://b.com 둘 다'), ['https://a.com', 'https://b.com']);
  });

  test('링크가 없으면 통짜 한 조각이다', () {
    final spans = splitMessageLinks('오늘 회의는 3시입니다');
    expect(spans.length, 1);
    expect(spans.first.isLink, false);
  });

  test('글과 링크가 순서대로 쪼개진다 — 화면에 그대로 그린다', () {
    final spans = splitMessageLinks('앞 https://a.com 뒤');
    expect(spans.map((s) => s.text).toList(), ['앞 ', 'https://a.com', ' 뒤']);
    expect(spans.map((s) => s.isLink).toList(), [false, true, false]);
  });

  test('한글이 붙어 있어도 링크를 찾는다', () {
    expect(links('공지https://carev.kr/notice 참고'), ['https://carev.kr/notice']);
  });

  test('빈 글은 조각이 없다', () {
    expect(splitMessageLinks(''), isEmpty);
  });

  test('firstLinkOf는 첫 링크만 준다 — 미리보기를 붙일 대상', () {
    expect(firstLinkOf('https://a.com 과 https://b.com'), 'https://a.com');
    expect(firstLinkOf('링크 없음'), isNull);
  });
}
