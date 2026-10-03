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
    // 기본 시트는 화면의 9/16에서 멈춘다. 채팅방 ⋮ 메뉴(제목 + 다섯 항목)는 360×640 폰에서
    // 그보다 8px 길어 마지막 항목이 잘렸고, 글자를 크게 해 둔 분은 47px까지 잘렸다.
    // 내용만큼 커지되 화면의 85%에서 멈추고, 그래도 길면 스크롤한다.
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.85,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppBorderRadius.xl2),
      ),
    ),
    // 제목 띠가 둥근 모서리 밖으로 삐져나오지 않게
    clipBehavior: Clip.antiAlias,
    builder: (sheetContext) {
      final hasTitle = title != null && title.isNotEmpty;
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: hasTitle ? 0 : AppSpacing.space4,
            bottom: AppSpacing.space4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasTitle) ...[
                // 시트 제목 — 화면 안쪽 머리(연한 틸 면 + 아래 연한 틸 선)
                Container(
                  decoration: const BoxDecoration(
                    color: AppSemanticColors.subheaderBackground,
                    border: Border(
                      bottom: BorderSide(
                        color: AppSemanticColors.subheaderBorder,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space5,
                    AppSpacing.space4,
                    AppSpacing.space5,
                    AppSpacing.space3,
                  ),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.heading6.copyWith(
                      color: AppSemanticColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.space2),
              ],
              for (final action in actions) _ActionTile(action: action),
            ],
          ),
        ),
      );
    },
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
