import 'package:flutter/material.dart';

class AppTypography {
  /// 앱 전체 서체 (pubspec.yaml에 실어 둔 Pretendard).
  ///
  /// 한글을 품은 서체를 직접 싣는 이유: 기본 서체(Roboto·Geist)에 한글이 없으면 한글은
  /// 기기의 대체 서체로 그려진다. 대체 서체는 기기마다 다르고, 같은 기기에서도 기호(♡·❤)가
  /// 섞인 줄은 다른 대체 서체가 골라져 말풍선마다 글꼴이 달라졌다
  /// (제보 2026-09-08 "안드로이드에서 폰트와 크기가 제각각으로 나오는 현상").
  /// 전에는 'Inter'라고 적혀 있었지만 실린 적도 쓰인 적도 없는 값이었다.
  static const String fontFamilySans = 'Pretendard';

  // Font sizes
  static const double fontSizeXs = 11.0;
  static const double fontSizeSm = 12.0;
  static const double fontSizeBase = 14.0;
  static const double fontSizeMd = 15.0;
  static const double fontSizeLg = 16.0;
  static const double fontSizeXl = 18.0;
  static const double fontSize2xl = 20.0;
  static const double fontSize3xl = 24.0;
  static const double fontSize4xl = 30.0;
  static const double fontSize5xl = 36.0;
  // B안(2026-11-12) 단계에 새로 들어온 크기
  static const double fontSize13 = 13.0;
  static const double fontSize17 = 17.0;
  static const double fontSize19 = 19.0;
  static const double fontSize21 = 21.0;

  // Line heights
  static const double lineHeightTight = 1.25;
  static const double lineHeightSnug = 1.4;
  static const double lineHeightNormal = 1.5;
  static const double lineHeightRelaxed = 1.75;
  static const double lineHeightLoose = 2.0;

  // Font weights
  static const FontWeight fontWeightThin = FontWeight.w100;
  static const FontWeight fontWeightLight = FontWeight.w300;
  static const FontWeight fontWeightNormal = FontWeight.w400;
  static const FontWeight fontWeightMedium = FontWeight.w500;
  static const FontWeight fontWeightSemibold = FontWeight.w600;
  static const FontWeight fontWeightBold = FontWeight.w700;
  static const FontWeight fontWeightExtrabold = FontWeight.w800;

  // Letter spacing
  static const double letterSpacingTighter = -0.05;
  static const double letterSpacingTight = -0.025;
  static const double letterSpacingNormal = 0.0;
  static const double letterSpacingWide = 0.025;
  static const double letterSpacingWider = 0.05;

