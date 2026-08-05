import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 당근 Seed 디자인 시스템 — List Item / List Header.
/// 스펙 참조: docs/seed-component-specs.md §3 List
/// (root padding·body gap·prefix/suffix 간격·아이콘 크기, pressed 상태 마진/라운드/스케일)
class SeedListCell extends StatefulWidget {
  /// 회색 사각 칩 안에 아이콘을 넣어주는 간편 leading. 커스텀이 필요하면 [leading] 사용.
  final IconData? leadingIcon;
  final Widget? leading;
  final String title;
  final String? description;
  final Widget? trailing;
  final bool showChevron;
  final bool isDestructive;
  final bool isDisabled;
  final VoidCallback? onTap;

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
    final descriptionColor =
        widget.isDisabled ? AppSemanticColors.textDisabled : AppSemanticColors.textTertiary;
    final iconColor = widget.isDisabled
        ? AppSemanticColors.textDisabled
        : widget.isDestructive
            ? AppSemanticColors.statusErrorIcon
            : AppSemanticColors.textSecondary;

    Widget? leadingWidget = widget.leading;
    leadingWidget ??= widget.leadingIcon != null
        ? Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppSemanticColors.backgroundTertiary,
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            ),
            child: Icon(widget.leadingIcon, size: 22, color: iconColor),
          )
        : null;

    // pressed: margin-x x1_5, radius x2_5, scale s97 — spec §3 상태별 색상 표
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: EdgeInsets.symmetric(horizontal: _pressed ? AppSpacing.space1_5 : 0),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4, // global-gutter
        vertical: AppSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: _pressed ? AppSemanticColors.surfaceActive : AppColors.transparent,
        borderRadius: BorderRadius.circular(_pressed ? AppSpacing.space2_5 : 0),
      ),
      child: Row(
        children: [
          if (leadingWidget != null) ...[
            leadingWidget,
            const SizedBox(width: AppSpacing.space3), // prefix padding-right
          ],
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.space2_5), // body padding-right
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 15, // t5
                      fontWeight: AppTypography.fontWeightMedium,
                      color: titleColor,
                      height: 1.4,
                    ),
                  ),
                  if (widget.description != null && widget.description!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.space0_5), // body gap
                    Text(
                      widget.description!,
                      style: TextStyle(
                        fontSize: 13, // t3
                        color: descriptionColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (widget.trailing != null)
            widget.trailing!
          else if (widget.showChevron)
            Icon(Icons.chevron_right, size: 18, color: AppSemanticColors.textTertiary),
        ],
      ),
    );

    if (!_isInteractive) return content;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: content,
    );
  }
}

/// List Header + 그룹 컨테이너 — 흰 표면 + 얇은 구분선 (화면 배경은 gray 위에 올린다).
/// 스펙 참조: docs/seed-component-specs.md §3 List Header
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space4, // global-gutter
              vertical: AppSpacing.space2,
            ),
            child: Text(
              title!,
              style: TextStyle(
                fontSize: AppTypography.fontSizeBase, // t4
                fontWeight: AppTypography.fontWeightMedium, // mediumWeak
                color: AppSemanticColors.textTertiary,
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: AppSemanticColors.surfaceDefault,
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            border: Border.all(color: AppSemanticColors.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: AppSpacing.space4,
                    color: AppSemanticColors.borderSubtle,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
