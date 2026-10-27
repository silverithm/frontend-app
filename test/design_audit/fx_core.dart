// 코어: 로그인·구독·알림·일정·휴무·업무진행도·직원 명단
import 'fixtures.dart';

DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String iso(DateTime d) => d.toIso8601String().split('.').first;
DateTime daysFromNow(int n, [int h = 9, int m = 0]) {
  final t = today().add(Duration(days: n));
  return DateTime(t.year, t.month, t.day, h, m);
}

const adminId = 'admin_1';

/// (id, 이름, 직책, memberRole)
const List<(int, String, String)> staff = [
  (1, '김민지', '요양보호사'),
  (2, '이서연', '요양보호사'),
  (3, '박지훈', '요양보호사'),
  (4, '최유진', '요양보호사'),
  (5, '정다은', '요양보호사'),
  (6, '강태윤', '요양보호사'),
  (7, '조은비', '사회복지사'),
  (8, '윤성민', '사회복지사'),
  (9, '한소연', '사무원'),
  (10, '임재현', '사무원'),
  (11, '오하늘', '조리원'),
  (12, '신동욱', '조리원'),
];

String staffName(int id) => staff.firstWhere((s) => s.$1 == id).$2;

class Fixtures {
  static Map<String, dynamic> signinResponse(Role role) {
    final tokenInfo = {
      'accessToken': 'fake-access-token',
      'refreshToken': 'fake-refresh-token',
      'expiresAt': iso(DateTime.now().add(const Duration(days: 7))),
    };
    if (role == Role.adm) {
      return {
        'userId': 1,
        'userName': '김관리',
        'userEmail': 'admin@carev.kr',
        'companyId': 1,
        'companyName': '햇살주간보호센터',
        'companyAddressName': '광주광역시 서구 상무대로 120',
        'companyAddress': {'latitude': 35.152, 'longitude': 126.851},
        'companyCode': 'SUN2026',
        'position': '센터장',
        'tokenInfo': tokenInfo,
      };
    }
    return {
      'memberId': 1,
      'username': 'staff1@carev.kr',
      'name': '김민지',
      'email': 'staff1@carev.kr',
      'role': 'CAREGIVER',
      'status': 'active',
      'position': '요양보호사',
      'company': {
        'id': 1,
        'name': '햇살주간보호센터',
        'addressName': '광주광역시 서구 상무대로 120',
        'companyAddress': {'latitude': 35.152, 'longitude': 126.851},
      },
      'tokenInfo': tokenInfo,
      'permissions': <String>[],
    };
  }
}

Map<String, dynamic> _member(int id, String name, String position, {String status = 'active'}) => {
      'id': id,
      'username': 'staff$id@carev.kr',
      'email': 'staff$id@carev.kr',
      'name': name,
      'role': 'CAREGIVER',
      'status': status,
      'position': position,
      'isActive': status == 'active',
      'createdAt': iso(daysFromNow(-200)),
      'lastLoginAt': iso(daysFromNow(0, 8, 10)),
      'company': {'id': 1, 'name': '햇살주간보호센터', 'addressName': '광주광역시 서구 상무대로 120'},
      'permissions': <String>[],
    };

List<Map<String, dynamic>> membersJson() => [
      for (final s in staff) _member(s.$1, s.$2, s.$3),
    ];

