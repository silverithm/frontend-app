import 'package:flutter/material.dart';

import '../../utils/form_field_width.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../seed/seed_chip.dart';
import '../seed/seed_text_field.dart';

/// 결재 양식(formSchema)의 필드를 "공문 표" 레이아웃(라벨 셀 + 입력 셀, 섹션 구획)으로
/// 렌더링한다.
///
/// 웹 FormRenderer의 documentFrame 규칙(행 분할·라벨/입력 셀·섹션)을 모바일 화면폭에
/// 맞게 옮긴 것 — 좁은 화면에서 표가 깨지지 않도록 한 행에 최대 1~2필드만 배치하고,
/// 나머지는 세로로 접는다.
///
/// [readOnly]가 true면 입력을 받지 않고 항목 구성만 보여주는 미리보기 모드로 동작한다
/// (양식 미리보기 화면에서 재사용).
class DocumentFormFields extends StatefulWidget {
  final List<Map<String, dynamic>> fields;
  final Map<String, dynamic> values;
  final bool readOnly;
  final VoidCallback? onChanged;

  const DocumentFormFields({
    super.key,
    required this.fields,
    required this.values,
    this.readOnly = false,
    this.onChanged,
  });

  /// 필수 필드 검증 — 누락된 첫 필드 라벨 반환 (모두 채워지면 null)
  static String? validateRequired(
      List<Map<String, dynamic>> fields, Map<String, dynamic> values) {
    for (final field in fields) {
      final type = field['type']?.toString();
      if (type == 'section' || type == 'file') continue;
      if (field['required'] != true) continue;
      final id = field['id']?.toString() ?? '';
      final value = type == 'dateRange'
          ? (values['${id}_start'] ?? values['${id}_end'])
          : values[id];
      final isEmpty = value == null ||
          (value is String && value.trim().isEmpty) ||
          (value is List && value.isEmpty);
      if (isEmpty) {
        return field['label']?.toString() ?? id;
      }
    }
    return null;
  }

  /// width 메타데이터를 기준으로 필드를 행 단위로 묶는다.
  /// - section은 항상 단독 행.
  /// - half/third/quarter처럼 폭이 좁은 필드는 연속 2개까지 한 행에 묶는다.
  /// - full/twoThirds 등 넓은 필드(또는 width 정보가 없는 구형 필드)는 모바일 화면폭 상
  ///   단독 행으로 접는다.
  /// width 메타데이터를 기준으로 필드를 행 단위로 묶는다.
  ///
  /// 웹(formValueFormat.ts의 groupFieldsIntoRows)과 같은 규칙 — 12칼럼이 찰 때까지 묶는다.
  /// 그래서 1/3 + 2/3처럼 서로 다른 폭도 한 줄에 선다.
  /// 다만 작성 화면은 손가락으로 입력하는 곳이라 한 줄에 둘까지만 둔다
  /// (공문 보기는 넷까지 — official_document_view 참고).
  static List<List<Map<String, dynamic>>> groupRows(
      List<Map<String, dynamic>> fields) {
    return groupIntoRowsBySpan<Map<String, dynamic>>(
      fields,
      spanOf: (field) => fieldWidthSpan(field['width']),
      isBlock: (field) => field['type']?.toString() == 'section',
      maxPerRow: 2,
    );
  }

  @override
  State<DocumentFormFields> createState() => _DocumentFormFieldsState();
}

class _DocumentFormFieldsState extends State<DocumentFormFields> {
  final Map<String, TextEditingController> _controllers = {};

