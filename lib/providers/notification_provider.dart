import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';

class NotificationProvider with ChangeNotifier {
  List<NotificationItem> _notifications = [];
  bool _isLoading = false;
  String _errorMessage = '';

  List<NotificationItem> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  int get unreadCount => _notifications.where((n) => n.isUnread).length;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  Future<void> loadNotifications(String userId) async {
    try {
      setLoading(true);
      clearError();

      final response = await ApiService().getNotifications(userId: userId);

      if (response['notifications'] != null) {
        final List<dynamic> notificationsList = response['notifications'];
        _notifications = notificationsList
            .map((n) => NotificationItem.fromJson(n))
            .toList();
      } else {
        _notifications = [];
      }

      notifyListeners();
    } catch (e) {
      setError('알림을 불러올 수 없습니다: $e');
      _notifications = [];
      notifyListeners();
    } finally {
      setLoading(false);
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1) return;

    // 즉시 UI 업데이트
    _notifications[index].isUnread = false;
    notifyListeners();

    // 백엔드 API 호출
    try {
      await ApiService().markNotificationAsRead(notificationId: notificationId);
    } catch (e) {
      print('[NotificationProvider] 읽음 처리 API 실패: $e');
    }
  }

  Future<void> markAllAsRead(String userId) async {
    // 즉시 UI 업데이트
    for (var notification in _notifications) {
      notification.isUnread = false;
    }
    notifyListeners();

    // 백엔드 API 호출
    try {
      await ApiService().markAllNotificationsAsRead(userId: userId);
    } catch (e) {
      print('[NotificationProvider] 전체 읽음 처리 API 실패: $e');
    }
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String type; // 'vacation_approved', 'vacation_rejected', 'system'
  final DateTime createdAt;
  bool isUnread;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isUnread = true,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'system',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      isUnread: !(json['isRead'] ?? false),
    );
  }

  IconData get icon {
    switch (type) {
      case 'vacation_approved':
        return Icons.check_circle;
      case 'vacation_rejected':
        return Icons.cancel;
      case 'system':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  Color get color {
    switch (type) {
      case 'vacation_approved':
        return AppSemanticColors.statusSuccessIcon;
      case 'vacation_rejected':
        return AppSemanticColors.statusErrorIcon;
      case 'system':
        return AppSemanticColors.statusInfoIcon;
      default:
        return AppSemanticColors.textDisabled;
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }
}
