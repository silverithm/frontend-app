import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/chat_message.dart';
import 'package:frontend_app/providers/chat_files_controller.dart';
import 'package:frontend_app/utils/chat_files_browse.dart';

Map<String, dynamic> _json(int id, String type, String? mime, String? name, String sender, DateTime at,
        {String? mediaType}) =>
    {
      'id': id,
      'chatRoomId': 7,
      'senderId': '1',
      'senderName': sender,
      'type': type,
      'content': name ?? '',
      'fileName': name,
      'fileUrl': name == null ? null : 'https://img.example/$id',
      'mimeType': mime,
      if (mediaType != null) 'mediaType': mediaType,
      'createdAt': at.toIso8601String(),
      'isDeleted': false,
      'readCount': 0,
      'reactions': <dynamic>[],
    };

/// 11월: 사진 2·동영상 2(하나는 옛 .MOV)·문서 1, 10월: 사진 2·문서 1 — 섞어서
List<Map<String, dynamic>> _roomJson() => [
      _json(5, 'IMAGE', 'image/jpeg', 'a.jpg', '박선영', DateTime(2026, 10, 30, 9)),
      _json(11, 'IMAGE', 'image/jpeg', 'b.jpg', '김민지', DateTime(2026, 11, 24, 18)),
      _json(9, 'FILE', 'video/mp4', '행사.mp4', '박선영', DateTime(2026, 11, 20, 10), mediaType: 'VIDEO'),
      _json(10, 'IMAGE', 'image/jpeg', 'c.jpg', '박선영', DateTime(2026, 11, 22, 8)),
      _json(8, 'FILE', null, 'IMG_0001.MOV', '김민지', DateTime(2026, 11, 3, 10)),
      _json(7, 'FILE', 'application/pdf', '11월 근무표.pdf', '김관리', DateTime(2026, 11, 2, 10)),
      _json(4, 'IMAGE', 'image/jpeg', 'd.jpg', '김민지', DateTime(2026, 10, 12, 9)),
      _json(3, 'FILE', 'application/x-hwp', '10월 교육 자료.hwp', '김관리', DateTime(2026, 10, 2, 9)),
    ];

List<ChatMessage> _room() => _roomJson().map(ChatMessage.fromJson).toList();

List<int> _ids(List<ChatMessage> items) => items.map((m) => m.id).toList();

