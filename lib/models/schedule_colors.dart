import 'package:flutter/material.dart';

import 'schedule.dart';

/// 일정 카테고리 기본색.
///
/// 색을 직접 고르지 않은 일정도 카테고리별로 구분되어 보이도록 쓰는 폴백색이다.
/// 웹(`src/types/schedule.ts`의 `SCHEDULE_CATEGORY_COLORS`)과 값이 반드시 같아야 한다 —
/// 다르면 같은 일정이 앱과 웹에서 다른 색으로 보인다.
class ScheduleCategoryColors {
  const ScheduleCategoryColors._();

  static const Color meeting = Color(0xFF3B82F6); // 회의 - 파랑
  static const Color event = Color(0xFFEC4899); // 행사 - 분홍
  static const Color training = Color(0xFF8B5CF6); // 교육 - 보라
  static const Color other = Color(0xFF14B8A6); // 기타 - 틸

  /// 카테고리 코드('MEETING' 등)로 기본색을 찾는다. 모르는 값은 '기타'로 취급.
  static Color forCategory(String category) {
    switch (category) {
      case 'MEETING':
        return meeting;
      case 'EVENT':
        return event;
      case 'TRAINING':
        return training;
      case 'OTHER':
      default:
        return other;
    }
  }
}

/// 일정 색상 팔레트 옵션 하나 (선택 UI용).
class ScheduleColorOption {
  const ScheduleColorOption(this.hex, this.color, this.name);

  final String hex;
  final Color color;
  final String name;
}

/// 일정 색상 팔레트 — 웹(`SCHEDULE_COLORS`)과 동일한 12색, 같은 순서.
/// 일정 등록/수정 폼의 색 선택 UI에서 그대로 노출한다.
///
/// 색상환 순서(빨강 → 보라 → 분홍)로 늘어놓고 무채색을 끝에 둔다. 기존 8색의 값은
/// 그대로 두고 사이를 메웠으므로 이미 저장된 일정의 색이 목록 밖으로 밀리지 않는다.
/// 웹과 값·순서가 어긋나면 같은 일정이 두 화면에서 다른 자리에 놓이므로 함께 고쳐야 한다.
class ScheduleColorPalette {
  const ScheduleColorPalette._();

  static const List<ScheduleColorOption> values = [
    ScheduleColorOption('#EF4444', Color(0xFFEF4444), '빨강'),
    ScheduleColorOption('#F97316', Color(0xFFF97316), '주황'),
    ScheduleColorOption('#EAB308', Color(0xFFEAB308), '노랑'),
    ScheduleColorOption('#84CC16', Color(0xFF84CC16), '연두'),
    ScheduleColorOption('#22C55E', Color(0xFF22C55E), '초록'),
    ScheduleColorOption('#14B8A6', Color(0xFF14B8A6), '청록'),
    ScheduleColorOption('#0EA5E9', Color(0xFF0EA5E9), '하늘'),
    ScheduleColorOption('#3B82F6', Color(0xFF3B82F6), '파랑'),
    ScheduleColorOption('#6366F1', Color(0xFF6366F1), '남보라'),
    ScheduleColorOption('#8B5CF6', Color(0xFF8B5CF6), '보라'),
    ScheduleColorOption('#EC4899', Color(0xFFEC4899), '분홍'),
    ScheduleColorOption('#6B7280', Color(0xFF6B7280), '회색'),
  ];
}

/// "#RRGGBB"(또는 "#AARRGGBB") 문자열을 [Color]로 변환한다. 형식이 아니거나 비어있으면 null.
Color? colorFromHex(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final cleaned = hex.replaceFirst('#', '');
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return null;
  return Color(cleaned.length == 8 ? value : 0xFF000000 | value);
}

/// 일정을 화면에 그릴 때 쓸 색.
///
/// 일정에 직접 고른 색(schedule.color)이 있으면 그 색, 없으면 카테고리 기본색으로 폴백한다.
/// 웹의 `getScheduleColor()`와 같은 규칙이다. 일정 색을 그리는 모든 곳(오늘 일정 팝업,
/// 캘린더 목록 카드, 대시보드 도트 등)이 이 함수 하나로 색을 결정해야 앱 전체가 일관된다.
Color scheduleDisplayColor(Schedule schedule) {
  return colorFromHex(schedule.color) ??
      ScheduleCategoryColors.forCategory(schedule.category);
}
