import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_lines.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../common/app_pressable.dart';

/// 꽉 찬 달력 — 크로박스 홈 달력(2026-11 현재 코드)을 옮긴 것.
///
///  - 카드 없이 화면 폭을 다 쓰고, 남은 높이를 주 수로 나눠 칸이 화면 아래까지 찬다.
///  - 칸마다 날짜 아래에 그날 것(휴무자 이름·일정 제목)을 색 칩으로, 칸 높이에 들어가는 만큼.
///    넘치면 '+n'. 펼치면 주마다 그 주에서 가장 많은 날에 맞춰 칸이 길어지고 위아래로 넘긴다.
///  - 날짜를 누르면 아래에서 그날 시트가 반쯤 올라오고, 고른 줄이 시트에 가리면 달력을
///    줄 단위로 밀어 올려 고른 칸이 늘 시트 바로 위에 보이게 한다.
///  - 좌우로 쓸면 달이 바뀐다. 앞뒤 달 날짜는 흐리게, 누르면 그 달로 간다.

/// 칸 하나에 그리는 칩(이름·제목 한 줄).
class CalendarChipData {
  final String label;
  final Color color;
  final bool faded;
  final Widget? trailing;

  const CalendarChipData({
    required this.label,
    required this.color,
    this.faded = false,
    this.trailing,
  });
}

/// 칸 치수. 칸 안 글자(날짜·칩·+n)는 폰 글자 배율을 따르지 않는다 — 크로박스와 같다.
/// 칸 폭이 정해져 있어 1.3배로 키우면 이름이 '이...'로 잘리고 세 명인 날은 '+3'만 남았다
/// (글자 단계의 '달력 칸만 10' 예외와 같은 자리). 머리줄·시트·목록은 앱 전체처럼 커진다.
class _CellMetrics {
  final double scale;
  _CellMetrics(this.scale);

  double get number => (22 * scale).roundToDouble();
  double get chip =>
      (AppTypography.fontSizeCalendar * scale * 1.2 + 3).roundToDouble();
  static const double gap = 2;

  /// 날짜(위 4 + 동그라미 + 3) 아래로 칩이 들어갈 높이를 뺀 머리 높이.
  double get head => 4 + number + 3;

  double heightFor(int count) => head + 4 + count * (chip + gap) + 6;
}

class MonthChipGrid extends StatelessWidget {
  /// 보여 줄 달(그 달의 아무 날)
  final DateTime month;
  final DateTime? selected;

  /// 고른 칸에 테두리를 그릴지 — 시트가 닫혀 있고 오늘을 골라 둔 상태면 오늘 동그라미만.
  final bool showSelection;
  final bool expanded;
  final List<CalendarChipData> Function(DateTime date) chipsFor;

  /// 칸 바탕(직종 하나를 고르면 여유·초과 색)
  final Color? Function(DateTime date)? tintFor;

  /// 칸 오른쪽 위 작은 표시(마감일 별·행사 핀)
  final Widget? Function(DateTime date)? badgeFor;

  /// 칸 맨 아래 한 줄(직종 하나를 고르면 '인원/한도') — 칩이 이 자리를 비워 둔다
  final Widget? Function(DateTime date)? footerFor;
  static const double _footerHeight = 13;

  /// 신청할 수 없는 날 등 흐리게 그릴 날
  final bool Function(DateTime date)? dimFor;

  /// 공휴일 — 날짜를 일요일처럼 빨갛게
  final bool Function(DateTime date)? holidayFor;
  final ValueChanged<DateTime> onTapDay;
  final ValueChanged<int> onSwipeMonth;

  /// 탭 본문 전체 높이(시트 위치 계산)
  final double bodyHeight;
  final DraggableScrollableController sheet;
  final double sheetSplit;
  final bool sheetOpen;

  /// 떠 있는 추가 단추 자리
  static const double bottomReserve = 76;

  const MonthChipGrid({
    super.key,
    required this.month,
    required this.selected,
    required this.showSelection,
    required this.expanded,
    required this.chipsFor,
    required this.onTapDay,
    required this.onSwipeMonth,
    required this.bodyHeight,
    required this.sheet,
    required this.sheetSplit,
    required this.sheetOpen,
    this.tintFor,
    this.badgeFor,
    this.dimFor,
    this.holidayFor,
    this.footerFor,
  });

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday % 7; // 일요일 시작
    final rows = ((lead + daysInMonth) / 7).ceil();
    final m = _CellMetrics(1);
    final now = DateTime.now();

