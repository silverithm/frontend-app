import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 결재 양식(formSchema)의 필드를 렌더링하고 값을 수집한다.
/// 웹 FormRenderer와 동일한 필드 타입 지원: text/textarea/number/date/dateRange/select/radio/checkbox/section
/// (file 타입은 앱에서는 별도 첨부 흐름을 쓰므로 안내만 표시)
class DynamicFormFields extends StatefulWidget {
  final List<Map<String, dynamic>> fields;
  final Map<String, dynamic> values;
  final VoidCallback? onChanged;

  const DynamicFormFields({
    super.key,
    required this.fields,
    required this.values,
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

  @override
  State<DynamicFormFields> createState() => _DynamicFormFieldsState();
}

class _DynamicFormFieldsState extends State<DynamicFormFields> {
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

  InputDecoration _decoration(String? hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.space3),
        ),
      );

  Widget _label(Map<String, dynamic> field) {
    final label = field['label']?.toString() ?? '';
    final required = field['required'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space1),
      child: Row(
        children: [
          Text(label,
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textPrimary,
                fontWeight: FontWeight.w600,
              )),
          if (required)
            Text(' *',
                style: AppTypography.bodySmall
                    .copyWith(color: AppSemanticColors.statusErrorIcon)),
        ],
      ),
    );
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
    return OutlinedButton.icon(
      onPressed: () => _pickDate(key),
      icon: const Icon(Icons.calendar_today, size: 14),
      label: Text(value == null || value.isEmpty ? placeholder : value,
          style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppSemanticColors.textPrimary,
        side: BorderSide(color: AppSemanticColors.borderDefault),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.space3),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _options(Map<String, dynamic> field) {
    final options = field['options'];
    if (options is List) {
      return options.whereType<Map>().map((o) => Map<String, dynamic>.from(o)).toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.fields.map((field) {
        final type = field['type']?.toString() ?? 'text';
        final id = field['id']?.toString() ?? '';

        Widget body;
        switch (type) {
          case 'section':
            return Padding(
              padding: const EdgeInsets.only(
                  top: AppSpacing.space4, bottom: AppSpacing.space2),
              child: Row(
                children: [
                  Text(field['label']?.toString() ?? '',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppSemanticColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                      child: Divider(color: AppSemanticColors.borderDefault)),
                ],
              ),
            );

          case 'textarea':
            body = TextField(
              controller: _controllerFor(id),
              maxLines: 4,
              decoration: _decoration(field['placeholder']?.toString()),
            );
            break;

          case 'number':
            body = TextField(
              controller: _controllerFor(id),
              keyboardType: TextInputType.number,
              decoration: _decoration(field['placeholder']?.toString()),
            );
            break;

          case 'date':
            body = _dateButton(id);
            break;

          case 'dateRange':
            body = Row(
              children: [
                Expanded(child: _dateButton('${id}_start', placeholder: '시작일')),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('~'),
                ),
                Expanded(child: _dateButton('${id}_end', placeholder: '종료일')),
              ],
            );
            break;

          case 'select':
            final options = _options(field);
            body = DropdownButtonFormField<String>(
              initialValue: widget.values[id]?.toString(),
              decoration: _decoration('선택하세요'),
              items: options
                  .map((o) => DropdownMenuItem<String>(
                        value: o['value']?.toString(),
                        child: Text(o['label']?.toString() ?? '',
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => widget.values[id] = value);
                widget.onChanged?.call();
              },
            );
            break;

          case 'radio':
            final options = _options(field);
            body = Wrap(
              spacing: AppSpacing.space2,
              runSpacing: AppSpacing.space1,
              children: options.map((option) {
                final value = option['value']?.toString();
                final selected = widget.values[id]?.toString() == value;
                return ChoiceChip(
                  label: Text(option['label']?.toString() ?? '',
                      style: const TextStyle(fontSize: 12)),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => widget.values[id] = value);
                    widget.onChanged?.call();
                  },
                );
              }).toList(),
            );
            break;

          case 'checkbox':
            final options = _options(field);
            final selectedValues = (widget.values[id] is List)
                ? List<String>.from(
                    (widget.values[id] as List).map((v) => v.toString()))
                : <String>[];
            body = Wrap(
              spacing: AppSpacing.space2,
              runSpacing: AppSpacing.space1,
              children: options.map((option) {
                final value = option['value']?.toString() ?? '';
                final selected = selectedValues.contains(value);
                return FilterChip(
                  label: Text(option['label']?.toString() ?? '',
                      style: const TextStyle(fontSize: 12)),
                  selected: selected,
                  onSelected: (checked) {
                    setState(() {
                      final next = List<String>.from(selectedValues);
                      if (checked) {
                        next.add(value);
                      } else {
                        next.remove(value);
                      }
                      widget.values[id] = next;
                    });
                    widget.onChanged?.call();
                  },
                );
              }).toList(),
            );
            break;

          case 'file':
            body = Text(
              '파일은 아래 첨부파일 영역에서 올려주세요.',
              style: AppTypography.caption
                  .copyWith(color: AppSemanticColors.textTertiary),
            );
            break;

          default: // text
            body = TextField(
              controller: _controllerFor(id),
              decoration: _decoration(field['placeholder']?.toString()),
            );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(field),
              body,
              if (field['description'] != null &&
                  field['description'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(field['description'].toString(),
                      style: AppTypography.caption
                          .copyWith(color: AppSemanticColors.textTertiary)),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
