/// 앱 글자 크기 규칙.
///
/// **왜 필요한가.** 앱은 기기 설정의 글꼴 배율을 아무 제한 없이 그대로 따라가고 있었다.
/// 삼성 기기는 배율을 아주 크게 올릴 수 있는데, 글자만 커지고 말풍선·행 높이·아이콘은
/// 그대로라 균형이 무너진다. 실제로 입력창 문구가 "메시지를 입력하세 / 요"로 잘려 나왔다
/// (제보 2026-09-08: "안드로이드에서 폰트와 크기가 제각각으로 나오는 현상").
///
/// **그렇다고 배율을 무시하면 안 된다.** 눈이 어두우신 분들이 일부러 키워 둔 설정이다.
/// 그래서 기기 설정을 존중하되 화면이 견디는 범위로 자르고, 그 위에 앱에서 직접 고를 수
/// 있게 한다("앱 내에서 폰트 크기 조절 기능 요청합니다" — 같은 날 같은 분의 요청).
library;

import 'dart:math' as math;

/// 앱에서 고를 수 있는 글자 크기.
enum AppTextSize {
  small('작게', 0.9),
  normal('보통', 1.0),
  large('크게', 1.15),
  extraLarge('아주 크게', 1.3);

  const AppTextSize(this.label, this.factor);

  /// 설정 화면에 보여줄 이름
  final String label;

  /// 기기 배율에 곱할 값
  final double factor;

  /// 저장해 둔 값을 되읽는다. 모르는 값이면 '보통'.
  static AppTextSize fromName(String? name) {
    for (final size in AppTextSize.values) {
      if (size.name == name) return size;
    }
    return AppTextSize.normal;
  }
}

/// 화면이 견디는 최소·최대 배율.
///
/// 위쪽 1.4는 눈대중이 아니라 제보 화면 기준이다 — 그보다 커지면 채팅 입력창 문구가
/// 글자 중간에서 줄바꿈되고 말풍선이 화면을 넘친다. 아래쪽 0.85는 더 줄이면 요양 현장에서
/// 읽기 힘들어지는 선이다.
const double minTextScale = 0.85;
const double maxTextScale = 1.4;

/// 실제로 적용할 글자 배율.
///
/// [systemScale]은 기기 설정에서 온 값, [size]는 앱에서 고른 값이다.
/// 둘을 곱한 뒤 화면이 견디는 범위로 자른다 — 기기에서 이미 크게 해둔 분이 앱에서 '크게'를
/// 또 고르면 곱해져 화면이 깨지기 때문이다.
double effectiveTextScale(double systemScale, AppTextSize size) {
  final raw = systemScale * size.factor;
  if (raw.isNaN || raw <= 0) return size.factor;
  return math.min(math.max(raw, minTextScale), maxTextScale);
}
