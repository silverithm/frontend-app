/// 채팅방 '주고받은 파일'의 순수 로직 — 종류 구분, 날짜 묶음, 이름표, 옛 서버용 앱 안 거르기.
///
/// 예전 화면은 방의 사진·파일 5천여 건을 한 줄씩 쭉 늘어놓았다(사용자 "검색도 날짜별도 안 되고
/// 한 줄로만 쭉 나온다"). 이제 서버가 종류·검색어·달로 걸러 한 쪽씩 준다(GET /files?size=…).
/// 서버가 아직 옛 버전이면 통째로 오는데, 그때도 같은 규칙으로 앱에서 거른다
/// ([browseChatFilesLocally]) — 규칙은 서버 SharedMediaBrowser와 같다.
library;

import '../models/chat_message.dart';

enum ChatFilesKind { photo, video, file }

extension ChatFilesKindInfo on ChatFilesKind {
  /// 서버 kind 값
  String get apiValue => switch (this) {
        ChatFilesKind.photo => 'IMAGE',
        ChatFilesKind.video => 'VIDEO',
        ChatFilesKind.file => 'FILE',
      };

  String get label => switch (this) {
        ChatFilesKind.photo => '사진',
        ChatFilesKind.video => '동영상',
        ChatFilesKind.file => '파일',
      };

  /// 사진·동영상은 바둑판, 파일은 줄 목록
  bool get isGrid => this != ChatFilesKind.file;
}

ChatFilesKind chatFilesKindOf(ChatMessage m) {
  if (m.isVideoMessage) return ChatFilesKind.video;
  if (m.isPhotoMessage) return ChatFilesKind.photo;
  return ChatFilesKind.file;
}

/// 달별 개수 — month는 "yyyy-MM"
class ChatFilesMonth {
  const ChatFilesMonth(this.month, this.count);
  final String month;
  final int count;
}

/// 한 쪽 — 서버 응답이든 앱 안 거르기든 같은 모양
class ChatFilesPage {
  const ChatFilesPage({
    required this.items,
    required this.hasMore,
    required this.counts,
    required this.months,
  });

  final List<ChatMessage> items;
  final bool hasMore;
  final Map<ChatFilesKind, int> counts;
  final List<ChatFilesMonth> months;
}

/// 새 서버 응답({files, hasMore, counts, months})인지 — 옛 서버는 files만 준다
bool isPagedChatFilesResponse(Map<String, dynamic> json) => json.containsKey('hasMore');

