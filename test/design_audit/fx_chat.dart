// 채팅: 방 목록·메시지·참가자
import 'fixtures.dart';
import 'fx_core.dart';

String get _me => FixtureRouter.role == Role.adm ? adminId : '1';
String get _myName => FixtureRouter.role == Role.adm ? '김관리' : '김민지';

Map<String, dynamic> _msg(int id, int room, String sender, String name, String content,
    {int minsAgo = 10, String type = 'TEXT', Map<String, dynamic>? extra, int readCount = 0}) =>
    {
      'id': id,
      'chatRoomId': room,
      'senderId': sender,
      'senderName': name,
      'senderPosition': sender == adminId ? '센터장' : '요양보호사',
      'type': type,
      'content': content,
      'readCount': readCount,
      'createdAt': iso(DateTime.now().subtract(Duration(minutes: minsAgo))),
      'isDeleted': false,
      'reactions': <dynamic>[],
      ...?extra,
    };

List<Map<String, dynamic>> _rooms() {
  Map<String, dynamic> room(int id, String name, int count, Map<String, dynamic>? last, int unread,
          {bool pinned = false, Map<String, dynamic>? notice}) =>
      {
        'id': id,
        'name': name,
        'companyId': 1,
        'createdBy': adminId,
        'createdByName': '김관리',
        'participantCount': count,
        'unreadCount': unread,
        'createdAt': iso(daysFromNow(-100)),
        'status': 'ACTIVE',
        'lastMessage': last,
        'lastMessageAt': last?['createdAt'],
        'pinned': pinned,
        'avatars': [
          for (final s in staff.take(count.clamp(1, 4))) {'userId': '${s.$1}', 'userName': s.$2}
        ],
        ...?notice,
      };
  return [
    room(1, '전체 공지방', 13, _msg(1001, 1, adminId, '김관리', '내일 안전점검 교육 오전 10시입니다.', minsAgo: 35), 2,
        pinned: true,
        notice: {'noticeMessageId': 1001, 'noticeContent': '안전점검 교육 오전 10시 필참', 'noticeByName': '김관리', 'noticeAt': iso(daysFromNow(-1))}),
    room(3, '김민지', 2, _msg(3003, 3, '1', '김민지', '사진', minsAgo: 50, type: 'IMAGE', extra: {'fileUrl': 'https://img.example/1.jpg', 'mediaType': 'image', 'mimeType': 'image/jpeg'}), 5),
    room(5, '배차 조율방', 4, _msg(5003, 5, '11', '오하늘', '오늘 3호차 늦어요', minsAgo: 95), 1),
    room(2, '요양보호사 1팀', 6, _msg(2003, 2, '3', '박지훈', '네 확인했습니다', minsAgo: 60 * 20), 0),
    room(4, '사무국', 3, _msg(4003, 4, '9', '한소연', '급여대장.xlsx', minsAgo: 60 * 30, type: 'FILE', extra: {'fileUrl': 'https://img.example/f.xlsx', 'fileName': '급여대장.xlsx', 'fileSize': 34000}), 0),
    room(6, '조리팀', 3, _msg(6001, 6, '12', '신동욱', '내일 식단 확인 부탁드려요', minsAgo: 60 * 50), 0),
  ];
}

List<Map<String, dynamic>> _messages(int room) {
  // 최신이 앞
  if (room == 3) {
    return [
      _msg(3010, 3, '1', '김민지', '네, 감사합니다!', minsAgo: 20),
      _msg(3009, 3, _me, _myName, '확인했어요. 오후에 다시 말씀드릴게요.', minsAgo: 24, readCount: 1),
      _msg(3008, 3, '1', '김민지', '사진', minsAgo: 50, type: 'IMAGE', extra: {'fileUrl': 'https://img.example/1.jpg', 'thumbnailUrl': 'https://img.example/1t.jpg', 'mediaType': 'image', 'mimeType': 'image/jpeg'}),
      _msg(3007, 3, '1', '김민지', '오늘 생신잔치 장식 준비한 거예요 🎈', minsAgo: 51),
      _msg(3006, 3, _me, _myName, '수고 많으셨어요. 케이크는 2시에 도착해요.', minsAgo: 60 * 3, readCount: 1),
      _msg(3005, 3, '1', '김민지', '내일 오전 반차 가능할까요?', minsAgo: 60 * 26),
    ];
  }
  return [
    _msg(1010, room, '9', '한소연', '확인했습니다. 서류는 오늘 중으로 정리해서 올릴게요.', minsAgo: 8),
    _msg(1009, room, '3', '박지훈', '1호차 하원 경로 변경 건, 내일부터 적용되나요?', minsAgo: 22),
    _msg(1008, room, _me, _myName, '네, 내일부터 적용됩니다. 배차표 다시 올려둘게요.', minsAgo: 30, readCount: 6),
    _msg(1007, room, '2', '이서연', '사진', minsAgo: 45, type: 'IMAGE', extra: {'fileUrl': 'https://img.example/2.jpg', 'thumbnailUrl': 'https://img.example/2t.jpg', 'mediaType': 'image', 'mimeType': 'image/jpeg'}),
    _msg(1006, room, '2', '이서연', '오늘 오전 프로그램 사진입니다.', minsAgo: 46),
    _msg(1005, room, '9', '한소연', '10월 급여명세서는 25일에 개별 발송됩니다.', minsAgo: 60 * 5),
    _msg(1004, room, adminId, '김관리', '내일 안전점검 교육 오전 10시입니다. 전원 참석 부탁드립니다.', minsAgo: 60 * 24 + 5, readCount: 11),
    _msg(1003, room, '4', '최유진', '네 알겠습니다!', minsAgo: 60 * 24 + 8),
  ];
}

List<Map<String, dynamic>> _participants(int room) => [
      {'id': 1, 'chatRoomId': room, 'userId': adminId, 'userName': '김관리', 'position': '센터장', 'role': 'OWNER', 'joinedAt': iso(daysFromNow(-100)), 'isActive': true},
      for (final s in staff.take(8))
        {'id': 10 + s.$1, 'chatRoomId': room, 'userId': '${s.$1}', 'userName': s.$2, 'position': s.$3, 'role': 'MEMBER', 'joinedAt': iso(daysFromNow(-90)), 'isActive': true},
    ];

void registerChat() {
  final on = FixtureRouter.on;
  on('GET', '/v1/chat/rooms', (u, b, m) => {'rooms': _rooms()});
  on('GET', '/v1/chat/rooms/\\d+', (u, b, m) {
    final id = int.parse(u.pathSegments.last);
    final r = _rooms().firstWhere((e) => e['id'] == id, orElse: () => _rooms().first);
    return {...r, 'participants': _participants(id)};
  });
  on('GET', '/v1/chat/rooms/\\d+/messages', (u, b, m) {
    final id = int.parse(u.pathSegments[u.pathSegments.length - 2]);
    final page = int.tryParse(u.queryParameters['page'] ?? '0') ?? 0;
    return {'messages': page == 0 ? _messages(id) : <dynamic>[], 'hasMore': false};
  });
  on('GET', '/v1/chat/rooms/\\d+/participants', (u, b, m) {
    final id = int.parse(u.pathSegments[u.pathSegments.length - 2]);
    return {'participants': _participants(id)};
  });
  on('GET', '/v1/chat/online-users', (u, b, m) => {'onlineUserIds': ['1', '2', '9', adminId]});
  on('GET', '/v1/chat/rooms/\\d+/media', (u, b, m) => {'items': <dynamic>[]});
}

List<Map<String, dynamic>> roomsForSpec() => _rooms();
