import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/app_haptics.dart';
import 'app_pressable.dart';

/// 알약 FAB — B안(2026-11-12, 시안 .fab).
///
/// 틸 알약 높이 56, 아이콘 24 + 글자 17/w600, 부드러운 그림자(AppShadows.floating).
/// [collapsed]를 true로 주면(목록을 아래로 스크롤할 때) 글자가 접혀 동그란 단추만 남는다.
/// 누르면 impact 햅틱(PLAN 햅틱 표), 0.97 스프링, 짙은 틸. 접혀도 화면 낭독기는 [label]을 읽는다.
class AppFab extends StatefulWidget {
  const AppFab({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.collapsed = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool collapsed;

  @override
  State<AppFab> createState() => _AppFabState();
}

class _AppFabState extends State<AppFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // '동작 줄이기'면 글자가 접히는 움직임 없이 바로 바뀐다. AnimatedSize에 0초를 주면
    // 배치 도중 스스로 다시 배치를 요청해 오류가 난다 — 아예 감싸지 않는다.
    final reduceMotion = AppMotion.reduceMotion(context);
    final Widget labelSlot = widget.collapsed
        ? const SizedBox(height: 24)
        : Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.space1_5,
            ),
            child: ExcludeSemantics(
              child: Text(
                widget.label,
                maxLines: 1,
                softWrap: false,
                style: AppTypography.buttonLarge.copyWith(
                  color: AppSemanticColors.textInverse,
                ),
              ),
            ),
          );
    return Semantics(
      label: widget.label,
      child: AppPressable(
        onTap: widget.onPressed,
        haptic: AppHapticKind.impact,
        focusBorderRadius: BorderRadius.circular(AppBorderRadius.full),
        onHighlightChanged: (down) {
          if (mounted) setState(() => _pressed = down);
        },
        child: AnimatedContainer(
          duration: AppMotion.press,
          height: 56,
          padding: EdgeInsetsDirectional.only(
            start: AppSpacing.space4,
            end: widget.collapsed ? AppSpacing.space4 : AppSpacing.space5,
          ),
          decoration: BoxDecoration(
            color: _pressed
                ? AppSemanticColors.brandPressed
                : AppSemanticColors.brandDefault,
            borderRadius: BorderRadius.circular(AppBorderRadius.full),
            boxShadow: AppShadows.floating,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 24, color: AppSemanticColors.textInverse),
              ClipRect(
                child: reduceMotion
                    ? labelSlot
                    : AnimatedSize(
                        duration: const Duration(milliseconds: 240),
                        curve: AppMotion.enterCurve,
                        alignment: AlignmentDirectional.centerStart,
                        child: labelSlot,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
