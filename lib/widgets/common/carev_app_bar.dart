import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// 케어브이 공통 앱바.
///
/// D6: 화면마다 제각각이던 앱바를 이 위젯 하나로 통일한다. 색은 여기서 정하지 않고
/// 앱 공통 상단 바 테마(AppTheme.headerTheme — 틸 바탕 + 진한 틸 아래 선)를 따른다.
/// 배차관리 화면은 별도 작업 중이라 이 위젯을 쓰지 않는다.
class CareVAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CareVAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.showBackButton,
    this.bottom,
    this.centerTitle = false,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final bool? showBackButton;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    final canPop = showBackButton ?? ModalRoute.of(context)?.canPop ?? false;

    return AppBar(
      title: Text(
        title,
        style: AppTypography.heading6.copyWith(
          color: AppSemanticColors.headerForeground,
        ),
      ),
      elevation: 0,
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading ??
          (automaticallyImplyLeading && canPop
              ? IconButton(
                  tooltip: '뒤로 가기',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null),
      actions: actions,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}
