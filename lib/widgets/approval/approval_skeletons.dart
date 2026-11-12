import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../common/app_skeleton.dart';

/// 공문 한 장 뼈대 — 제목, 기안 정보 표(항목 이름 칸 + 값 줄), 본문 문단.
///
/// 결재 상세의 공문 카드(흰 카드, 안쪽 여백 12) 안에 들어간다. [standalone]이 false면
/// 바깥 [AppSkeleton]의 빛을 같이 쓴다([ApprovalDetailSkeleton]이 그렇게 쓴다).
class ApprovalDocumentSkeleton extends StatelessWidget {
  const ApprovalDocumentSkeleton({super.key, this.standalone = true});

  final bool standalone;

  static const List<double> _valueWidths = [0.6, 0.45, 0.7, 0.5];
  static const List<double> _bodyWidths = [1, 0.94, 0.98, 0.6];

  @override
  Widget build(BuildContext context) {
    final paper = Padding(
      padding: const EdgeInsets.all(AppSpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSkeletonLine(widthFactor: 0.5, height: AppSpacing.space6),
          const SizedBox(height: AppSpacing.space6),
          for (final width in _valueWidths) ...[
            Row(
              children: [
                const AppSkeletonBox(
                  width: AppSpacing.space16,
                  height: AppSpacing.space5,
                  radius: AppBorderRadius.base,
                ),
                const SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: AppSkeletonLine(
                    widthFactor: width,
                    height: AppSpacing.space4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space3),
          ],
          const SizedBox(height: AppSpacing.space3),
          for (final width in _bodyWidths) ...[
            AppSkeletonLine(widthFactor: width),
            const SizedBox(height: AppSpacing.space3),
          ],
        ],
      ),
    );
    if (!standalone) return paper;
    // 흰 카드 안의 뼈는 한 단계 옅은 색
    return AppSkeleton(
      baseColor: AppSemanticColors.skeletonBaseOnCard,
      child: paper,
    );
  }
}

/// 결재 상세 화면 첫 불러오기 뼈대 — 상태 카드(제목 + 상태 알약 + 이름표 두 줄) + 공문 카드.
/// 결재 상세와 같은 바깥 여백·카드 사이 간격(10)이라 문서가 떠도 덜 튄다.
class ApprovalDetailSkeleton extends StatelessWidget {
  const ApprovalDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cardDecoration = BoxDecoration(
      color: AppSemanticColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppBorderRadius.card),
    );
    return AppSkeleton(
      baseColor: AppSemanticColors.skeletonBaseOnCard,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          AppSpacing.space3,
          AppSpacing.screenGutter,
          AppSpacing.space6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              decoration: cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: AppSkeletonLine(
                          widthFactor: 0.7,
                          height: AppSpacing.space6,
                        ),
                      ),
                      SizedBox(width: AppSpacing.space2),
                      AppSkeletonBox(
                        width: AppSpacing.space12,
                        height: AppSpacing.space6,
                        radius: AppBorderRadius.full,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  for (final width in const [0.42, 0.56]) ...[
                    AppSkeletonLine(widthFactor: width, height: AppSpacing.space4),
                    const SizedBox(height: AppSpacing.space2_5),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),
            Container(
              padding: const EdgeInsets.all(AppSpacing.space3),
              decoration: cardDecoration,
              child: const ApprovalDocumentSkeleton(standalone: false),
            ),
          ],
        ),
      ),
    );
  }
}
