import 'package:flutter/material.dart';

/// 케어브이 앱 컬러 팔레트.
///
/// 당근 Seed 디자인 시스템의 팔레트·시맨틱 토큰 구조를 이식하되,
/// 브랜드(프라이머리)는 케어브이 틸(#20C997) 스케일로 치환했다.
/// 스케일 매핑: 앱 50~900 ↔ Seed 100~1000.
class AppColors {
  // Base colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Colors.transparent;

  // Base color variants
  static const Color white70 = Color(0xB3FFFFFF); // white with 70% opacity
  static const Color black87 = Color(0xDE000000); // black with 87% opacity
  static const Color black26 = Color(0x42000000); // black with 26% opacity

  // Gray palette (Seed gray)
  static const Color gray50 = Color(0xFFF7F8F9);
  static const Color gray100 = Color(0xFFF3F4F5);
  static const Color gray200 = Color(0xFFEEEFF1);
  static const Color gray300 = Color(0xFFDCDEE3);
  static const Color gray400 = Color(0xFFD1D3D8);
  static const Color gray500 = Color(0xFFB0B3BA);
  static const Color gray600 = Color(0xFF868B94);
  static const Color gray700 = Color(0xFF555D6D);
  static const Color gray800 = Color(0xFF2A3038);
  static const Color gray900 = Color(0xFF1A1C20);

  // Grey aliases (for backwards compatibility)
  static const Color grey50 = gray50;
  static const Color grey100 = gray100;
  static const Color grey200 = gray200;
  static const Color grey300 = gray300;
  static const Color grey400 = gray400;
  static const Color grey500 = gray500;
  static const Color grey600 = gray600;
  static const Color grey700 = gray700;
  static const Color grey800 = gray800;
  static const Color grey900 = gray900;

  // Blue palette (Seed blue)
  static const Color blue50 = Color(0xFFEFF6FF);
  static const Color blue100 = Color(0xFFE2EDFC);
  static const Color blue200 = Color(0xFFCBDFFA);
  static const Color blue300 = Color(0xFFAACEFD);
  static const Color blue400 = Color(0xFF85B8FD);
  static const Color blue500 = Color(0xFF5E98FE);
  static const Color blue600 = Color(0xFF217CF9);
  static const Color blue700 = Color(0xFF135FCD);
  static const Color blue800 = Color(0xFF0B4596);
  static const Color blue900 = Color(0xFF032451);

  // Green palette (Seed green)
  static const Color green50 = Color(0xFFEDFAF6);
  static const Color green100 = Color(0xFFD9F6E9);
  static const Color green200 = Color(0xFFB9E9D2);
  static const Color green300 = Color(0xFF7DDCB3);
  static const Color green400 = Color(0xFF42C593);
  static const Color green500 = Color(0xFF10AB7D);
  static const Color green600 = Color(0xFF079171);
  static const Color green700 = Color(0xFF00745F);
  static const Color green800 = Color(0xFF075445);
  static const Color green900 = Color(0xFF0A2B24);

  // Yellow palette (Seed yellow)
  static const Color yellow50 = Color(0xFFFFF7DE);
  static const Color yellow100 = Color(0xFFFDEFB9);
  static const Color yellow200 = Color(0xFFFBDC65);
  static const Color yellow300 = Color(0xFFE9C647);
  static const Color yellow400 = Color(0xFFD4AB28);
  static const Color yellow500 = Color(0xFFC49725);
  static const Color yellow600 = Color(0xFF9B7821);
  static const Color yellow700 = Color(0xFF755B22);
  static const Color yellow800 = Color(0xFF4F3E1F);
  static const Color yellow900 = Color(0xFF2C2512);

  // Red palette (Seed red)
  static const Color red50 = Color(0xFFFDF0F0);
  static const Color red100 = Color(0xFFFDE7E7);
  static const Color red200 = Color(0xFFFED4D2);
  static const Color red300 = Color(0xFFFEB7B3);
  static const Color red400 = Color(0xFFFE928D);
  static const Color red500 = Color(0xFFFC6A66);
  static const Color red600 = Color(0xFFFA342C);
  static const Color red700 = Color(0xFFCA1D13);
  static const Color red800 = Color(0xFF921708);
  static const Color red900 = Color(0xFF4A1209);

