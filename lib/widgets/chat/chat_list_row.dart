import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_lines.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../common/app_pressable.dart';

/// 채팅 화면들(방 목록·직원·참가자·새 방 참가자 고르기)의 한 줄 감싸개 — B안.
///
/// 흰 카드 안 줄(또는 화면 끝까지 채운 목록의 줄)로 쓴다. 누르면 크기는 줄지 않고 줄 바탕이 옅은 회색(모서리 12)으로 바뀐다
/// ([SeedListCell]과 같은 눌림). 길게 누르기는 AppPressable 기본 impact 햅틱.
/// 높이는 [AppSpacing.listRowMinHeight](52) 이상, 좌우 12·위아래 10 — 카드 안쪽 여백 8과 더해
/// 글자 시작이 카드 가장자리에서 20이 된다. 높이를 못 박지 않아 글자를 키워도 넘치지 않는다.
class ChatListRow extends StatefulWidget {
  const ChatListRow({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;

  /// null이면(누를 수 없는 줄) 눌림 색도 없다.
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<ChatListRow> createState() => _ChatListRowState();
}

class _ChatListRowState extends State<ChatListRow> {
  bool _pressed = false;

  bool get _isInteractive => widget.onTap != null || widget.onLongPress != null;

  @override
  void didUpdateWidget(covariant ChatListRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 누르는 중에 줄이 잠기면(방 여는 중 등) 회색 바탕이 남지 않게
    if (!_isInteractive) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: AppMotion.press,
      constraints: const BoxConstraints(minHeight: AppSpacing.listRowMinHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space2_5,
      ),
      decoration: BoxDecoration(
        color: _pressed
            ? AppSemanticColors.surfacePressed
            : AppColors.transparent,
        borderRadius: BorderRadius.circular(AppBorderRadius.control),
      ),
      child: widget.child,
    );

    if (!_isInteractive) return content;

    return AppPressable(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
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

/// 흰 카드(모서리 16)의 한 조각 — 긴 목록을 `ListView.builder`로 그리면서도 한 장의 카드로 보이게 한다.
///
/// 묶음 첫 줄([isFirst])은 위 모서리와 위 여백 8, 끝 줄([isLast])은 아래 모서리·아래 여백 8과
/// 다음 묶음과의 간격([AppSpacing.cardGap])을 둔다. 카드 둘레 테두리와 줄 사이 선을 함께 그린다.
/// [fullBleed]면 카드 없이 화면 끝까지 채운다(대화·직원 탭).
class ChatCardSlice extends StatelessWidget {
  const ChatCardSlice({
    super.key,
    required this.isFirst,
    required this.isLast,
    required this.child,
    this.gapAfter,
    this.dividerIndent = AppSpacing.space4,
    this.fullBleed = false,
  });

  /// 화면 폭을 다 쓰는 목록(대화·직원)에서 true — 카드 없이 화면 끝까지 채운다.
  final bool fullBleed;

  final bool isFirst;
  final bool isLast;
  final Widget child;

  /// 꽉 찬 목록에서 묶음 끝에 회색 띠를 둘지. 없으면 [isLast]를 따른다.
  final bool? gapAfter;

  /// 꽉 찬 목록에서 줄 사이 선의 왼쪽 들여쓰기 — 글자 시작에 맞춘다.
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    if (fullBleed) return _buildFullBleed();
    const radius = Radius.circular(AppBorderRadius.card);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? AppSpacing.cardGap : 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppSemanticColors.surfaceCard,
          borderRadius: BorderRadius.vertical(
            top: isFirst ? radius : Radius.zero,
            bottom: isLast ? radius : Radius.zero,
          ),
          border: Border(
            left: AppLines.cardSide,
            right: AppLines.cardSide,
            top: isFirst ? AppLines.cardSide : BorderSide.none,
            bottom: isLast ? AppLines.cardSide : BorderSide.none,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.space2,
            isFirst ? AppSpacing.space2 : 0,
            AppSpacing.space2,
            isLast ? AppSpacing.space2 : 0,
          ),
          child: !isFirst
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppRowDivider(indent: AppSpacing.space3),
                    child,
                  ],
                )
              : child,
        ),
      ),
    );
  }

  /// 꽉 찬 목록 — 카드 없이 화면 끝에서 끝까지. 줄 사이는 글자 시작에 맞춘 선,
  /// 묶음(고정/일반) 사이는 회색 띠로 나눈다.
  Widget _buildFullBleed() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isFirst) AppRowDivider(indent: dividerIndent, endIndent: 0),
        ColoredBox(
          color: AppSemanticColors.surfaceCard,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space1),
            child: child,
          ),
        ),
        if (gapAfter ?? isLast)
          const SizedBox(
            height: AppSpacing.space2,
            child: ColoredBox(color: AppSemanticColors.backgroundCanvas),
          ),
      ],
    );
  }
}
