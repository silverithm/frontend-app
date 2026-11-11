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
          // B안: 스피너는 짧게 끝나는 자리용. 화면 첫 불러오기는 AppSkeletonList·AppSkeletonDetail 뼈대를 쓴다.
          SizedBox(
            width: size ?? 32,
            height: size ?? 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              strokeCap: StrokeCap.round,
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

// 뼈대(skeleton)는 app_skeleton.dart로 옮겼다 — AppSkeleton·AppSkeletonList·AppSkeletonDetail·AppSkeletonCard.
