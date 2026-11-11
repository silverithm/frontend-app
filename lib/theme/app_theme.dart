import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_spacing.dart';
import 'app_page_transitions.dart';

class AppTheme {
  /// 화면 상단 바·구분선을 앱 전체에 한 번에 입힌다.
  /// 실제로 쓰이는 Material 테마는 ShadcnApp이 만들기 때문에(아래 lightTheme은 연결돼
  /// 있지 않다) main.dart의 builder에서 그 테마 위에 덧씌운다.
  ///
  /// 화면 넘김(pageTransitionsTheme)도 여기서 건다 — 앱의 MaterialPageRoute가 전부 이걸 쓴다
  /// (theme/app_page_transitions.dart).
  ///
  /// B안(2026-11-12): 회색 바탕·흰 카드·큰 단추·옅은 알약·아래 시트를 여기서 기본값으로 건다.
  /// 화면이 색·모양을 따로 정한 곳은 그 값이 이긴다(3단계에서 화면별로 걷어낸다).
  static ThemeData withAppChrome(ThemeData base) {
    return base.copyWith(
      scaffoldBackgroundColor: AppSemanticColors.backgroundCanvas,
      colorScheme: _colorScheme(base.colorScheme),
      appBarTheme: headerTheme,
      pageTransitionsTheme: appPageTransitionsTheme,
      actionIconTheme: _actionIconTheme,
      dividerTheme: base.dividerTheme.copyWith(
        color: AppSemanticColors.borderHairline,
      ),
      cardTheme: _cardTheme,
      filledButtonTheme: _filledButtonTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      iconButtonTheme: _iconButtonTheme,
      inputDecorationTheme: _inputDecorationTheme,
      chipTheme: _chipTheme,
      floatingActionButtonTheme: _fabTheme,
      bottomSheetTheme: _bottomSheetTheme,
      dialogTheme: _dialogTheme,
      snackBarTheme: _snackBarTheme,
      switchTheme: _switchTheme,
      checkboxTheme: _checkboxTheme,
      radioTheme: _radioTheme,
      progressIndicatorTheme: _progressTheme,
      bottomNavigationBarTheme: _bottomNavTheme,
      tabBarTheme: _tabBarTheme,
      listTileTheme: _listTileTheme,
      popupMenuTheme: _popupMenuTheme,
      textSelectionTheme: _textSelectionTheme,
    );
  }

  /// 상단 바 — B안(2026-11-12): 틸 바탕은 남기고 높이 56, 아래 선은 없앴다(회색 바탕과 맞닿아
  /// 선이 없어도 구분된다). 안쪽 화면 제목은 가운데 17/w600, 탭 첫 화면은 CareVAppBar(isRoot)로
  /// 왼쪽 20/w700. 스크롤해도 색·그림자가 바뀌지 않는다.
  static AppBarTheme get headerTheme {
    return AppBarTheme(
      backgroundColor: AppSemanticColors.headerBackground,
      foregroundColor: AppSemanticColors.headerForeground,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: AppSpacing.toolbarHeight,
      surfaceTintColor: AppColors.transparent,
      actionsPadding: const EdgeInsets.only(right: AppSpacing.space1),
      iconTheme: const IconThemeData(
        color: AppSemanticColors.headerForeground,
        size: 24,
      ),
      actionsIconTheme: const IconThemeData(
        color: AppSemanticColors.headerForeground,
        size: 24,
      ),
      titleTextStyle: AppTypography.appBarTitle.copyWith(
        fontFamily: AppTypography.fontFamilySans,
        color: AppSemanticColors.headerForeground,
      ),
      // 상태표시줄 아이콘 밝기는 지정하지 않는다 — AppBar가 바탕 밝기로 정하게 둬야
      // 검은 사진 뷰어 상단 바에서도 아이콘이 보인다
    );
  }

  // ── B안 부품 기본값 (withAppChrome에서 건다) ──────────────────────────

  static ColorScheme _colorScheme(ColorScheme base) => base.copyWith(
        primary: AppSemanticColors.brandDefault,
        onPrimary: AppSemanticColors.textInverse,
        surface: AppSemanticColors.surfaceCard,
        onSurface: AppSemanticColors.textPrimary,
        onSurfaceVariant: AppSemanticColors.textSecondary,
        surfaceContainer: AppSemanticColors.surfaceCard,
        surfaceContainerHigh: AppSemanticColors.surfaceCard,
        surfaceTint: AppColors.transparent,
        outline: AppSemanticColors.borderDefault,
        outlineVariant: AppSemanticColors.borderHairline,
        error: AppSemanticColors.dangerDefault,
        scrim: AppSemanticColors.overlayScrim,
      );

