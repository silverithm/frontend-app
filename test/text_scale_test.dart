import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/theme/text_scale.dart';

/// 글자 배율 규칙.
///
/// 앱은 기기 설정을 아무 제한 없이 따라가고 있었다. 삼성 기기에서 크게 키워 두면
/// 글자만 커지고 말풍선·행 높이는 그대로라, 입력창 문구가 "메시지를 입력하세 / 요"로
/// 잘려 나왔다 (제보 2026-09-08).
///
/// 그렇다고 기기 설정을 무시하면 눈이 어두우신 분들이 일부러 키워 둔 것을 뺏는 셈이다.
/// **존중하되 화면이 견디는 범위로 자른다**는 것이 이 규칙이다.
void main() {
  group('기기 설정을 존중한다', () {
    test('보통으로 두면 기기 배율을 그대로 쓴다', () {
      expect(effectiveTextScale(1.0, AppTextSize.normal), 1.0);
      expect(effectiveTextScale(1.2, AppTextSize.normal), closeTo(1.2, 0.001));
    });

    test('기기에서 키운 만큼 앱도 커진다 — 상한 안에서는', () {
      final small = effectiveTextScale(1.0, AppTextSize.normal);
      final bigger = effectiveTextScale(1.25, AppTextSize.normal);
      expect(bigger, greaterThan(small));
    });
  });

  group('화면이 견디는 범위로 자른다', () {
    test('기기에서 아주 크게 해둬도 상한을 넘지 않는다 — 여기서 화면이 깨졌다', () {
      expect(effectiveTextScale(2.0, AppTextSize.normal), maxTextScale);
      expect(effectiveTextScale(3.5, AppTextSize.extraLarge), maxTextScale);
    });

    test('기기에서 아주 작게 해둬도 하한 아래로 내려가지 않는다', () {
      expect(effectiveTextScale(0.5, AppTextSize.normal), minTextScale);
      expect(effectiveTextScale(0.3, AppTextSize.small), minTextScale);
    });

    test('어떤 조합에서도 범위를 벗어나지 않는다', () {
      for (final systemScale in [0.1, 0.5, 0.85, 1.0, 1.3, 2.0, 5.0]) {
        for (final size in AppTextSize.values) {
          final scale = effectiveTextScale(systemScale, size);
          expect(scale, greaterThanOrEqualTo(minTextScale), reason: '$systemScale $size');
          expect(scale, lessThanOrEqualTo(maxTextScale), reason: '$systemScale $size');
        }
      }
    });
  });

  group('앱에서 고른 크기', () {
    test('크게 고르면 실제로 커지고, 작게 고르면 작아진다', () {
      final small = effectiveTextScale(1.0, AppTextSize.small);
      final normal = effectiveTextScale(1.0, AppTextSize.normal);
      final large = effectiveTextScale(1.0, AppTextSize.large);
      final extraLarge = effectiveTextScale(1.0, AppTextSize.extraLarge);

      expect(small, lessThan(normal));
      expect(large, greaterThan(normal));
      expect(extraLarge, greaterThan(large));
    });

    test('기기에서 이미 키운 분이 앱에서도 크게 고르면 곱해지되 상한에서 멈춘다', () {
      expect(effectiveTextScale(1.3, AppTextSize.extraLarge), maxTextScale);
    });
  });

  group('저장한 값 되읽기', () {
    test('고른 값을 이름으로 저장했다가 그대로 되읽는다', () {
      for (final size in AppTextSize.values) {
        expect(AppTextSize.fromName(size.name), size);
      }
    });

    test('저장된 값이 없거나 모르는 값이면 보통으로 시작한다', () {
      expect(AppTextSize.fromName(null), AppTextSize.normal);
      expect(AppTextSize.fromName(''), AppTextSize.normal);
      expect(AppTextSize.fromName('huge'), AppTextSize.normal);
    });
  });

  test('이상한 기기 값이 와도 앱이 멈추지 않는다', () {
    expect(effectiveTextScale(0, AppTextSize.normal), AppTextSize.normal.factor);
    expect(effectiveTextScale(double.nan, AppTextSize.large), AppTextSize.large.factor);
  });
}
