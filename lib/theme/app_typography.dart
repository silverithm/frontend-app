import 'package:flutter/material.dart';

class AppTypography {
  // Font families
  static const String fontFamilySans = 'Inter';
  static const String fontFamilyMono = 'SF Mono';

  // Font sizes
  static const double fontSizeXs = 11.0;
  static const double fontSizeSm = 12.0;
  static const double fontSizeBase = 14.0;
  static const double fontSizeLg = 16.0;
  static const double fontSizeXl = 18.0;
  static const double fontSize2xl = 20.0;
  static const double fontSize3xl = 24.0;
  static const double fontSize4xl = 30.0;
  static const double fontSize5xl = 36.0;

  // Line heights
  static const double lineHeightTight = 1.25;
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
    fontWeight: fontWeightSemibold,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle heading5 = TextStyle(
    fontSize: fontSizeXl,
    fontWeight: fontWeightSemibold,
    height: lineHeightNormal,
    letterSpacing: letterSpacingNormal,
  );

  static const TextStyle heading6 = TextStyle(
    fontSize: fontSizeLg,
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