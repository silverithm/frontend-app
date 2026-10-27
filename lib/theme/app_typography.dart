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
  // 글자 역할 표(2026-10-27) — 같은 역할은 화면이 달라도 같은 토큰 하나를 쓰고, 굵기를 덮어쓰지 않는다.
  // 굵기는 w400(본문)·w600(제목·강조)·w700(화면·구역 제목, 큰 숫자) 세 단계만 쓴다.
  //   화면·시트·대화상자 제목   heading5 18/w700
  //   구역 머리                 heading6 16/w700
  //   카드·목록 한 줄의 제목    titleMedium 15/w600
  //   작은 행 제목·폼 라벨      titleSmall 14/w600
  //   본문                      bodyMedium 14/w400
  //   부제·메타(날짜·작성자)    bodySmall 12/w400 (textSecondary·textTertiary)
  //   작은 강조(달력 날짜·상태 숫자 등 12/w600)  labelStrong
  //   꼬리표·배지 숫자          labelSmall 11 (AppTag) — 11은 이 자리에만
  //   큰 숫자 요약              heading4 20/w700
  // 예전에는 같은 '목록 제목'이 14/w600·15/w500·16/w600·16/w700으로 화면마다 달라 들쭉날쭉해 보였다.
  static const TextStyle heading1 = TextStyle(
    fontSize: fontSize5xl,
    fontWeight: fontWeightBold,
    height: lineHeightTight,
    letterSpacing: letterSpacingTight,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: fontSize4xl,
    fontWeight: fontWeightBold,
    height: lineHeightTight,
    letterSpacing: letterSpacingTight,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: fontSize3xl,
    fontWeight: fontWeightSemibold,
    height: lineHeightTight,
    letterSpacing: letterSpacingTight,
  );

  static const TextStyle heading4 = TextStyle(
    fontSize: fontSize2xl,
    fontWeight: fontWeightBold,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle heading5 = TextStyle(
    fontSize: fontSizeXl,
    fontWeight: fontWeightBold,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle heading6 = TextStyle(
    fontSize: fontSizeLg,
    fontWeight: fontWeightBold,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );

  /// 카드·목록 한 줄의 제목 — 공지·결재·알림·채팅방·게시글·어르신 카드 등
  static const TextStyle titleMedium = TextStyle(
    fontSize: fontSizeMd,
    fontWeight: fontWeightSemibold,
    height: lineHeightSnug,
    letterSpacing: letterSpacingNormal,
  );

  /// 작은 행 제목·폼 라벨·카드 안 소제목
  static const TextStyle titleSmall = TextStyle(
    fontSize: fontSizeBase,
    fontWeight: fontWeightSemibold,
    height: lineHeightSnug,
    letterSpacing: letterSpacingNormal,
  );

  /// 작은 강조 글자 12/w600 — 달력 날짜 숫자·상태 숫자처럼 본문보다 작지만 눈에 띄어야 하는 자리.
  /// (단추 토큰 buttonSmall을 빌려 쓰지 않는다)
  static const TextStyle labelStrong = TextStyle(
    fontSize: fontSizeSm,
    fontWeight: fontWeightSemibold,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: fontSizeLg,
    fontWeight: fontWeightNormal,
    height: lineHeightRelaxed,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: fontSizeBase,
    fontWeight: fontWeightNormal,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: fontSizeSm,
    fontWeight: fontWeightNormal,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: fontSizeBase,
    fontWeight: fontWeightMedium,
    height: lineHeightNormal,
    letterSpacing: letterSpacingWide,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: fontSizeSm,
    fontWeight: fontWeightMedium,
    height: lineHeightNormal,
    letterSpacing: letterSpacingWide,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: fontSizeXs,
    fontWeight: fontWeightMedium,
    height: lineHeightNormal,
    letterSpacing: letterSpacingWide,
  );

  static const TextStyle buttonLarge = TextStyle(
    fontSize: fontSizeLg,
    fontWeight: fontWeightSemibold,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontSize: fontSizeBase,
    fontWeight: fontWeightSemibold,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontSize: fontSizeSm,
    fontWeight: fontWeightSemibold,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle caption = TextStyle(
    fontSize: fontSizeXs,
    fontWeight: fontWeightNormal,
    height: lineHeightNormal,
    letterSpacing: letterSpacingWide,
  );

  static const TextStyle overline = TextStyle(
    fontSize: fontSizeXs,
    fontWeight: fontWeightMedium,
    height: lineHeightNormal,
    letterSpacing: letterSpacingWider,
  );
}