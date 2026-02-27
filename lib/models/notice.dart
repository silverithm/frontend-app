enum NoticePriority { high, normal, low }

enum NoticeStatus { draft, published, archived }

// 공지사항 첨부파일
class NoticeAttachment {
  final int id;
  final int noticeId;
  final String fileName;
  final String fileUrl;
  final int fileSize;
  final String? fileType;
  final DateTime createdAt;

  NoticeAttachment({
    required this.id,
    required this.noticeId,
    required this.fileName,
    required this.fileUrl,
    required this.fileSize,
    this.fileType,
    required this.createdAt,
  });

  factory NoticeAttachment.fromJson(Map<String, dynamic> json) {
    return NoticeAttachment(
      id: json['id'] as int? ?? 0,
      noticeId: json['noticeId'] as int? ?? 0,
      fileName: json['fileName']?.toString() ?? json['name']?.toString() ?? '',
      fileUrl: json['fileUrl']?.toString() ?? json['url']?.toString() ?? '',
      fileSize: json['fileSize'] as int? ?? json['size'] as int? ?? 0,
      fileType: json['fileType']?.toString() ?? json['type']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'noticeId': noticeId,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileSize': fileSize,
      'fileType': fileType,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  bool get isImage {
    final ext = fileName.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.gif') ||
        ext.endsWith('.webp');
  }

  String get fileSizeText {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}

// 공지사항 댓글
class NoticeComment {
  final int id;
  final int noticeId;
  final String authorId;
  final String authorName;
  final String content;
  final DateTime createdAt;

  NoticeComment({
    required this.id,
    required this.noticeId,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdAt,
  });

  factory NoticeComment.fromJson(Map<String, dynamic> json) {
    return NoticeComment(
      id: json['id'] as int? ?? 0,
      noticeId: json['noticeId'] as int? ?? 0,
      authorId: json['authorId']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'noticeId': noticeId,
      'authorId': authorId,
      'authorName': authorName,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

// 공지사항 읽음 확인
class NoticeReader {
  final int id;
  final int noticeId;
  final String userId;
  final String userName;
  final DateTime readAt;

  NoticeReader({
    required this.id,
    required this.noticeId,
    required this.userId,
    required this.userName,
    required this.readAt,
  });

  factory NoticeReader.fromJson(Map<String, dynamic> json) {
    return NoticeReader(
      id: json['id'] as int? ?? 0,
      noticeId: json['noticeId'] as int? ?? 0,
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      readAt: DateTime.tryParse(json['readAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'noticeId': noticeId,
      'userId': userId,
      'userName': userName,
      'readAt': readAt.toIso8601String(),
    };
  }
}

class Notice {
  final int id;
  final String title;
  final String content;
  final NoticePriority priority;
  final NoticeStatus status;
  final bool isPinned;
  final String authorId;
  final String authorName;
  final int companyId;
  final int viewCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;
  final List<NoticeAttachment> attachments;

  Notice({
    required this.id,
    required this.title,
    required this.content,
    this.priority = NoticePriority.normal,
    this.status = NoticeStatus.draft,
    this.isPinned = false,
    required this.authorId,
    required this.authorName,
    required this.companyId,
    this.viewCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.publishedAt,
    this.attachments = const [],
  });

  factory Notice.fromJson(Map<String, dynamic> json) {
    List<NoticeAttachment> attachments = [];
    if (json['attachments'] != null) {
      attachments = (json['attachments'] as List<dynamic>)
          .map((e) => NoticeAttachment.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json['files'] != null) {
      attachments = (json['files'] as List<dynamic>)
          .map((e) => NoticeAttachment.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return Notice(
      id: json['id'] as int? ?? 0,
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      priority: _parsePriority(json['priority']?.toString()),
      status: _parseStatus(json['status']?.toString()),
      isPinned: json['isPinned'] as bool? ?? json['pinned'] as bool? ?? false,
      authorId: json['authorId']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? '',
      companyId: json['companyId'] as int? ?? 0,
      viewCount: json['viewCount'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'].toString())
          : null,
      attachments: attachments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'priority': priority.name.toUpperCase(),
      'status': status.name.toUpperCase(),
      'isPinned': isPinned,
      'authorId': authorId,
      'authorName': authorName,
      'companyId': companyId,
      'viewCount': viewCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'publishedAt': publishedAt?.toIso8601String(),
      'attachments': attachments.map((e) => e.toJson()).toList(),
    };
  }

  static NoticePriority _parsePriority(String? priority) {
    switch (priority?.toUpperCase()) {
      case 'HIGH':
        return NoticePriority.high;
      case 'LOW':
        return NoticePriority.low;
      case 'NORMAL':
      default:
        return NoticePriority.normal;
    }
  }

  static NoticeStatus _parseStatus(String? status) {
    switch (status?.toUpperCase()) {
      case 'PUBLISHED':
        return NoticeStatus.published;
      case 'ARCHIVED':
        return NoticeStatus.archived;
      case 'DRAFT':
      default:
        return NoticeStatus.draft;
    }
  }

  String get priorityText {
    switch (priority) {
      case NoticePriority.high:
        return '긴급';
      case NoticePriority.normal:
        return '일반';
      case NoticePriority.low:
        return '낮음';
    }
  }

  String get statusText {
    switch (status) {
      case NoticeStatus.draft:
        return '임시저장';
      case NoticeStatus.published:
        return '게시됨';
      case NoticeStatus.archived:
        return '보관됨';
    }
  }

  Notice copyWith({
    int? id,
    String? title,
    String? content,
    NoticePriority? priority,
    NoticeStatus? status,
    bool? isPinned,
    String? authorId,
    String? authorName,
    int? companyId,
    int? viewCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? publishedAt,
    List<NoticeAttachment>? attachments,
  }) {
    return Notice(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      isPinned: isPinned ?? this.isPinned,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      companyId: companyId ?? this.companyId,
      viewCount: viewCount ?? this.viewCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: publishedAt ?? this.publishedAt,
      attachments: attachments ?? this.attachments,
    );
  }
}