// ───────── 일정 ─────────
// (오늘 기준 offset, 길이(일), 분류, 제목, 시작시간, 끝시간, 완료)
const _sched = <(int, int, String, String, String, String, bool)>[
  (-12, 1, 'MEETING', '9월 정기 직원 회의', '10:00', '11:00', true),
  (-9, 1, 'EVENT', '어르신 생신잔치 (박순자님)', '14:00', '15:30', true),
  (-6, 1, 'TRAINING', '심폐소생술(CPR) 보수교육', '09:30', '12:00', true),
  (-4, 1, 'OTHER', '차량 정기점검', '13:00', '14:00', true),
  (-2, 1, 'MEETING', '학부모(보호자) 상담 주간 운영 및 만족도 조사 결과 공유', '10:00', '11:30', true),
  (0, 1, 'MEETING', '요양보호사 1팀 주간 회의', '09:30', '10:00', false),
  (0, 1, 'EVENT', '어르신 생신잔치 (이말순님)', '14:00', '15:30', false),
  (0, 1, 'OTHER', '급식 위생 점검', '11:00', '12:00', false),
  (1, 1, 'TRAINING', '치매 케어 실무 교육', '10:00', '12:00', false),
  (2, 1, 'OTHER', '소방안전점검', '15:00', '16:00', false),
  (3, 3, 'EVENT', '가을 나들이 (근교 공원)', '09:00', '16:00', false),
  (5, 1, 'MEETING', '보호자 간담회', '16:00', '17:30', false),
  (6, 1, 'TRAINING', '응급처치 실습 교육', '10:00', '12:00', false),
  (8, 1, 'OTHER', '정수기·공기청정기 필터 교체', '13:00', '14:00', false),
  (9, 1, 'MEETING', '센터장-팀장 월례 회의', '15:00', '16:00', false),
  (12, 1, 'EVENT', '노인의 날 기념 행사', '10:00', '12:00', false),
  (14, 1, 'OTHER', '비품 정기 발주', '09:00', '09:30', false),
  (16, 1, 'TRAINING', '장기요양 급여제공기록지 작성법 교육', '14:00', '16:00', false),
  (19, 1, 'MEETING', '신규 입사자 오리엔테이션', '10:00', '11:00', false),
  (-15, 1, 'OTHER', '차량 배차표 확정', '17:00', '17:30', true),
  (-20, 1, 'EVENT', '추석 명절 프로그램', '10:00', '12:00', true),
];
const _catColor = {
  'MEETING': '#3B82F6',
  'EVENT': '#EC4899',
  'TRAINING': '#8B5CF6',
  'OTHER': '#14B8A6',
};

Map<String, dynamic> _scheduleJson(int i) {
  final s = _sched[i];
  final start = daysFromNow(s.$1);
  final end = daysFromNow(s.$1 + s.$2 - 1);
  final hasTasks = i % 4 == 0;
  return {
    'id': 100 + i,
    'companyId': 1,
    'title': s.$4,
    'content': i % 3 == 0 ? '장소와 준비물은 채팅방 공지를 확인해 주세요.' : '',
    'category': s.$3,
    'color': _catColor[s.$3],
    'location': i % 2 == 0 ? '프로그램실' : null,
    'startDate': ymd(start),
    'startTime': s.$5,
    'endDate': ymd(end),
    'endTime': s.$6,
    'isAllDay': s.$2 > 1,
    'sendNotification': false,
    'isCompleted': s.$7,
    'completedAt': s.$7 ? iso(start) : null,
    'completedByName': s.$7 ? '김관리' : null,
    'managerId': 1,
    'managerName': '김관리',
    'authorId': adminId,
    'authorName': '김관리',
    'taskTotal': hasTasks ? 2 : 0,
    'taskCompleted': hasTasks && s.$7 ? 2 : (hasTasks ? 1 : 0),
    'participants': [
      {'id': 1, 'memberId': '1', 'memberName': '김민지'},
      {'id': 2, 'memberId': '2', 'memberName': '이서연'},
    ],
    'tasks': hasTasks
        ? [
            {'id': 900 + i, 'scheduleId': 100 + i, 'content': '자료 준비', 'assigneeMemberId': 1, 'assigneeName': '김민지', 'isCompleted': true},
            {'id': 950 + i, 'scheduleId': 100 + i, 'content': '현장 정리', 'assigneeMemberId': 2, 'assigneeName': '이서연', 'isCompleted': s.$7},
          ]
        : <Map<String, dynamic>>[],
  };
}

// ───────── 휴무 ─────────
// (offset, 직원id, 상태, 유형, 기간)
const _vac = <(int, int, String, String, String)>[
  (-10, 2, 'approved', 'personal', 'FULL_DAY'),
  (-7, 3, 'approved', 'substitute', 'FULL_DAY'),
  (-3, 5, 'approved', 'personal', 'HALF_DAY_AM'),
  (0, 9, 'approved', 'personal', 'FULL_DAY'),
  (0, 10, 'approved', 'personal', 'FULL_DAY'),
  (0, 11, 'approved', 'mandatory', 'FULL_DAY'),
  (1, 4, 'approved', 'mandatory', 'FULL_DAY'),
  (1, 6, 'pending', 'personal', 'FULL_DAY'),
  (1, 7, 'pending', 'personal', 'FULL_DAY'),
  (3, 1, 'approved', 'personal', 'FULL_DAY'),
  (4, 8, 'approved', 'personal', 'HALF_DAY_PM'),
  (7, 12, 'pending', 'personal', 'FULL_DAY'),
  (7, 2, 'rejected', 'personal', 'FULL_DAY'),
  (10, 3, 'pending', 'substitute', 'HALF_DAY_AM'),
  (13, 4, 'approved', 'personal', 'FULL_DAY'),
  (-1, 1, 'approved', 'personal', 'FULL_DAY'),
];
String _staffRole(int id) => id <= 6 ? 'caregiver' : 'office';