    DateTime dateAt(int r, int c) =>
        DateTime(month.year, month.month, r * 7 + c - lead + 1);

    var selectedRow = -1;
    if (selected != null) {
      final idx = DateTime.utc(
        selected!.year,
        selected!.month,
        selected!.day,
      ).difference(DateTime.utc(month.year, month.month, 1 - lead)).inDays;
      if (idx >= 0 && idx < rows * 7) selectedRow = idx ~/ 7;
    }

    Widget week(int r, double height, int maxLines) => SizedBox(
      height: height,
      child: Row(
        children: [
          for (var c = 0; c < 7; c++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: _cell(context, dateAt(r, c), height, maxLines, now, m),
              ),
            ),
        ],
      ),
    );

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -250) {
          onSwipeMonth(1);
        } else if (v > 250) {
          onSwipeMonth(-1);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            const _WeekdayRow(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final footer = footerFor == null ? 0.0 : _footerHeight;
                  final minRow = m.heightFor(1) + footer;
                  final fitRow = (constraints.maxHeight - bottomReserve) / rows;
                  final rowH = math.max(minRow, fitRow);
                  // 작은 폰(360x640 등)에서 칸 최소 높이로도 다 안 들어가면 위아래로 넘긴다 —
                  // 못 넘기면 마지막 주가 추가 단추 아래로 숨었다
                  final tooSmall = fitRow < minRow;

                  if ((expanded || tooSmall) && !sheetOpen) {
                    final heights = <double>[];
                    for (var r = 0; r < rows; r++) {
                      var most = 0;
                      for (var c = 0; c < 7; c++) {
                        final d = dateAt(r, c);
                        if (d.month != month.month) continue;
                        most = math.max(most, chipsFor(d).length);
                      }
                      heights.add(
                        expanded
                            ? math.max(rowH, m.heightFor(most) + footer)
                            : rowH,
                      );
                    }
                    return SingleChildScrollView(
                      // 두 탭(근무조정·월간일정)이 바뀌는 동안 같은 PrimaryScrollController에 함께 붙지 않게
                      primary: false,
                      padding: const EdgeInsets.only(bottom: bottomReserve),
                      child: Column(
                        children: [
                          for (var r = 0; r < rows; r++)
                            week(r, heights[r], expanded ? 99 : 8),
                        ],
                      ),
                    );
                  }

                  final gridTop = bodyHeight - constraints.maxHeight;
                  final sheetTop = bodyHeight * (1 - sheetSplit);
                  // 고른 줄이 가리는 만큼 줄 단위로 민다 — 반만 밀면 맨 윗줄이 잘려 보인다
                  final needed = selectedRow < 0
                      ? 0.0
                      : gridTop + (selectedRow + 1) * rowH + 6 - sheetTop;
                  final targetShift = needed <= 0
                      ? 0.0
                      : math.min((needed / rowH).ceil(), selectedRow) * rowH;

                  final grid = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [for (var r = 0; r < rows; r++) week(r, rowH, 8)],
                  );

                  return ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      minHeight: 0,
                      maxHeight: double.infinity,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: targetShift),
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        child: grid,
                        builder: (context, shift, child) => AnimatedBuilder(
                          animation: sheet,
                          child: child,
                          builder: (context, child) {
                            final size = sheet.isAttached ? sheet.size : 0.0;
                            final f = (size / sheetSplit).clamp(0.0, 1.0);
                            return Transform.translate(
                              offset: Offset(0, -shift * f),
                              child: child,
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    DateTime date,
    double height,
    int maxLines,
    DateTime now,
    _CellMetrics m,
  ) {
    final inMonth = date.month == month.month;
    final isToday = _sameDay(date, now);
    final isSelected =
        showSelection && selected != null && _sameDay(date, selected!);

    Color numberColor;
    if (isToday) {
      numberColor = AppSemanticColors.textInverse;
    } else if (date.weekday == DateTime.sunday ||
        (inMonth && (holidayFor?.call(date) ?? false))) {
      numberColor = AppSemanticColors.statusErrorIcon;
    } else if (date.weekday == DateTime.saturday) {
      numberColor = AppSemanticColors.statusInfoIcon;
    } else {
      numberColor = AppSemanticColors.textPrimary;
    }
    if (!inMonth) numberColor = numberColor.withValues(alpha: 0.35);

    final number = Container(
      width: m.number,
      height: m.number,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isToday && inMonth ? AppSemanticColors.brandDefault : null,
        shape: BoxShape.circle,
      ),
      child: Text(
        '${date.day}',
        style: AppTypography.titleSmall.copyWith(
          height: 1,
          color: isToday && !inMonth
              ? AppSemanticColors.brandDefault.withValues(alpha: 0.35)
              : numberColor,
          fontWeight: isToday || isSelected
              ? AppTypography.fontWeightBold
              : AppTypography.fontWeightSemibold,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );

    final chips = inMonth ? chipsFor(date) : const <CalendarChipData>[];
    final footerWidget = inMonth ? footerFor?.call(date) : null;
    final footerSpace = footerFor == null ? 0.0 : _footerHeight;
    final lines =
        ((height - m.head - 4 - footerSpace) / (m.chip + _CellMetrics.gap))
            .floor()
            .clamp(0, maxLines);
    final children = <Widget>[];
    if (chips.isNotEmpty) {
      final overflow = chips.length > lines;
      if (overflow && lines == 1) {
        // 칸에 한 줄밖에 안 들어가면(작은 폰) 첫 이름과 '+n'을 한 칩에 — '+3'만 남으면 누군지 모른다
        children.add(
          _Chip(
            data: chips.first,
            height: m.chip,
            extra: '+${chips.length - 1}',
          ),
        );
      } else {
        final shown = overflow ? math.max(0, lines - 1) : chips.length;
        for (var i = 0; i < shown; i++) {
          children.add(_Chip(data: chips[i], height: m.chip));
        }
        if (overflow) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: _CellMetrics.gap, left: 3),
              child: Text(
                '+${chips.length - shown}',
                style: AppTypography.calendarCell.copyWith(
                  fontWeight: AppTypography.fontWeightBold,
                  color: AppSemanticColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ),
          );
        }
      }
    }

    final tint = inMonth ? tintFor?.call(date) : null;
    final badge = inMonth ? badgeFor?.call(date) : null;
    final dim = inMonth && (dimFor?.call(date) ?? false);

    Widget cell = Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
      decoration: tint != null || isSelected
          ? BoxDecoration(
              color: tint ?? AppSemanticColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppBorderRadius.lg + 2),
            )
          : null,
      // 테두리는 그림만 — 레이아웃이 움직이지 않게 앞에 덧그린다
      foregroundDecoration: isSelected
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(AppBorderRadius.lg + 2),
              border: Border.all(
                color: AppSemanticColors.brandDefault,
                width: 1.5,
              ),
            )
          : const BoxDecoration(
              border: Border(top: BorderSide(color: AppLines.rowColor)),
            ),
      child: ClipRect(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: number),
                const SizedBox(height: 1),
                ...children,
              ],
            ),
            if (badge != null) Positioned(top: 0, right: 0, child: badge),
            if (footerWidget != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 2,
                child: Center(child: footerWidget),
              ),
          ],
        ),
      ),
    );
    if (dim) cell = Opacity(opacity: 0.45, child: cell);
    cell = MediaQuery.withNoTextScaling(child: cell);

    final weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    return Semantics(
      button: true,
      selected: isSelected,
      label:
          '${date.month}월 ${date.day}일 ${weekdays[date.weekday % 7]}요일'
          '${chips.isEmpty ? '' : ', ${chips.map((c) => c.label).join(', ')}'}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AppHaptics.selection();
          onTapDay(date);
        },
        child: cell,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final CalendarChipData data;
  final double height;

  /// 칩 끝에 붙이는 '+n'(한 줄짜리 칸)
  final String? extra;

  const _Chip({required this.data, required this.height, this.extra});

  @override
  Widget build(BuildContext context) {
    final label = Text(
      data.label,
      maxLines: 1,
      softWrap: false,
      overflow: extra == null ? TextOverflow.ellipsis : TextOverflow.visible,
      style: AppTypography.calendarCell.copyWith(
        color: AppSemanticColors.textPrimary,
        letterSpacing: -0.2,
      ),
    );
    Widget chip = Container(
      height: height,
      margin: const EdgeInsets.only(top: _CellMetrics.gap),
      padding: const EdgeInsets.only(left: 3, right: 1),
      decoration: BoxDecoration(
        color: data.color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: extra == null
                ? label
                // '+n'과 같이 들어가면 이름을 칸에 맞춰 살짝 줄인다 — 말줄임이면 '한...'만 남았다
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: label,
                  ),
          ),
          if (extra != null)
            Padding(
              padding: const EdgeInsets.only(left: 1, right: 1),
              child: Text(
                extra!,
                style: AppTypography.calendarCell.copyWith(
                  fontWeight: AppTypography.fontWeightBold,
                  color: AppSemanticColors.textSecondary,
                  height: 1,
                ),
              ),
            )
          else if (data.trailing != null)
            data.trailing!,
        ],
      ),
    );
    if (data.faded) chip = Opacity(opacity: 0.45, child: chip);
    return chip;
  }
}

