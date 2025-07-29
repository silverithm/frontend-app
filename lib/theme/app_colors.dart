import 'package:flutter/material.dart';

class AppColors {
  // Base colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Colors.transparent;

  // Gray palette
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);

  // Blue palette
  static const Color blue50 = Color(0xFFEFF6FF);
  static const Color blue100 = Color(0xFFDBEAFE);
  static const Color blue200 = Color(0xFFBFDBFE);
  static const Color blue300 = Color(0xFF93C5FD);
  static const Color blue400 = Color(0xFF60A5FA);
  static const Color blue500 = Color(0xFF3B82F6);
  static const Color blue600 = Color(0xFF2563EB);
  static const Color blue700 = Color(0xFF1D4ED8);
  static const Color blue800 = Color(0xFF1E40AF);
  static const Color blue900 = Color(0xFF1E3A8A);

  // Green palette
  static const Color green50 = Color(0xFFF0FDF4);
  static const Color green100 = Color(0xFFDCFCE7);
  static const Color green200 = Color(0xFFBBF7D0);
  static const Color green300 = Color(0xFF86EFAC);
  static const Color green400 = Color(0xFF4ADE80);
  static const Color green500 = Color(0xFF22C55E);
  static const Color green600 = Color(0xFF16A34A);
  static const Color green700 = Color(0xFF15803D);
  static const Color green800 = Color(0xFF166534);
  static const Color green900 = Color(0xFF14532D);

  // Yellow palette
  static const Color yellow50 = Color(0xFFFEFCE8);
  static const Color yellow100 = Color(0xFFFEF9C3);
  static const Color yellow200 = Color(0xFFFEF08A);
  static const Color yellow300 = Color(0xFFFDE047);
  static const Color yellow400 = Color(0xFFFACC15);
  static const Color yellow500 = Color(0xFFEAB308);
  static const Color yellow600 = Color(0xFFCA8A04);
  static const Color yellow700 = Color(0xFFA16207);
  static const Color yellow800 = Color(0xFF854D0E);
  static const Color yellow900 = Color(0xFF713F12);

  // Red palette
  static const Color red50 = Color(0xFFFEF2F2);
  static const Color red100 = Color(0xFFFEE2E2);
  static const Color red200 = Color(0xFFFECACA);
  static const Color red300 = Color(0xFFFCA5A5);
  static const Color red400 = Color(0xFFF87171);
  static const Color red500 = Color(0xFFEF4444);
  static const Color red600 = Color(0xFFDC2626);
  static const Color red700 = Color(0xFFB91C1C);
  static const Color red800 = Color(0xFF991B1B);
  static const Color red900 = Color(0xFF7F1D1D);

  // Purple palette
  static const Color purple50 = Color(0xFFFAF5FF);
  static const Color purple100 = Color(0xFFF3E8FF);
  static const Color purple200 = Color(0xFFE9D5FF);
  static const Color purple300 = Color(0xFFD8B4FE);
  static const Color purple400 = Color(0xFFC084FC);
  static const Color purple500 = Color(0xFFA855F7);
  static const Color purple600 = Color(0xFF9333EA);
  static const Color purple700 = Color(0xFF7C3AED);
  static const Color purple800 = Color(0xFF6B21A8);
  static const Color purple900 = Color(0xFF581C87);
}

class AppSemanticColors {
  // Background colors
  static const Color backgroundPrimary = AppColors.white;
  static const Color backgroundSecondary = AppColors.gray50;
  static const Color backgroundTertiary = AppColors.gray100;
  static const Color backgroundElevated = AppColors.white;
  static const Color backgroundOverlay = Color(0x80000000); // rgba(0, 0, 0, 0.5)

  // Surface colors
  static const Color surfaceDefault = AppColors.white;
  static const Color surfaceHover = AppColors.gray50;
  static const Color surfaceActive = AppColors.gray100;
  static const Color surfaceDisabled = AppColors.gray200;
  static const Color surfaceSelected = AppColors.blue50;

  // Border colors
  static const Color borderDefault = AppColors.gray200;
  static const Color borderHover = AppColors.gray300;
  static const Color borderFocus = AppColors.blue500;
  static const Color borderDisabled = AppColors.gray100;

  // Text colors
  static const Color textPrimary = AppColors.gray900;
  static const Color textSecondary = AppColors.gray700;
  static const Color textTertiary = AppColors.gray500;
  static const Color textDisabled = AppColors.gray400;
  static const Color textInverse = AppColors.white;
  static const Color textLink = AppColors.blue600;
  static const Color textError = AppColors.red600;

  // Interactive colors
  static const Color interactivePrimaryDefault = AppColors.blue600;
  static const Color interactivePrimaryHover = AppColors.blue700;
  static const Color interactivePrimaryActive = AppColors.blue800;
  static const Color interactivePrimaryDisabled = AppColors.blue300;

  static const Color interactiveSecondaryDefault = AppColors.gray600;
  static const Color interactiveSecondaryHover = AppColors.gray700;
  static const Color interactiveSecondaryActive = AppColors.gray800;
  static const Color interactiveSecondaryDisabled = AppColors.gray300;

  // Status colors
  static const Color statusSuccessBackground = AppColors.green50;
  static const Color statusSuccessBorder = AppColors.green200;
  static const Color statusSuccessText = AppColors.green800;
  static const Color statusSuccessIcon = AppColors.green600;

  static const Color statusWarningBackground = AppColors.yellow50;
  static const Color statusWarningBorder = AppColors.yellow200;
  static const Color statusWarningText = AppColors.yellow800;
  static const Color statusWarningIcon = AppColors.yellow600;

  static const Color statusErrorBackground = AppColors.red50;
  static const Color statusErrorBorder = AppColors.red200;
  static const Color statusErrorText = AppColors.red800;
  static const Color statusErrorIcon = AppColors.red600;

  static const Color statusInfoBackground = AppColors.blue50;
  static const Color statusInfoBorder = AppColors.blue200;
  static const Color statusInfoText = AppColors.blue800;
  static const Color statusInfoIcon = AppColors.blue600;
}

class AppDarkColors {
  // Dark mode overrides
  static const Color backgroundPrimary = AppColors.gray900;
  static const Color backgroundSecondary = AppColors.gray800;
  static const Color backgroundTertiary = AppColors.gray700;

  static const Color surfaceDefault = AppColors.gray800;
  static const Color surfaceHover = AppColors.gray700;
  static const Color surfaceActive = AppColors.gray600;

  static const Color borderDefault = AppColors.gray700;
  static const Color borderHover = AppColors.gray600;

  static const Color textPrimary = AppColors.gray50;
  static const Color textSecondary = AppColors.gray200;
  static const Color textTertiary = AppColors.gray400;
}