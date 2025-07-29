import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_spacing.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // Color scheme
      colorScheme: const ColorScheme.light(
        primary: AppSemanticColors.interactivePrimaryDefault,
        onPrimary: AppSemanticColors.textInverse,
        primaryContainer: AppColors.blue100,
        onPrimaryContainer: AppColors.blue900,
        
        secondary: AppSemanticColors.interactiveSecondaryDefault,
        onSecondary: AppSemanticColors.textInverse,
        secondaryContainer: AppColors.gray100,
        onSecondaryContainer: AppColors.gray900,
        
        tertiary: AppColors.purple600,
        onTertiary: AppSemanticColors.textInverse,
        tertiaryContainer: AppColors.purple100,
        onTertiaryContainer: AppColors.purple900,
        
        error: AppSemanticColors.statusErrorIcon,
        onError: AppSemanticColors.textInverse,
        errorContainer: AppSemanticColors.statusErrorBackground,
        onErrorContainer: AppSemanticColors.statusErrorText,
        
        surface: AppSemanticColors.surfaceDefault,
        onSurface: AppSemanticColors.textPrimary,
        surfaceContainerHighest: AppSemanticColors.backgroundSecondary,
        
        outline: AppSemanticColors.borderDefault,
        outlineVariant: AppSemanticColors.borderHover,
        
        scrim: AppSemanticColors.backgroundOverlay,
      ),
      
      // App bar theme
      appBarTheme: AppBarTheme(
        backgroundColor: AppSemanticColors.backgroundPrimary,
        foregroundColor: AppSemanticColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.heading5.copyWith(
          color: AppSemanticColors.textPrimary,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      
      // Card theme
      cardTheme: CardThemeData(
        color: AppSemanticColors.surfaceDefault,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          side: const BorderSide(
            color: AppSemanticColors.borderDefault,
            width: 1,
          ),
        ),
        margin: const EdgeInsets.all(AppSpacing.space4),
      ),
      
      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppSemanticColors.interactivePrimaryDefault,
          foregroundColor: AppSemanticColors.textInverse,
          disabledBackgroundColor: AppSemanticColors.interactivePrimaryDisabled,
          disabledForegroundColor: AppSemanticColors.textDisabled,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space6,
            vertical: AppSpacing.space3,
          ),
          textStyle: AppTypography.buttonMedium,
          minimumSize: const Size(0, 44),
        ),
      ),
      
      // Outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppSemanticColors.interactivePrimaryDefault,
          disabledForegroundColor: AppSemanticColors.textDisabled,
          side: const BorderSide(
            color: AppSemanticColors.borderDefault,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space6,
            vertical: AppSpacing.space3,
          ),
          textStyle: AppTypography.buttonMedium,
          minimumSize: const Size(0, 44),
        ),
      ),
      
      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppSemanticColors.interactivePrimaryDefault,
          disabledForegroundColor: AppSemanticColors.textDisabled,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space2,
          ),
          textStyle: AppTypography.buttonMedium,
          minimumSize: const Size(0, 40),
        ),
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppSemanticColors.surfaceDefault,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(
            color: AppSemanticColors.borderDefault,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(
            color: AppSemanticColors.borderDefault,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(
            color: AppSemanticColors.borderFocus,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(
            color: AppSemanticColors.statusErrorIcon,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(
            color: AppSemanticColors.statusErrorIcon,
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(
            color: AppSemanticColors.borderDisabled,
            width: 1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space3,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppSemanticColors.textTertiary,
        ),
        labelStyle: AppTypography.labelMedium.copyWith(
          color: AppSemanticColors.textSecondary,
        ),
        errorStyle: AppTypography.labelSmall.copyWith(
          color: AppSemanticColors.statusErrorText,
        ),
        helperStyle: AppTypography.labelSmall.copyWith(
          color: AppSemanticColors.textTertiary,
        ),
      ),
      
      // Checkbox theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppSemanticColors.interactivePrimaryDefault;
          }
          return AppSemanticColors.surfaceDefault;
        }),
        checkColor: WidgetStateProperty.all(AppSemanticColors.textInverse),
        side: const BorderSide(
          color: AppSemanticColors.borderDefault,
          width: 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        ),
      ),
      
      // Radio theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppSemanticColors.interactivePrimaryDefault;
          }
          return AppSemanticColors.surfaceDefault;
        }),
      ),
      
      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppSemanticColors.interactivePrimaryDefault;
          }
          return AppSemanticColors.surfaceDefault;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppSemanticColors.interactivePrimaryDefault.withValues(alpha: 0.5);
          }
          return AppSemanticColors.borderDefault;
        }),
      ),
      
      // Divider theme
      dividerTheme: const DividerThemeData(
        color: AppSemanticColors.borderDefault,
        thickness: 1,
        space: 1,
      ),
      
      // Bottom navigation bar theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppSemanticColors.surfaceDefault,
        selectedItemColor: AppSemanticColors.interactivePrimaryDefault,
        unselectedItemColor: AppSemanticColors.textTertiary,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      
      // Tab bar theme
      tabBarTheme: TabBarThemeData(
        labelColor: AppSemanticColors.interactivePrimaryDefault,
        unselectedLabelColor: AppSemanticColors.textTertiary,
        labelStyle: AppTypography.labelMedium,
        unselectedLabelStyle: AppTypography.labelMedium,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(
            color: AppSemanticColors.interactivePrimaryDefault,
            width: 2,
          ),
        ),
      ),
      
      // Floating action button theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        foregroundColor: AppSemanticColors.textInverse,
        elevation: 6,
        shape: CircleBorder(),
      ),
      
      // Snack bar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppSemanticColors.textPrimary,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppSemanticColors.textInverse,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppSemanticColors.surfaceDefault,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        ),
        titleTextStyle: AppTypography.heading5.copyWith(
          color: AppSemanticColors.textPrimary,
        ),
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppSemanticColors.textSecondary,
        ),
      ),
      
      // Text theme
      textTheme: TextTheme(
        displayLarge: AppTypography.heading1.copyWith(
          color: AppSemanticColors.textPrimary,
        ),
        displayMedium: AppTypography.heading2.copyWith(
          color: AppSemanticColors.textPrimary,
        ),
        displaySmall: AppTypography.heading3.copyWith(
          color: AppSemanticColors.textPrimary,
        ),
        headlineLarge: AppTypography.heading4.copyWith(
          color: AppSemanticColors.textPrimary,
        ),
        headlineMedium: AppTypography.heading5.copyWith(
          color: AppSemanticColors.textPrimary,
        ),
        headlineSmall: AppTypography.heading6.copyWith(
          color: AppSemanticColors.textPrimary,
        ),
        titleLarge: AppTypography.heading5.copyWith(
          color: AppSemanticColors.textPrimary,
        ),
        titleMedium: AppTypography.heading6.copyWith(
          color: AppSemanticColors.textPrimary,
        ),
        titleSmall: AppTypography.labelLarge.copyWith(
          color: AppSemanticColors.textPrimary,
        ),
        bodyLarge: AppTypography.bodyLarge.copyWith(
          color: AppSemanticColors.textPrimary,
        ),
        bodyMedium: AppTypography.bodyMedium.copyWith(
          color: AppSemanticColors.textPrimary,
        ),
        bodySmall: AppTypography.bodySmall.copyWith(
          color: AppSemanticColors.textSecondary,
        ),
        labelLarge: AppTypography.labelLarge.copyWith(
          color: AppSemanticColors.textSecondary,
        ),
        labelMedium: AppTypography.labelMedium.copyWith(
          color: AppSemanticColors.textSecondary,
        ),
        labelSmall: AppTypography.labelSmall.copyWith(
          color: AppSemanticColors.textTertiary,
        ),
      ),
      
      // Scaffold background color
      scaffoldBackgroundColor: AppSemanticColors.backgroundPrimary,
    );
  }
  
  static ThemeData get darkTheme {
    final lightTheme = AppTheme.lightTheme;
    
    return lightTheme.copyWith(
      brightness: Brightness.dark,
      
      // Color scheme for dark mode
      colorScheme: lightTheme.colorScheme.copyWith(
        brightness: Brightness.dark,
        surface: AppDarkColors.surfaceDefault,
        onSurface: AppDarkColors.textPrimary,
        surfaceContainerHighest: AppDarkColors.backgroundSecondary,
        outline: AppDarkColors.borderDefault,
        outlineVariant: AppDarkColors.borderHover,
      ),
      
      // App bar theme for dark mode
      appBarTheme: lightTheme.appBarTheme.copyWith(
        backgroundColor: AppDarkColors.backgroundPrimary,
        foregroundColor: AppDarkColors.textPrimary,
        titleTextStyle: AppTypography.heading5.copyWith(
          color: AppDarkColors.textPrimary,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      
      // Card theme for dark mode
      cardTheme: lightTheme.cardTheme.copyWith(
        color: AppDarkColors.surfaceDefault,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          side: const BorderSide(
            color: AppDarkColors.borderDefault,
            width: 1,
          ),
        ),
      ),
      
      // Input decoration theme for dark mode
      inputDecorationTheme: lightTheme.inputDecorationTheme.copyWith(
        fillColor: AppDarkColors.surfaceDefault,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(
            color: AppDarkColors.borderDefault,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          borderSide: const BorderSide(
            color: AppDarkColors.borderDefault,
            width: 1,
          ),
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppDarkColors.textTertiary,
        ),
        labelStyle: AppTypography.labelMedium.copyWith(
          color: AppDarkColors.textSecondary,
        ),
      ),
      
      // Bottom navigation bar theme for dark mode
      bottomNavigationBarTheme: lightTheme.bottomNavigationBarTheme.copyWith(
        backgroundColor: AppDarkColors.surfaceDefault,
        unselectedItemColor: AppDarkColors.textTertiary,
      ),
      
      // Tab bar theme for dark mode
      tabBarTheme: lightTheme.tabBarTheme.copyWith(
        unselectedLabelColor: AppDarkColors.textTertiary,
      ),
      
      // Snack bar theme for dark mode
      snackBarTheme: lightTheme.snackBarTheme.copyWith(
        backgroundColor: AppDarkColors.textPrimary,
      ),
      
      // Dialog theme for dark mode
      dialogTheme: lightTheme.dialogTheme.copyWith(
        backgroundColor: AppDarkColors.surfaceDefault,
        titleTextStyle: AppTypography.heading5.copyWith(
          color: AppDarkColors.textPrimary,
        ),
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppDarkColors.textSecondary,
        ),
      ),
      
      // Divider theme for dark mode
      dividerTheme: lightTheme.dividerTheme.copyWith(
        color: AppDarkColors.borderDefault,
      ),
      
      // Text theme for dark mode
      textTheme: lightTheme.textTheme.copyWith(
        displayLarge: AppTypography.heading1.copyWith(
          color: AppDarkColors.textPrimary,
        ),
        displayMedium: AppTypography.heading2.copyWith(
          color: AppDarkColors.textPrimary,
        ),
        displaySmall: AppTypography.heading3.copyWith(
          color: AppDarkColors.textPrimary,
        ),
        headlineLarge: AppTypography.heading4.copyWith(
          color: AppDarkColors.textPrimary,
        ),
        headlineMedium: AppTypography.heading5.copyWith(
          color: AppDarkColors.textPrimary,
        ),
        headlineSmall: AppTypography.heading6.copyWith(
          color: AppDarkColors.textPrimary,
        ),
        titleLarge: AppTypography.heading5.copyWith(
          color: AppDarkColors.textPrimary,
        ),
        titleMedium: AppTypography.heading6.copyWith(
          color: AppDarkColors.textPrimary,
        ),
        titleSmall: AppTypography.labelLarge.copyWith(
          color: AppDarkColors.textPrimary,
        ),
        bodyLarge: AppTypography.bodyLarge.copyWith(
          color: AppDarkColors.textPrimary,
        ),
        bodyMedium: AppTypography.bodyMedium.copyWith(
          color: AppDarkColors.textPrimary,
        ),
        bodySmall: AppTypography.bodySmall.copyWith(
          color: AppDarkColors.textSecondary,
        ),
        labelLarge: AppTypography.labelLarge.copyWith(
          color: AppDarkColors.textSecondary,
        ),
        labelMedium: AppTypography.labelMedium.copyWith(
          color: AppDarkColors.textSecondary,
        ),
        labelSmall: AppTypography.labelSmall.copyWith(
          color: AppDarkColors.textTertiary,
        ),
      ),
      
      // Scaffold background color for dark mode
      scaffoldBackgroundColor: AppDarkColors.backgroundPrimary,
    );
  }
}