import 'package:flutter/painting.dart';

class AppSpacing {
  static const double none = 0;
  static const double px = 1;
  static const double space0_5 = 2;
  static const double space1 = 4;
  static const double space1_5 = 6;
  static const double space2 = 8;
  static const double space2_5 = 10;
  static const double space3 = 12;
  static const double space3_5 = 14;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space7 = 28;
  static const double space8 = 32;
  static const double space9 = 36;
  static const double space10 = 40;
  static const double space12 = 48;
  static const double space14 = 56;
  static const double space16 = 64;
  static const double space20 = 80;

  // ── 역할 간격 (B안 2026-11-12) ──
  /// 화면 좌우 여백
  static const double screenGutter = space4; // 16
  /// 카드 안쪽 여백
  static const double cardPadding = space5; // 20
  /// 카드와 카드 사이
  static const double cardGap = space3; // 12
  /// 손가락이 닿는 최소 크기
  static const double minTouchTarget = space12; // 48
  /// 상단 바 높이(B안: 틸 바 유지, 높이 56)
  static const double toolbarHeight = space14; // 56
  /// 하단 탭 높이(안전 영역 제외)
  static const double bottomTabHeight = space16; // 64
  /// 목록 한 줄 최소 높이
  static const double listRowMinHeight = 60;
  /// 둥근 아이콘(옅은 틸 바탕) 지름
  static const double iconCircle = 44;
  /// 단추 높이 — 큰 단추 54, 보통 48
  static const double buttonHeightLarge = 54;
  static const double buttonHeight = space12; // 48
}

class AppBorderRadius {
  static const double none = 0;
  static const double sm = 2;
  static const double base = 4;
  static const double md = 6;
  static const double lg = 8;
  static const double xl = 12;
  static const double xl2 = 16;
  static const double xl3 = 24;
  static const double full = 9999;

  // ── 역할 모서리 (B안 2026-11-12) ──
  /// 나눔 조절 안 칸·작은 안쪽 상자
  static const double inner = 10;
  /// 단추·입력칸·눌린 줄·아이콘 단추
  static const double control = 14;
  /// 카드(회색 바탕 위 흰 상자)
  static const double card = 20;
  /// 아래에서 올라오는 시트·대화상자
  static const double sheet = xl3; // 24
}

class AppShadows {
  static const List<double> xs = [0, 1, 2, 0];
  static const List<double> sm = [0, 1, 3, 0];
  static const List<double> base = [0, 4, 6, -1];
  static const List<double> md = [0, 10, 15, -3];
  static const List<double> lg = [0, 20, 25, -5];
  static const List<double> xl = [0, 25, 50, -12];

  // ── B안(2026-11-12) 그림자 — 테두리 대신 아주 옅게, 뜬 것(알약 FAB)에만 ──
  /// 떠 있는 것(알약 FAB): 0 8 18 -6 rgba(16,24,40,.32) + 0 2 4 rgba(16,24,40,.08)
  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x52101828),
      offset: Offset(0, 8),
      blurRadius: 18,
      spreadRadius: -6,
    ),
    BoxShadow(
      color: Color(0x14101828),
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
  ];

  /// 나눔 조절의 고른 칸: 0 1 2 rgba(16,24,40,.08)
  static const List<BoxShadow> raised = [
    BoxShadow(
      color: Color(0x14101828),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];
}

class AppTransitions {
  static const Duration fastest = Duration(milliseconds: 75);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
  static const Duration slowest = Duration(milliseconds: 500);
}