  // Text styles
  //
  // 글자 역할 표 — B안(2026-11-12)부터 이 값이 기준. 같은 역할은 화면이 달라도 같은 토큰 하나를 쓰고
  // 굵기를 덮어쓰지 않는다. 굵기는 w400(본문)·w600(제목·강조)·w700(화면·구역 제목, 큰 숫자) 세 단계.
  // 쓰는 분이 50~60대가 많아 글자는 커지는 쪽으로만 옮겼다(시안 template.html 값).
  //   탭 첫 화면 상단 바 제목       appBarTitleLarge 20/w700 (왼쪽 정렬)
  //   안쪽 화면 상단 바 제목        appBarTitle 17/w600 (가운데)
  //   시트·대화상자·상세 제목        heading5 21/w700      (예전 18)
  //   카드·구역 제목                heading6 19/w700      (예전 16)
  //   목록 한 줄의 제목             titleMedium 16/w600   (예전 15)
  //   작은 행 제목·폼 라벨          titleSmall 15/w600    (예전 14)
  //   본문                          bodyMedium 16/w400    (예전 14)
  //   부제·메타(날짜·작성자)        bodySmall 14/w400     (예전 12) + textSecondary·textTertiary
  //   작은 강조·꼬리표(상태 알약)    labelStrong 13/w600   (예전 12) — AppTag
  //   배지 숫자·하단 탭 글자         labelSmall 12         (예전 11) — 12보다 작은 글자는 없다
  //   큰 숫자 요약                  heading4 24/w700 고정폭 숫자 (예전 20)
  //   단추                          buttonLarge 17 / buttonMedium 16 / buttonSmall 14 (w600)
  static const TextStyle heading1 = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: fontSize5xl,
    fontWeight: fontWeightBold,
    height: lineHeightTight,
    letterSpacing: letterSpacingTight,
  );

  static const TextStyle heading2 = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: fontSize4xl,
    fontWeight: fontWeightBold,
    height: lineHeightTight,
    letterSpacing: letterSpacingTight,
  );

  static const TextStyle heading3 = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: fontSize3xl,
    fontWeight: fontWeightSemibold,
    height: lineHeightTight,
    letterSpacing: letterSpacingTight,
  );

  /// 큰 숫자 요약(건수·합계) — 숫자 폭이 같아 세어 올라가도 흔들리지 않는다.
  static const TextStyle heading4 = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: fontSize3xl,
    fontWeight: fontWeightBold,
    height: lineHeightTight,
    letterSpacing: letterSpacingNormal,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// 시트·대화상자·상세 화면 제목
  static const TextStyle heading5 = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: fontSize21,
    fontWeight: fontWeightBold,
    height: lineHeightSnug,
    letterSpacing: -0.2,
  );

  /// 카드·구역 제목("공지사항"·"전자결재")
  static const TextStyle heading6 = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: fontSize19,
    fontWeight: fontWeightBold,
    height: 1.35,
    letterSpacing: -0.2,
  );

  /// 안쪽 화면 상단 바 제목(가운데)
  static const TextStyle appBarTitle = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: fontSize17,
    fontWeight: fontWeightSemibold,
    height: lineHeightTight,
    letterSpacing: letterSpacingNormal,
  );

  /// 탭 첫 화면 상단 바 제목(왼쪽) — 홈 인사말도 이 자리
  static const TextStyle appBarTitleLarge = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: fontSize2xl,
    fontWeight: fontWeightBold,
    height: lineHeightTight,
    letterSpacing: letterSpacingNormal,
  );

  /// 카드·목록 한 줄의 제목 — 공지·결재·알림·채팅방·게시글·어르신 카드 등
  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: fontSizeLg,
    fontWeight: fontWeightSemibold,
    height: 1.45,
    letterSpacing: letterSpacingNormal,
  );

  /// 작은 행 제목·폼 라벨·카드 안 소제목
  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: fontSizeMd,
    fontWeight: fontWeightSemibold,
    height: lineHeightSnug,
    letterSpacing: letterSpacingNormal,
  );

  /// 작은 강조 13/w600 — 상태 알약(꼬리표)·달력 날짜 숫자처럼 본문보다 작지만 눈에 띄어야 하는 자리.
  /// (단추 토큰 buttonSmall을 빌려 쓰지 않는다)
  static const TextStyle labelStrong = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: fontSize13,
    fontWeight: fontWeightSemibold,
    height: lineHeightSnug,
    letterSpacing: letterSpacingNormal,
  );

  /// 긴 글(공지 본문 등)
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: fontSize17,
    fontWeight: fontWeightNormal,
    height: 1.6,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: fontSizeLg,
    fontWeight: fontWeightNormal,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: fontSizeBase,
    fontWeight: fontWeightNormal,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: fontSizeMd,
    fontWeight: fontWeightMedium,
    height: lineHeightSnug,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: fontSize13,
    fontWeight: fontWeightMedium,
    height: lineHeightSnug,
    letterSpacing: letterSpacingNormal,
  );

  /// 배지 숫자·하단 탭 글자 — 앱에서 가장 작은 글자(12)
  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: fontSizeSm,
    fontWeight: fontWeightMedium,
    height: 1.35,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle buttonLarge = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: fontSize17,
    fontWeight: fontWeightSemibold,
    height: lineHeightTight,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: fontSizeLg,
    fontWeight: fontWeightSemibold,
    height: lineHeightTight,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: fontSizeBase,
    fontWeight: fontWeightSemibold,
    height: lineHeightTight,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: fontSizeSm,
    fontWeight: fontWeightNormal,
    height: lineHeightSnug,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle overline = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: fontSizeSm,
    fontWeight: fontWeightMedium,
    height: lineHeightSnug,
    letterSpacing: letterSpacingWide,
  );
}
