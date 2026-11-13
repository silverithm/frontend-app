import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_lines.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';

/// 불러오는 동안 화면 모양을 미리 보여 주는 뼈대(skeleton).
///
/// [AppSkeleton]이 묶은 영역 전체를 기준으로 은은한 빛이 한 줄로 지나간다 — 뼈마다 따로
/// 돌지 않아 서로 어긋나지 않는다. 빛은 뼈([AppSkeletonLine]·[AppSkeletonBox]·
/// [AppSkeletonCircle])에만 칠해지므로 그 사이에 카드 바탕·테두리를 둬도 된다.
/// '동작 줄이기'면 빛 없이 회색 뼈만 둔다. 화면 낭독기에는 "불러오는 중" 하나만 읽힌다.
///
/// 바로 갖다 쓰는 조합:
/// - [AppSkeletonList] — 목록 화면(동그라미 + 두 줄)
/// - [AppSkeletonDetail] — 상세 화면(제목·작성자 줄·본문 문단)
/// - [AppSkeletonCard] — 카드 한 장
///
/// 테스트에서 이 위젯이 화면에 있으면 빛이 계속 돌아 `pumpAndSettle`이 끝나지 않는다
/// (스피너와 같다) — `pump(duration)`을 쓴다.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    required this.child,
    this.semanticLabel = '불러오는 중',
    // B안(시안 --sk): 회색 바탕 위 #E3E6EA, 흰 카드 안은 AppSkeletonCard처럼 skeletonBaseOnCard
    this.baseColor = AppSemanticColors.skeletonBase,
    this.highlightColor = AppColors.gray50,
  });

  final Widget child;
  final String semanticLabel;

  /// 뼈 바탕색.
  final Color baseColor;

  /// 지나가는 빛의 색.
  final Color highlightColor;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: AppMotion.shimmer,
  );
  final GlobalKey _anchorKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduceMotion(context)) {
      if (_shimmer.isAnimating) _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  RenderBox? _anchor() {
    final object = _anchorKey.currentContext?.findRenderObject();
    return object is RenderBox && object.hasSize ? object : null;
  }

  @override
  Widget build(BuildContext context) {
    final reduce = AppMotion.reduceMotion(context);
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      child: ExcludeSemantics(
        child: _AppSkeletonScope(
          shimmer: reduce ? null : _shimmer,
          baseColor: widget.baseColor,
          highlightColor: widget.highlightColor,
          anchor: _anchor,
          child: _SkeletonAnchor(key: _anchorKey, child: widget.child),
        ),
      ),
    );
  }
}

class _AppSkeletonScope extends InheritedWidget {
  const _AppSkeletonScope({
    required this.shimmer,
    required this.baseColor,
    required this.highlightColor,
    required this.anchor,
    required super.child,
  });

  final Animation<double>? shimmer;
  final Color baseColor;
  final Color highlightColor;
  final RenderBox? Function() anchor;

  static _AppSkeletonScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AppSkeletonScope>();

  @override
  bool updateShouldNotify(_AppSkeletonScope oldWidget) =>
      shimmer != oldWidget.shimmer ||
      baseColor != oldWidget.baseColor ||
      highlightColor != oldWidget.highlightColor;
}

/// 빛의 기준 영역. 빛이 돌 때 다시 그리는 범위를 뼈대 안으로 가둔다.
class _SkeletonAnchor extends SingleChildRenderObjectWidget {
  const _SkeletonAnchor({super.key, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderAnchor();
}

class _RenderAnchor extends RenderProxyBox {
  @override
  bool get isRepaintBoundary => true;
}

// ── 뼈 하나 ─────────────────────────────────────────────────────────

/// 글 한 줄 모양. [widthFactor]를 주면 남는 너비의 그 비율만큼(왼쪽 정렬), [width]를 주면 그 길이,
/// 둘 다 없으면 꽉 채운다.
class AppSkeletonLine extends StatelessWidget {
  const AppSkeletonLine({
    super.key,
    this.width,
    this.widthFactor,
    this.height = AppSpacing.space3_5,
    this.radius = AppBorderRadius.base,
  }) : assert(width == null || widthFactor == null);

  final double? width;
  final double? widthFactor;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bone = SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: _Bone(borderRadius: BorderRadius.circular(radius)),
    );
    final factor = widthFactor;
    if (factor == null) return bone;
    return FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: factor,
      child: bone,
    );
  }
}

/// 사각 덩어리(사진·카드·버튼 자리). [width]가 없으면 꽉 채운다.
class AppSkeletonBox extends StatelessWidget {
  const AppSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = AppBorderRadius.xl,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: _Bone(borderRadius: BorderRadius.circular(radius)),
    );
  }
}

