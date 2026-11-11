import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import 'app_badge_pop.dart';

/// [AppSegmentedTabs]의 한 칸.
class AppSegmentedTab {
  const AppSegmentedTab(this.label, {this.badgeCount = 0});

  /// 칸에 보이는 글자.
  final String label;

  /// 0보다 크면 글자 뒤에 빨간 숫자 배지를 붙인다(99 넘으면 '99+').
  final int badgeCount;
}

/// 나눔 조절(구간 탭) — 상단 바 아래, 회색 띠 위에서 흰 칸이 미끄러진다(B안).
///
/// `TabBar` 자리에 그대로 넣는다 — 같은 [TabController]를 받으므로 `TabBarView`를
/// 옆으로 쓸면 흰 칸이 손가락을 따라간다. 상단 바의 `bottom:`이 아니라 본문 맨 위에 둔다:
///
/// ```dart
/// body: Column(
///   children: [
///     AppSegmentedTabs(
///       controller: _tabController,
///       tabs: const [AppSegmentedTab('대화'), AppSegmentedTab('직원')],
///     ),
///     Expanded(child: TabBarView(controller: _tabController, children: [...])),
///   ],
/// ),
/// ```
///
/// - 다른 칸을 누르면 selection 햅틱이 울린다(같은 칸을 다시 누르면 울리지 않는다).
/// - '동작 줄이기'면 미끄러지지 않고 바로 바뀐다.
/// - 글자를 크게 해도 잘리지 않게 칸 높이는 최소값만 둔다.
class AppSegmentedTabs extends StatefulWidget implements PreferredSizeWidget {
  const AppSegmentedTabs({
    super.key,
    required this.controller,
    required this.tabs,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.space4,
      AppSpacing.space3,
      AppSpacing.space4,
      AppSpacing.space2,
    ),
    this.backgroundColor,
    this.onTap,
  }) : assert(tabs.length >= 2, '칸은 둘 이상이어야 한다');

  final TabController controller;
  final List<AppSegmentedTab> tabs;

  /// 회색 띠 둘레 여백. 카드 안에 넣을 때는 `EdgeInsets.zero`.
  final EdgeInsetsGeometry padding;

  /// 띠 뒤 바탕. 기본은 화면 바탕(옅은 회색).
  final Color? backgroundColor;

  /// 칸을 눌렀을 때(같은 칸 포함). 화면이 따로 할 일이 있을 때만 쓴다.
  final ValueChanged<int>? onTap;

  /// 한 칸의 최소 높이.
  static const double segmentMinHeight = 42;

  /// 회색 띠 안쪽 여백.
  static const double trackPadding = AppSpacing.space1;

  /// 기본 글자 크기·기본 여백일 때의 전체 높이 — `PreferredSize`가 필요한 자리에서 쓴다.
  static const double defaultHeight = segmentMinHeight +
      trackPadding * 2 +
      AppSpacing.space3 +
      AppSpacing.space2;

  @override
  Size get preferredSize => const Size.fromHeight(defaultHeight);

  @override
  State<AppSegmentedTabs> createState() => _AppSegmentedTabsState();
}

class _AppSegmentedTabsState extends State<AppSegmentedTabs> {
  int? _pressedIndex;

  void _select(int index) {
    final controller = widget.controller;
    widget.onTap?.call(index);
    if (index == controller.index && !controller.indexIsChanging) return;
    AppHaptics.selection();
    if (AppMotion.reduceMotion(context)) {
      controller.index = index;
    } else {
      controller.animateTo(
        index,
        duration: AppMotion.tabSwitch,
        curve: AppMotion.standardCurve,
      );
    }
  }

  void _setPressed(int? index) {
    if (_pressedIndex == index) return;
    setState(() => _pressedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.tabs.length;
    final animation = widget.controller.animation ?? widget.controller;
    final allowMovement = AppMotion.allowsMovement(context);

    return ColoredBox(
      color: widget.backgroundColor ?? AppSemanticColors.backgroundCanvas,
      child: Padding(
        padding: widget.padding,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppSemanticColors.fillStrong,
            borderRadius: BorderRadius.circular(AppBorderRadius.control),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSegmentedTabs.trackPadding),
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                // 쓸어 넘기는 중에는 0~(count-1) 사이의 소수 — 흰 칸이 손가락을 따라간다.
                final position = (widget.controller.animation?.value ??
                        widget.controller.index.toDouble())
                    .clamp(0.0, (count - 1).toDouble());
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment(
                          -1 + 2 * position / (count - 1),
                          0,
                        ),
                        child: FractionallySizedBox(
                          widthFactor: 1 / count,
                          heightFactor: 1,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppSemanticColors.surfaceCard,
                              borderRadius: BorderRadius.all(
                                Radius.circular(AppBorderRadius.inner),
                              ),
                              boxShadow: AppShadows.raised,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < count; i++)
                          Expanded(
                            child: _Segment(
                              tab: widget.tabs[i],
                              // 1 = 고른 칸, 0 = 한 칸 이상 떨어짐
                              selectedness:
                                  (1 - (position - i).abs()).clamp(0.0, 1.0),
                              selected: widget.controller.index == i,
                              pressed: allowMovement && _pressedIndex == i,
                              onTap: () => _select(i),
                              onPressedChanged: (down) =>
                                  _setPressed(down ? i : null),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.tab,
    required this.selectedness,
    required this.selected,
    required this.pressed,
    required this.onTap,
    required this.onPressedChanged,
  });

  final AppSegmentedTab tab;
  final double selectedness;
  final bool selected;
  final bool pressed;
  final VoidCallback onTap;
  final ValueChanged<bool> onPressedChanged;

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(
      AppSemanticColors.textSecondary,
      AppSemanticColors.textPrimary,
      selectedness,
    );
    final badge = tab.badgeCount;

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: badge > 0 ? '${tab.label}, $badge건' : tab.label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onPressedChanged(true),
        onTapUp: (_) => onPressedChanged(false),
        onTapCancel: () => onPressedChanged(false),
        onTap: onTap,
        child: AnimatedScale(
          scale: pressed ? AppMotion.pressedScale : 1,
          duration: AppMotion.press,
          curve: AppMotion.pressCurve,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSegmentedTabs.segmentMinHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space2,
                vertical: AppSpacing.space1,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      tab.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: AppTypography.fontWeightSemibold,
                        color: color,
                      ),
                    ),
                  ),
                  if (badge > 0) ...[
                    const SizedBox(width: AppSpacing.space1 + 2),
                    AppBadgePop(value: badge, child: _CountBadge(badge)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 빨간 숫자 배지 — 하단 탭·결재 탭과 같은 뜻(내가 처리할 건수).
class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space1 + 2),
      decoration: BoxDecoration(
        color: AppSemanticColors.badgeBackground,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        maxLines: 1,
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.white,
          fontWeight: AppTypography.fontWeightBold,
          height: 1.2,
        ),
      ),
    );
  }
}