  /// 뒤로 가기는 시안처럼 꺾쇠(‹) — AppBar가 저절로 넣는 뒤로 단추도 이 모양이 된다.
  static final ActionIconThemeData _actionIconTheme = ActionIconThemeData(
    backButtonIconBuilder: (context) =>
        const Icon(Icons.chevron_left_rounded, size: 30),
  );

  /// 카드 — 흰 바탕, 테두리·그림자 없음, 모서리 20.
  static const CardThemeData _cardTheme = CardThemeData(
    color: AppSemanticColors.surfaceCard,
    surfaceTintColor: AppColors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppBorderRadius.card)),
    ),
  );

  static const RoundedRectangleBorder _controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppBorderRadius.control)),
  );

  /// 주 단추 — 틸, 높이 48 이상, 모서리 14, 16/w600.
  static ButtonStyle get _primaryButtonStyle => ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) {
            return AppSemanticColors.surfaceDisabled;
          }
          if (s.contains(WidgetState.pressed)) {
            return AppSemanticColors.brandPressed;
          }
          return AppSemanticColors.brandDefault;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.disabled)
                ? AppSemanticColors.textDisabled
                : AppSemanticColors.textInverse),
        overlayColor: const WidgetStatePropertyAll(AppColors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        shape: const WidgetStatePropertyAll(_controlShape),
        minimumSize: const WidgetStatePropertyAll(
          Size(AppSpacing.minTouchTarget, AppSpacing.buttonHeight),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpacing.space5),
        ),
        textStyle: const WidgetStatePropertyAll(AppTypography.buttonMedium),
      );

  static FilledButtonThemeData get _filledButtonTheme =>
      FilledButtonThemeData(style: _primaryButtonStyle);

  static ElevatedButtonThemeData get _elevatedButtonTheme =>
      ElevatedButtonThemeData(style: _primaryButtonStyle);

  /// 테두리 단추 — 흰 바탕 위 보조 동작. 선은 기본 회색 한 줄만.
  static OutlinedButtonThemeData get _outlinedButtonTheme =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppSemanticColors.textPrimary,
          disabledForegroundColor: AppSemanticColors.textDisabled,
          side: const BorderSide(color: AppSemanticColors.borderDefault),
          shape: _controlShape,
          minimumSize: const Size(
            AppSpacing.minTouchTarget,
            AppSpacing.buttonHeight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5),
          textStyle: AppTypography.buttonMedium,
        ),
      );

  /// 글자 단추("전체보기"·"취소") — 틸 15/w600, 터치 48.
  static TextButtonThemeData get _textButtonTheme => TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppSemanticColors.textLink,
          disabledForegroundColor: AppSemanticColors.textDisabled,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppBorderRadius.xl)),
          ),
          minimumSize: const Size(
            AppSpacing.minTouchTarget,
            AppSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space3),
          textStyle: AppTypography.titleSmall,
        ),
      );

  /// 아이콘 단추 — 48 터치, 눌림 자국은 모서리 14 네모(시안 .ibtn).
  static IconButtonThemeData get _iconButtonTheme => IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: _controlShape,
          minimumSize: const Size(
            AppSpacing.minTouchTarget,
            AppSpacing.minTouchTarget,
          ),
        ),
      );

  /// 입력칸 — 테마에서는 채우지 않는다(filled: false). 화면 곳곳의 맨 TextField가 저마다
  /// 테두리·바탕을 정해 두어, 여기서 채우면 그 안에 네모 회색이 겹쳐 보인다. B안의 '회색으로
  /// 채운 입력칸'은 SeedTextField·AppInput이 직접 그린다. 여기는 테두리를 정하지 않은 칸의 기본값.
  ///
  /// 상태별 테두리(enabled·focused·error)는 일부러 걸지 않는다.
  /// 걸면 화면이 `border: InputBorder.none`으로 테두리를 뺀 칸(채팅 입력, SeedTextField 안쪽 칸)에도
  /// 테마 테두리가 다시 그려져 칸 안에 칸이 생긴다. `border` 하나만 두면 Flutter가 상태 색을
  /// colorScheme(outline·primary·error)에서 고르고, 화면이 준 `border`는 모든 상태에서 이긴다.
  static const InputDecorationTheme _inputDecorationTheme =
      InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppBorderRadius.control)),
      borderSide: BorderSide(color: AppSemanticColors.borderDefault),
    ),
    contentPadding: EdgeInsets.symmetric(
      horizontal: AppSpacing.space4,
      vertical: 13,
    ),
    hintStyle: TextStyle(color: AppSemanticColors.textTertiary),
    labelStyle: TextStyle(color: AppSemanticColors.textSecondary),
    errorStyle: TextStyle(
      fontSize: AppTypography.fontSizeBase,
      color: AppSemanticColors.statusErrorText,
    ),
    helperStyle: TextStyle(
      fontSize: AppTypography.fontSizeBase,
      color: AppSemanticColors.textTertiary,
    ),
  );

  /// 칩 — 테두리 없는 알약. 고르면 틸 바탕 + 흰 글자(체크 표시 없음).
  static ChipThemeData get _chipTheme => ChipThemeData(
        backgroundColor: AppSemanticColors.fillDefault,
        selectedColor: AppSemanticColors.brandDefault,
        disabledColor: AppSemanticColors.surfaceDisabled,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        showCheckmark: false,
        checkmarkColor: AppSemanticColors.textInverse,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
        labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.space1),
        labelStyle: AppTypography.titleSmall.copyWith(
          color: WidgetStateColor.resolveWith((s) {
            if (s.contains(WidgetState.disabled)) {
              return AppSemanticColors.textDisabled;
            }
            return s.contains(WidgetState.selected)
                ? AppSemanticColors.textInverse
                : AppSemanticColors.textSecondary;
          }),
        ),
      );

  /// FAB — 알약 모양 틸, 글자 17/w600, 높이 56.
  static const FloatingActionButtonThemeData _fabTheme =
      FloatingActionButtonThemeData(
    backgroundColor: AppSemanticColors.brandDefault,
    foregroundColor: AppSemanticColors.textInverse,
    splashColor: AppSemanticColors.brandPressed,
    elevation: 4,
    focusElevation: 4,
    hoverElevation: 5,
    highlightElevation: 6,
    shape: StadiumBorder(),
    extendedTextStyle: AppTypography.buttonLarge,
    extendedPadding: EdgeInsetsDirectional.only(
      start: AppSpacing.space4,
      end: AppSpacing.space5,
    ),
    extendedIconLabelSpacing: AppSpacing.space1_5,
    extendedSizeConstraints: BoxConstraints.tightFor(height: 56),
  );

  /// 아래에서 올라오는 시트 — 흰 바탕, 위 모서리 24, 뒤는 rgba(11,15,20,.45).
  static const BottomSheetThemeData _bottomSheetTheme = BottomSheetThemeData(
    backgroundColor: AppSemanticColors.surfaceCard,
    surfaceTintColor: AppColors.transparent,
    modalBackgroundColor: AppSemanticColors.surfaceCard,
    modalBarrierColor: AppSemanticColors.overlayScrim,
    elevation: 0,
    modalElevation: 0,
    clipBehavior: Clip.antiAlias,
    dragHandleColor: AppSemanticColors.sheetHandle,
    dragHandleSize: Size(40, 5),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppBorderRadius.sheet),
      ),
    ),
  );

  /// 가운데 대화상자(남아 있는 맞춤 창) — 흰 바탕, 모서리 24.
  static final DialogThemeData _dialogTheme = DialogThemeData(
    backgroundColor: AppSemanticColors.surfaceCard,
    surfaceTintColor: AppColors.transparent,
    barrierColor: AppSemanticColors.overlayScrim,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppBorderRadius.sheet)),
    ),
    titleTextStyle:
        AppTypography.heading5.copyWith(color: AppSemanticColors.textPrimary),
    contentTextStyle:
        AppTypography.bodyMedium.copyWith(color: AppSemanticColors.textSecondary),
  );

  /// 알림 띠 — 짙은 회색 반투명, 흰 글자, 모서리 14(시안 .toast).
  static final SnackBarThemeData _snackBarTheme = SnackBarThemeData(
    backgroundColor: AppSemanticColors.toastBackground,
    contentTextStyle:
        AppTypography.labelLarge.copyWith(color: AppSemanticColors.textInverse),
    actionTextColor: AppColors.teal300,
    elevation: 0,
    behavior: SnackBarBehavior.floating,
    insetPadding: const EdgeInsets.all(AppSpacing.space4),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppBorderRadius.control)),
    ),
  );

  /// 스위치 — 켜면 틸, 끄면 회색(#C5CAD1), 손잡이는 늘 흰색, 테두리 없음.
  static final SwitchThemeData _switchTheme = SwitchThemeData(
    thumbColor: const WidgetStatePropertyAll(AppSemanticColors.surfaceCard),
    trackColor: WidgetStateProperty.resolveWith((s) {
      if (s.contains(WidgetState.disabled)) {
        return AppSemanticColors.surfaceDisabled;
      }
      return s.contains(WidgetState.selected)
          ? AppSemanticColors.brandDefault
          : AppSemanticColors.switchTrackOff;
    }),
    trackOutlineColor: const WidgetStatePropertyAll(AppColors.transparent),
  );

  /// 체크 — 고르면 틸. 빈 칸 테두리는 흰 바탕에서 보이는 iconSubtle(4.8:1).
  static final CheckboxThemeData _checkboxTheme = CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected)
            ? AppSemanticColors.brandDefault
            : AppColors.transparent),
    checkColor: const WidgetStatePropertyAll(AppSemanticColors.textInverse),
    side: const BorderSide(color: AppSemanticColors.iconSubtle, width: 1.5),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppBorderRadius.md)),
    ),
  );

  static final RadioThemeData _radioTheme = RadioThemeData(
    fillColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected)
            ? AppSemanticColors.brandDefault
            : AppSemanticColors.iconSubtle),
  );

  static const ProgressIndicatorThemeData _progressTheme =
      ProgressIndicatorThemeData(
    color: AppSemanticColors.brandDefault,
    linearTrackColor: AppSemanticColors.fillStrong,
    circularTrackColor: AppColors.transparent,
  );

  /// 하단 탭 기본값 — 실제 앱은 AppBottomTabBar(widgets/common)를 쓴다.
  static final BottomNavigationBarThemeData _bottomNavTheme =
      BottomNavigationBarThemeData(
    backgroundColor: AppSemanticColors.surfaceCard,
    selectedItemColor: AppSemanticColors.brandDefault,
    unselectedItemColor: AppSemanticColors.iconSubtle,
    selectedLabelStyle:
        AppTypography.labelSmall.copyWith(fontWeight: AppTypography.fontWeightBold),
    unselectedLabelStyle: AppTypography.labelSmall,
    elevation: 0,
    type: BottomNavigationBarType.fixed,
  );

  /// 상단 바 밖의 탭바 — 틸 밑줄, 글자 15/w600. 상단 바 안 탭바는 화면이 흰 글자로 따로 정한다.
  static const TabBarThemeData _tabBarTheme = TabBarThemeData(
    labelColor: AppSemanticColors.textPrimary,
    unselectedLabelColor: AppSemanticColors.textSecondary,
    labelStyle: AppTypography.titleSmall,
    unselectedLabelStyle: AppTypography.labelLarge,
    indicatorColor: AppSemanticColors.brandDefault,
    dividerColor: AppSemanticColors.borderHairline,
  );

  /// 목록 줄 — 제목 16/w600, 부제 14 ink2.
  static final ListTileThemeData _listTileTheme = ListTileThemeData(
    titleTextStyle:
        AppTypography.titleMedium.copyWith(color: AppSemanticColors.textPrimary),
    subtitleTextStyle:
        AppTypography.bodySmall.copyWith(color: AppSemanticColors.textSecondary),
    iconColor: AppSemanticColors.textSecondary,
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
  );

  static final PopupMenuThemeData _popupMenuTheme = PopupMenuThemeData(
    color: AppSemanticColors.surfaceCard,
    surfaceTintColor: AppColors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppBorderRadius.control)),
    ),
    textStyle:
        AppTypography.bodyMedium.copyWith(color: AppSemanticColors.textPrimary),
  );

  static const TextSelectionThemeData _textSelectionTheme =
      TextSelectionThemeData(
    cursorColor: AppSemanticColors.brandDefault,
    selectionColor: Color(0xFFBFE3DC), // 시안 ::selection
    selectionHandleColor: AppSemanticColors.brandDefault,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // Color scheme (shadcn zinc - black/white minimal)
      colorScheme: const ColorScheme.light(
        primary: AppSemanticColors.interactivePrimaryDefault,
        onPrimary: AppSemanticColors.textInverse,
        primaryContainer: Color(0xFFF3F4F5), // zinc-100
        onPrimaryContainer: Color(0xFF1A1C20), // zinc-950

        secondary: AppSemanticColors.interactiveSecondaryDefault,
        onSecondary: Color(0xFF1A1C20), // zinc-950
        secondaryContainer: Color(0xFFF3F4F5), // zinc-100
        onSecondaryContainer: Color(0xFF1A1C20), // zinc-950

        tertiary: Color(0xFF1A1C20), // zinc-900
        onTertiary: AppSemanticColors.textInverse,
        tertiaryContainer: Color(0xFFF3F4F5), // zinc-100
        onTertiaryContainer: Color(0xFF1A1C20), // zinc-950

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
        shadowColor: AppColors.black.withValues(alpha: 0.1),
        surfaceTintColor: AppColors.transparent,
        titleTextStyle: AppTypography.heading5.copyWith(
          color: AppSemanticColors.textPrimary,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppColors.transparent,
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
          shadowColor: AppColors.transparent,
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
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        foregroundColor: AppSemanticColors.textInverse,
        elevation: 6,
        // shape를 지정하지 않으면 기본값 사용 (일반 FAB은 원형, extended는 StadiumBorder)
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
          statusBarColor: AppColors.transparent,
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