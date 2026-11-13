import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 선 규칙(2026-11-13) — 새 모습에서 뺐던 카드 테두리·줄 사이 선을 되살렸다.
///
///  - 흰 카드는 회색 바탕 위에서도 가장자리가 보이도록 1px 테두리([cardBorder])를 두른다.
///  - 카드 안에 줄이 여럿이면 줄 사이에 1px 선([AppRowDivider])을 긋는다.
///  - 한 종류가 죽 이어지는 목록(채팅 대화·직원)은 카드에 가두지 않고 화면 끝까지 채운다.
class AppLines {
  AppLines._();

  /// 줄 사이 선 색 — 흰 카드 안에서 또렷이 보이는 회색
  static const Color rowColor = AppSemanticColors.borderSubtle;

  /// 카드 테두리 색 — 회색 바탕(#F2F4F6) 위에서도 보이도록 줄 선보다 한 단계 진하게
  static const Color cardColor = AppSemanticColors.borderHover;

  static const BorderSide cardSide = BorderSide(color: cardColor);

  /// 흰 카드 테두리
  static const Border cardBorder = Border.fromBorderSide(cardSide);

  /// [children] 사이사이에 줄 구분선을 끼운다.
  static List<Widget> between(List<Widget> children, {double indent = 0}) {
    if (children.length < 2) return children;
    return [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) AppRowDivider(indent: indent),
        children[i],
      ],
    ];
  }
}

/// 목록 줄 사이 1px 선. [indent]만큼 들여 줄 글자 시작에 맞춘다.
class AppRowDivider extends StatelessWidget {
  const AppRowDivider({super.key, this.indent = 0, this.endIndent});

  final double indent;

  /// 오른쪽 들여쓰기. 없으면 [indent]와 같다.
  final double? endIndent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent, right: endIndent ?? indent),
      // 가운데 맞춤 Column 안에서도 폭이 0이 되지 않게 가로를 다 채운다
      child: const SizedBox(
        width: double.infinity,
        height: 1,
        child: ColoredBox(color: AppLines.rowColor),
      ),
    );
  }
}