/// 동그라미(얼굴 사진·아이콘 자리).
class AppSkeletonCircle extends StatelessWidget {
  const AppSkeletonCircle({super.key, this.size = AppSpacing.space10});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: _Bone(borderRadius: BorderRadius.circular(AppBorderRadius.full)),
    );
  }
}

/// 뼈 하나. 받은 크기를 꽉 채워 둥근 사각을 칠하고, 빛이 돌면 [AppSkeleton] 영역을 기준으로
/// 같은 띠를 칠한다(다시 짓지 않고 다시 그리기만 한다).
class _Bone extends LeafRenderObjectWidget {
  const _Bone({required this.borderRadius});

  final BorderRadius borderRadius;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final scope = _AppSkeletonScope.maybeOf(context);
    return _RenderBone(
      borderRadius: borderRadius,
      baseColor: scope?.baseColor ?? AppSemanticColors.skeletonBase,
      highlightColor: scope?.highlightColor ?? AppColors.gray50,
      shimmer: scope?.shimmer,
      anchor: scope?.anchor,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderBone renderObject) {
    final scope = _AppSkeletonScope.maybeOf(context);
    renderObject
      ..borderRadius = borderRadius
      ..baseColor = scope?.baseColor ?? AppSemanticColors.skeletonBase
      ..highlightColor = scope?.highlightColor ?? AppColors.gray50
      ..shimmer = scope?.shimmer
      ..anchor = scope?.anchor;
  }
}

class _RenderBone extends RenderBox {
  _RenderBone({
    required BorderRadius borderRadius,
    required Color baseColor,
    required Color highlightColor,
    Animation<double>? shimmer,
    RenderBox? Function()? anchor,
  })  : _borderRadius = borderRadius,
        _baseColor = baseColor,
        _highlightColor = highlightColor,
        _shimmer = shimmer,
        _anchor = anchor;

  BorderRadius _borderRadius;
  set borderRadius(BorderRadius value) {
    if (_borderRadius == value) return;
    _borderRadius = value;
    markNeedsPaint();
  }

  Color _baseColor;
  set baseColor(Color value) {
    if (_baseColor == value) return;
    _baseColor = value;
    markNeedsPaint();
  }

  Color _highlightColor;
  set highlightColor(Color value) {
    if (_highlightColor == value) return;
    _highlightColor = value;
    markNeedsPaint();
  }

  Animation<double>? _shimmer;
  set shimmer(Animation<double>? value) {
    if (_shimmer == value) return;
    if (attached) _shimmer?.removeListener(markNeedsPaint);
    _shimmer = value;
    if (attached) _shimmer?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  RenderBox? Function()? _anchor;
  set anchor(RenderBox? Function()? value) {
    _anchor = value;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _shimmer?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _shimmer?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    return constraints.constrain(
      Size(
        constraints.hasBoundedWidth ? constraints.maxWidth : 0,
        constraints.hasBoundedHeight ? constraints.maxHeight : 0,
      ),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;
    final rrect = _borderRadius.toRRect(offset & size);
    final paint = Paint()..color = _baseColor;

    final shimmer = _shimmer;
    final anchor = _anchor?.call();
    if (shimmer != null && anchor != null && anchor.attached) {
      // 이 뼈에서 본 기준 영역의 위치 — 모든 뼈가 같은 띠를 나눠 칠하게 된다.
      final Offset inAnchor = localToGlobal(Offset.zero, ancestor: anchor);
      final Rect area = (offset - inAnchor) & anchor.size;
      paint.shader = LinearGradient(
        begin: const Alignment(-1, -0.3),
        end: const Alignment(1, 0.3),
        colors: [_baseColor, _highlightColor, _baseColor],
        stops: const [0.35, 0.5, 0.65],
        transform: _SlideGradient(shimmer.value * 2 - 1),
      ).createShader(area);
    }
    context.canvas.drawRRect(rrect, paint);
  }
}

/// 빛 띠를 기준 영역 왼쪽 밖(-1)에서 오른쪽 밖(1)까지 옮긴다.
class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.percent);

  final double percent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * percent, 0, 0);
  }
}

// ── 조합 ─────────────────────────────────────────────────────────────

