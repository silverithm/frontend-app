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

  /// 알림함을 채운다.
  ///
  /// [alsoUserId]는 같은 사람의 **다른 식별자**다. 관리자는 채팅·결재 상신·가입 요청·휴가
  /// 신청 알림이 채팅 규약(admin_<id>)으로 저장되고, 공지·회의록·휴가 결과는 원시 id로
  /// 저장된다. 한 쪽만 조회하면 나머지 절반이 통째로 안 보인다.
  Future<void> loadNotifications(String userId, {String? alsoUserId}) async {
    try {
      setLoading(true);
      clearError();

      final ids = <String>{userId, if (alsoUserId != null) alsoUserId};

      final merged = <String, NotificationItem>{};
      Object? lastError;

      for (final id in ids) {
        try {
          final response = await ApiService().getNotifications(userId: id);
          final list = response['notifications'];
          if (list is List) {
            for (final n in list) {
              final item = NotificationItem.fromJson(n as Map<String, dynamic>);
              merged[item.id] = item; // 같은 알림이 두 번 잡히면 하나로
            }
          }
        } catch (e) {
          // 한쪽 조회가 실패해도 다른 쪽 알림은 보여준다
          lastError = e;
        }
      }

      if (merged.isEmpty && lastError != null) {
        throw lastError;
      }

      _notifications = merged.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

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

  /// [alsoUserId]는 loadNotifications와 같은 이유 — 관리자는 식별자가 둘이라
  /// 한쪽만 읽음 처리하면 나머지가 안 읽음으로 남아 배지가 계속 켜져 있다.
  Future<void> markAllAsRead(String userId, {String? alsoUserId}) async {
    // 즉시 UI 업데이트
    for (var notification in _notifications) {
      notification.isUnread = false;
    }
    notifyListeners();

    // 백엔드 API 호출
    for (final id in <String>{userId, if (alsoUserId != null) alsoUserId}) {
      try {
        await ApiService().markAllNotificationsAsRead(userId: id);
      } catch (e) {
        print('[NotificationProvider] 전체 읽음 처리 API 실패: $e');
      }
    }
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String type; // 'vacation_approved', 'vacation_rejected', 'system'

  /// 이 알림이 가리키는 대상의 id — 채팅방, 공지, 회의록, 결재 문서 등.
  /// 서버가 relatedEntityId로 늘 함께 내려주는데 앱이 읽지 않아, 알림을 눌러도
  /// 그 대상까지 못 가고 목록에서 멈췄다(채팅 알림이 방이 아니라 목록으로 가던 이유).
  final int? relatedEntityId;

  /// 대상의 종류 — 일정 알림은 type이 `general`이라 이 값(schedule…)으로 갈 곳을 안다
  final String? relatedEntityType;

  /// 알림을 일으킨 사람 — 채팅식 번호('12' 직원, 'admin_3' 시설장). 서버 V1.111.0(2026-11-19)부터
  /// 내려온다. 그 전에 생긴 알림은 비어 있어 [actorName]으로 글에서 이름을 읽는다.
  final String? actorId;

  final DateTime createdAt;
  bool isUnread;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.relatedEntityId,
    this.relatedEntityType,
    this.actorId,
    this.isUnread = true,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'system',
      relatedEntityId: int.tryParse(json['relatedEntityId']?.toString() ?? ''),
      relatedEntityType: json['relatedEntityType']?.toString(),
      actorId: () {
        final raw = json['actorId']?.toString().trim() ?? '';
        return raw.isEmpty ? null : raw;
      }(),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      isUnread: !(json['isRead'] ?? false),
    );
  }

  // 이름(직책) — 웹 notificationActor.ts와 같은 규칙. 한글·영문으로 시작, 20자 안쪽.
  static const String _namePattern =
      r'([가-힣A-Za-z][가-힣A-Za-z ·]{0,18}?)\s*(?:\([^)]{1,20}\))?';
  static final RegExp _chatSender = RegExp('^\\s*$_namePattern\\s*\$');
  static final RegExp _sentenceSubject = RegExp(
    '^\\s*$_namePattern\\s*님(?:이|의|께서)\\s',
  );

  /// 알림을 일으킨 사람 이름 — 사진 찾기용. 채팅은 제목이 보낸 사람, 휴무 신청·결재·업무·회의록은
  /// 글이 "한희정(조리원)님이 …"로 시작한다. 가입 요청은 아직 직원이 아니라 찾지 않는다.
  String? get actorName {
    final kind = type.toLowerCase();
    RegExpMatch? match;
    if (kind == 'chat') {
      match = _chatSender.firstMatch(title);
    } else if (kind == 'vacation_submitted' ||
        kind == 'approval' ||
        kind == 'work_task' ||
        kind == 'meeting_minutes') {
      match = _sentenceSubject.firstMatch(message);
    }
    final name = match?.group(1)?.trim();
    return (name == null || name.isEmpty) ? null : name;
  }

  /// 알림 종류마다 아이콘·색 — 예전에는 휴무 승인·반려 말고는 모두 회색 종이었다
  IconData get icon {
    switch (type) {
      case 'vacation_approved':
        return Icons.check_circle;
      case 'vacation_rejected':
        return Icons.cancel;
      case 'system':
        return Icons.info;
      case 'chat':
        return Icons.chat_bubble_outline_rounded;
      case 'approval':
        return Icons.fact_check_outlined;
      case 'work_task':
        return Icons.checklist_rounded;
      case 'notice':
        return Icons.campaign_outlined;
      case 'meeting_minutes':
        return Icons.edit_note_rounded;
    }
    if (type.startsWith('vacation')) return Icons.beach_access_outlined;
    if (type.startsWith('member_join')) return Icons.person_add_alt_1_outlined;
    if (relatedEntityType?.startsWith('schedule') ?? false) {
      return Icons.event_outlined;
    }
    return Icons.notifications;
  }

  /// 알림 머리 아이콘 색 — 색은 상태에만 쓴다(웹 DESIGN.md '색은 상태만').
  /// 휴무 승인·거절만 결과(상태)라 초록·빨강이고, 나머지 종류는 모두 기본 틸이다 —
  /// 예전에는 업무=노랑·일정=파랑처럼 종류마다 색을 돌려 써서 대기(노랑)·정보(파랑)와 섞였다.
  Color get color {
    switch (type) {
      case 'vacation_approved':
        return AppSemanticColors.statusSuccessIcon;
      case 'vacation_rejected':
        return AppSemanticColors.statusErrorIcon;
    }
    return AppSemanticColors.brandDefault;
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
