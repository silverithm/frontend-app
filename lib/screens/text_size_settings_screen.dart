import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/text_scale.dart';

/// 글자 크기 설정.
///
/// 기기 설정으로만 조절하면 두 가지가 곤란하다 — 크게 키운 분은 앱 화면이 깨지고,
/// 앱만 크게 보고 싶은 분은 기기 전체를 키워야 한다. 그래서 앱에서 직접 고르게 한다
/// ("앱 내에서 폰트 크기 조절 기능 요청합니다", 2026-09-08).
///
/// 고른 즉시 이 화면의 글자부터 바뀌므로 결과를 보고 정할 수 있다.
class TextSizeSettingsScreen extends StatelessWidget {
  const TextSizeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final current = appProvider.textSize;

    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundSecondary,
      appBar: AppBar(
        title: const Text('글자 크기'),
        backgroundColor: AppSemanticColors.surfaceDefault,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.space4),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.space4),
            decoration: BoxDecoration(
              color: AppSemanticColors.surfaceDefault,
              borderRadius: BorderRadius.circular(AppBorderRadius.xl),
              border: Border.all(color: AppSemanticColors.borderDefault),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '미리보기',
                  style: AppTypography.caption.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space2),
                Text(
                  '어르신 오후 재활운동 마쳤습니다',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  '오후 4:14',
                  style: AppTypography.caption.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          for (final size in AppTextSize.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space2),
              child: _SizeOption(
                size: size,
                selected: size == current,
                onTap: () => context.read<AppProvider>().setTextSize(size),
              ),
            ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            '기기 설정의 글자 크기도 함께 반영됩니다. '
            '화면이 깨지지 않는 범위까지만 커집니다.',
            style: AppTypography.caption.copyWith(
              color: AppSemanticColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SizeOption extends StatelessWidget {
  final AppTextSize size;
  final bool selected;
  final VoidCallback onTap;

  const _SizeOption({
    required this.size,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppSemanticColors.surfaceDefault,
      borderRadius: BorderRadius.circular(AppBorderRadius.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.space4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            border: Border.all(
              color: selected
                  ? AppSemanticColors.brandDefault
                  : AppSemanticColors.borderDefault,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  size.label,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: AppSemanticColors.brandDefault, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
