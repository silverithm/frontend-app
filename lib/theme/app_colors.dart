import 'package:flutter/material.dart';

class AppColors {
  // Base colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Colors.transparent;

  // Base color variants
  static const Color white70 = Color(0xB3FFFFFF); // white with 70% opacity
  static const Color black87 = Color(0xDE000000); // black with 87% opacity
  static const Color black26 = Color(0x42000000); // black with 26% opacity

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

  // Orange palette
  static const Color orange50 = Color(0xFFFFF7ED);
  static const Color orange100 = Color(0xFFFFEDD5);
  static const Color orange200 = Color(0xFFFED7AA);
  static const Color orange300 = Color(0xFFFDBA74);
  static const Color orange400 = Color(0xFFFB923C);
  static const Color orange500 = Color(0xFFF97316);
  static const Color orange600 = Color(0xFFEA580C);
  static const Color orange700 = Color(0xFFC2410C);
  static const Color orange800 = Color(0xFF9A3412);
  static const Color orange900 = Color(0xFF7C2D12);

  // Amber palette
  static const Color amber50 = Color(0xFFFFFBEB);
  static const Color amber100 = Color(0xFFFEF3C7);
  static const Color amber200 = Color(0xFFFDE68A);
  static const Color amber300 = Color(0xFFFCD34D);
  static const Color amber400 = Color(0xFFFBBF24);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber600 = Color(0xFFD97706);
  static const Color amber700 = Color(0xFFB45309);
  static const Color amber800 = Color(0xFF92400E);
  static const Color amber900 = Color(0xFF78350F);

  // Indigo palette
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

  // Teal palette
  static const Color teal50 = Color(0xFFF0FDFA);
  static const Color teal100 = Color(0xFFCCFBF1);
  static const Color teal200 = Color(0xFF99F6E4);
  static const Color teal300 = Color(0xFF5EEAD4);
  static const Color teal400 = Color(0xFF2DD4BF);
  static const Color teal500 = Color(0xFF14B8A6);
  static const Color teal600 = Color(0xFF0D9488);
  static const Color teal700 = Color(0xFF0F766E);
  static const Color teal800 = Color(0xFF115E59);
  static const Color teal900 = Color(0xFF134E4A);

  // Pink palette
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

  // Cyan palette
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

class AppSemanticColors {
  // Background colors (shadcn zinc - clean white base)
  static const Color backgroundPrimary = AppColors.white;
  static const Color backgroundSecondary = Color(0xFFFAFAFA); // zinc-50
  static const Color backgroundTertiary = Color(0xFFF4F4F5); // zinc-100
  static const Color backgroundElevated = AppColors.white;
  static const Color backgroundOverlay = Color(0x80000000);

  // Surface colors
  static const Color surfaceDefault = AppColors.white;
  static const Color surfaceHover = Color(0xFFFAFAFA); // zinc-50
  static const Color surfaceActive = Color(0xFFF4F4F5); // zinc-100
  static const Color surfaceDisabled = Color(0xFFE4E4E7); // zinc-200
  static const Color surfaceSelected = Color(0xFFF4F4F5); // zinc-100

  // Border colors (subtle zinc borders)
  static const Color borderDefault = Color(0xFFE4E4E7); // zinc-200
  static const Color borderSubtle = Color(0xFFF4F4F5); // zinc-100
  static const Color borderHover = Color(0xFFD4D4D8); // zinc-300
  static const Color borderFocus = Color(0xFF18181B); // zinc-900 (shadcn ring)
  static const Color borderDisabled = Color(0xFFF4F4F5); // zinc-100

  // Text colors (high contrast black/white)
  static const Color textPrimary = Color(0xFF09090B); // zinc-950
  static const Color textSecondary = Color(0xFF3F3F46); // zinc-700
  static const Color textTertiary = Color(0xFF71717A); // zinc-500
  static const Color textDisabled = Color(0xFFA1A1AA); // zinc-400
  static const Color textInverse = AppColors.white;
  static const Color textLink = Color(0xFF18181B); // zinc-900
  static const Color textError = AppColors.red600;

  // Interactive colors (shadcn default: near-black primary)
  static const Color interactivePrimaryDefault = Color(0xFF18181B); // zinc-900
  static const Color interactivePrimaryHover = Color(0xFF27272A); // zinc-800
  static const Color interactivePrimaryActive = Color(0xFF3F3F46); // zinc-700
  static const Color interactivePrimaryDisabled = Color(0xFFA1A1AA); // zinc-400

  static const Color interactiveSecondaryDefault = Color(0xFFF4F4F5); // zinc-100
  static const Color interactiveSecondaryHover = Color(0xFFE4E4E7); // zinc-200
  static const Color interactiveSecondaryActive = Color(0xFFD4D4D8); // zinc-300
  static const Color interactiveSecondaryDisabled = Color(0xFFF4F4F5); // zinc-100

  // Status colors (functional - kept for clarity)
  static const Color statusSuccessBackground = Color(0xFFF0FDF4);
  static const Color statusSuccessBorder = Color(0xFFBBF7D0);
  static const Color statusSuccessText = Color(0xFF166534);
  static const Color statusSuccessIcon = Color(0xFF16A34A);

  static const Color statusWarningBackground = Color(0xFFFEFCE8);
  static const Color statusWarningBorder = Color(0xFFFEF08A);
  static const Color statusWarningText = Color(0xFF854D0E);
  static const Color statusWarningIcon = Color(0xFFCA8A04);

  static const Color statusErrorBackground = Color(0xFFFEF2F2);
  static const Color statusErrorBorder = Color(0xFFFECACA);
  static const Color statusErrorText = Color(0xFF991B1B);
  static const Color statusErrorIcon = Color(0xFFDC2626);

  static const Color statusInfoBackground = Color(0xFFFAFAFA); // zinc-50 (neutral)
  static const Color statusInfoBorder = Color(0xFFE4E4E7); // zinc-200
  static const Color statusInfoText = Color(0xFF3F3F46); // zinc-700
  static const Color statusInfoIcon = Color(0xFF71717A); // zinc-500
}

class AppDarkColors {
  // Dark mode overrides (shadcn zinc dark)
  static const Color backgroundPrimary = Color(0xFF09090B); // zinc-950
  static const Color backgroundSecondary = Color(0xFF18181B); // zinc-900
  static const Color backgroundTertiary = Color(0xFF27272A); // zinc-800

  static const Color surfaceDefault = Color(0xFF09090B); // zinc-950
  static const Color surfaceHover = Color(0xFF18181B); // zinc-900
  static const Color surfaceActive = Color(0xFF27272A); // zinc-800

  static const Color borderDefault = Color(0xFF27272A); // zinc-800
  static const Color borderHover = Color(0xFF3F3F46); // zinc-700

  static const Color textPrimary = Color(0xFFFAFAFA); // zinc-50
  static const Color textSecondary = Color(0xFFD4D4D8); // zinc-300
  static const Color textTertiary = Color(0xFFA1A1AA); // zinc-400
}