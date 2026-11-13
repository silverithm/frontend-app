import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/theme/app_spacing.dart';
import 'package:frontend_app/theme/app_typography.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// B안(2026-11-12) 토큰 — 시안 template.html의 값이 그대로 들어갔는지, 글자 대비가 4.5:1을 넘는지.
void main() {
  group('글자 대비 4.5:1 이상', () {
    final pairs = <String, (Color, Color)>{
      '틸 상단 바 위 흰 글자': (AppSemanticColors.headerForeground, AppSemanticColors.headerBackground),
      '틸 상단 바 위 보조 글자': (AppSemanticColors.headerForegroundMuted, AppSemanticColors.headerBackground),
      '회색 바탕 위 본문': (AppSemanticColors.textPrimary, AppSemanticColors.backgroundCanvas),
      '회색 바탕 위 보조 글자': (AppSemanticColors.textSecondary, AppSemanticColors.backgroundCanvas),
      '회색 바탕 위 옅은 글자': (AppSemanticColors.textTertiary, AppSemanticColors.backgroundCanvas),
      '흰 카드 위 옅은 글자': (AppSemanticColors.textTertiary, AppSemanticColors.surfaceCard),
      '회색 바탕 위 틸 링크': (AppSemanticColors.textLink, AppSemanticColors.backgroundCanvas),
      '옅은 틸 위 진한 틸': (AppSemanticColors.brandWeakForeground, AppSemanticColors.brandWeak),
      '틸 단추 위 흰 글자': (AppSemanticColors.textInverse, AppSemanticColors.brandDefault),
      '틸 단추 눌림 위 흰 글자': (AppSemanticColors.textInverse, AppSemanticColors.brandPressed),
      '위험 단추 위 흰 글자': (AppSemanticColors.textInverse, AppSemanticColors.dangerDefault),
      '배지 위 흰 글자': (AppSemanticColors.textInverse, AppSemanticColors.badgeBackground),
      '보조 단추 위 글자': (AppSemanticColors.textPrimary, AppSemanticColors.fillDefault),
      '대기 알약': (AppSemanticColors.statusWarningText, AppSemanticColors.statusWarningBackground),
      '승인 알약': (AppSemanticColors.statusSuccessText, AppSemanticColors.statusSuccessBackground),
      '반려 알약': (AppSemanticColors.statusErrorText, AppSemanticColors.statusErrorBackground),
      '중립 알약': (AppSemanticColors.textSecondary, AppSemanticColors.fillDefault),
      '알림 띠 위 흰 글자': (AppSemanticColors.textInverse, AppSemanticColors.toastBackground),
    };
    for (final e in pairs.entries) {
      test(e.key, () {
        // 반투명 알림 띠는 회색 바탕 위에 얹힌 색으로 잰다.
        final bg = Color.alphaBlend(e.value.$2, AppSemanticColors.backgroundCanvas);
        expect(_contrast(e.value.$1, bg), greaterThanOrEqualTo(4.5), reason: e.key);
      });
    }
  });

  test('시안 값 그대로 — 바탕·카드·틸·옅은 틸', () {
    expect(AppSemanticColors.backgroundCanvas, const Color(0xFFF2F4F6));
    expect(AppSemanticColors.surfaceCard, const Color(0xFFFFFFFF));
    expect(AppSemanticColors.brandDefault, const Color(0xFF0F766E));
    expect(AppSemanticColors.brandPressed, const Color(0xFF0B5D57));
    expect(AppSemanticColors.brandWeak, const Color(0xFFE6F4F1));
    expect(AppSemanticColors.fillStrong, const Color(0xFFE8EBEE));
    expect(AppSemanticColors.surfacePressed, const Color(0xFFEEF0F3));
    expect(AppSemanticColors.borderHairline, const Color(0xFFE4E7EB));
  });

  test('글자 크기는 22·17·15·13·11 다섯 단계(+ 달력 칸 10)뿐 — 사이 크기를 두지 않는다', () {
    const ladder = <double>[22, 17, 15, 13, 11];
    final styles = <String, TextStyle>{
      'heading4': AppTypography.heading4,
      'heading5': AppTypography.heading5,
      'heading6': AppTypography.heading6,
      'appBarTitle': AppTypography.appBarTitle,
      'appBarTitleLarge': AppTypography.appBarTitleLarge,
      'titleMedium': AppTypography.titleMedium,
      'titleSmall': AppTypography.titleSmall,
      'labelStrong': AppTypography.labelStrong,
      'bodyLarge': AppTypography.bodyLarge,
      'bodyMedium': AppTypography.bodyMedium,
      'bodySmall': AppTypography.bodySmall,
      'labelLarge': AppTypography.labelLarge,
      'labelMedium': AppTypography.labelMedium,
      'labelSmall': AppTypography.labelSmall,
      'buttonLarge': AppTypography.buttonLarge,
      'buttonMedium': AppTypography.buttonMedium,
      'buttonSmall': AppTypography.buttonSmall,
      'caption': AppTypography.caption,
      'overline': AppTypography.overline,
      'heading1': AppTypography.heading1,
      'heading2': AppTypography.heading2,
      'heading3': AppTypography.heading3,
    };
    styles.forEach((name, style) {
      expect(ladder, contains(style.fontSize), reason: '$name ${style.fontSize}');
    });
    // 달력 칸만 10
    expect(AppTypography.calendarCell.fontSize, 10);
    // 크기 상수도 같은 단계만
    for (final size in [
      AppTypography.fontSizeXs,
      AppTypography.fontSizeSm,
      AppTypography.fontSizeBase,
      AppTypography.fontSizeLg,
      AppTypography.fontSizeXl,
    ]) {
      expect(ladder, contains(size));
    }
  });

  // 글자 단계(2026-11-14): 큰 제목 22 / 제목 17 / 본문 15 / 보조 13 / 작은 글씨 11
  test('글자 단계 — 본문 15, 보조 13, 목록 제목 15/w600, 카드·시트 제목 17, 큰 제목·큰 숫자 22 고정폭', () {
    expect(AppTypography.bodyMedium.fontSize, 15);
    expect(AppTypography.bodySmall.fontSize, 13);
    expect(AppTypography.titleMedium.fontSize, 15);
    expect(AppTypography.titleMedium.fontWeight, FontWeight.w600);
    expect(AppTypography.titleSmall.fontSize, 13);
    expect(AppTypography.heading6.fontSize, 17);
    expect(AppTypography.heading5.fontSize, 17);
    expect(AppTypography.appBarTitle.fontSize, 17);
    expect(AppTypography.appBarTitleLarge.fontSize, 22);
    expect(AppTypography.appBarTitleLarge.fontWeight, FontWeight.w700);
    expect(AppTypography.heading4.fontSize, 22);
    expect(AppTypography.labelStrong.fontSize, 11);
    expect(AppTypography.labelSmall.fontSize, 11);
    expect(AppTypography.heading4.fontFeatures, contains(const FontFeature.tabularFigures()));
    // 11보다 작은 글자는 달력 칸(10)뿐이다
    for (final style in [
      AppTypography.labelSmall,
      AppTypography.caption,
      AppTypography.overline,
      AppTypography.labelMedium,
      AppTypography.labelStrong,
      AppTypography.buttonSmall,
    ]) {
      expect(style.fontSize, greaterThanOrEqualTo(11));
    }
  });

  test('모서리·높이 — 카드 16, 단추 12·52, 시트 24, 하단 탭 64', () {
    expect(AppBorderRadius.card, 16);
    expect(AppBorderRadius.control, 12);
    expect(AppBorderRadius.sheet, 24);
    expect(AppSpacing.buttonHeightLarge, 52);
    expect(AppSpacing.bottomTabHeight, 64);
    expect(AppSpacing.toolbarHeight, 56);
    expect(AppSpacing.minTouchTarget, 48);
  });
}
