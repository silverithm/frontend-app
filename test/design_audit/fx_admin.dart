// 어르신·배차·회의록·자료실·고충함·커뮤니티·구독 결제
import 'dart:convert';

import 'fixtures.dart';
import 'fx_core.dart';

const _elderNames = ['김영희', '박순자', '이말순', '최정숙', '정옥순', '한금례', '강영자', '윤말자'];

List<Map<String, dynamic>> elders() => [
      for (var i = 0; i < _elderNames.length; i++)
        {
          'id': i + 1,
          'name': _elderNames[i],
          'homeAddressName': '광주광역시 서구 상무대로 ${120 + i}',
          'careProfile': {
            'residentNumberMasked': '4${i}0203-2******',
            'birthDate': '194$i-02-03',
            'gender': 'FEMALE',
            'age': 84 - i,
            'careGrade': ['GRADE_2', 'GRADE_3', 'GRADE_1', 'COGNITIVE_SUPPORT'][i % 4],
            'fallRisk': i % 3 == 0,
            'fallNote': i % 3 == 0 ? '보행 시 부축 필요, 화장실 이동 시 동행' : null,
            'pressureSore': i == 2,
            'pressureSoreNote': i == 2 ? '엉덩이 쪽 2단계, 체위 변경 2시간마다' : null,
            'diaperType': i % 2 == 0 ? 'PAD' : null,
            'diaperIntermittent': i % 2 == 0,
            'cognitionLevel': ['NORMAL', 'MILD', 'MODERATE', 'MILD'][i % 4],
            'cognitionNote': i % 4 == 2 ? '오후에 배회 증상, 시간 안내 필요' : null,
            'mealType': ['REGULAR', 'CHOPPED', 'PORRIDGE', 'REGULAR'][i % 4],
            'morningSnack': true,
            'afternoonSnack': true,
            'dinner': i % 2 == 0,
            'mealNote': i == 1 ? '견과류 알레르기' : null,
            'bathTime': i % 3 == 0 ? '화·금 오전' : null,
            'medMorning': true,
            'medMorningTime': '08:30',
            'medLunch': i % 2 == 1,
            'medLunchTime': i % 2 == 1 ? '12:30' : null,
            'medEvening': false,
            'medNote': i == 0 ? '혈압약 식후 30분' : null,
            'vehicleNote': i == 2 ? '앞좌석 탑승 필요(멀미)' : null,
            'floor': 1 + i % 4,
            'seatNote': null,
            'careNote': i == 0 ? '대화를 좋아하시고 노래 부르기 프로그램 선호' : null,
            'updatedAt': iso(daysFromNow(-10)),
          },
        }
    ];

Map<String, dynamic> _dispatchSettings() => {
      'routes': [
        {'id': 'r1', 'name': '1호차(등원)', 'type': '등원', 'routeDrivers': [{'driverId': '3', 'driverName': '박지훈', 'vehicleName': '1호차', 'vehicleCapacity': 8}]},
        {'id': 'r2', 'name': '2호차(등원)', 'type': '등원', 'routeDrivers': [{'driverId': '11', 'driverName': '오하늘', 'vehicleName': '2호차', 'vehicleCapacity': 6}]},
        {'id': 'r3', 'name': '1호차(하원)', 'type': '하원', 'routeDrivers': [{'driverId': '3', 'driverName': '박지훈', 'vehicleName': '1호차', 'vehicleCapacity': 8}]},
        {'id': 'r4', 'name': '2호차(하원)', 'type': '하원', 'routeDrivers': [{'driverId': '11', 'driverName': '오하늘', 'vehicleName': '2호차', 'vehicleCapacity': 6}]},
      ],
      'seniors': [
        for (var i = 0; i < 8; i++) ...[
          {'id': 's${i}a', 'name': _elderNames[i], 'routeId': i < 4 ? 'r1' : 'r2', 'boardingOrder': (i % 4) + 1, 'elderlyId': i + 1},
          {'id': 's${i}b', 'name': _elderNames[i], 'routeId': i < 4 ? 'r3' : 'r4', 'boardingOrder': (i % 4) + 1, 'elderlyId': i + 1},
        ]
      ],
      'seniorAbsences': <dynamic>[],
    };

