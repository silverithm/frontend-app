import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class AppLoading extends StatelessWidget {
  final String? message;
  final double? size;
  final Color? color;

  const AppLoading({
    super.key,
    this.message,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size ?? 32,
            height: size ?? 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? AppSemanticColors.interactivePrimaryDefault,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.space4),
            Text(
              message!,
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class AppLoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? loadingMessage;
  final Color? overlayColor;
  final Color? indicatorColor;

  const AppLoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.loadingMessage,
    this.overlayColor,
    this.indicatorColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: overlayColor ?? AppSemanticColors.backgroundOverlay,
              child: AppLoading(
                message: loadingMessage,
                color: indicatorColor,
              ),
            ),
          ),
      ],
    );
  }
}

class AppInlineLoading extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;

  const AppInlineLoading({
    super.key,
    this.message,
    this.size = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? AppSemanticColors.interactivePrimaryDefault,
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(width: AppSpacing.space2),
          Text(
            message!,
            style: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class AppSkeletonLoader extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const AppSkeletonLoader({
    super.key,
    required this.height,
    this.width,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<AppSkeletonLoader> createState() => _AppSkeletonLoaderState();
}

class _AppSkeletonLoaderState extends State<AppSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.baseColor ?? AppSemanticColors.surfaceDisabled;
    final highlightColor = widget.highlightColor ?? AppSemanticColors.surfaceHover;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(AppBorderRadius.base),
            gradient: LinearGradient(
              colors: [
                baseColor,
                Color.lerp(baseColor, highlightColor, _animation.value)!,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        );
      },
    );
  }
}

class AppSkeletonCard extends StatelessWidget {
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const AppSkeletonCard({
    super.key,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.all(AppSpacing.space4),
      padding: padding ?? const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(
          color: AppSemanticColors.borderDefault,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeletonLoader(
            height: 20,
            width: 150,
            borderRadius: BorderRadius.circular(AppBorderRadius.base),
          ),
          const SizedBox(height: AppSpacing.space3),
          AppSkeletonLoader(
            height: 16,
            borderRadius: BorderRadius.circular(AppBorderRadius.base),
          ),
          const SizedBox(height: AppSpacing.space2),
          AppSkeletonLoader(
            height: 16,
            width: 200,
            borderRadius: BorderRadius.circular(AppBorderRadius.base),
          ),
        ],
      ),
    );
  }
}