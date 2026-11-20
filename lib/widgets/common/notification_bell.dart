import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../services/fcm_service.dart';
import '../../services/member_directory.dart';
import 'app_empty_state.dart';
import 'app_sheet_frame.dart';
import 'app_skeleton.dart';
import 'app_tag.dart';
import 'member_avatar.dart';

class NotificationBell extends StatelessWidget {
  final Color? iconColor;

  const NotificationBell({super.key, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final bool onDark = iconColor != null;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space1, right: AppSpacing.space1),
      child: SizedBox(
        width: AppSpacing.space10,
        height: AppSpacing.space10,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: AppSpacing.space10,
              height: AppSpacing.space10,
            decoration: BoxDecoration(
              color: onDark ? AppColors.transparent : AppSemanticColors.surfaceDefault,
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              border: onDark ? null : Border.all(
                color: AppSemanticColors.borderDefault,
                width: 1,
              ),
            ),
            child: IconButton(
              tooltip: '알림',
              icon: Icon(
                Icons.notifications_outlined,
                color: iconColor ?? AppSemanticColors.textSecondary,
                size: 20,
              ),
              onPressed: () => _showNotificationsSheet(context),
              padding: EdgeInsets.zero,
            ),
          ),
          // 알림 뱃지
          Positioned(
            top: -2,
            right: -2,
            child: Consumer<NotificationProvider>(
              builder: (context, notificationProvider, child) {
                final unreadCount = notificationProvider.unreadCount;
                if (unreadCount == 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.space0_5),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.statusErrorIcon,
                    borderRadius: BorderRadius.circular(AppBorderRadius.full),
                    // 화면에 고정 부착된 장식 뱃지(FAB/다이얼로그/시트가 아님) — 그림자 대신 보더로만 구분
                    border: Border.all(
                      color: AppSemanticColors.textInverse,
                      width: 1.5,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: AppTag.labelStyle.copyWith(
                      color: AppSemanticColors.textInverse,
                      letterSpacing: 0,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final notificationProvider = context.read<NotificationProvider>();
    // 열기 전에 안 읽은 알림을 적어 둔다 — 열자마자 모두 읽음으로 바뀌어도
    // 이번에 처음 보는 알림은 '새 알림'으로 눈에 띄게 보여 준다.
    final newIds = {
      for (final n in notificationProvider.notifications)
        if (n.isUnread) n.id,
    };
    if (authProvider.currentUser != null) {
      final userId = authProvider.currentUser!.id.toString();
      // 관리자는 알림이 두 식별자(원시 id, admin_<id>)로 나뉘어 저장된다 — 둘 다 봐야 한다
      final chatUserId = authProvider.currentUser!.chatUserId;
      // 즉시 모두 읽음 처리 (UI 배지 즉시 사라짐)
      notificationProvider.markAllAsRead(userId, alsoUserId: chatUserId).then((_) {
        // API 완료 후 알림 목록 새로고침
        notificationProvider.loadNotifications(userId, alsoUserId: chatUserId);
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (sheetContext) => NotificationSheet(newIds: newIds),
    );
  }
}

/// 알림함 시트(2026-11-20 새 모양).
///
/// 예전엔 테두리 상자를 줄줄이 쌓고 글을 통째로 펼쳐 '대충 만든 목록'처럼 보였다.
/// 이제 알림을 일으킨 사람 얼굴(+ 종류 표시) · 제목 · 두 줄 요약 · 시간을 한 줄 묶음으로 두고,
/// 오늘·어제·이번 주·이전으로 나눈다. 이번에 처음 보는 알림은 옅은 틸 바탕과 점으로 표시한다.
@visibleForTesting
class NotificationSheet extends StatelessWidget {
  const NotificationSheet({super.key, this.newIds = const {}, this.now});

  /// 시트를 열 때 안 읽음이던 알림 id — 열자마자 모두 읽음이 되므로 미리 받아 둔다.
  final Set<String> newIds;

  /// 날짜 묶음 기준 시각(테스트용). 없으면 지금.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
      decoration: const BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppBorderRadius.xl3),
          topRight: Radius.circular(AppBorderRadius.xl3),
        ),
      ),
      child: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          final items = provider.notifications;
          final newCount = items.where((n) => newIds.contains(n.id)).length;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.space2_5),
              const Center(child: AppSheetHandle()),
              _SheetHeader(newCount: newCount),
              Flexible(child: _buildBody(context, provider, items, media)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    NotificationProvider provider,
    List<NotificationItem> items,
    MediaQueryData media,
  ) {
    // 목록이 이미 있으면 다시 받는 동안에도 그대로 둔다 — 열 때마다 목록이 뼈대로 깜빡이지 않게
    if (items.isEmpty && provider.isLoading) {
      return AppSkeleton(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 5; i++)
                const AppSkeletonListTile(
                  leadingSize: _NotificationRow.faceSize,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.space5,
                    vertical: AppSpacing.space3,
                  ),
                  titleWidthFactor: 0.55,
                  subtitleWidthFactor: 0.85,
                ),
            ],
          ),
        ),
      );
    }

    if (items.isEmpty && provider.errorMessage.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.space8),
        child: AppEmptyState(
          icon: Icons.error_outline,
          title: provider.errorMessage,
          topSpacing: AppSpacing.space8,
        ),
      );
    }

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.space8),
        child: AppEmptyState(
          icon: Icons.notifications_off_outlined,
          title: '알림이 없습니다',
          topSpacing: AppSpacing.space8,
        ),
      );
    }

    final sections = groupNotificationsByDay(items, now ?? DateTime.now());
    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.only(bottom: AppSpacing.space4 + media.padding.bottom),
      children: [
        for (final section in sections) ...[
          _SectionLabel(section.label),
          for (final n in section.items)
            _NotificationRow(
              notification: n,
              isNew: newIds.contains(n.id),
              onTap: () {
                if (n.isUnread) provider.markAsRead(n.id);
                _navigateByType(
                  context,
                  n.type,
                  n.relatedEntityId,
                  relatedEntityType: n.relatedEntityType,
                );
              },
            ),
        ],
      ],
    );
  }

  /// 알림 유형별 딥링크.
  ///
  /// 화면 선택 규칙은 **푸시 탭과 같은 함수**(screenForNotification)를 쓴다. 예전에는
  /// 여기에 따로 적힌 표가 있었고 그게 뒤처져 있었다 — 채팅 알림을 눌러도 방이 아니라
  /// 목록에서 멈추고, 회의록·가입요청·일정 알림은 아무 일도 일어나지 않았다.
  ///
  /// [entityId]는 서버가 준 relatedEntityId다(채팅방·공지·회의록·결재 문서·업무 id).
  /// 일정 알림은 type이 `general`이라 [relatedEntityType]으로 갈 곳을 안다.
  void _navigateByType(
    BuildContext context,
    String type,
    int? entityId, {
    String? relatedEntityType,
  }) {
    final target = screenForNotification(
      resolveFCMDestination(type, relatedEntityType: relatedEntityType),
      entityId: entityId,
    );
    if (target == null) return; // system 등 — 이동할 곳 없음

    Navigator.of(context).pop(); // 알림 바텀시트 닫기
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => target),
    );
  }
}