Map<String, dynamic> _minutes(int id) {
  final ended = id != 3;
  return {
    'id': id,
    'title': const {1: '정기 직원 회의', 2: '운영위원회 월례 회의', 3: '요양보호사 1팀 주간 회의', 4: '보호자 간담회 준비 회의'}[id],
    'location': '프로그램실',
    'authorType': 'ADMIN',
    'authorRefId': 1,
    'authorName': '김관리',
    'meetingStartAt': iso(daysFromNow(-id * 2, 14)),
    'meetingEndAt': iso(daysFromNow(-id * 2, 15)),
    'status': const {1: 'COMPLETED', 2: 'REGISTERED', 3: 'IN_PROGRESS', 4: 'REGISTERED'}[id],
    'signedCount': const {1: 8, 2: 3, 3: 0, 4: 2}[id],
    'attendeeCount': const {1: 8, 2: 5, 3: 6, 4: 4}[id],
    'myAttendeeId': id == 2 ? 1 : null,
    'mySignedAt': null,
    'createdAt': iso(daysFromNow(-id * 2, 15)),
    'completedAt': ended && id == 1 ? iso(daysFromNow(-2)) : null,
    'sectionsJson': jsonEncode([
      {'label': '안건', 'content': '1. 10월 행사 일정 확인\n2. 겨울철 낙상 예방 점검 계획\n3. 직원 교육 일정 조정'},
      {'label': '논의 내용', 'content': '- 노인의 날 행사는 오전 프로그램실에서 진행하고, 보호자 초청은 별도 안내한다.\n- 겨울철 복도 미끄럼 방지 매트를 추가로 구입한다.'},
      {'label': '결정 사항', 'content': '매트 구입은 이번 주 안에 지출결의서로 올리고, 교육은 다음 달 둘째 주로 확정한다.'},
    ]),
    'attendees': [
      {'id': 1, 'attendeeType': 'ADMIN', 'refId': 1, 'attendeeName': '김관리', 'signedAt': iso(daysFromNow(-id * 2, 16)), 'signatureUrl': 'https://files.example/sig.png'},
      {'id': 2, 'attendeeType': 'MEMBER', 'refId': 1, 'attendeeName': '김민지', 'signedAt': id == 2 ? null : iso(daysFromNow(-id * 2, 16))},
      {'id': 3, 'attendeeType': 'MEMBER', 'refId': 2, 'attendeeName': '이서연', 'signedAt': iso(daysFromNow(-id * 2, 16))},
      {'id': 4, 'attendeeType': 'MEMBER', 'refId': 9, 'attendeeName': '한소연', 'signedAt': null},
      {'id': 5, 'attendeeType': 'EXTERNAL', 'refId': null, 'attendeeName': '박보호(보호자 대표)', 'signedAt': null},
    ],
  };
}

