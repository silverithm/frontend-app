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

/// 화면 위에 안내를 알림 카드로 잠깐 띄우는 자리(2026-11-15).
///
/// 예전엔 화면 맨 위에 안내 상자가 늘 붙어 공간만 차지했다(일정 탭은 안내 둘이면 달력이 반으로 줄었다).
/// 이제 [child] 위 빈 Overlay에 안내마다 카드 한 장씩 쌓여 내려온다 — 카드·애니메이션·밀어 닫기·
/// 남은 시간 막대는 toastification 라이브러리가 그린다.
///
/// - 8초 뒤 저절로 들어간다. 누르고 있으면 멈춘다. X·옆으로 밀면 그 카드만 닫힌다.
/// - X로 닫은 안내는 앱을 켜 둔 동안 같은 [noticeKey]에서 다시 띄우지 않는다.
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
  final List<ToastificationItem> _items = [];
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
          n,
    ];
    // 새 카드가 맨 위에 끼므로 뒤 안내부터 띄워야 첫 안내가 맨 위에 온다
    for (final n in open.reversed) {
      _items.add(_show(overlay, n, '${widget.noticeKey}|${n.title}'));
    }
  }

  void _hide() {
    _shownKey = null;
    for (final item in _items) {
      toastification.dismiss(item);
    }
    _items.clear();
  }

  ToastificationItem _show(OverlayState overlay, AppNotice n, String closeKey) {
    final description = n.description;
    return toastification.show(
      overlayState: overlay,
      alignment: Alignment.topCenter,
      style: ToastificationStyle.flat,
      autoCloseDuration: AppNoticeHost.visibleFor,
      showProgressBar: true,
      progressBarTheme: ProgressIndicatorThemeData(
        color: n.iconColor,
        linearTrackColor: n.background,
        linearMinHeight: 3,
      ),
      dragToClose: true,
      pauseOnHover: true,
      closeOnClick: false,
      applyBlurEffect: false,
      // 라이브러리 기본 X는 손가락 자리가 작고 화면 낭독 이름이 없다 — 40 칸 + '안내 닫기'
      closeButton: ToastCloseButton(
        showType: CloseButtonShowType.always,
        buttonBuilder: (context, onClose) => SizedBox(
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
      ),
      primaryColor: n.iconColor,
      backgroundColor: AppSemanticColors.surfaceCard,
      foregroundColor: AppSemanticColors.textPrimary,
      borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
      borderSide: const BorderSide(color: AppSemanticColors.borderDefault),
      boxShadow: AppShadows.floating,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space1,
      ),
      icon: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: n.background, shape: BoxShape.circle),
        child: Icon(n.icon, size: 18, color: n.iconColor),
      ),
      title: Text(
        n.title,
        style: AppTypography.titleSmall.copyWith(
          color: AppSemanticColors.textPrimary,
        ),
      ),
      description: description == null
          ? null
          : Text(
              description,
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textSecondary,
                height: 1.4,
              ),
            ),
      callbacks: ToastificationCallbacks(
        onCloseButtonTap: (item) {
          AppNoticeHost._closed.add(closeKey);
          _items.remove(item);
          toastification.dismiss(item);
        },
        onDismissed: (item) {
          // 옆으로 밀어 닫아도 X와 같이 본다
          AppNoticeHost._closed.add(closeKey);
          _items.remove(item);
        },
        onAutoCompleteCompleted: _items.remove,
      ),
    );
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
              maxToastLimit: 3,
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
