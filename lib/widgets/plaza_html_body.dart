import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/html_utils.dart';

/// 커뮤니티 게시글 본문(`content`)은 웹 리치텍스트 에디터가 저장한 HTML이다.
/// 이 위젯이 태그를 실제로 렌더링해 `<p>`, `<strong>` 같은 태그가 그대로
/// 노출되는 표시 버그를 막는다. Seed 타이포그래피 토큰에 맞춰 스타일을 매핑한다.
class PlazaHtmlBody extends StatelessWidget {
  final String html;

  const PlazaHtmlBody({super.key, required this.html});

  Future<void> _openLink(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Html(
      // flutter_html에는 "블록 끝 <br>은 줄을 만들지 않는다"는 브라우저 규칙이 없다.
      // 그대로 그리면 웹에서 두 줄인 글이 앱에서 네 줄이 되므로, 그리기 직전에
      // 웹과 같은 규칙으로 군더더기를 덜어낸다 (이미 저장된 글까지 고쳐야 해서 표시 단계).
      data: normalizeNoticeHtml(html),
      onLinkTap: (url, attributes, element) => _openLink(url),
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontSize: FontSize(AppTypography.fontSizeBase),
          color: AppSemanticColors.textPrimary,
          lineHeight: const LineHeight(1.6),
        ),
        // top을 명시해 flutter_html의 p 기본 margin(상하 1em)을 확실히 지운다.
        // Flutter에는 margin collapsing이 없어, 위아래가 그대로 더해져 문단 사이가 벌어진다.
        'p': Style(margin: Margins.only(top: 0, bottom: 10)),
        'div': Style(margin: Margins.zero),
        'strong': Style(fontWeight: AppTypography.fontWeightBold),
        'b': Style(fontWeight: AppTypography.fontWeightBold),
        'em': Style(fontStyle: FontStyle.italic),
        'i': Style(fontStyle: FontStyle.italic),
        'a': Style(
          color: AppSemanticColors.textLink,
          textDecoration: TextDecoration.underline,
        ),
        'img': Style(
          margin: Margins.symmetric(vertical: 8),
        ),
        'ul': Style(margin: Margins.only(bottom: 10, left: 4)),
        'ol': Style(margin: Margins.only(bottom: 10, left: 4)),
        'li': Style(margin: Margins.only(bottom: 4)),
        'h1': Style(
          fontSize: FontSize(AppTypography.fontSize2xl),
          fontWeight: AppTypography.fontWeightBold,
          margin: Margins.only(top: 12, bottom: 8),
        ),
        'h2': Style(
          fontSize: FontSize(AppTypography.fontSizeXl),
          fontWeight: AppTypography.fontWeightBold,
          margin: Margins.only(top: 12, bottom: 8),
        ),
        'h3': Style(
          fontSize: FontSize(AppTypography.fontSizeLg),
          fontWeight: AppTypography.fontWeightSemibold,
          margin: Margins.only(top: 10, bottom: 6),
        ),
        'blockquote': Style(
          margin: Margins.symmetric(vertical: 8),
          padding: HtmlPaddings.only(left: 12),
          border: Border(
            left: BorderSide(color: AppSemanticColors.borderDefault, width: 3),
          ),
          color: AppSemanticColors.textSecondary,
        ),
      },
    );
  }
}
