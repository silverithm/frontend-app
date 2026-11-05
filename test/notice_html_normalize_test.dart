import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/utils/html_utils.dart';

/// 같은 글이 웹과 앱에서 다른 높이로 그려지던 문제를 막는 규칙들.
///
/// flutter_html은 `<br>`을 언제나 하드 개행으로 그린다 — 브라우저의 "블록 끝 `<br>`은
/// 줄을 만들지 않는다"는 규칙이 없다. 그래서 크롬 contentEditable이 남기는
/// `<div>…<br></div>`가 앱에서만 글을 두 배로 늘려 왔다.
void main() {
  group('normalizeNoticeHtml', () {
    test('블록 끝에 붙은 <br>을 덜어낸다 — 신고된 "수정하면 길어진다"의 실체', () {
      expect(
        normalizeNoticeHtml('<div>첫째<br></div><div>둘째<br></div>'),
        '<div>첫째</div><div>둘째</div>',
      );
    });

    test('<p>·<li>·<blockquote>도 같은 규칙을 받는다', () {
      expect(normalizeNoticeHtml('<p>문단<br></p><p>다음<br></p>'),
          '<p>문단</p><p>다음</p>');
      expect(normalizeNoticeHtml('<ul><li>하나<br></li><li>둘<br></li></ul>'),
          '<ul><li>하나</li><li>둘</li></ul>');
      expect(normalizeNoticeHtml('<blockquote>인용<br></blockquote><p>뒤</p>'),
          '<blockquote>인용</blockquote><p>뒤</p>');
    });

    test('내용이 <br> 하나뿐인 블록은 일부러 넣은 빈 줄이라 남긴다', () {
      expect(
        normalizeNoticeHtml('<div>위<br></div><div><br></div><div>아래</div>'),
        '<div>위</div><div><br></div><div>아래</div>',
      );
    });

    test('블록 안 연속 <br>은 빈 줄 한 칸으로 수렴한다 — 고정점이 하나여야 멱등이 된다', () {
      expect(normalizeNoticeHtml('<div>글<br><br></div><p>뒤</p>'),
          '<div>글</div><p>뒤</p>');
      expect(normalizeNoticeHtml('<div><br><br></div><p>뒤</p>'),
          '<div><br></div><p>뒤</p>');
    });

    test('문서 맨 끝의 빈 줄·빈 블록·공백은 연속으로 걷어낸다', () {
      expect(
        normalizeNoticeHtml(
            '<div>본문</div><div><br></div><p><br></p><div></div>  \n'),
        '<div>본문</div>',
      );
      expect(normalizeNoticeHtml('<div>본문</div><br><br>'), '<div>본문</div>');
      expect(normalizeNoticeHtml('<p>본문</p><p>&nbsp;</p>'), '<p>본문</p>');
    });

    test('글자와 서식 태그는 건드리지 않는다', () {
      const html =
          '<p>안녕하세요 <strong>굵게</strong>와 <span style="color:#f00">빨강</span>입니다.</p>'
          '<p>줄 안의 <br> 줄바꿈은 그대로.</p>';
      expect(normalizeNoticeHtml(html), html);
    });

    test('<br> 뒤에 다른 블록이 오면 끝이 아니므로 건드리지 않는다', () {
      const html = '<div>앞<br><div>안쪽</div></div>';
      expect(normalizeNoticeHtml(html), html);
    });

    test('멱등 — 두 번 돌려도 결과가 같다', () {
      const inputs = [
        '<div>첫째<br></div><div>둘째<br></div>',
        '<div>글<br><br></div>',
        '<div><br><br></div><p>뒤</p>',
        '<div>본문</div><div><br></div><p><br></p>  ',
        '<p>그대로</p>',
        '',
      ];
      for (final input in inputs) {
        final once = normalizeNoticeHtml(input);
        expect(normalizeNoticeHtml(once), once, reason: '입력: $input');
      }
    });

    test('빈 문자열은 그대로 돌려준다', () {
      expect(normalizeNoticeHtml(''), '');
    });
  });

  group('htmlToEditableText', () {
    test('블록 경계와 <br>을 줄바꿈으로 살린다', () {
      expect(
        htmlToEditableText('<div>첫째<br></div><div>둘째<br></div>'),
        '첫째\n둘째',
      );
      expect(htmlToEditableText('<p>한 줄<br>두 줄</p>'), '한 줄\n두 줄');
    });

    test('일부러 넣은 빈 줄은 빈 줄로 남는다', () {
      expect(
        htmlToEditableText('<div>위</div><div><br></div><div>아래</div>'),
        '위\n\n아래',
      );
      expect(
        htmlToEditableText(
            '<div>위</div><div><br></div><div><br></div><div>아래</div>'),
        '위\n\n\n아래',
      );
    });

    test('서식 태그는 벗기고 글자만 남긴다 — 앱에서 고치면 서식이 사라지는 지점', () {
      expect(
        htmlToEditableText(
            '<p><strong>굵게</strong>와 <span style="color:#f00">빨강</span></p>'),
        '굵게와 빨강',
      );
    });

    test('엔티티를 풀어 준다 (&amp;는 마지막에 풀어 이중 복원을 막는다)', () {
      expect(htmlToEditableText('<p>A &amp; B &lt;태그&gt; &quot;따옴표&quot;</p>'),
          'A & B <태그> "따옴표"');
      expect(htmlToEditableText('<p>&amp;lt; 는 글자다</p>'), '&lt; 는 글자다');
      expect(htmlToEditableText('<p>공백&nbsp;하나</p>'), '공백 하나');
      expect(htmlToEditableText('<p>&#39;작은따옴표&#39;</p>'), "'작은따옴표'");
    });

    test('첫 줄이 블록 밖에 있어도 다음 블록과 붙지 않는다', () {
      expect(htmlToEditableText('첫줄<div>둘째</div>'), '첫줄\n둘째');
    });

    test('빈 문자열은 그대로 돌려준다', () {
      expect(htmlToEditableText(''), '');
    });
  });

  group('plainTextToHtml', () {
    test('이스케이프한 뒤 줄바꿈을 <br>로 바꾼다 (웹 toEditorHtml과 같은 규칙)', () {
      expect(plainTextToHtml('첫째\n둘째'), '첫째<br>둘째');
      expect(plainTextToHtml('A & B <태그>'), 'A &amp; B &lt;태그&gt;');
      expect(plainTextToHtml('윈도우\r\n줄바꿈'), '윈도우<br>줄바꿈');
    });

    test('왕복해도 글이 그대로다 — 앱에서 열었다 저장해도 줄 수가 늘지 않는다', () {
      const texts = ['첫째\n둘째', '위\n\n아래', 'A & B <태그>', '한 줄'];
      for (final text in texts) {
        expect(htmlToEditableText(plainTextToHtml(text)), text,
            reason: '입력: $text');
      }
    });

    test('웹에서 쓴 글 → 앱 편집창 → 저장 → 다시 편집창, 길이가 늘지 않는다', () {
      const fromWeb = '<div>첫째<br></div><div>둘째<br></div>';
      final editable = htmlToEditableText(fromWeb);
      final saved = plainTextToHtml(editable);
      expect(saved, '첫째<br>둘째');
      expect(htmlToEditableText(saved), editable);
    });

    test('빈 문자열은 그대로 돌려준다', () {
      expect(plainTextToHtml(''), '');
    });
  });
}