Map<String, dynamic> vacationJson(int i, {bool mine = false}) {
  final v = _vac[i];
  return {
    'id': '${700 + i}',
    'userId': '${v.$2}',
    'userName': staffName(v.$2),
    'role': _staffRole(v.$2),
    'date': ymd(daysFromNow(v.$1)),
    'status': v.$3,
    'type': v.$4,
    'duration': v.$5,
    'reason': '개인 사유',
    'createdAt': iso(daysFromNow(v.$1 - 6)),
    'updatedAt': iso(daysFromNow(v.$1 - 5)),
    if (v.$3 == 'rejected') 'rejectionReason': '해당 주 근무 인원 부족',
  };
}

List<Map<String, dynamic>> allVacations() => [for (var i = 0; i < _vac.length; i++) vacationJson(i)];

/// 업무진행도
List<Map<String, dynamic>> workTasks(Role role) {
  final canEdit = role == Role.adm;
  Map<String, dynamic> t(int id, String content, String imp, int progress, int? due, List<(String, String)> who,
          {bool done = false}) =>
      {
        'id': id,
        'content': content,
        'importance': imp,
        'progress': progress,
        'dueDate': due == null ? null : ymd(daysFromNow(due)),
        'assignees': [for (final w in who) {'id': w.$1, 'name': w.$2}],
        'createdBy': {'id': adminId, 'name': '김관리'},
        'createdAt': iso(daysFromNow(-5)),
        'completedAt': done ? iso(daysFromNow(-1)) : null,
        'canEdit': canEdit || who.any((w) => w.$1 == '1'),
        'canDelete': canEdit,
      };
  return [
    t(1, '10월 보호자 간담회 안내문 발송', 'HIGH', 60, 2, [('1', '김민지'), ('9', '한소연')]),
    t(2, '평가 대비 서류 정리 — 안전점검표·교육 이수 현황 최신화', 'HIGH', 30, 5, [('9', '한소연')]),
    t(3, '프로그램실 비품 재고 확인', 'NORMAL', 80, 7, [('2', '이서연'), ('1', '김민지')]),
    t(4, '차량 정기점검 일정 조율', 'NORMAL', 0, null, [('11', '오하늘')]),
    t(5, '신규 입사자 오리엔테이션 자료 준비', 'LOW', 100, -1, [('7', '조은비')], done: true),
  ];
}

