import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import '../common/app_pressable.dart';

/// 목록 한 줄 — B안(2026-11-12, 시안 .row/.mrow).
///
/// 옅은 틸 바탕 둥근 아이콘(44) + 제목 16/w600 + 부제 14 + 꺾쇠, 줄 높이 60 이상.
/// 누르면 줄 바탕이 옅은 회색(모서리 14)으로 바뀐다(크기는 줄지 않는다 — 줄 전체가 움직이면 어지럽다).
/// 흰 카드([SeedListSection]) 안에서 카드 여백 20에 글자 시작이 맞도록 좌우 12를 쓴다.
class SeedListCell extends StatefulWidget {
  /// 옅은 틸 둥근 바탕에 아이콘을 넣어주는 간편 leading. 커스텀이 필요하면 [leading] 사용.
  final IconData? leadingIcon;
  final Widget? leading;
  final String title;
  final String? description;
  final Widget? trailing;
  final bool showChevron;
  final bool isDestructive;
  final bool isDisabled;
  final VoidCallback? onTap;

  /// 눌렀을 때 울릴 햅틱. 기본은 울리지 않는다(줄 눌러 들어가기는 선택 — PLAN 햅틱 표).
  final AppHapticKind? haptic;

  const SeedListCell({
    super.key,
    this.leadingIcon,
    this.leading,
    required this.title,
    this.description,
    this.trailing,
    this.showChevron = true,
    this.isDestructive = false,
    this.isDisabled = false,
    this.onTap,
    this.haptic,
  });

  @override
  State<SeedListCell> createState() => _SeedListCellState();
}

class _SeedListCellState extends State<SeedListCell> {
  bool _pressed = false;

  bool get _isInteractive => !widget.isDisabled && widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final titleColor = widget.isDisabled
        ? AppSemanticColors.textDisabled
        : widget.isDestructive
            ? AppSemanticColors.statusErrorText
            : AppSemanticColors.textPrimary;
    final descriptionColor = widget.isDisabled
        ? AppSemanticColors.textDisabled
        : AppSemanticColors.textSecondary;
    final iconColor = widget.isDisabled
        ? AppSemanticColors.textDisabled
        : widget.isDestructive
            ? AppSemanticColors.statusErrorText
            : AppSemanticColors.brandDefault;
    final iconBackground = widget.isDestructive
        ? AppSemanticColors.statusErrorBackground
        : AppSemanticColors.brandWeak;

    Widget? leadingWidget = widget.leading;
    leadingWidget ??= widget.leadingIcon != null
        ? Container(
            width: AppSpacing.iconCircle,
            height: AppSpacing.iconCircle,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.isDisabled
                  ? AppSemanticColors.surfaceDisabled
                  : iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(widget.leadingIcon, size: 22, color: iconColor),
          )
        : null;

    final content = AnimatedContainer(
      duration: AppMotion.press,
      constraints: const BoxConstraints(minHeight: AppSpacing.listRowMinHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space2_5,
      ),
      decoration: BoxDecoration(
        color: _pressed ? AppSemanticColors.surfacePressed : AppColors.transparent,
        borderRadius: BorderRadius.circular(AppBorderRadius.control),
      ),
      child: Row(
        children: [
          if (leadingWidget != null) ...[
            leadingWidget,
            const SizedBox(width: AppSpacing.space3_5),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: AppTypography.titleMedium.copyWith(color: titleColor),
                ),
                if (widget.description != null && widget.description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.space0_5),
                  Text(
                    widget.description!,
                    style: AppTypography.bodySmall.copyWith(color: descriptionColor),
                  ),
                ],
              ],
            ),
          ),
          if (widget.trailing != null) ...[
            const SizedBox(width: AppSpacing.space2),
            widget.trailing!,
          ] else if (widget.showChevron) ...[
            const SizedBox(width: AppSpacing.space2),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: AppSemanticColors.iconSubtle,
            ),
          ],
        ],
      ),
    );

    if (!_isInteractive) return content;

    return AppPressable(
      onTap: widget.onTap,
      haptic: widget.haptic,
      pressedScale: 1.0,
      minTouchSize: Size.zero,
      focusBorderRadius: BorderRadius.circular(AppBorderRadius.control),
      onHighlightChanged: (down) {
        if (mounted) setState(() => _pressed = down);
      },
      child: content,
    );
  }
}

/// 목록 묶음 — B안: 묶음 제목(14/w600 회색, 막대 없음) + 흰 카드(모서리 20, 테두리·구분선 없음).
/// 줄 사이는 선 대신 줄 자체의 여백으로 나눈다(시안 .sec-h + .menu-card).
class SeedListSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const SeedListSection({super.key, this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space1,
              AppSpacing.space4,
              AppSpacing.space1,
              AppSpacing.space2,
            ),
            child: Semantics(
              header: true,
              child: Text(
                title!,
                style: AppTypography.titleSmall.copyWith(
                  color: AppSemanticColors.textSecondary,
                ),
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.space2),
          decoration: BoxDecoration(
            color: AppSemanticColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppBorderRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}