/// 날짜 묶음 하나 — '오늘'·'어제'·'이번 주'·'이전'.
class NotificationSection {
  const NotificationSection(this.label, this.items);
  final String label;
  final List<NotificationItem> items;
}

/// 알림을 날짜 묶음으로 나눈다(받은 순서 그대로, 빈 묶음은 뺀다).
/// 이번 주 = 어제보다 앞이면서 7일 안.
@visibleForTesting
List<NotificationSection> groupNotificationsByDay(
  List<NotificationItem> items,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekAgo = today.subtract(const Duration(days: 6));
  final buckets = <String, List<NotificationItem>>{
    '오늘': [],
    '어제': [],
    '이번 주': [],
    '이전': [],
  };
  for (final n in items) {
    final local = n.createdAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final key = !day.isBefore(today)
        ? '오늘'
        : !day.isBefore(yesterday)
        ? '어제'
        : !day.isBefore(weekAgo)
        ? '이번 주'
        : '이전';
    buckets[key]!.add(n);
  }
  return [
    for (final e in buckets.entries)
      if (e.value.isNotEmpty) NotificationSection(e.key, e.value),
  ];
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.newCount});
  final int newCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space5,
        AppSpacing.space3,
        AppSpacing.space2,
        AppSpacing.space1,
      ),
      child: Row(
        children: [
          Text(
            '알림',
            style: AppTypography.heading5.copyWith(
              color: AppSemanticColors.textPrimary,
            ),
          ),
          if (newCount > 0) ...[
            const SizedBox(width: AppSpacing.space2),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space2,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppSemanticColors.brandWeak,
                borderRadius: BorderRadius.circular(AppBorderRadius.full),
              ),
              child: Text(
                '새 알림 $newCount',
                style: AppTypography.labelMedium.copyWith(
                  color: AppSemanticColors.brandWeakForeground,
                ),
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            tooltip: '닫기',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.close_rounded,
              size: 24,
              color: AppSemanticColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space5,
        AppSpacing.space4,
        AppSpacing.space5,
        AppSpacing.space1,
      ),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: AppSemanticColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// 알림 한 줄 — 얼굴(+ 종류 표시) · 제목 · 시간 · 두 줄 요약.
class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.isNew,
    required this.onTap,
  });

  static const double faceSize = 44;

  final NotificationItem notification;
  final bool isNew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return Material(
      color: isNew
          ? AppSemanticColors.brandWeak.withValues(alpha: 0.55)
          : AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space5,
            vertical: AppSpacing.space3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ActorFace(notification: n, size: faceSize),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleSmall.copyWith(
                              color: AppSemanticColors.textPrimary,
                              fontWeight: isNew
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.space2),
                        Text(
                          n.timeAgo,
                          style: AppTypography.caption.copyWith(
                            color: isNew
                                ? AppSemanticColors.brandDefault
                                : AppSemanticColors.textTertiary,
                          ),
                        ),
                        if (isNew) ...[
                          const SizedBox(width: AppSpacing.space1_5),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppSemanticColors.brandDefault,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      n.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppSemanticColors.textSecondary,
                        height: 1.45,
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

/// 알림을 일으킨 사람 얼굴 + 오른쪽 아래 종류 표시. 명단에서 못 찾으면 종류 아이콘 동그라미.
class _ActorFace extends StatelessWidget {
  const _ActorFace({required this.notification, required this.size});

  final NotificationItem notification;
  final double size;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final directory = MemberDirectory.instance;
    return ListenableBuilder(
      listenable: directory,
      builder: (context, _) {
        final ref = PersonRef.parse(n.actorId);
        final actorName = n.actorName;
        final person = (ref.memberId == null &&
                ref.adminId == null &&
                actorName == null)
            ? null
            : directory.find(
                memberId: ref.memberId,
                adminId: ref.adminId,
                name: actorName,
              );
        // 직원 명단에서 찾은 사람만 얼굴로 — 단체방 이름 같은 글을 사람으로 그리지 않는다
        if (person == null) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: n.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(n.icon, color: n.color, size: 22),
          );
        }
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              MemberAvatar(
                name: person.name,
                memberId: ref.memberId,
                adminId: ref.adminId,
                imageUrl: person.imageUrl,
                size: size,
              ),
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      n.color.withValues(alpha: 0.16),
                      AppSemanticColors.surfaceDefault,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppSemanticColors.surfaceDefault,
                      width: 2,
                    ),
                  ),
                  child: Icon(n.icon, color: n.color, size: 11),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
