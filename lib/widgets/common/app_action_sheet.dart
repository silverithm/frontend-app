import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 카드·목록의 ⋮(더보기) 액션 메뉴 공용 시트.
///
/// 기본 Material `PopupMenuButton` 대신 앱 공통 문법(둥근 상단 바텀시트 +
/// 아이콘 한 줄 + Seed 타이포)을 쓴다. 채팅 길게 누르기·첨부·더보기 시트도 이것 하나를 쓴다.
///
/// 모양(2026-10-27 점검 R3-14·R1-14): 머리글은 띠 없이 작은 회색 글자, 항목은 색 칸 없이
/// 아이콘(20·textSecondary) + bodyMedium 한 줄(높이 48). 삭제처럼 되돌릴 수 없는 항목만 빨강.
class AppSheetAction {
  final IconData icon;
  final String label;
  final VoidCallback onSelected;
  final bool isDestructive;

  /// 항목 아래 한 줄 설명(첨부 시트처럼 무엇이 열리는지 알려야 할 때). 있으면 줄이 56으로 커진다.
  final String? description;

  /// 이 항목 위에 구분선 한 줄 — 비슷한 항목끼리 묶을 때.
  final bool hasDividerAbove;

  const AppSheetAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.isDestructive = false,
    this.description,
    this.hasDividerAbove = false,
  });
}

Future<void> showAppActionSheet(
  BuildContext context, {
  String? title,
  required List<AppSheetAction> actions,

  /// 항목 위에 끼울 위젯(예: 길게 누르기 시트의 이모지 줄). 아래에 구분선이 자동으로 붙는다.
  Widget? header,
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
    clipBehavior: Clip.antiAlias,
    builder: (sheetContext) {
      final hasTitle = title != null && title.isNotEmpty;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            top: AppSpacing.space2,
            bottom: AppSpacing.space2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasTitle)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space5,
                    AppSpacing.space2,
                    AppSpacing.space5,
                    AppSpacing.space1,
                  ),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppSemanticColors.textTertiary,
                    ),
                  ),
                ),
              if (header != null) ...[
                header,
                const Divider(height: 1, color: AppSemanticColors.borderSubtle),
              ],
              for (final action in actions) ...[
                if (action.hasDividerAbove)
                  const Divider(
                    height: 1,
                    color: AppSemanticColors.borderSubtle,
                  ),
                _ActionTile(action: action),
              ],
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
        : AppSemanticColors.textSecondary;
    final Color textColor = action.isDestructive
        ? AppSemanticColors.statusErrorText
        : AppSemanticColors.textPrimary;
    final description = action.description;
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        action.onSelected();
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: description == null
              ? AppSpacing.space12
              : AppSpacing.space14,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space5,
            vertical: AppSpacing.space2,
          ),
          child: Row(
            children: [
              Icon(action.icon, size: AppSpacing.space5, color: iconColor),
              const SizedBox(width: AppSpacing.space4),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.label,
                      style: AppTypography.bodyMedium.copyWith(
                        color: textColor,
                      ),
                    ),
                    if (description != null)
                      Text(
                        description,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppSemanticColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
