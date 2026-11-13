import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'app_badge_pop.dart';

/// 하단 탭 한 칸.
class AppBottomTabItem {
  const AppBottomTabItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
  });

  /// 고르지 않았을 때(선 아이콘)
  final IconData icon;

  /// 골랐을 때(채운 아이콘)
  final IconData selectedIcon;
  final String label;

  /// 0이면 배지를 그리지 않는다. 99를 넘으면 99+.
  final int badgeCount;
}

/// 하단 탭 — B안(2026-11-12, 시안 .tabbar).
///
/// 흰 바탕 + 위 옅은 선 한 줄, 높이 64(+ 안전 영역). 고르면 채운 아이콘 + 틸 글자 12/w700,
/// 아니면 선 아이콘 + 회색(ink4) 12/w500. 선택 알약 바탕은 없다. 고르는 순간 아이콘이 살짝 튀고,
/// 배지 숫자가 바뀌면 배지가 톡 튄다('동작 줄이기'면 튀지 않음).
/// 진동은 부르는 쪽(MainScreen._onNavBarTapped)이 selection으로 울린다.
class AppBottomTabBar extends StatelessWidget {
  const AppBottomTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<AppBottomTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppSemanticColors.surfaceCard,
        border: Border(
          top: BorderSide(color: AppSemanticColors.borderHairline),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSpacing.bottomTabHeight,
          // 글자 배율은 앱 전체에서 1.3배로 잘린다(theme/text_scale.dart) — 탭 바만 따로 다루지 않는다
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _AppBottomTab(
                    item: items[i],
                    selected: i == currentIndex,
                    index: i,
                    count: items.length,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBottomTab extends StatelessWidget {
  const _AppBottomTab({
    required this.item,
    required this.selected,
    required this.index,
    required this.count,
    required this.onTap,
  });

  final AppBottomTabItem item;
  final bool selected;
  final int index;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppSemanticColors.brandDefault
        : AppSemanticColors.iconSubtle;
    final badge = item.badgeCount;
    final badgeText = badge > 99 ? '99+' : '$badge';

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: badge > 0 ? '${item.label}, 새 소식 $badgeText건' : item.label,
      // 탭 순서 안내(1/5 등)는 화면 낭독기가 스스로 붙이지 않아 넣어 준다
      hint: '탭 ${index + 1}/$count',
      // 아이콘·글자·배지를 한 덩어리로 읽히게 묶고, 누르기 동작은 여기서 직접 준다
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        highlightColor: AppColors.transparent,
        splashFactory: NoSplash.splashFactory,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  AppBadgePop(
                    value: selected,
                    scale: 1.12,
                    popWhen: (prev, next) => next == true,
                    child: Icon(
                      selected ? item.selectedIcon : item.icon,
                      size: 26,
                      color: color,
                    ),
                  ),
                  if (badge > 0)
                    Positioned(
                      top: -5,
                      left: 17,
                      child: AppBadgePop(
                        value: badge,
                        child: _TabBadge(text: badgeText),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall.copyWith(
                color: color,
                fontWeight: selected
                    ? AppTypography.fontWeightBold
                    : AppTypography.fontWeightMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 숫자 배지 — 빨강(#D92D20) 알약 20, 흰 글자 12/w700, 둘레 흰 2px.
class _TabBadge extends StatelessWidget {
  const _TabBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppSemanticColors.badgeBackground,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
        border: Border.all(color: AppSemanticColors.surfaceCard, width: 2),
      ),
      child: Text(
        text,
        style: AppTypography.labelSmall.copyWith(
          color: AppSemanticColors.textInverse,
          fontWeight: AppTypography.fontWeightBold,
          height: 1.0,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
