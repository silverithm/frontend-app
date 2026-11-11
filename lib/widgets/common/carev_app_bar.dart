import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 케어브이 공통 앱바.
///
/// D6: 화면마다 제각각이던 앱바를 이 위젯 하나로 통일한다. 색은 여기서 정하지 않고
/// 앱 공통 상단 바 테마(AppTheme.headerTheme — 틸 바탕, 높이 56, 아래 선 없음)를 따른다.
/// 배차관리 화면은 별도 작업 중이라 이 위젯을 쓰지 않는다.
///
/// B안(2026-11-12) 두 가지 모양:
/// - 안쪽 화면(기본): 꺾쇠(‹) 뒤로 + 가운데 제목 17/w600, 필요하면 [subtitle] 13.
/// - 탭 첫 화면([isRoot]): 뒤로 없이 왼쪽 제목 20/w700(홈은 인사말이 이 자리).
class CareVAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CareVAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.showBackButton,
    this.bottom,
    this.centerTitle = true,
    this.isRoot = false,
  });

  final String title;

  /// 제목 아래 작은 글(대화방 인원 등). 탭 첫 화면에서는 쓰지 않는다.
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final bool? showBackButton;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;

  /// 탭 첫 화면(홈·채팅·일정·전자결재·전체) — 왼쪽 큰 제목, 뒤로 없음.
  final bool isRoot;

  /// 탭 첫 화면 제목 왼쪽 여백(시안 padding-left 20)
  static const double rootTitleSpacing = AppSpacing.space5;

  /// 탭 첫 화면이 아닌데 직접 AppBar를 쓰는 곳에서 같은 뒤로 단추를 쓸 때.
  static Widget backButton(BuildContext context) => IconButton(
        tooltip: '뒤로 가기',
        icon: const Icon(Icons.chevron_left_rounded, size: 30),
        onPressed: () => Navigator.of(context).maybePop(),
      );

  @override
  Widget build(BuildContext context) {
    final canPop = showBackButton ?? ModalRoute.of(context)?.canPop ?? false;
    final showBack = !isRoot && automaticallyImplyLeading && canPop;

    final titleStyle = (isRoot
            ? AppTypography.appBarTitleLarge
            : AppTypography.appBarTitle)
        .copyWith(color: AppSemanticColors.headerForeground);

    Widget titleWidget = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: titleStyle,
    );
    final sub = subtitle;
    if (!isRoot && sub != null && sub.isNotEmpty) {
      titleWidget = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: centerTitle
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          titleWidget,
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelMedium.copyWith(
              color: AppSemanticColors.headerForegroundMuted,
            ),
          ),
        ],
      );
    }

    return AppBar(
      title: titleWidget,
      elevation: 0,
      centerTitle: isRoot ? false : centerTitle,
      titleSpacing: isRoot ? rootTitleSpacing : null,
      automaticallyImplyLeading: !isRoot && automaticallyImplyLeading,
      leading: leading ?? (showBack ? backButton(context) : null),
      actions: actions,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
      AppSpacing.toolbarHeight + (bottom?.preferredSize.height ?? 0));
}
