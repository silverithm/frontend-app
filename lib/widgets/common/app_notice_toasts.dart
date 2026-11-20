import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'main_tab_visibility.dart';

/// 안내 한 건 — 아이콘·옅은 바탕색·제목·설명. 고정 상자(VacationPlanningBanner 등)와
/// 잠깐 뜨는 알림 카드([AppNoticeHost])가 같은 값을 쓴다.
class AppNotice {
  const AppNotice({
    required this.icon,
    required this.background,
    required this.iconColor,
    required this.title,
    this.description,
  });

  /// 정보(파랑) — 쓰는 법·안내
  const AppNotice.info({required this.title, this.description})
    : icon = Icons.info_outline_rounded,
      background = AppSemanticColors.statusInfoBackground,
      iconColor = AppSemanticColors.statusInfoIcon;

  /// 주의(노랑) — 할 일이 남았을 때
  const AppNotice.warning({required this.title, this.description})
    : icon = Icons.error_outline_rounded,
      background = AppSemanticColors.statusWarningBackground,
      iconColor = AppSemanticColors.statusWarningIcon;

  final IconData icon;
  final Color background;
  final Color iconColor;
  final String title;
  final String? description;
}

/// 화면 위에 안내를 알림 카드로 잠깐 띄우는 자리(2026-11-15, 겹쳐 쌓기 2026-11-20).
///
/// 예전엔 화면 맨 위에 안내 상자가 늘 붙어 공간만 차지했다(일정 탭은 안내 둘이면 달력이 반으로 줄었다).
/// 11/15엔 안내마다 카드가 한 장씩 위아래로 늘어서 둘이면 여전히 화면을 크게 가렸다.
/// 이제 웹 오른쪽 위 알림처럼 **겹쳐 쌓는다** — 맨 앞 카드 한 장만 보이고 뒤 카드는 아래로
/// 살짝 비친다. 카드를 누르면 펼쳐 모두 보이고, 다시 누르면 접힌다.
/// 띄우기·들어가기 움직임·남은 시간은 toastification 라이브러리가 맡는다(더미 한 묶음이 알림 하나).
///
/// - 8초 뒤 저절로 들어간다. 누르고 있거나 펼쳐 둔 동안은 멈춘다.
/// - X는 그 카드만 닫는다. 더미를 옆으로 밀면 모두 닫힌다.
/// - X(또는 밀기)로 닫은 안내는 앱을 켜 둔 동안 같은 [noticeKey]에서 다시 띄우지 않는다.
///   8초 만에 들어간 안내는 다음에 이 화면(이 [noticeKey])을 열 때 다시 뜬다.
/// - [visible]이 false이거나 하단 탭에서 가려져 있으면([MainTabVisibility]) 걷는다.
/// - [noticeKey]나 안내 글이 바뀌면(보는 달이 바뀌는 등) 다시 띄운다.
class AppNoticeHost extends StatefulWidget {
  const AppNoticeHost({
    super.key,
    required this.noticeKey,
    required this.notices,
    required this.child,
    this.visible = true,
  });

  final String noticeKey;
  final List<AppNotice> notices;
  final bool visible;
  final Widget child;

  static const Duration visibleFor = Duration(seconds: 8);

  /// X로 닫은 안내 — 'noticeKey|제목'
  static final Set<String> _closed = {};

  @visibleForTesting
  static void resetClosed() => _closed.clear();

  @override
  State<AppNoticeHost> createState() => _AppNoticeHostState();
}