/// 목록 한 줄 — (동그라미) + 제목 줄 + 보조 줄. [AppSkeleton] 안에서 쓴다.
class AppSkeletonListTile extends StatelessWidget {
  const AppSkeletonListTile({
    super.key,
    this.showLeading = true,
    this.leadingSize = AppSpacing.space10,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.space4,
      vertical: AppSpacing.space3,
    ),
    this.titleWidthFactor = 0.6,
    this.subtitleWidthFactor = 0.4,
  });

  final bool showLeading;
  final double leadingSize;
  final EdgeInsetsGeometry padding;
  final double titleWidthFactor;
  final double subtitleWidthFactor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (showLeading) ...[
            AppSkeletonCircle(size: leadingSize),
            const SizedBox(width: AppSpacing.space3),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonLine(widthFactor: titleWidthFactor, height: 15),
                const SizedBox(height: AppSpacing.space2),
                AppSkeletonLine(
                  widthFactor: subtitleWidthFactor,
                  height: AppSpacing.space3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 목록 화면용 뼈대 — 스피너 대신 바로 갖다 쓴다.
///
/// ```dart
/// body: isLoading ? const AppSkeletonList() : ListView(...)
/// ```
/// 줄마다 제목 길이를 조금씩 달리해 진짜 목록처럼 보이게 한다. 스크롤되지 않는다.
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({
    super.key,
    this.itemCount = 8,
    this.showLeading = true,
    this.padding = const EdgeInsets.symmetric(vertical: AppSpacing.space2),
  });

  final int itemCount;
  final bool showLeading;
  final EdgeInsetsGeometry padding;

  static const List<double> _titleWidths = [0.62, 0.48, 0.7, 0.55, 0.66, 0.44];
  static const List<double> _subtitleWidths = [0.38, 0.3, 0.42, 0.34, 0.26, 0.4];

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: ListView.builder(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) => AppSkeletonListTile(
          showLeading: showLeading,
          titleWidthFactor: _titleWidths[index % _titleWidths.length],
          subtitleWidthFactor: _subtitleWidths[index % _subtitleWidths.length],
        ),
      ),
    );
  }
}

/// 상세 화면용 뼈대 — 제목, 작성자 줄, (사진), 본문 문단.
class AppSkeletonDetail extends StatelessWidget {
  const AppSkeletonDetail({
    super.key,
    this.showMedia = false,
    this.paragraphLines = 6,
    this.padding = const EdgeInsets.all(AppSpacing.space5),
  });

  /// 본문 위 사진 자리를 둘지.
  final bool showMedia;
  final int paragraphLines;
  final EdgeInsetsGeometry padding;

  static const List<double> _lineWidths = [1, 0.96, 1, 0.9, 0.98, 0.94, 1, 0.88];

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSkeletonLine(widthFactor: 0.72, height: AppSpacing.space5),
            const SizedBox(height: AppSpacing.space4),
            const Row(
              children: [
                AppSkeletonCircle(size: AppSpacing.space8),
                SizedBox(width: AppSpacing.space2),
                Expanded(
                  child: AppSkeletonLine(
                    widthFactor: 0.4,
                    height: AppSpacing.space3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space6),
            if (showMedia) ...[
              const AppSkeletonBox(height: 180),
              const SizedBox(height: AppSpacing.space6),
            ],
            for (var i = 0; i < paragraphLines; i++) ...[
              AppSkeletonLine(
                // 마지막 줄은 문단 끝처럼 짧게
                widthFactor: i == paragraphLines - 1
                    ? 0.6
                    : _lineWidths[i % _lineWidths.length],
              ),
              const SizedBox(height: AppSpacing.space3),
            ],
          ],
        ),
      ),
    );
  }
}

/// 카드 한 장 뼈대 — 제목 + 두 줄. 혼자 쓰면 스스로 [AppSkeleton]을 두른다.
/// (예전 app_loading.dart의 AppSkeletonCard와 같은 모양 — 쓰는 곳이 없어 이리로 옮겼다.)
class AppSkeletonCard extends StatelessWidget {
  const AppSkeletonCard({
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.margin = const EdgeInsets.all(AppSpacing.space4),
    this.standalone = true,
  });

  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  /// false면 바깥 [AppSkeleton]의 빛을 같이 쓴다(카드 여러 장을 한 번에 묶을 때).
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    // B안: 테두리 없는 흰 카드(모서리 16) 안의 뼈는 한 단계 옅은 색(시안 --sk-in)
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppBorderRadius.card),
        border: AppLines.cardBorder,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeletonLine(width: 150, height: AppSpacing.space5),
          SizedBox(height: AppSpacing.space3),
          AppSkeletonLine(height: AppSpacing.space4),
          SizedBox(height: AppSpacing.space2),
          AppSkeletonLine(widthFactor: 0.7, height: AppSpacing.space4),
        ],
      ),
    );
    return standalone
        ? AppSkeleton(
            baseColor: AppSemanticColors.skeletonBaseOnCard,
            child: card,
          )
        : card;
  }
}