void main() {
  group('앱 안 거르기(옛 서버용) — 서버 SharedMediaBrowser와 같은 규칙', () {
    test('종류별·최신순, 탭 숫자', () {
      final p = browseChatFilesLocally(_room(), kind: ChatFilesKind.photo);
      expect(_ids(p.items), [11, 10, 5, 4]);
      expect(p.counts[ChatFilesKind.photo], 4);
      expect(p.counts[ChatFilesKind.video], 2);
      expect(p.counts[ChatFilesKind.file], 2);
      expect(_ids(browseChatFilesLocally(_room(), kind: ChatFilesKind.video).items), [9, 8]);
      expect(_ids(browseChatFilesLocally(_room(), kind: ChatFilesKind.file).items), [7, 3]);
    });

    test('검색어는 파일 이름·보낸 사람에서', () {
      final p = browseChatFilesLocally(_room(), kind: ChatFilesKind.photo, query: ' 박선영 ');
      expect(_ids(p.items), [10, 5]);
      expect(p.counts[ChatFilesKind.video], 1);
      expect(_ids(browseChatFilesLocally(_room(), kind: ChatFilesKind.file, query: '근무표').items), [7]);
    });

    test('이어 받기·달로 이동', () {
      final first = browseChatFilesLocally(_room(), kind: ChatFilesKind.photo, size: 2);
      expect(_ids(first.items), [11, 10]);
      expect(first.hasMore, isTrue);
      final next = browseChatFilesLocally(_room(), kind: ChatFilesKind.photo, size: 2, beforeId: 10);
      expect(_ids(next.items), [5, 4]);
      expect(next.hasMore, isFalse);
      final oct = browseChatFilesLocally(_room(), kind: ChatFilesKind.photo, month: '2026-10');
      expect(_ids(oct.items), [5, 4]);
      expect(oct.months.map((m) => '${m.month}:${m.count}').toList(), ['2026-11:2', '2026-10:2']);
    });
  });

  group('날짜 묶음·이름표', () {
    test('같은 날끼리, 최신 날 먼저', () {
      final days = groupChatFilesByDay(_room()..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
      expect(days.first.day, DateTime(2026, 11, 24));
      expect(days.length, 8);
    });

    test('오늘·어제·요일·다른 해', () {
      final now = DateTime(2026, 11, 24, 21);
      expect(formatChatFilesDay(DateTime(2026, 11, 24), now: now), '오늘');
      expect(formatChatFilesDay(DateTime(2026, 11, 23), now: now), '어제');
      expect(formatChatFilesDay(DateTime(2026, 11, 2), now: now), '11월 2일 (월)');
      expect(formatChatFilesDay(DateTime(2025, 12, 3), now: now), '2025년 12월 3일 (수)');
      expect(formatChatFilesMonth('2026-11', now: now), '11월');
      expect(formatChatFilesMonth('2025-12', now: now), '2025년 12월');
      expect(formatChatFilesCount(4922), '4,922');
      expect(formatChatFilesCount(12), '12');
      expect(formatChatFileSize(34000), '33.2 KB');
    });
  });

  group('ChatFilesController', () {
    test('새 서버 응답 — 쪽을 이어 붙이고 탭 숫자·달 목록을 받는다', () async {
      final calls = <String>[];
      final c = ChatFilesController(
        roomId: 7,
        pageSize: 2,
        fetch: ({required roomId, required kind, query, beforeId, month, size = 60}) async {
          calls.add('$kind|${query ?? ''}|${beforeId ?? ''}|${month ?? ''}');
          final p = browseChatFilesLocally(_room(),
              kind: ChatFilesKind.values.firstWhere((k) => k.apiValue == kind),
              query: query ?? '',
              beforeId: beforeId,
              month: month,
              size: size);
          return {
            'files': p.items.map((m) => _roomJson().firstWhere((j) => j['id'] == m.id)).toList(),
            'hasMore': p.hasMore,
            'counts': {for (final e in p.counts.entries) e.key.apiValue: e.value},
            'months': [for (final m in p.months) {'month': m.month, 'count': m.count}],
          };
        },
      );
      await c.load();
      expect(_ids(c.items), [11, 10]);
      expect(c.hasMore, isTrue);
      expect(c.counts[ChatFilesKind.photo], 4);
      expect(c.months.length, 2);
      await c.loadMore();
      expect(_ids(c.items), [11, 10, 5, 4]);
      expect(c.hasMore, isFalse);
      expect(calls, ['IMAGE|||', 'IMAGE||10|']);
      c.dispose();
    });

    test('옛 서버(files만) — 한 번만 받고 이후는 앱 안에서 거른다', () async {
      var fetches = 0;
      final c = ChatFilesController(
        roomId: 7,
        pageSize: 3,
        fetch: ({required roomId, required kind, query, beforeId, month, size = 60}) async {
          fetches++;
          return {'files': _roomJson()};
        },
      );
      await c.load();
      expect(_ids(c.items), [11, 10, 5]);
      expect(c.hasMore, isTrue);
      c.setKind(ChatFilesKind.file);
      await Future<void>.delayed(Duration.zero);
      expect(_ids(c.items), [7, 3]);
      expect(fetches, 1);
      c.dispose();
    });

    test('사진이 없는 방은 처음 열 때 있는 쪽 탭으로', () async {
      final onlyFiles = _roomJson().where((j) => j['type'] == 'FILE' && j['mimeType'] == 'application/pdf').toList();
      final c = ChatFilesController(
        roomId: 7,
        fetch: ({required roomId, required kind, query, beforeId, month, size = 60}) async => {'files': onlyFiles},
      );
      await c.load(hopToResults: true);
      expect(c.kind, ChatFilesKind.file);
      expect(_ids(c.items), [7]);
      c.dispose();
    });

    test('검색 결과가 다른 탭에만 있으면 그 탭으로, 직접 고른 빈 탭은 그대로', () async {
      final c = ChatFilesController(
        roomId: 7,
        fetch: ({required roomId, required kind, query, beforeId, month, size = 60}) async => {'files': _roomJson()},
      );
      await c.load(hopToResults: true);
      expect(c.kind, ChatFilesKind.photo);
      c.setQuery('근무표');
      await Future<void>.delayed(Duration.zero);
      expect(c.kind, ChatFilesKind.file);
      expect(_ids(c.items), [7]);
      // 검색 중에 사람이 동영상 탭을 고르면 비어 있어도 옮기지 않는다
      c.setKind(ChatFilesKind.video);
      await Future<void>.delayed(Duration.zero);
      expect(c.kind, ChatFilesKind.video);
      expect(c.items, isEmpty);
      c.dispose();
    });

    test('늦게 온 옛 응답이 새 검색 결과를 덮지 않는다', () async {
      final c = ChatFilesController(
        roomId: 7,
        fetch: ({required roomId, required kind, query, beforeId, month, size = 60}) async {
          // 검색어 없는 첫 요청을 일부러 늦게 돌려준다
          if (query == null) await Future<void>.delayed(const Duration(milliseconds: 30));
          final p = browseChatFilesLocally(_room(), kind: ChatFilesKind.photo, query: query ?? '');
          return {
            'files': p.items.map((m) => _roomJson().firstWhere((j) => j['id'] == m.id)).toList(),
            'hasMore': false,
            'counts': {for (final e in p.counts.entries) e.key.apiValue: e.value},
            'months': const [],
          };
        },
      );
      final first = c.load();
      c.setQuery('김민지');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await first;
      expect(_ids(c.items), [11, 4]);
      c.dispose();
    });
  });
}