List<ChatMessage> parseChatFilesList(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

ChatFilesPage parseChatFilesPage(Map<String, dynamic> json) {
  final counts = <ChatFilesKind, int>{
    for (final k in ChatFilesKind.values) k: 0,
  };
  final rawCounts = json['counts'];
  if (rawCounts is Map) {
    for (final k in ChatFilesKind.values) {
      final v = rawCounts[k.apiValue];
      if (v is num) counts[k] = v.toInt();
    }
  }
  final months = <ChatFilesMonth>[];
  final rawMonths = json['months'];
  if (rawMonths is List) {
    for (final row in rawMonths.whereType<Map>()) {
      final m = row['month']?.toString();
      final c = row['count'];
      if (m != null && c is num) months.add(ChatFilesMonth(m, c.toInt()));
    }
  }
  return ChatFilesPage(
    items: parseChatFilesList(json['files']),
    hasMore: json['hasMore'] == true,
    counts: counts,
    months: months,
  );
}

String _monthKey(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}';

/// 옛 서버가 통째로 준 목록을 서버와 같은 규칙으로 거르고 자른다.
ChatFilesPage browseChatFilesLocally(
  List<ChatMessage> all, {
  required ChatFilesKind kind,
  String query = '',
  String? month,
  int? beforeId,
  int size = 60,
}) {
  final needle = query.trim().toLowerCase();
  final sorted = [...all]..sort((a, b) {
      final byTime = b.createdAt.compareTo(a.createdAt);
      return byTime != 0 ? byTime : b.id.compareTo(a.id);
    });

  final matched = sorted.where((m) {
    if (m.isDeleted) return false;
    if (m.type != MessageType.image && m.type != MessageType.file) return false;
    if (needle.isEmpty) return true;
    final name = (m.fileName ?? '').toLowerCase();
    final sender = m.senderName.toLowerCase();
    return name.contains(needle) || sender.contains(needle);
  }).toList();

  final counts = <ChatFilesKind, int>{
    for (final k in ChatFilesKind.values) k: 0,
  };
  for (final m in matched) {
    final k = chatFilesKindOf(m);
    counts[k] = counts[k]! + 1;
  }

  final ofKind = matched.where((m) => chatFilesKindOf(m) == kind).toList();

  final monthCounts = <String, int>{};
  for (final m in ofKind) {
    final key = _monthKey(m.createdAt);
    monthCounts[key] = (monthCounts[key] ?? 0) + 1;
  }
  final months = [
    for (final e in monthCounts.entries) ChatFilesMonth(e.key, e.value),
  ];

  var start = 0;
  if (beforeId != null) {
    final idx = ofKind.indexWhere((m) => m.id == beforeId);
    if (idx >= 0) {
      start = idx + 1;
    } else {
      final next = ofKind.indexWhere((m) => m.id < beforeId);
      start = next >= 0 ? next : ofKind.length;
    }
  } else if (month != null) {
    final parts = month.split('-');
    final y = parts.length == 2 ? int.tryParse(parts[0]) : null;
    final mo = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (y != null && mo != null && mo >= 1 && mo <= 12) {
      final nextMonthStart = DateTime(y, mo + 1, 1);
      final idx = ofKind.indexWhere((m) => m.createdAt.isBefore(nextMonthStart));
      start = idx >= 0 ? idx : ofKind.length;
    }
  }

  final pageSize = size.clamp(1, 200);
  final end = (start + pageSize).clamp(0, ofKind.length);
  return ChatFilesPage(
    items: start >= ofKind.length ? const [] : ofKind.sublist(start, end),
    hasMore: end < ofKind.length,
    counts: counts,
    months: months,
  );
}

/// 같은 날끼리 — 입력은 최신순, 결과도 최신 날 먼저
class ChatFilesDay {
  ChatFilesDay(this.day, this.items);
  final DateTime day;
  final List<ChatMessage> items;
}

List<ChatFilesDay> groupChatFilesByDay(List<ChatMessage> newestFirst) {
  final out = <ChatFilesDay>[];
  for (final m in newestFirst) {
    final t = m.createdAt;
    final day = DateTime(t.year, t.month, t.day);
    if (out.isNotEmpty && out.last.day == day) {
      out.last.items.add(m);
    } else {
      out.add(ChatFilesDay(day, [m]));
    }
  }
  return out;
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// '오늘' · '어제' · '11월 24일 (월)' · 올해가 아니면 '2025년 12월 3일 (수)'
String formatChatFilesDay(DateTime day, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final d = DateTime(day.year, day.month, day.day);
  if (d == today) return '오늘';
  if (d == today.subtract(const Duration(days: 1))) return '어제';
  final wd = _weekdays[d.weekday - 1];
  return d.year == current.year
      ? '${d.month}월 ${d.day}일 ($wd)'
      : '${d.year}년 ${d.month}월 ${d.day}일 ($wd)';
}

/// "2026-11" → '11월' (올해) / '2025년 12월'
String formatChatFilesMonth(String month, {DateTime? now}) {
  final parts = month.split('-');
  final y = parts.length == 2 ? int.tryParse(parts[0]) : null;
  final m = parts.length == 2 ? int.tryParse(parts[1]) : null;
  if (y == null || m == null) return month;
  final current = now ?? DateTime.now();
  return y == current.year ? '$m월' : '$y년 $m월';
}

/// 4922 → '4,922'
String formatChatFilesCount(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String formatChatFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