void registerCore() {
  final on = FixtureRouter.on;
  final role = FixtureRouter.role;

  on('POST', '/v1/validate-token', (u, b, m) => {
        'username': 'x',
        'expiresAt': DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch,
      });
  on('POST', '/v1/refresh-token', (u, b, m) => {'accessToken': 'fake-access-token', 'refreshToken': 'fake-refresh-token'});
  on('GET', '/v1/app-version', (u, b, m) => {
        'iosVersion': '1.19.0',
        'androidVersion': '1.19.0',
        'iosMinimumVersion': '1.0.0',
        'androidMinimumVersion': '1.0.0',
        'forceUpdate': false,
      });
  on('GET', '/v1/users/info', (u, b, m) => {
        'userId': 1,
        'userName': role == Role.adm ? '김관리' : '김민지',
        'userEmail': role == Role.adm ? 'admin@carev.kr' : 'staff1@carev.kr',
        'companyId': 1,
        'companyName': '햇살주간보호센터',
        'companyAddressName': '광주광역시 서구 상무대로 120',
        'customerKey': 'customer_1',
        'subscription': _subscription(),
      });
  on('GET', '/v1/subscriptions', (u, b, m) => _subscription());
  on('GET', '/v1/members/\\d+/permissions', (u, b, m) => {'permissions': <String>[]});

  // 알림 — 두 식별자(숫자/admin_) 모두 같은 목록 반환
  on('GET', '/notifications/user/.+', (u, b, m) => {'notifications': _notifications()});
  on('PUT', '/notifications/.*', (u, b, m) => {});

  // 일정
  on('GET', '/v1/schedules', (u, b, m) {
    final s = DateTime.tryParse(u.queryParameters['startDate'] ?? '');
    final e = DateTime.tryParse(u.queryParameters['endDate'] ?? '');
    final list = <Map<String, dynamic>>[];
    for (var i = 0; i < _sched.length; i++) {
      final j = _scheduleJson(i);
      final sd = DateTime.parse(j['startDate'] as String);
      final ed = DateTime.parse(j['endDate'] as String);
      if (s != null && e != null && (ed.isBefore(s) || sd.isAfter(e))) continue;
      list.add(j);
    }
    return {'schedules': list};
  });
  on('GET', '/v1/schedules/my-tasks', (u, b, m) => {
        'tasks': [
          {'id': 900, 'scheduleId': 100, 'content': '자료 준비', 'assigneeMemberId': 1, 'assigneeName': '김민지', 'isCompleted': false, 'scheduleTitle': '9월 정기 직원 회의', 'scheduleStartDate': ymd(daysFromNow(0))},
        ]
      });
  on('GET', '/v1/schedules/\\d+', (u, b, m) {
    final id = int.parse(u.pathSegments.last);
    final i = (id - 100).clamp(0, _sched.length - 1);
    return {'schedule': _scheduleJson(i)};
  });
  on('GET', '/v1/schedule-categories', (u, b, m) => {
        'categories': [
          for (final e in const [('MEETING', '회의'), ('EVENT', '행사'), ('TRAINING', '교육'), ('OTHER', '기타')])
            {'category': e.$1, 'name': e.$2, 'color': _catColor[e.$1], 'hidden': false, 'defaultName': e.$2, 'defaultColor': _catColor[e.$1], 'customized': false}
        ]
      });
  on('GET', '/v1/schedule-labels', (u, b, m) => {'labels': <dynamic>[]});

  // 휴무
  on('GET', '/vacation/calendar', (u, b, m) {
    final s = DateTime.tryParse(u.queryParameters['startDate'] ?? '');
    final e = DateTime.tryParse(u.queryParameters['endDate'] ?? '');
    final dates = <String, dynamic>{};
    for (final v in allVacations()) {
      final d = DateTime.parse(v['date'] as String);
      if (s != null && e != null && (d.isBefore(s) || d.isAfter(e))) continue;
      final entry = dates.putIfAbsent(v['date'] as String, () => {'date': v['date'], 'vacations': <dynamic>[], 'maxPeople': 4, 'totalVacationers': 0});
      (entry['vacations'] as List).add(v);
      entry['totalVacationers'] = (entry['vacations'] as List).length;
    }
    return {'dates': dates};
  });
  on('GET', '/vacation/date/.+', (u, b, m) {
    final d = u.pathSegments.last;
    return {'vacations': [for (final v in allVacations()) if (v['date'] == d) v]};
  });
  on('GET', '/vacation/my/requests', (u, b, m) => {
        'success': true,
        'data': [for (var i = 0; i < _vac.length; i++) if (_vac[i].$2 == 1) vacationJson(i)],
      });
  on('GET', '/vacation/deadline-setting', (u, b, m) => {'deadlineDay': 20, 'enabled': false, 'nextMonthOnly': false});
  on('GET', '/vacation/deadline-dates', (u, b, m) => {'dates': <String, String>{}});
  on('GET', '/vacation/events', (u, b, m) => {
        'events': [
          {'id': 1, 'title': '노인의 날 기념 행사', 'description': '휴무 신청 제한', 'startDate': ymd(daysFromNow(12)), 'endDate': ymd(daysFromNow(12)), 'warnOnRequest': true},
        ]
      });
  on('GET', '/vacation/limits', (u, b, m) => {
        'limits': [
          {'id': 'l1', 'date': ymd(daysFromNow(1)), 'maxPeople': 3, 'role': 'caregiver', 'createdAt': iso(daysFromNow(-20))},
          {'id': 'l2', 'date': ymd(daysFromNow(7)), 'maxPeople': 2, 'role': 'all', 'createdAt': iso(daysFromNow(-20))},
        ]
      });
  on('GET', '/vacation/requests', (u, b, m) => {'requests': allVacations()});

  on('GET', '/v1/positions', (u, b, m) => {
        'positions': [
          for (final p in const [(1, '요양보호사', 'caregiver'), (2, '사회복지사', 'caregiver'), (3, '사무원', 'office'), (4, '조리원', 'office')])
            {'id': p.$1, 'companyId': 1, 'name': p.$2, 'description': '', 'memberRole': p.$3, 'sortOrder': p.$1}
        ]
      });

  // 업무진행도
  on('GET', '/v1/work-tasks', (u, b, m) => {'tasks': workTasks(role)});
  on('GET', '/v1/approvals/approver-candidates', (u, b, m) => {
        'candidates': [
          {'approverType': 'ADMIN', 'approverId': 1, 'name': '김관리', 'position': '센터장'},
          for (final s in staff) {'approverType': 'MEMBER', 'approverId': s.$1, 'name': s.$2, 'position': s.$3},
        ]
      });
  on('GET', '/v1/members/\\d+', (u, b, m) => membersJson().firstWhere((e) => '${e['id']}' == u.pathSegments.last, orElse: () => membersJson().first));
  on('GET', '/v1/members/\\d+/push-enabled', (u, b, m) => {'pushEnabled': true});
  on('GET', '/v1/presence', (u, b, m) => {'onlineUserIds': ['1', '2', '9', adminId]});
  on('GET', '/v1/members/companies', (u, b, m) => {
        'companies': [
          {'id': 1, 'name': '햇살주간보호센터', 'addressName': '광주광역시 서구 상무대로 120'},
          {'id': 2, 'name': '해든주간보호', 'addressName': '광주광역시 북구 첨단로 55'},
        ]
      });
  on('GET', '/v1/members', (u, b, m) => {'members': membersJson()});
  on('GET', '/v1/members/join-requests/pending', (u, b, m) => {
        'requests': [
          {'id': 101, 'username': 'sujin.bae@carev.kr', 'email': 'sujin.bae@carev.kr', 'name': '배수진', 'role': 'CAREGIVER', 'status': 'pending', 'position': '요양보호사', 'createdAt': iso(daysFromNow(-2))},
          {'id': 102, 'username': 'woosuk.jang@carev.kr', 'email': 'woosuk.jang@carev.kr', 'name': '장우석', 'role': 'CAREGIVER', 'status': 'pending', 'position': '사회복지사', 'createdAt': iso(daysFromNow(-1))},
        ]
      });
}

