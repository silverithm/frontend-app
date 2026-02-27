import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 4),
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
              color: AppSemanticColors.surfaceDefault,
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              border: Border.all(
                color: AppSemanticColors.borderDefault,
                width: 1,
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.notifications_outlined,
                color: AppSemanticColors.textSecondary,
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
                    border: Border.all(
                      color: AppSemanticColors.textInverse,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.red300.withValues(alpha: 0.5),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: AppTypography.overline.copyWith(
                      color: AppSemanticColors.textInverse,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
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
    // 알림 데이터 로드
    final authProvider = context.read<AuthProvider>();
    final notificationProvider = context.read<NotificationProvider>();
    if (authProvider.currentUser != null) {
      notificationProvider.loadNotifications(authProvider.currentUser!.id.toString());
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (sheetContext) => const _NotificationBottomSheet(),
    );
  }
}

class _NotificationBottomSheet extends StatelessWidget {
  const _NotificationBottomSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppBorderRadius.xl3),
          topRight: Radius.circular(AppBorderRadius.xl3),
        ),
      ),
      child: Column(
        children: [
          // 핸들 바
          Container(
            width: AppSpacing.space10,
            height: AppSpacing.space1,
            margin: const EdgeInsets.symmetric(
              vertical: AppSpacing.space3,
            ),
            decoration: BoxDecoration(
              color: AppSemanticColors.borderSubtle,
              borderRadius: BorderRadius.circular(AppBorderRadius.sm),
            ),
          ),
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space6,
              vertical: AppSpacing.space4,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppSemanticColors.borderDefault,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.space2),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.statusInfoBackground,
                        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                      ),
                      child: Icon(
                        Icons.notifications,
                        color: AppSemanticColors.statusInfoIcon,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space3),
                    Text(
                      '알림',
                      style: AppTypography.heading5.copyWith(
                        color: AppSemanticColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                shadcn.GhostButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '닫기',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppSemanticColors.textSecondary,
                      fontWeight: AppTypography.fontWeightSemibold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 알림 목록
          Expanded(
            child: Consumer<NotificationProvider>(
              builder: (context, notificationProvider, child) {
                if (notificationProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (notificationProvider.errorMessage.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppSemanticColors.statusErrorBorder,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          notificationProvider.errorMessage,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppSemanticColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (notificationProvider.notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 48,
                          color: AppSemanticColors.borderSubtle,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '알림이 없습니다',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppSemanticColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notificationProvider.notifications.length,
                  itemBuilder: (context, index) {
                    final notification =
                        notificationProvider.notifications[index];
                    return _buildNotificationItem(
                      context,
                      notificationProvider,
                      notification.title,
                      notification.message,
                      notification.icon,
                      notification.color,
                      notification.timeAgo,
                      notification.isUnread,
                      onTap: () {
                        if (notification.isUnread) {
                          notificationProvider.markAsRead(notification.id);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    NotificationProvider notificationProvider,
    String title,
    String message,
    IconData icon,
    Color color,
    String time,
    bool isUnread, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnread
              ? color.withValues(alpha: 0.05)
              : AppSemanticColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread
                ? color.withValues(alpha: 0.2)
                : AppSemanticColors.borderDefault,
            width: 1,
          ),
          boxShadow: isUnread
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppSemanticColors.textPrimary,
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppSemanticColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    time,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppSemanticColors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
