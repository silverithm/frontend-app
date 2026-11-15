import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../common/app_pressable.dart';
import '../common/app_segmented_tabs.dart';

/// 일정 탭 초록 띠 안의 근무|일정 나눔 조절(2026-11-15).
///
/// 띠는 반투명 흰색, 고른 칸은 흰 바탕에 틸 글자, 안 고른 칸은 흰 글자([AppSegmentedTabs.onBrand]).
/// 칸 폭은 글자에 맞춘다(글자 배율이 커지면 같이 넓어진다).
class CalendarTabToggle extends StatelessWidget {
  const CalendarTabToggle({
    super.key,
    required this.controller,
    this.labels = const ['근무', '일정'],
    this.semanticLabels = const ['근무조정', '월간일정'],
    this.segmentPadding = AppSpacing.space3,
  });

  /// 화면 읽기에 읽힐 이름 — 보이는 글자를 줄여도 원래 이름(근무조정·월간일정)으로 읽힌다.
  final List<String>? semanticLabels;

  /// 칸 글자 양옆 여백 — 한 줄 머리에 넣을 때는 줄인다.
  final double segmentPadding;

  final TabController controller;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final style = AppTypography.bodyMedium.copyWith(
      fontWeight: AppTypography.fontWeightSemibold,
    );
    var widest = 0.0;
    for (final label in labels) {
      final w = (TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout()).width;
      if (w > widest) widest = w;
    }
    // 칸 = 글자 + 양옆 16씩, 띠 안쪽 여백 4씩
    final width =
        labels.length * (widest + segmentPadding * 2) +
        AppSegmentedTabs.trackPadding * 2;
    return SizedBox(
      width: width,
      child: AppSegmentedTabs(
        controller: controller,
        onBrand: true,
        padding: EdgeInsets.zero,
        tabs: [
          for (var i = 0; i < labels.length; i++)
            AppSegmentedTab(labels[i], semanticLabel: semanticLabels?[i]),
        ],
      ),
    );
  }
}

/// 일정 탭 한 줄 머리(2026-11-15) — 초록 띠 한 줄에 다 넣는다.
///
/// `11월 / 2026년 · [근무|일정] ······ 필터 · 펼치기 · 오늘`
///
/// - 달 넘기기는 달력을 좌우로 쓸어서(‹ › 없음). 화면 읽기는 달 이름에서 위아래로 쓸어 넘긴다.
/// - 필터·펼치기는 아이콘만, 켜져 있으면 흰 원으로 채운다. 무엇이 걸렸는지는 달 이름 아래 작은 줄에.
/// - 나눔 단추는 짧게 '근무'·'일정'(화면 읽기에는 근무조정·월간일정으로 읽힌다) — 그 덕에 글자 그대로의
///   '오늘' 단추가 들어간다(날짜 숫자 아이콘은 뭔지 모르겠다는 말이 있었다).
/// - 폰 글자 1.3배에서도 한 줄. 아주 좁으면 나눔 단추만 살짝 줄어든다.
class CalendarOneLineHeader extends StatelessWidget {
  const CalendarOneLineHeader({
    super.key,
    required this.month,
    required this.subtitle,
    required this.controller,
    required this.filterActive,
    required this.filterTooltip,
    required this.onFilter,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onToday,
    required this.onPrevious,
    required this.onNext,
    this.subtitleDone = false,
    this.leading,
  });

  final DateTime month;

  /// 달 이름 아래 작은 줄 — '2026년', '2026년 · 요양보호사', '완료 5/17', '김민지 · 완료 2/5'
  final String subtitle;

  /// true면 작은 줄 앞에 완료 체크
  final bool subtitleDone;
  final TabController controller;
  final bool filterActive;
  final String filterTooltip;
  final VoidCallback onFilter;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onToday;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        leading != null ? 0 : AppSpacing.space4,
        AppSpacing.space1,
        AppSpacing.space1,
        AppSpacing.space2,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            if (leading != null) leading!,
            _title(),
            const SizedBox(width: AppSpacing.space2_5),
            // 좁으면 나눔 단추만 살짝 줄인다(한 줄을 지킨다)
            Flexible(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: CalendarTabToggle(
                    controller: controller,
                    labels: const ['근무', '일정'],
                    semanticLabels: const ['근무조정', '월간일정'],
                    segmentPadding: AppSpacing.space3,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.space1),
            _BarIcon(
              icon: Icons.filter_list_rounded,
              tooltip: filterTooltip,
              active: filterActive,
              onTap: onFilter,
            ),
            _BarIcon(
              icon: expanded
                  ? Icons.unfold_less_rounded
                  : Icons.unfold_more_rounded,
              tooltip: expanded ? '접기' : '펼치기',
              active: expanded,
              onTap: onToggleExpanded,
            ),
            const SizedBox(width: AppSpacing.space1),
            _TodayPill(onTap: onToday),
          ],
        ),
      ),
    );
  }

  Widget _title() {
    final white = AppColors.white;
    return Semantics(
      header: true,
      label: '${month.year}년 ${month.month}월, $subtitle',
      hint: '좌우로 쓸어 달을 넘깁니다',
      onIncrease: onNext,
      onDecrease: onPrevious,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${month.month}월',
            maxLines: 1,
            style: AppTypography.appBarTitleLarge.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.1,
              color: white,
            ),
          ),
          ConstrainedBox(
            // 작은 줄이 길면(필터 이름) 달 이름 폭을 크게 넘지 않게 줄인다
            constraints: const BoxConstraints(maxWidth: 108),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (subtitleDone) ...[
                  Icon(Icons.check_circle_rounded, size: 11, color: white),
                  const SizedBox(width: 2),
                ],
                Flexible(
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      height: 1.2,
                      fontWeight: AppTypography.fontWeightMedium,
                      color: white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 초록 띠 위 아이콘 단추 — 40×44, 켜져 있으면 흰 원(34)에 틸 아이콘.
class _BarIcon extends StatelessWidget {
  const _BarIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppSemanticColors.brandDefault : AppColors.white;
    return Tooltip(
      message: tooltip,
      child: AppPressable(
        onTap: onTap,
        haptic: AppHapticKind.selection,
        semanticLabel: active ? '$tooltip, 켜짐' : tooltip,
        minTouchSize: const Size(40, 44),
        child: SizedBox(
          width: 40,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: active ? AppColors.white : Colors.transparent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 22, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

/// '오늘' 단추 — 초록 띠 위 흰 테두리 알약(이번 달로 돌아와 오늘을 고른다).
class _TodayPill extends StatelessWidget {
  const _TodayPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      haptic: AppHapticKind.selection,
      semanticLabel: '오늘로 가기',
      minTouchSize: const Size(44, 44),
      child: Container(
        constraints: const BoxConstraints(minHeight: 34, minWidth: 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppBorderRadius.full),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.7)),
        ),
        child: Text(
          '오늘',
          maxLines: 1,
          style: AppTypography.titleSmall.copyWith(color: AppColors.white),
        ),
      ),
    );
  }
}