List<Map<String, dynamic>> _library() => [
      {'id': 1, 'category': '서식', 'title': '급여제공기록지 양식', 'description': '일일 급여제공기록지 표준 양식', 'fileName': '급여제공기록지_양식.hwp', 'fileSize': 88000, 'filePath': '/files/lib/1.hwp', 'uploaderName': '김관리', 'createdAt': iso(daysFromNow(-250))},
      {'id': 2, 'category': '매뉴얼', 'title': '응급상황 대응 매뉴얼', 'description': '낙상·질식 등 응급 대응 절차', 'fileName': '응급상황_대응_매뉴얼.pdf', 'fileSize': 512000, 'filePath': '/files/lib/2.pdf', 'uploaderName': '한소연', 'createdAt': iso(daysFromNow(-200))},
      {'id': 3, 'category': '서식', 'title': '차량 운행일지 양식', 'description': null, 'fileName': '차량_운행일지.xlsx', 'fileSize': 34000, 'filePath': '/files/lib/3.xlsx', 'uploaderName': '오하늘', 'createdAt': iso(daysFromNow(-170))},
      {'id': 4, 'category': '교육자료', 'title': '치매 케어 실무 교육 자료', 'description': '9월 보수교육 슬라이드', 'fileName': '치매케어_실무교육.pptx', 'fileSize': 2100000, 'filePath': '/files/lib/4.pptx', 'uploaderName': '조은비', 'createdAt': iso(daysFromNow(-40))},
      {'id': 5, 'category': '매뉴얼', 'title': '개인정보 보호 지침', 'description': '어르신·직원 개인정보 취급 지침', 'fileName': '개인정보_보호_지침.pdf', 'fileSize': 210000, 'filePath': '/files/lib/5.pdf', 'uploaderName': '김관리', 'createdAt': iso(daysFromNow(-120))},
      {'id': 6, 'category': null, 'title': '상반기 만족도 조사 결과', 'description': null, 'fileName': '만족도조사_상반기.xlsx', 'fileSize': 76000, 'filePath': '/files/lib/6.xlsx', 'uploaderName': '임재현', 'createdAt': iso(daysFromNow(-90))},
    ];

List<Map<String, dynamic>> _voice({required bool mine}) {
  final all = [
    {'id': 1, 'type': 'GRIEVANCE', 'isAnonymous': true, 'authorName': null, 'title': '휴게시간 관련 건의', 'content': '점심시간이 너무 짧게 느껴집니다. 조정 부탁드립니다.', 'status': 'RESOLVED', 'adminReply': '이번 달부터 점심시간을 50분으로 조정했습니다.', 'repliedAt': iso(daysFromNow(-20)), 'createdAt': iso(daysFromNow(-25))},
    {'id': 2, 'type': 'SUGGESTION', 'isAnonymous': false, 'authorName': '이서연', 'title': '프로그램실 비품 추가 요청', 'content': '색칠 도구를 더 다양하게 구비하면 좋겠습니다.', 'status': 'IN_REVIEW', 'adminReply': null, 'createdAt': iso(daysFromNow(-12))},
    {'id': 3, 'type': 'GRIEVANCE', 'isAnonymous': true, 'authorName': null, 'title': '주차 공간 부족', 'content': '출근 시간대 주차 공간이 부족합니다.', 'status': 'RECEIVED', 'adminReply': null, 'createdAt': iso(daysFromNow(-6))},
    {'id': 4, 'type': 'SUGGESTION', 'isAnonymous': false, 'authorName': '윤성민', 'title': '행사 사진 공유 방식 개선', 'content': '행사 사진을 채팅방 앨범으로 모아주시면 좋겠습니다.', 'status': 'ON_HOLD', 'adminReply': '다음 업데이트에 검토 예정입니다.', 'repliedAt': iso(daysFromNow(-9)), 'createdAt': iso(daysFromNow(-10))},
    {'id': 5, 'type': 'GRIEVANCE', 'isAnonymous': false, 'authorName': '박지훈', 'title': '야간 근무자 간식 지원 요청', 'content': '야간 대기 근무 시 간식 지원을 요청드립니다.', 'status': 'IN_REVIEW', 'adminReply': null, 'createdAt': iso(daysFromNow(-3))},
  ];
  return mine ? all.take(3).toList() : all;
}

