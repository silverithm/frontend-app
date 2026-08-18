import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 카드·목록의 ⋮(더보기) 액션 메뉴 공용 시트.
///
/// 기본 Material `PopupMenuButton` 대신 앱 공통 문법(둥근 상단 바텀시트 +
/// 틴트 아이콘 + Seed 타이포)을 쓴다. 채팅 첨부·필터 시트와 같은 생김새라
/// 화면마다 메뉴가 다르게 생기는 것을 막는다.
class AppSheetAction {
  final IconData icon;
  final String label;
  final VoidCallback onSelected;
  final bool isDestructive;

  const AppSheetAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.isDestructive = false,
  });
}

Future<void> showAppActionSheet(
  BuildContext context, {
  String? title,
  required List<AppSheetAction> actions,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppSemanticColors.surfaceDefault,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppBorderRadius.xl2),
      ),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null && title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.space5,
                  right: AppSpacing.space5,
                  bottom: AppSpacing.space2,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.heading6.copyWith(
                      color: AppSemanticColors.textPrimary,
                    ),
                  ),
                ),
              ),
            for (final action in actions) _ActionTile(action: action),
          ],
        ),
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  final AppSheetAction action;

  const _ActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    final Color iconColor = action.isDestructive
        ? AppSemanticColors.statusErrorIcon
        : AppSemanticColors.interactivePrimaryDefault;
    final Color textColor = action.isDestructive
        ? AppSemanticColors.statusErrorText
        : AppSemanticColors.textPrimary;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppSpacing.space2),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        ),
        child: Icon(action.icon, color: iconColor),
      ),
      title: Text(
        action.label,
        style: AppTypography.bodyLarge.copyWith(color: textColor),
      ),
      onTap: () {
        Navigator.of(context).pop();
        action.onSelected();
      },
    );
  }
}