  TextEditingController _controllerFor(String id) {
    return _controllers.putIfAbsent(id, () {
      final controller =
          TextEditingController(text: widget.values[id]?.toString() ?? '');
      controller.addListener(() {
        widget.values[id] = controller.text;
        widget.onChanged?.call();
      });
      return controller;
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> _options(Map<String, dynamic> field) {
    final options = field['options'];
    if (options is List) {
      return options
          .whereType<Map>()
          .map((o) => Map<String, dynamic>.from(o))
          .toList();
    }
    return const [];
  }

  Future<void> _pickDate(String key) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(widget.values[key]?.toString() ?? '') ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) {
      setState(() {
        widget.values[key] = DateFormat('yyyy-MM-dd').format(picked);
      });
      widget.onChanged?.call();
    }
  }

  Widget _dateButton(String key, {String placeholder = '날짜 선택'}) {
    final value = widget.values[key]?.toString();
    final hasValue = value != null && value.isNotEmpty;
    return InkWell(
      onTap: widget.readOnly ? null : () => _pickDate(key),
      borderRadius: BorderRadius.circular(AppBorderRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space2_5,
          vertical: AppSpacing.space2,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppSemanticColors.borderDefault),
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today,
                size: 13, color: AppSemanticColors.textTertiary),
            const SizedBox(width: AppSpacing.space1_5),
            Text(
              hasValue ? value : placeholder,
              style: AppTypography.bodySmall.copyWith(
                color: hasValue
                    ? AppSemanticColors.textPrimary
                    : AppSemanticColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String? hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space2_5,
          vertical: AppSpacing.space2,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: BorderSide(color: AppSemanticColors.borderDefault),
        ),
      );

  /// 미리보기(readOnly) 모드 — 실제 입력 위젯 대신 항목 구성만 보여준다.
  Widget _placeholderCell(Map<String, dynamic> field) {
    final type = field['type']?.toString();
    if (type == 'select' || type == 'radio' || type == 'checkbox') {
      final labels = _options(field)
          .map((o) => o['label']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .join(' / ');
      return Text(
        labels.isEmpty ? '선택 항목' : labels,
        style: AppTypography.bodySmall
            .copyWith(color: AppSemanticColors.textTertiary),
      );
    }
    if (type == 'date') {
      return Text('날짜 선택',
          style: AppTypography.bodySmall
              .copyWith(color: AppSemanticColors.textTertiary));
    }
    if (type == 'dateRange') {
      return Text('시작일 ~ 종료일',
          style: AppTypography.bodySmall
              .copyWith(color: AppSemanticColors.textTertiary));
    }
    return Container(
      height: 1,
      color: AppSemanticColors.borderDefault,
      margin: const EdgeInsets.only(top: AppSpacing.space3),
    );
  }

  Widget _control(Map<String, dynamic> field) {
    if (widget.readOnly) return _placeholderCell(field);

    final type = field['type']?.toString() ?? 'text';
    final id = field['id']?.toString() ?? '';

    switch (type) {
      case 'textarea':
        return SeedTextField(
          label: field['label']?.toString() ?? '',
          showLabel: false,
          controller: _controllerFor(id),
          maxLines: 3,
          placeholder: field['placeholder']?.toString(),
        );

      case 'number':
        return SeedTextField(
          label: field['label']?.toString() ?? '',
          showLabel: false,
          controller: _controllerFor(id),
          keyboardType: TextInputType.number,
          placeholder: field['placeholder']?.toString(),
        );

      case 'date':
        return _dateButton(id);

      case 'dateRange':
        return Wrap(
          spacing: AppSpacing.space2,
          runSpacing: AppSpacing.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _dateButton('${id}_start', placeholder: '시작일'),
            Text('~', style: AppTypography.bodySmall),
            _dateButton('${id}_end', placeholder: '종료일'),
          ],
        );

      case 'select':
        final options = _options(field);
        return DropdownButtonFormField<String>(
          initialValue: widget.values[id]?.toString(),
          isExpanded: true,
          isDense: true,
          decoration: _decoration('선택하세요'),
          style: AppTypography.bodySmall
              .copyWith(color: AppSemanticColors.textPrimary),
          items: options
              .map((o) => DropdownMenuItem<String>(
                    value: o['value']?.toString(),
                    child: Text(o['label']?.toString() ?? '',
                        style: AppTypography.bodySmall),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() => widget.values[id] = value);
            widget.onChanged?.call();
          },
        );

      case 'radio':
        // 단일 선택 — 탭하면 해당 옵션 값으로 교체
        final options = _options(field);
        return Wrap(
          spacing: AppSpacing.space1_5,
          runSpacing: AppSpacing.space1_5,
          children: options.map((option) {
            final value = option['value']?.toString();
            final selected = widget.values[id]?.toString() == value;
            return SeedChip(
              label: option['label']?.toString() ?? '',
              selected: selected,
              size: SeedChipSize.small,
              onTap: () {
                setState(() => widget.values[id] = value);
                widget.onChanged?.call();
              },
            );
          }).toList(),
        );

      case 'checkbox':
        // 다중 선택 — 탭할 때마다 선택 목록에 추가/제거 토글
        final options = _options(field);
        final selectedValues = (widget.values[id] is List)
            ? List<String>.from(
                (widget.values[id] as List).map((v) => v.toString()))
            : <String>[];
        return Wrap(
          spacing: AppSpacing.space1_5,
          runSpacing: AppSpacing.space1_5,
          children: options.map((option) {
            final value = option['value']?.toString() ?? '';
            final selected = selectedValues.contains(value);
            return SeedChip(
              label: option['label']?.toString() ?? '',
              selected: selected,
              size: SeedChipSize.small,
              onTap: () {
                setState(() {
                  final next = List<String>.from(selectedValues);
                  if (selected) {
                    next.remove(value);
                  } else {
                    next.add(value);
                  }
                  widget.values[id] = next;
                });
                widget.onChanged?.call();
              },
            );
          }).toList(),
        );

      case 'file':
        return Text(
          '아래 첨부파일 영역에서 올려주세요',
          style: AppTypography.caption
              .copyWith(color: AppSemanticColors.textTertiary),
        );

      default: // text
        return SeedTextField(
          label: field['label']?.toString() ?? '',
          showLabel: false,
          controller: _controllerFor(id),
          placeholder: field['placeholder']?.toString(),
        );
    }
  }

  Widget _labelCell(Map<String, dynamic> field) {
    final label = field['label']?.toString() ?? '';
    final required = field['required'] == true;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: label,
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: AppSemanticColors.textPrimary,
            ),
          ),
          if (required)
            TextSpan(
              text: ' *',
              style: AppTypography.bodySmall
                  .copyWith(color: AppSemanticColors.statusErrorIcon),
            ),
        ],
      ),
    );
  }

  Widget _sectionRow(Map<String, dynamic> field) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space2,
      ),
      color: AppSemanticColors.backgroundTertiary,
      child: Text(
        field['label']?.toString() ?? '',
        style: AppTypography.bodySmall.copyWith(
          fontWeight: FontWeight.w700,
          color: AppSemanticColors.textSecondary,
        ),
      ),
    );
  }

  Widget _fieldCell(Map<String, dynamic> field, {bool bordered = false}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space3),
      decoration: bordered
          ? BoxDecoration(
              border: Border(
                left: BorderSide(color: AppSemanticColors.borderSubtle),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _labelCell(field),
          const SizedBox(height: AppSpacing.space1_5),
          _control(field),
          if (!widget.readOnly &&
              field['description'] != null &&
              field['description'].toString().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.space1),
            Text(
              field['description'].toString(),
              style: AppTypography.caption
                  .copyWith(color: AppSemanticColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fields.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.space6),
        decoration: BoxDecoration(
          border: Border.all(color: AppSemanticColors.borderDefault),
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        ),
        child: Center(
          child: Text(
            '입력할 항목이 없습니다',
            style: AppTypography.bodySmall
                .copyWith(color: AppSemanticColors.textTertiary),
          ),
        ),
      );
    }

    final rows = DocumentFormFields.groupRows(widget.fields);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: AppSemanticColors.borderDefault),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1, thickness: 1, color: AppSemanticColors.borderSubtle),
            if (rows[i].length == 1 &&
                rows[i][0]['type']?.toString() == 'section')
              _sectionRow(rows[i][0])
            else if (rows[i].length == 2)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 양식에 정해둔 비율대로 나눈다 — 예전엔 무조건 반씩 나눠서
                    // 1/3+2/3으로 만든 양식이 앱에서는 반반으로 보였다
                    Expanded(
                      flex: fieldWidthSpan(rows[i][0]['width']),
                      child: _fieldCell(rows[i][0]),
                    ),
                    Expanded(
                      flex: fieldWidthSpan(rows[i][1]['width']),
                      child: _fieldCell(rows[i][1], bordered: true),
                    ),
                  ],
                ),
              )
            else
              _fieldCell(rows[i][0]),
          ],
        ],
      ),
    );
  }
}