List<Map<String, dynamic>> _posts() => [
      {'id': 1, 'board': 'qna', 'title': '야간보호 어르신 낙상 예방, 다들 어떻게 하시나요?', 'preview': '최근 낙상 사고가 있어서 환경 점검을 다시 하려고 합니다. 매트나 손잡이 외에 효과 있었던 방법 공유 부탁드려요.', 'displayAuthor': '햇살센터 사회복지사', 'isPinned': false, 'hasAccepted': true, 'viewCount': 182, 'likeCount': 12, 'commentCount': 6, 'createdAt': iso(daysFromNow(-1, 14))},
      {'id': 2, 'board': 'free', 'title': '[운영] 커뮤니티 이용 안내', 'preview': '서로 존중하는 대화를 부탁드립니다. 개인정보와 어르신 실명은 올리지 마세요.', 'displayAuthor': '케어브이 운영자', 'isPinned': true, 'viewCount': 640, 'likeCount': 31, 'commentCount': 2, 'createdAt': iso(daysFromNow(-30))},
      {'id': 3, 'board': 'review', 'title': '전자결재 도입 후기 — 서류 시간이 절반으로', 'preview': '종이 서류로 돌리던 지출결의서를 전자결재로 바꿨더니 결재 대기 시간이 확 줄었어요.', 'displayAuthor': '해든주간보호 원장', 'viewCount': 301, 'likeCount': 24, 'commentCount': 9, 'createdAt': iso(daysFromNow(-3, 10))},
      {'id': 4, 'board': 'job_offer', 'title': '[광주 서구] 요양보호사 모집 (주 5일, 09~18시)', 'preview': '주간보호센터에서 요양보호사 선생님을 모십니다. 운전 가능자 우대.', 'displayAuthor': '무등주간보호', 'viewCount': 412, 'likeCount': 3, 'commentCount': 1, 'createdAt': iso(daysFromNow(-4, 9))},
      {'id': 5, 'board': 'free', 'title': '가을 나들이 프로그램 아이디어 공유합니다', 'preview': '근교 공원 산책과 단풍 만들기 프로그램을 했는데 반응이 좋았습니다.', 'displayAuthor': '소망주간보호', 'viewCount': 96, 'likeCount': 8, 'commentCount': 4, 'createdAt': iso(daysFromNow(-5, 16))},
    ];