class _AppNoticeHostState extends State<AppNoticeHost> {
  final GlobalKey<OverlayState> _overlayKey = GlobalKey<OverlayState>();
  ToastificationItem? _item;
  String? _shownKey;
  bool _syncScheduled = false;

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  /// 그리는 중에는 Overlay에 넣을 수 없다 — 이번 장면이 끝난 뒤 맞춘다.
  void _scheduleSync(bool tabVisible) {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted) return;
      _sync(widget.visible && tabVisible);
    });
  }

  void _sync(bool visible) {
    final overlay = _overlayKey.currentState;
    if (!visible || overlay == null || !overlay.mounted) {
      _hide();
      return;
    }
    final key =
        '${widget.noticeKey}|${widget.notices.map((n) => n.title).join('|')}';
    if (key == _shownKey) return;
    _hide();
    _shownKey = key;
    final open = [
      for (final n in widget.notices)
        if (!AppNoticeHost._closed.contains('${widget.noticeKey}|${n.title}'))
          _DeckEntry(n, '${widget.noticeKey}|${n.title}'),
    ];
    if (open.isEmpty) return;
    _item = toastification.showCustom(
      overlayState: overlay,
      alignment: Alignment.topCenter,
      autoCloseDuration: AppNoticeHost.visibleFor,
      callbacks: ToastificationCallbacks(
        onAutoCompleteCompleted: (_) => _item = null,
      ),
      builder: (context, item) => _NoticeDeck(
        item: item,
        entries: open,
        onClose: AppNoticeHost._closed.add,
        onEmpty: () {
          if (_item == item) _item = null;
        },
      ),
    );
  }

  void _hide() {
    _shownKey = null;
    final item = _item;
    _item = null;
    if (item != null) toastification.dismiss(item);
  }

  @override
  Widget build(BuildContext context) {
    _scheduleSync(MainTabVisibility.of(context));
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: ToastificationConfigProvider(
            config: ToastificationConfig(
              alignment: Alignment.topCenter,
              // 화면(내용) 맨 위 바로 아래에서 시작(라이브러리 기본은 12)
              marginBuilder: (context, alignment) =>
                  const EdgeInsets.only(top: AppSpacing.space1),
              animationDuration: const Duration(milliseconds: 450),
            ),
            // 상태 표시줄 높이는 위 띠·상단 바가 이미 받았다 — 여기서 또 띄우지 않게 뺀다
            child: MediaQuery.removeViewPadding(
              context: context,
              removeTop: true,
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                // 빈 곳은 손가락을 통과시켜 아래 화면을 그대로 누를 수 있다
                child: Overlay(key: _overlayKey),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 더미 안 카드 한 장 — 안내와, X로 닫았을 때 기억할 열쇠.
class _DeckEntry {
  const _DeckEntry(this.notice, this.closeKey);
  final AppNotice notice;
  final String closeKey;
}

/// 겹쳐 쌓인 안내 더미. 접히면 맨 앞 카드 + 뒤 카드 두 장까지 아래로 비치는 종이,
/// 펼치면 카드가 위아래로 늘어선다.
class _NoticeDeck extends StatefulWidget {
  const _NoticeDeck({
    required this.item,
    required this.entries,
    required this.onClose,
    required this.onEmpty,
  });

  final ToastificationItem item;
  final List<_DeckEntry> entries;

  /// X·밀기로 닫은 안내의 열쇠를 넘긴다(다시 띄우지 않게).
  final void Function(String closeKey) onClose;

  /// 마지막 카드까지 닫혔을 때.
  final VoidCallback onEmpty;

  /// 뒤 카드가 앞 카드 아래로 비치는 높이(한 장마다)
  static const double peek = 8;

  @override
  State<_NoticeDeck> createState() => _NoticeDeckState();
}

class _NoticeDeckState extends State<_NoticeDeck> {
  late final List<_DeckEntry> _entries = [...widget.entries];
  bool _expanded = false;
  double _dragProgress = 0;

  void _toggle() {
    if (_entries.length < 2) return;
    setState(() => _expanded = !_expanded);
    // 펼쳐 읽는 동안은 저절로 들어가지 않는다
    if (widget.item.hasTimer) {
      _expanded ? widget.item.pause() : widget.item.start();
    }
  }

  void _closeOne(_DeckEntry entry) {
    widget.onClose(entry.closeKey);
    if (_entries.length == 1) {
      widget.onEmpty();
      toastification.dismiss(widget.item);
      return;
    }
    setState(() {
      _entries.remove(entry);
      if (_entries.length < 2) _expanded = false;
    });
    // 펼침이 풀렸으면 멈춰 둔 시간을 다시 흐르게 한다
    if (!_expanded && widget.item.hasTimer) widget.item.start();
  }

  void _closeAll() {
    for (final e in _entries) {
      widget.onClose(e.closeKey);
    }
    widget.onEmpty();
    toastification.dismiss(widget.item, showRemoveAnimation: false);
  }

  void _holdTimer(bool down) {
    if (!widget.item.hasTimer) return;
    if (down) {
      widget.item.pause();
    } else if (!_expanded) {
      widget.item.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _entries.length;
    final behind = (count - 1).clamp(0, 2);
    final Widget body;
    if (_expanded) {
      body = Column(
        key: const ValueKey('expanded'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.space2),
            _NoticeCard(
              entry: _entries[i],
              item: i == 0 ? widget.item : null,
              onTap: _toggle,
              onClose: () => _closeOne(_entries[i]),
            ),
          ],
        ],
      );
    } else {
      body = Padding(
        key: const ValueKey('collapsed'),
        padding: EdgeInsets.only(bottom: _NoticeDeck.peek * behind),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 뒤 카드 — 글 없이 종이만, 한 장마다 8씩 내려가고 5%씩 작아진다(웹 알림 더미와 같은 모양)
            for (var k = behind; k >= 1; k--)
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(0, _NoticeDeck.peek * k),
                  child: Transform.scale(
                    scale: 1 - 0.05 * k,
                    alignment: Alignment.bottomCenter,
                    child: const _BackPaper(),
                  ),
                ),
              ),
            _NoticeCard(
              entry: _entries.first,
              item: widget.item,
              moreCount: count - 1,
              onTap: _toggle,
              onClose: () => _closeOne(_entries.first),
            ),
          ],
        ),
      );
    }

    return Listener(
      onPointerDown: (_) => _holdTimer(true),
      onPointerUp: (_) => _holdTimer(false),
      onPointerCancel: (_) => _holdTimer(false),
      child: Dismissible(
        key: ValueKey('notice-deck-${widget.item.id}'),
        direction: DismissDirection.horizontal,
        behavior: HitTestBehavior.deferToChild,
        onUpdate: (d) => setState(() => _dragProgress = d.progress),
        onDismissed: (_) => _closeAll(),
        child: Opacity(
          opacity: (1 - _dragProgress).clamp(0.0, 1.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space3,
              vertical: AppSpacing.space1,
            ),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, ?current],
                ),
                child: body,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 접힌 더미 뒤에 비치는 카드 종이 — 앞 카드보다 한 단 어둡게 해 흰 화면에서도 겹친 줄이 보인다.
class _BackPaper extends StatelessWidget {
  const _BackPaper();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppSemanticColors.backgroundTertiary,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
        border: Border.all(color: AppSemanticColors.borderDefault),
        boxShadow: AppShadows.floating,
      ),
    );
  }
}