/// 요일 줄 — 높이 20, 11/600. 일 빨강·토 파랑.
class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  static const _labels = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space1),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Text(
                _labels[i],
                textAlign: TextAlign.center,
                style: AppTypography.labelStrong.copyWith(
                  color: i == 0
                      ? AppSemanticColors.statusErrorIcon
                      : i == 6
                      ? AppSemanticColors.statusInfoIcon
                      : AppSemanticColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 달력 머리줄 — '11월'(22 굵게) + '2026년'(13), 오른쪽에 ‹ › · 펼치기 · 오늘(알약 높이 36).
/// 좁은 화면·큰 글씨에서 다 안 들어가면 펼치기는 아이콘만 남긴다(크로박스와 같은 규칙).
class CalendarHeaderBar extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  const CalendarHeaderBar({
    super.key,
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.expanded,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    double textW(String text, TextStyle style) => (TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout()).width;
    final pillStyle = AppTypography.titleSmall;
    final titleW =
        textW('${month.month}월', AppTypography.appBarTitleLarge) +
        6 +
        textW('${month.year}년', AppTypography.bodySmall);
    final need =
        20 +
        titleW +
        8 +
        80 +
        6 +
        (12 + 18 + 4 + textW('펼치기', pillStyle) + 12) +
        6 +
        (28 + textW('오늘', pillStyle)) +
        12;
    final showExpandLabel = need <= MediaQuery.sizeOf(context).width;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space5,
        AppSpacing.space2,
        AppSpacing.space3,
        AppSpacing.space1,
      ),
      child: Row(
        children: [
          Flexible(
            fit: FlexFit.tight,
            child: Semantics(
              header: true,
              label: '${month.year}년 ${month.month}월',
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      '${month.month}월',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.appBarTitleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppSemanticColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${month.year}년',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: AppTypography.fontWeightMedium,
                        color: AppSemanticColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _IconStep(
            icon: Icons.chevron_left_rounded,
            label: '이전 달',
            onTap: onPrevious,
          ),
          _IconStep(
            icon: Icons.chevron_right_rounded,
            label: '다음 달',
            onTap: onNext,
          ),
          const SizedBox(width: AppSpacing.space1),
          _Pill(
            label: expanded ? '접기' : '펼치기',
            icon: expanded
                ? Icons.unfold_less_rounded
                : Icons.unfold_more_rounded,
            showLabel: showExpandLabel,
            filled: expanded,
            onTap: onToggleExpanded,
          ),
          const SizedBox(width: 6),
          _Pill(label: '오늘', onTap: onToday, semanticLabel: '오늘로 가기'),
        ],
      ),
    );
  }
}

class _IconStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _IconStep({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: AppPressable(
        onTap: onTap,
        haptic: AppHapticKind.selection,
        semanticLabel: label,
        minTouchSize: const Size(40, 44),
        child: SizedBox(
          width: 40,
          height: 44,
          child: Icon(icon, size: 26, color: AppSemanticColors.textPrimary),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool showLabel;
  final bool filled;
  final VoidCallback onTap;
  final String? semanticLabel;

  const _Pill({
    required this.label,
    required this.onTap,
    this.icon,
    this.showLabel = true,
    this.filled = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled
        ? AppSemanticColors.textInverse
        : AppSemanticColors.textPrimary;
    return AppPressable(
      onTap: onTap,
      haptic: AppHapticKind.selection,
      semanticLabel: semanticLabel ?? label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minHeight: 36, minWidth: 36),
        padding: EdgeInsets.symmetric(
          horizontal: showLabel ? AppSpacing.space3 : 0,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? AppSemanticColors.brandDefault
              : AppSemanticColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppBorderRadius.full),
          border: Border.all(
            color: filled ? AppSemanticColors.brandDefault : AppLines.cardColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 18, color: fg),
            if (icon != null && showLabel) const SizedBox(width: 4),
            if (showLabel)
              Text(label, style: AppTypography.titleSmall.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}

/// 떠 있는 추가 단추 '11월 14일에 휴무 추가 +' — 고른 날짜를 따라 글자가 바뀐다(크로박스 _AddPill).
class CalendarAddPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const CalendarAddPill({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: AppSemanticColors.brandDefault,
        shape: const StadiumBorder(),
        elevation: 6,
        shadowColor: AppSemanticColors.brandDefault.withValues(alpha: 0.35),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () {
            AppHaptics.tap();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 7, 7, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 230),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.buttonMedium.copyWith(
                      color: AppSemanticColors.textInverse,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: AppSemanticColors.textInverse,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 그날 시트 — 아래에서 반쯤 올라오는 흰 판(위 모서리 20, 위쪽 그림자).
/// 손잡이를 누르거나 끌어내리면 닫힌다. 머리: '11월 15일 일요일'(17) + 오늘 꼬리표 + 닫기,
/// 아래 [subtitle](건수·진행). 본문은 [children].
class CalendarDaySheet extends StatelessWidget {
  final DraggableScrollableController controller;

  /// 멈출 자리 — 상수 목록으로 넘긴다(아래 주석)
  final List<double> snapSizes;
  final DateTime date;
  final Widget? subtitle;
  final VoidCallback onClose;
  final List<Widget> children;

  const CalendarDaySheet({
    super.key,
    required this.controller,
    required this.snapSizes,
    required this.date,
    required this.onClose,
    required this.children,
    this.subtitle,
  });

  static const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        now.year == date.year && now.month == date.month && now.day == date.day;
    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: 0,
      minChildSize: 0,
      maxChildSize: 0.94,
      snap: true,
      // 같은 목록을 넘겨야 한다 — 그릴 때마다 새 목록이면 Flutter가 멈출 자리가 바뀐 줄 알고
      // 시트를 가까운 자리로 다시 붙이는데, 막 열리는 중이면 도로 닫혀 버린다
      snapSizes: snapSizes,
      builder: (context, scrollController) {
        return ListenableBuilder(
          listenable: controller,
          builder: (context, child) {
            final visible = controller.isAttached && controller.size > 0.001;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: AppSemanticColors.surfaceCard,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: visible
                    ? [
                        BoxShadow(
                          color: AppColors.black.withValues(alpha: 0.12),
                          blurRadius: 24,
                          offset: const Offset(0, -6),
                        ),
                      ]
                    : null,
              ),
              child: child,
            );
          },
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                Semantics(
                  button: true,
                  label: '닫기',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onClose,
                    child: SizedBox(
                      height: 22,
                      child: Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppSemanticColors.borderSubtle,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '${date.month}월 ${date.day}일 ${_weekdays[date.weekday % 7]}요일',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.heading6.copyWith(
                                      color: AppSemanticColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (isToday) ...[
                                  const SizedBox(width: AppSpacing.space2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.space2,
                                      vertical: AppSpacing.space0_5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppSemanticColors.brandWeak,
                                      borderRadius: BorderRadius.circular(
                                        AppBorderRadius.lg,
                                      ),
                                    ),
                                    child: Text(
                                      '오늘',
                                      style: AppTypography.labelStrong.copyWith(
                                        color: AppSemanticColors
                                            .brandWeakForeground,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: AppSpacing.space0_5),
                              subtitle!,
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '닫기',
                        onPressed: onClose,
                        icon: Container(
                          padding: const EdgeInsets.all(AppSpacing.space1_5),
                          decoration: const BoxDecoration(
                            color: AppSemanticColors.fillDefault,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppSemanticColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...children,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 시트 머리 아래 진행 줄 — 작은 막대 + '3건 중 1건 완료'(크로박스 _DayProgress).
class CalendarDayProgress extends StatelessWidget {
  final int done;
  final int total;
  final String text;

  const CalendarDayProgress({
    super.key,
    required this.done,
    required this.total,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : done / total;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            width: 40,
            height: 4,
            child: Stack(
              children: [
                Container(color: AppLines.rowColor),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(color: AppSemanticColors.statusSuccessIcon),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppTypography.bodySmall.copyWith(
            color: AppSemanticColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