void registerAdmin() {
  final on = FixtureRouter.on;

  on('GET', '/v1/elders/company/\\d+', (u, b, m) => {'elders': elders()});
  on('GET', '/v1/dispatch-settings', (u, b, m) => _dispatchSettings());
  on('GET', '/v1/attendance/elder/range', (u, b, m) => {
        'attendances': [
          for (var i = 0; i < 8; i++)
            {'elderlyId': i + 1, 'date': ymd(today()), 'status': i >= 6 ? 'ABSENT' : 'PRESENT', 'personalPickup': i == 2, 'personalDropoff': false}
        ]
      });
  on('GET', '/v1/dispatch-overrides/range', (u, b, m) => {'days': <String, dynamic>{}});
  on('GET', '/v1/dispatch-settings/driver-roles', (u, b, m) => {'roles': <dynamic>[]});

  on('GET', '/v1/meeting-minutes', (u, b, m) => {'items': [for (var i = 1; i <= 4; i++) _minutes(i)]});
  on('GET', '/v1/meeting-minutes/\\d+', (u, b, m) => {'minutes': _minutes(int.parse(u.pathSegments.last))});

  on('GET', '/v1/company-library', (u, b, m) => {'items': _library()});

  on('GET', '/v1/voice-box', (u, b, m) => {'messages': _voice(mine: u.queryParameters['scope'] == 'mine')});

  on('GET', '/v1/plaza/posts', (u, b, m) => {'content': _posts()});
  on('GET', '/v1/plaza/posts/\\d+', (u, b, m) {
    final id = int.parse(u.pathSegments.last);
    final p = _posts().firstWhere((e) => e['id'] == id, orElse: () => _posts().first);
    return {
      'post': {
        ...p,
        'content':
            '<p>최근 낙상 사고가 있어서 환경 점검을 다시 하려고 합니다.</p><p>매트나 손잡이 외에 <b>효과가 있었던 방법</b>이 있으면 공유 부탁드려요.</p><ul><li>복도 조도 개선</li><li>미끄럼 방지 양말 착용</li></ul>',
        'likeCount': 12,
        'likedByMe': false,
        'comments': [
          {'id': 1, 'displayAuthor': '무등주간보호 요양보호사', 'content': '이동 동선에 물건을 두지 않는 것만으로도 효과가 컸어요. 화장실 앞 센서등도 추천합니다.', 'isAccepted': true, 'isMine': false, 'createdAt': iso(daysFromNow(-1, 15))},
          {'id': 2, 'displayAuthor': '소망주간보호', 'content': '저희는 이용자별 낙상 위험도를 표시한 명찰을 사용합니다.', 'isAccepted': false, 'isMine': false, 'createdAt': iso(daysFromNow(-1, 17))},
        ],
      }
    };
  });
  on('GET', '/v1/plaza/notices', (u, b, m) => {'notices': <dynamic>[]});
  on('GET', '/v1/news', (u, b, m) => {
        'content': [
          {'title': '내년 장기요양 수가 인상 확정…주간보호 3.2%', 'url': 'https://news.example/1', 'source': '요양뉴스', 'publishedAt': iso(daysFromNow(-1, 9))},
          {'title': '치매 어르신 낙상 예방 환경 가이드 개정', 'url': 'https://news.example/2', 'source': '실버타임즈', 'publishedAt': iso(daysFromNow(-2, 11))},
          {'title': '요양보호사 처우 개선 방안 발표', 'url': 'https://news.example/3', 'source': '복지일보', 'publishedAt': iso(daysFromNow(-4, 8))},
        ]
      });
  on('GET', '/v1/external-notices', (u, b, m) => {
        'content': [
          {'id': 1, 'source': 'LTC_NOTICE', 'sourceLabel': '공지사항', 'title': '장기요양기관 평가 일정 안내', 'url': 'https://ltc.example/1', 'postedDate': ymd(daysFromNow(-2))},
          {'id': 2, 'source': 'LTC_EVAL', 'sourceLabel': '평가 매뉴얼', 'title': '재가급여 평가 매뉴얼 개정본', 'url': 'https://ltc.example/2', 'postedDate': ymd(daysFromNow(-6))},
          {'id': 3, 'source': 'LTC_EDU', 'sourceLabel': '기관종사자 교육', 'title': '종사자 직무교육 수강 신청 안내', 'url': 'https://ltc.example/3', 'postedDate': ymd(daysFromNow(-9))},
        ],
        'last': true,
        'totalPages': 1,
      });
  on('GET', '/v1/plaza/library/access', (u, b, m) => {'allowed': true});
  on('GET', '/v1/plaza/library', (u, b, m) => {
        'content': [
          {'id': 1, 'category': '서식', 'title': '낙상 사고 보고서 양식', 'description': '낙상 발생 시 작성하는 표준 보고서', 'fileName': '낙상사고_보고서.hwp', 'fileSize': 92000, 'downloadCount': 148, 'isMine': false},
          {'id': 2, 'category': '평가', 'title': '평가 대비 체크리스트 2026', 'description': '재가급여 평가 항목별 점검표', 'fileName': '평가_체크리스트.xlsx', 'fileSize': 310000, 'downloadCount': 96, 'isMine': true},
          {'id': 3, 'category': '프로그램', 'title': '가을 인지활동 프로그램 모음', 'description': null, 'fileName': '인지활동_프로그램.pptx', 'fileSize': 4200000, 'downloadCount': 57, 'isMine': false},
        ]
      });

  on('GET', '/v1/subscriptions/payment-failures', (u, b, m) => {
        'content': <dynamic>[], 'last': true, 'totalPages': 0, 'totalElements': 0, 'size': 10, 'number': 0, 'first': true,
      });
  on('GET', '/v1/users/push-enabled', (u, b, m) => {'pushEnabled': true});
  on('GET', '/v1/chat/rooms/\\d+/files', (u, b, m) => {'files': <dynamic>[]});
  on('POST', '/v1/chat/rooms/\\d+/read', (u, b, m) => {});
  on('POST', '/v1/notices/\\d+/(view|readers)', (u, b, m) => {});
}
