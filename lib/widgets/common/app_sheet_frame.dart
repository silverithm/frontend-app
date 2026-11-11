import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 아래에서 올라오는 시트의 공통 틀 — B안(2026-11-12, 시안 .sheet).
///
/// 손잡이(40×5) → (경고 아이콘 52) → 제목 21/w700 → 설명 16 회색 → 본문 → 단추 줄.
/// 좌우 20, 위 10, 아래 20 + 안전 영역 + 키보드 높이. 내용이 길면 시트 안에서 스크롤한다.
/// 단추 줄은 [AppSheetActions]로 만든다(취소 1 : 확인 1.7).
class AppSheetFrame extends StatelessWidget {
  const AppSheetFrame({
    super.key,
    this.title,
    this.message,
    this.warning = false,
    this.children = const [],
    this.actions,
  });

  final String? title;
  final String? message;

  /// 삭제·반려 확인처럼 경고가 필요한 창 — 옅은 빨강 둥근 바탕에 경고 아이콘.
  final bool warning;
  final List<Widget> children;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space5,
            AppSpacing.space2_5,
            AppSpacing.space5,
            AppSpacing.space5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AppSheetHandle()),
              const SizedBox(height: 18),
              if (warning) ...[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: AppSemanticColors.statusErrorBackground,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      size: 28,
                      color: AppSemanticColors.statusErrorText,
                      semanticLabel: '주의',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.space3_5),
              ],
              if (title != null)
                Semantics(
                  header: true,
                  child: Text(
                    title!,
                    style: AppTypography.heading5.copyWith(
                      color: AppSemanticColors.textPrimary,
                    ),
                  ),
                ),
              if (message != null && message!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space1_5),
                Text(
                  message!,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textSecondary,
                  ),
                ),
              ],
              ...children,
              if (actions != null) ...[
                const SizedBox(height: AppSpacing.space6),
                actions!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 시트 손잡이 40×5.
class AppSheetHandle extends StatelessWidget {
  const AppSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 5,
      decoration: BoxDecoration(
        color: AppSemanticColors.sheetHandle,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
      ),
    );
  }
}

/// 시트 단추 줄 — 취소 1 : 확인 1.7(시안 .sh-actions). 취소가 없으면 확인 하나가 꽉 찬다.
///
/// 취소 글자가 제 몫(1/2.7)에 한 줄로 안 들어가면 그만큼만 넓어진다(많아도 절반까지) —
/// 좁은 창에서 글자를 키우면 '나중에'가 '나중 / 에'로 쪼개졌다(2026-11-12 글자 1.3배 점검).
/// 글자가 들어가는 평소에는 예전과 같은 1 : 1.7이다.
class AppSheetActions extends StatelessWidget {
  const AppSheetActions({super.key, this.cancel, required this.confirm});

  final Widget? cancel;
  final Widget confirm;

  static const double _gap = AppSpacing.space2;

  @override
  Widget build(BuildContext context) {
    final c = cancel;
    if (c == null) return confirm;
    return LayoutBuilder(
      builder: (context, constraints) {
        // 폭이 정해지지 않은 자리에서는 예전처럼 비율로만 나눈다
        if (!constraints.hasBoundedWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 10, child: c),
              const SizedBox(width: _gap),
              Expanded(flex: 17, child: confirm),
            ],
          );
        }
        final room = (constraints.maxWidth - _gap).clamp(0.0, double.infinity);
        final share = room * 10 / 27;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: share, maxWidth: room / 2),
              child: IntrinsicWidth(child: c),
            ),
            const SizedBox(width: _gap),
            Expanded(child: confirm),
          ],
        );
      },
    );
  }
}

/// 시트를 띄우는 공통 설정 — 뒤 어둠·모서리 24·흰 바탕은 테마(AppTheme)가 준다.
/// 가운데 대화상자처럼 맨 위 Navigator에 띄운다(하단 탭 위로 올라온다).
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: AppSemanticColors.surfaceCard,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.92,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppBorderRadius.sheet),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    builder: builder,
  );
}
