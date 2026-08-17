/// 양식 필드가 한 줄에서 차지하는 폭.
///
/// 웹 관리자(`frontend-admin/src/types/formSchema.ts`의 FIELD_WIDTH_SPAN)와 같은 12칼럼 기준이다.
/// 양식 관리에서 1/2·1/3·2/3처럼 정해둔 비율을 앱에서도 같게 보여주려면 이 값을 써야 한다.
/// (예전에는 앱이 두 필드를 무조건 반씩 나눠서, 1/3+2/3으로 만든 양식이 앱에서는 반반으로 보였다)
///
/// 여기를 고치면 웹의 FIELD_WIDTH_SPAN도 함께 맞출 것.
library;

const Map<String, int> _fieldWidthSpan = {
  'full': 12,
  'twoThirds': 8,
  'half': 6,
  'third': 4,
  'quarter': 3,
};

/// 12칼럼 중 몇 칸을 차지하는지. 모르는 값(구형 필드)은 한 줄 전체로 본다.
int fieldWidthSpan(Object? width) {
  final key = width?.toString();
  return _fieldWidthSpan[key] ?? 12;
}

/// 한 줄에 혼자 서는 필드인지 (12칼럼을 통째로 쓴다)
bool isFullFieldWidth(Object? width) => fieldWidthSpan(width) >= 12;

/// 필드들을 12칼럼이 찰 때까지 한 줄로 묶는다.
///
/// 웹(`formValueFormat.ts`의 groupFieldsIntoRows)과 같은 규칙이다 —
/// "둘 다 좁을 때만 묶기"가 아니라 **합이 12를 넘지 않으면 묶는다**.
/// 그래서 1/3 + 2/3처럼 서로 다른 폭도 한 줄에 나란히 선다.
/// [spanOf]로 각 항목의 폭을, [isBlock]으로 한 줄을 통째로 쓰는 항목(구분선 등)을 알려준다.
List<List<T>> groupIntoRowsBySpan<T>(
  List<T> items, {
  required int Function(T) spanOf,
  required bool Function(T) isBlock,
  int maxPerRow = 2,
}) {
  final rows = <List<T>>[];
  var current = <T>[];
  var used = 0;

  void flush() {
    if (current.isNotEmpty) {
      rows.add(List<T>.from(current));
      current = [];
      used = 0;
    }
  }

  for (final item in items) {
    if (isBlock(item)) {
      flush();
      rows.add([item]);
      continue;
    }

    final span = spanOf(item);
    if (span >= 12) {
      flush();
      rows.add([item]);
      continue;
    }

    if (used + span > 12 || current.length >= maxPerRow) {
      flush();
    }
    current.add(item);
    used += span;
    if (used >= 12 || current.length >= maxPerRow) {
      flush();
    }
  }

  flush();
  return rows;
}
