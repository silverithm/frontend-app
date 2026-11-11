import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/text_scale.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/carev_app_bar.dart';
import '../widgets/seed/seed_list_cell.dart';

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
      // B안: 옅은 회색 바탕 위 테두리 없는 흰 카드
      backgroundColor: AppSemanticColors.backgroundCanvas,
      appBar: const CareVAppBar(title: '글자 크기'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.space4),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '미리보기',
                  style: AppTypography.bodySmall.copyWith(
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
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.cardGap),
          // B안: 칸마다 테두리 상자 대신 흰 카드 하나에 네 줄, 고른 줄은 옅은 틸 바탕 + 틸 체크
          SeedListSection(
            children: [
              for (final size in AppTextSize.values)
                _SizeOption(
                  size: size,
                  selected: size == current,
                  onTap: () => context.read<AppProvider>().setTextSize(size),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space1),
            child: Text(
              '기기 설정의 글자 크기도 함께 반영됩니다. '
              '화면이 깨지지 않는 범위까지만 커집니다.',
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
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
    final radius = BorderRadius.circular(AppBorderRadius.control);
    // 목록 줄(SeedListCell)과 같은 치수 — 줄 높이 60 이상, 좌우 12, 누름 모서리 14.
    // 고른 줄은 테두리 대신 옅은 틸 바탕 + 틸 글자·체크로 드러낸다.
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? AppSemanticColors.brandWeak : AppColors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.listRowMinHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space3,
                vertical: AppSpacing.space2_5,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      size.label,
                      style: selected
                          ? AppTypography.titleMedium.copyWith(
                              color: AppSemanticColors.brandWeakForeground,
                            )
                          : AppTypography.bodyMedium.copyWith(
                              color: AppSemanticColors.textPrimary,
                            ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_circle,
                      color: AppSemanticColors.brandDefault,
                      size: 24,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