  // Purple palette (Seed purple)
  static const Color purple50 = Color(0xFFF5F3FE);
  static const Color purple100 = Color(0xFFEFEAFE);
  static const Color purple200 = Color(0xFFE1D8FF);
  static const Color purple300 = Color(0xFFD0C0FF);
  static const Color purple400 = Color(0xFFB8A1FF);
  static const Color purple500 = Color(0xFF9F84FB);
  static const Color purple600 = Color(0xFF8969EA);
  static const Color purple700 = Color(0xFF6D50CB);
  static const Color purple800 = Color(0xFF50379B);
  static const Color purple900 = Color(0xFF29175D);

  // Orange palette (Seed carrot — 포인트 색으로만 사용)
  static const Color orange50 = Color(0xFFFFF2EC);
  static const Color orange100 = Color(0xFFFFE8DB);
  static const Color orange200 = Color(0xFFFFD5C0);
  static const Color orange300 = Color(0xFFFFB999);
  static const Color orange400 = Color(0xFFFF9364);
  static const Color orange500 = Color(0xFFFF6600);
  static const Color orange600 = Color(0xFFE14D00);
  static const Color orange700 = Color(0xFFB93901);
  static const Color orange800 = Color(0xFF862B00);
  static const Color orange900 = Color(0xFF471601);

  // Amber palette (yellow 톤 유지 — 하위 호환)
  static const Color amber50 = Color(0xFFFFF7DE);
  static const Color amber100 = Color(0xFFFDEFB9);
  static const Color amber200 = Color(0xFFFBDC65);
  static const Color amber300 = Color(0xFFE9C647);
  static const Color amber400 = Color(0xFFD4AB28);
  static const Color amber500 = Color(0xFFC49725);
  static const Color amber600 = Color(0xFF9B7821);
  static const Color amber700 = Color(0xFF755B22);
  static const Color amber800 = Color(0xFF4F3E1F);
  static const Color amber900 = Color(0xFF2C2512);

  // Indigo palette (blue 계열 유지 — 하위 호환)
  static const Color indigo50 = Color(0xFFEEF2FF);
  static const Color indigo100 = Color(0xFFE0E7FF);
  static const Color indigo200 = Color(0xFFC7D2FE);
  static const Color indigo300 = Color(0xFFA5B4FC);
  static const Color indigo400 = Color(0xFF818CF8);
  static const Color indigo500 = Color(0xFF6366F1);
  static const Color indigo600 = Color(0xFF4F46E5);
  static const Color indigo700 = Color(0xFF4338CA);
  static const Color indigo800 = Color(0xFF3730A3);
  static const Color indigo900 = Color(0xFF312E81);

  // Teal palette — 케어브이 브랜드 스케일 (#20C997 기준)
  static const Color teal50 = Color(0xFFE9FBF4);
  static const Color teal100 = Color(0xFFD4F7EA);
  static const Color teal200 = Color(0xFFA9EFD5);
  static const Color teal300 = Color(0xFF79E4BE);
  static const Color teal400 = Color(0xFF4AD8A8);
  static const Color teal500 = Color(0xFF2ECF9C);
  static const Color teal600 = Color(0xFF20C997);
  static const Color teal700 = Color(0xFF17A87D);
  static const Color teal800 = Color(0xFF128A67);
  static const Color teal900 = Color(0xFF0B5C45);

  // Pink palette (하위 호환 유지)
  static const Color pink50 = Color(0xFFFDF2F8);
  static const Color pink100 = Color(0xFFFCE7F3);
  static const Color pink200 = Color(0xFFFBCFE8);
  static const Color pink300 = Color(0xFFF9A8D4);
  static const Color pink400 = Color(0xFFF472B6);
  static const Color pink500 = Color(0xFFEC4899);
  static const Color pink600 = Color(0xFFDB2777);
  static const Color pink700 = Color(0xFFBE185D);
  static const Color pink800 = Color(0xFF9D174D);
  static const Color pink900 = Color(0xFF831843);

  // Cyan palette (하위 호환 유지)
  static const Color cyan50 = Color(0xFFECFEFF);
  static const Color cyan100 = Color(0xFFCFFAFE);
  static const Color cyan200 = Color(0xFFA5F3FC);
  static const Color cyan300 = Color(0xFF67E8F9);
  static const Color cyan400 = Color(0xFF22D3EE);
  static const Color cyan500 = Color(0xFF06B6D4);
  static const Color cyan600 = Color(0xFF0891B2);
  static const Color cyan700 = Color(0xFF0E7490);
  static const Color cyan800 = Color(0xFF155E75);
  static const Color cyan900 = Color(0xFF164E63);
}