Map<String, dynamic> _subscription() => {
      'id': 1,
      'companyId': 1,
      'planName': 'BASIC',
      'billingType': 'MONTHLY',
      'startDate': ymd(daysFromNow(-120)),
      'endDate': ymd(daysFromNow(240)),
      'status': 'ACTIVE',
      'amount': 49000,
      'hasUsedFreeSubscription': true,
    };

List<Map<String, dynamic>> _notifications() => [
      {'id': 1, 'title': '결재 요청', 'message': '한소연님이 「9월 비품 구매 지출결의서」 결재를 요청했습니다.', 'type': 'approval', 'relatedEntityId': 2, 'relatedEntityType': 'approval', 'createdAt': iso(DateTime.now().subtract(const Duration(minutes: 12))), 'isRead': false},
      {'id': 2, 'title': '새 업무', 'message': '「10월 보호자 간담회 안내문 발송」 업무를 맡았습니다.', 'type': 'work_task', 'relatedEntityId': 1, 'relatedEntityType': 'work_task', 'createdAt': iso(DateTime.now().subtract(const Duration(hours: 2))), 'isRead': false},
      {'id': 3, 'title': '채팅', 'message': '김민지: 사진을 보냈습니다.', 'type': 'chat', 'relatedEntityId': 3, 'relatedEntityType': 'chat', 'createdAt': iso(DateTime.now().subtract(const Duration(hours: 5))), 'isRead': false},
      {'id': 4, 'title': '휴무 승인', 'message': '10월 휴무 신청이 승인되었습니다.', 'type': 'vacation_approved', 'createdAt': iso(daysFromNow(-1, 15)), 'isRead': true},
      {'id': 5, 'title': '공지사항', 'message': '[필독] 10월 안전점검의 날 안내', 'type': 'notice', 'relatedEntityId': 1, 'relatedEntityType': 'notice', 'createdAt': iso(daysFromNow(-1, 9)), 'isRead': true},
      {'id': 6, 'title': '휴무 반려', 'message': '휴무 신청이 반려되었습니다. (사유: 해당 주 근무 인원 부족)', 'type': 'vacation_rejected', 'createdAt': iso(daysFromNow(-3, 11)), 'isRead': true},
      {'id': 7, 'title': '일정 알림', 'message': '내일 10:00 「치매 케어 실무 교육」 일정이 있습니다.', 'type': 'general', 'relatedEntityId': 108, 'relatedEntityType': 'schedule', 'createdAt': iso(daysFromNow(-4, 18)), 'isRead': true},
      {'id': 8, 'title': '시스템', 'message': '새 버전 1.19.0이 출시되었습니다.', 'type': 'system', 'createdAt': iso(daysFromNow(-6, 10)), 'isRead': true},
    ];
