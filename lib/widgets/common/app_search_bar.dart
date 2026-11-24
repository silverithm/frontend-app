import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../seed/seed_text_field.dart';

/// 목록 맨 위 검색 띠 — 어르신 정보 목록의 검색칸과 같은 모습(흰 면 위 회색 입력칸 + 지우기 버튼).
/// [child]를 주면 검색칸 아래에 칩 같은 필터를 이어 붙인다.
class AppSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final Widget? child;

  const AppSearchBar({
    super.key,
    required this.controller,
    required this.label,
    required this.placeholder,
    required this.onChanged,
    required this.onClear,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppSemanticColors.surfaceCard,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.space2,
        AppSpacing.screenGutter,
        AppSpacing.space2_5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final hasText = value.text.isNotEmpty;
              return SeedTextField(
                label: label,
                showLabel: false,
                controller: controller,
                onChanged: onChanged,
                placeholder: placeholder,
                prefixIcon: Icons.search,
                suffixIcon: hasText ? Icons.clear : null,
                onSuffixIconTap: hasText ? onClear : null,
              );
            },
          ),
          if (child != null) ...[
            const SizedBox(height: AppSpacing.space2),
            child!,
          ],
        ],
      ),
    );
  }
}

/// 검색어가 [fields] 중 하나라도 들어 있으면 통과(대소문자 무시). 검색어가 비면 모두 통과.
bool matchesKeyword(String keyword, Iterable<String?> fields) {
  final k = keyword.trim().toLowerCase();
  if (k.isEmpty) return true;
  return fields.any((f) => (f ?? '').toLowerCase().contains(k));
}