/// 시맨틱 토큰 — Seed의 역할 기반(bg/fg/stroke) 매핑을 따른다.
/// 브랜드 역할(interactivePrimary·brand*)은 케어브이 틸.
class AppSemanticColors {
  // Background colors (Seed bg.layer-*)
  static const Color backgroundPrimary = AppColors.white; // layer-default
  static const Color backgroundSecondary = AppColors.gray50; // gray-100
  static const Color backgroundTertiary = AppColors.gray100; // layer-basement
  static const Color backgroundElevated = AppColors.white; // layer-floating
  static const Color backgroundOverlay = Color(0x80000000);

  // Surface colors
  static const Color surfaceDefault = AppColors.white;
  static const Color surfaceHover = AppColors.gray50; // layer-default-pressed
  static const Color surfaceActive = AppColors.gray100;
  static const Color surfaceDisabled = AppColors.gray100; // bg.disabled
  static const Color surfaceSelected = AppColors.teal50; // brand-weak

  // Border colors (Seed stroke.neutral-*)
  static const Color borderDefault = AppColors.gray300; // stroke.neutral-weak
  static const Color borderSubtle = AppColors.gray200;
  static const Color borderHover = AppColors.gray400;
  static const Color borderFocus = AppColors.teal600; // brand
  static const Color borderDisabled = AppColors.gray200;

  // Text colors (Seed fg.neutral-*)
  static const Color textPrimary = AppColors.gray900; // fg.neutral
  static const Color textSecondary = AppColors.gray700; // fg.neutral-muted
  static const Color textTertiary = AppColors.gray600; // fg.neutral-subtle
  static const Color textDisabled = AppColors.gray500; // fg.disabled
  static const Color textInverse = AppColors.white;
  static const Color textLink = AppColors.teal700; // fg.brand-contrast
  static const Color textError = AppColors.red600;

  // Brand (케어브이 틸 — Seed bg.brand-*)
  static const Color brandDefault = AppColors.teal600;
  static const Color brandPressed = AppColors.teal700;
  static const Color brandWeak = AppColors.teal50;
  static const Color brandWeakPressed = AppColors.teal100;

  // Interactive colors — 프라이머리 액션은 브랜드 틸
  static const Color interactivePrimaryDefault = AppColors.teal600;
  static const Color interactivePrimaryHover = AppColors.teal700;
  static const Color interactivePrimaryActive = AppColors.teal800;
  static const Color interactivePrimaryDisabled = AppColors.gray400;

  static const Color interactiveSecondaryDefault = AppColors.gray100;
  static const Color interactiveSecondaryHover = AppColors.gray200;
  static const Color interactiveSecondaryActive = AppColors.gray300;
  static const Color interactiveSecondaryDisabled = AppColors.gray100;

  // Status colors (Seed positive/warning/critical/informative)
  static const Color statusSuccessBackground = AppColors.green50;
  static const Color statusSuccessBorder = AppColors.green200;
  static const Color statusSuccessText = AppColors.green700;
  static const Color statusSuccessIcon = AppColors.green600;

  static const Color statusWarningBackground = AppColors.yellow50;
  static const Color statusWarningBorder = AppColors.yellow200;
  static const Color statusWarningText = AppColors.yellow700;
  static const Color statusWarningIcon = AppColors.yellow600;

  static const Color statusErrorBackground = AppColors.red50;
  static const Color statusErrorBorder = AppColors.red200;
  static const Color statusErrorText = AppColors.red700;
  static const Color statusErrorIcon = AppColors.red600;

  static const Color statusInfoBackground = AppColors.blue50;
  static const Color statusInfoBorder = AppColors.blue200;
  static const Color statusInfoText = AppColors.blue700;
  static const Color statusInfoIcon = AppColors.blue600;
}

class AppDarkColors {
  // Dark mode overrides (Seed gray dark 계열)
  static const Color backgroundPrimary = AppColors.gray900;
  static const Color backgroundSecondary = AppColors.gray800;
  static const Color backgroundTertiary = Color(0xFF3E4550);

  static const Color surfaceDefault = AppColors.gray900;
  static const Color surfaceHover = AppColors.gray800;
  static const Color surfaceActive = Color(0xFF3E4550);

  static const Color borderDefault = Color(0xFF3E4550);
  static const Color borderHover = AppColors.gray700;

  static const Color textPrimary = AppColors.gray50;
  static const Color textSecondary = AppColors.gray400;
  static const Color textTertiary = AppColors.gray500;
}
