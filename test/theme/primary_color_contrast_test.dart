import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:frontend_app/theme/app_colors.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('주색(케어브이 틸)', () {
    test('주색 위 흰 글자 대비가 4.5:1 이상', () {
      for (final c in [
        AppSemanticColors.interactivePrimaryDefault,
        AppSemanticColors.interactivePrimaryHover,
        AppSemanticColors.interactivePrimaryActive,
        AppSemanticColors.brandDefault,
        AppSemanticColors.brandPressed,
      ]) {
        expect(_contrast(AppColors.white, c), greaterThanOrEqualTo(4.5),
            reason: '$c');
      }
    });

    test('흰 바탕 위 주색 글자(링크·포커스)도 4.5:1 이상', () {
      expect(_contrast(AppSemanticColors.textLink, AppColors.white),
          greaterThanOrEqualTo(4.5));
      expect(_contrast(AppSemanticColors.borderFocus, AppColors.white),
          greaterThanOrEqualTo(4.5));
    });

    test('주색 토큰은 케어브이 틸 값', () {
      expect(AppSemanticColors.interactivePrimaryDefault, AppColors.careTeal);
      expect(AppColors.careTeal, const Color(0xFF0F766E));
      expect(AppSemanticColors.brandWeak, AppColors.careTealTint);
    });
  });
}
