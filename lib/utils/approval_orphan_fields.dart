/// 양식을 고친 뒤 지난 결재 문서를 열 때, 지금 양식에 없는 항목에 써 둔 내용(2026-11-16).
///
/// 업무일지 양식에서 '행정 업무'를 복제한 뒤 원래 항목을 지우자 지난 업무일지 본문이 웹에서는
/// 사라졌고, 앱에서는 맨 아래에 'content' 같은 내부 키 이름으로 나왔다(빈 항목도 '-'로 줄줄이).
/// 웹(src/lib/retiredFields.ts)과 같은 규칙으로 맞춘다:
/// - 웹 양식 관리가 지운 항목의 이름·종류를 `formSchema.retiredFields`에 남긴다 → 그 이름으로 그린다.
/// - 그 전에 지운 항목은 기본 양식 사전의 이름, 빌더가 만든 id면 '이전 항목', 그 밖에는 키를 풀어 쓴다.
/// - 빈 값은 건너뛰고, 기간은 시작·끝을 한 줄로 묶는다.
library;

/// 웹 기본 양식(formTemplatePresets)의 항목 이름 — 웹 formFieldLabels와 같은 사전
const Map<String, String> _presetFieldLabels = {
  'leave-type': '휴가 유형',
  'start-date': '시작일',
  'end-date': '종료일',
  'reason': '사유',
  'medical-certificate': '진단서 첨부',
  'destination': '출장지',
  'purpose': '출장 목적',
  'trip-start': '출장 시작일',
  'trip-end': '출장 종료일',
  'transport-cost': '교통비',
  'accommodation-cost': '숙박비',
  'meal-cost': '식비',
  'other-cost': '기타 비용',
  'total': '합계',
  'receipt': '영수증 첨부',
  'note': '비고',
  'items': '구매 품목',
  'item-name': '품명',
  'item-qty': '수량',
  'item-amount': '금액',
  'total-price': '총 구매 금액',
  'usage': '용도',
  'purchase-link': '구매 링크',
  'overtime-type': '근무 유형',
  'work-date': '근무일',
  'start-time': '시작 시간',
  'end-time': '종료 시간',
  'report-type': '보고 유형',
  'report-date': '보고일',
  'content': '보고 내용',
  'issues': '특이사항',
  'attachment': '첨부파일',
};

/// 양식 빌더 genId()가 만든 항목 id(시각+난수 36진수) — 사람이 읽을 이름이 아니다
final RegExp _generatedId = RegExp(r'^[0-9a-z]{16,}$');

bool isGeneratedFieldId(String key) => _generatedId.hasMatch(key);

/// 비었는지 — 빈 글자, 빈 목록, 빈 줄만 있는 반복 항목, 값이 다 빈 객체
bool isEmptyFormValue(dynamic value) {
  if (value == null) return true;
  if (value is String) return value.trim().isEmpty;
  if (value is List) return value.every(isEmptyFormValue);
  if (value is Map) return value.values.every(isEmptyFormValue);
  return false;
}

/// 지금 양식에 없는 항목 하나
class OrphanField {
  /// formData 키(기간은 `_start`·`_end`를 뗀 항목 id)
  final String key;

  /// 지운 항목 정보(id·type·label·options) — 이름 모르는 기간이면 type만 있다
  final Map<String, dynamic>? field;

  const OrphanField(this.key, [this.field]);

  /// 그릴 이름
  String get label {
    final named = field?['label']?.toString() ?? '';
    if (named.isNotEmpty) return named;
    if (isGeneratedFieldId(key)) return '이전 항목';
    return _presetFieldLabels[key] ?? key.replaceAll(RegExp(r'[-_]'), ' ').trim();
  }

  /// 그릴 값 — 기간은 {start, end}로 묶어 준다
  dynamic valueIn(Map<String, dynamic> formData) {
    if (field?['type'] == 'dateRange' && formData[key] == null) {
      return {'start': formData['${key}_start'], 'end': formData['${key}_end']};
    }
    return formData[key];
  }

  @override
  bool operator ==(Object other) => other is OrphanField && other.key == key && other.field?['label'] == field?['label'];

  @override
  int get hashCode => Object.hash(key, field?['label']);

  @override
  String toString() => 'OrphanField($key, ${field?['label'] ?? ''})';
}

/// 항목 하나가 formData에 쓰는 키 — 기간은 `{id}_start`·`{id}_end`로 펴서 저장된다
List<String> _storageKeys(Map<String, dynamic> field) {
  final id = field['id']?.toString() ?? '';
  if (id.isEmpty) return const [];
  return field['type'] == 'dateRange' ? [id, '${id}_start', '${id}_end'] : [id];
}

/// 지운 항목 목록(`formSchema.retiredFields`) — 없으면 빈 목록
List<Map<String, dynamic>> retiredFieldsOf(Map<String, dynamic>? formSchema) {
  final raw = formSchema?['retiredFields'];
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((f) => Map<String, dynamic>.from(f)).toList();
}

/// 지금 양식([fields])에 없는 항목에 써 둔 값 — 값이 있는 것만, 지운 항목 순서 → 저장된 순서
List<OrphanField> orphanFields({
  required List<Map<String, dynamic>> fields,
  List<Map<String, dynamic>> retired = const [],
  required Map<String, dynamic> formData,
}) {
  final used = <String>{for (final f in fields) ..._storageKeys(f)};
  final result = <OrphanField>[];

  for (final field in retired) {
    final id = field['id']?.toString() ?? '';
    if (id.isEmpty || used.contains(id)) continue;
    final keys = _storageKeys(field);
    used.addAll(keys);
    if (keys.every((k) => isEmptyFormValue(formData[k]))) continue;
    result.add(OrphanField(id, field));
  }

  final range = RegExp(r'^(.+)_(start|end)$');
  for (final entry in formData.entries) {
    final key = entry.key;
    if (used.contains(key)) continue;
    // 이름 모르는 기간 — 시작·끝이 둘 다 있으면 한 줄로 묶는다
    final m = range.firstMatch(key);
    if (m != null && formData.containsKey('${m[1]}_start') && formData.containsKey('${m[1]}_end')) {
      final id = m[1]!;
      final keys = ['${id}_start', '${id}_end'];
      used.addAll(keys);
      if (keys.every((k) => isEmptyFormValue(formData[k]))) continue;
      result.add(OrphanField(id, {'id': id, 'type': 'dateRange'}));
      continue;
    }
    used.add(key);
    if (isEmptyFormValue(entry.value)) continue;
    result.add(OrphanField(key));
  }
  return result;
}

/// '이전 기안에서 불러오기'처럼 다른 문서 내용을 새 문서로 옮길 때 — 지금 양식([fields])에 있는 항목 값만.
/// 그 뒤 양식에서 지운 항목 값이 따라오면 새 기안에 보이지도 고치지도 못하는 값이 붙는다.
/// 양식에 항목이 없으면(파일 양식 등) 그대로 둔다.
Map<String, dynamic> pickLiveFormData(List<Map<String, dynamic>> fields, Map<String, dynamic> formData) {
  if (fields.isEmpty) return Map<String, dynamic>.from(formData);
  final live = <String>{for (final f in fields) ..._storageKeys(f)};
  return {
    for (final entry in formData.entries)
      if (live.contains(entry.key)) entry.key: entry.value,
  };
}