/// 안내 카드 한 장 — 아이콘 · 제목 · 설명 · X. 맨 앞 카드는 아래에 남은 시간 막대.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.entry,
    required this.onTap,
    required this.onClose,
    this.item,
    this.moreCount = 0,
  });

  final _DeckEntry entry;
  final VoidCallback onTap;
  final VoidCallback onClose;

  /// 남은 시간 막대를 그릴 때만 — 맨 앞(첫) 카드
  final ToastificationItem? item;

  /// 접힌 더미에서 뒤에 숨은 카드 수 — '+1' 표시
  final int moreCount;

  @override
  Widget build(BuildContext context) {
    final n = entry.notice;
    final description = n.description;
    final item = this.item;
    return Semantics(
      container: true,
      liveRegion: true,
      button: moreCount > 0,
      hint: moreCount > 0 ? '안내 ${moreCount + 1}개 — 눌러서 모두 보기' : null,
      // 그림자는 바깥 상자에 — Material이 모서리를 자르면 그림자까지 잘린다
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
          boxShadow: AppShadows.floating,
        ),
        child: Material(
          color: AppSemanticColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
                border: Border.all(color: AppSemanticColors.borderDefault),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.space4,
                      AppSpacing.space3,
                      AppSpacing.space1,
                      AppSpacing.space3,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: n.background,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(n.icon, size: 18, color: n.iconColor),
                        ),
                        const SizedBox(width: AppSpacing.space3),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n.title,
                                  style: AppTypography.titleSmall.copyWith(
                                    color: AppSemanticColors.textPrimary,
                                  ),
                                ),
                                if (description != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    description,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppSemanticColors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (moreCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 7,
                              left: AppSpacing.space1,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.space2,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppSemanticColors.backgroundTertiary,
                                borderRadius: BorderRadius.circular(
                                  AppBorderRadius.full,
                                ),
                              ),
                              child: Text(
                                '+$moreCount',
                                style: AppTypography.labelMedium.copyWith(
                                  color: AppSemanticColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        // 손가락 자리 40 + 화면 낭독 이름 '안내 닫기'
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: IconButton(
                            tooltip: '안내 닫기',
                            padding: EdgeInsets.zero,
                            onPressed: onClose,
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: AppSemanticColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item != null && item.hasTimer)
                    ToastTimerAnimationBuilder(
                      item: item,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 3,
                        color: n.iconColor,
                        backgroundColor: n.background,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
