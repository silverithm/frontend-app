// 공지사항·전자결재(결재 문서·양식)
import 'fixtures.dart';
import 'fx_core.dart';

// ───────── 공지 ─────────
List<Map<String, dynamic>> notices() {
  Map<String, dynamic> n(int id, String title, String content, String pri, int days, int views,
          {bool pinned = false, String status = 'PUBLISHED', List<Map<String, dynamic>>? files}) =>
      {
        'id': id,
        'title': title,
        'content': content,
        'priority': pri,
        'status': status,
        'isPinned': pinned,
        'authorId': adminId,
        'authorName': '김관리',
        'companyId': 1,
        'viewCount': views,
        'createdAt': iso(daysFromNow(days, 9)),
        'updatedAt': iso(daysFromNow(days, 9)),
        'publishedAt': status == 'PUBLISHED' ? iso(daysFromNow(days, 9)) : null,
        'attachments': files ?? <dynamic>[],
      };
  return [
    n(1, '[필독] 안전점검의 날 안내', '이번 주 금요일 오전 10시에 전 직원 안전점검 교육이 있습니다.\n\n■ 일시: 금요일 10:00~12:00\n■ 장소: 프로그램실\n■ 준비물: 필기도구, 개인 이름표\n\n시설 내 소화기 위치 확인과 응급상황 대응 절차를 함께 점검합니다. 전원 참석 부탁드립니다.', 'HIGH', -1, 24,
        pinned: true,
        files: [
          {'id': 1, 'noticeId': 1, 'fileName': '안전점검_체크리스트.pdf', 'fileUrl': 'https://files.example/a.pdf', 'fileSize': 210000, 'createdAt': iso(daysFromNow(-1))},
        ]),
    n(2, '추석 연휴 운영 안내', '추석 연휴 기간 주간보호센터는 휴관합니다. 연휴 전날 귀가 차량 시간은 별도로 안내드립니다.', 'HIGH', -3, 41, pinned: true),
    n(3, '급여명세서 발급 안내', '이번 달 급여명세서는 25일 개별 발송됩니다. 메일 주소가 바뀐 분은 사무국에 알려주세요.', 'NORMAL', -5, 18),
    n(4, '프로그램실 에어컨 점검 완료', '프로그램실 에어컨 점검이 완료되었습니다. 이상이 있으면 알려주세요.', 'NORMAL', -7, 9),
    n(5, '요양보호사 보수교육 신청 안내', '보수교육 신청은 이번 달 말일까지입니다. 신청서는 전자결재로 제출해 주세요.', 'NORMAL', -9, 15),
    n(6, '차량 정기점검 일정', '배차 차량 정기점검이 있습니다. 해당일 오전 배차는 2호차로 대체됩니다.', 'LOW', -12, 7),
    n(7, '다음 달 회의 일정 초안', '정기 회의 일정 초안입니다. 검토 후 게시 예정.', 'NORMAL', -1, 0, status: 'DRAFT'),
  ];
}

// ───────── 결재 양식 ─────────
Map<String, dynamic> _tpl(int id, String name, String desc, String cat, String type, bool active,
    [List<Map<String, dynamic>>? fields]) {
  final hasForm = type != 'file';
  return {
    'id': id,
    'companyId': 1,
    'name': name,
    'description': desc,
    'category': cat,
    'fileUrl': type == 'form' ? null : 'https://files.example/t$id.hwp',
    'fileName': type == 'form' ? null : '$name.hwp',
    'fileSize': type == 'form' ? 0 : 245000,
    'isActive': active,
    'templateType': type,
    'formSchema': hasForm ? {'fields': fields ?? _defaultFields} : null,
    'defaultApprovalLine': '[{"approverType":"MEMBER","approverId":9,"name":"한소연","position":"사무원"},{"approverType":"ADMIN","approverId":1,"name":"김관리","position":"센터장"}]',
    'createdAt': iso(daysFromNow(-200)),
    'updatedAt': iso(daysFromNow(-100)),
  };
}

const List<Map<String, dynamic>> _defaultFields = [
  {'id': 'item', 'label': '지출 항목', 'type': 'text', 'width': 'twoThirds', 'required': true},
  {'id': 'amount', 'label': '금액(원)', 'type': 'number', 'width': 'third', 'required': true},
  {'id': 'usedAt', 'label': '사용 일자', 'type': 'date', 'width': 'half'},
  {
    'id': 'kind',
    'label': '결제 방법',
    'type': 'select',
    'width': 'half',
    'options': [
      {'value': 'card', 'label': '법인카드'},
      {'value': 'cash', 'label': '현금'},
    ]
  },
  {'id': 'sec1', 'label': '상세 내용', 'type': 'section'},
  {'id': 'reason', 'label': '사유', 'type': 'textarea', 'width': 'full', 'required': true},
];

List<Map<String, dynamic>> templates() => [
      _tpl(1, '연차 신청서', '휴가 사용 전 사전 신청', '인사', 'form', true, const [
        {'id': 'kind', 'label': '휴가 종류', 'type': 'select', 'width': 'half', 'required': true, 'options': [{'value': 'annual', 'label': '연차'}, {'value': 'half', 'label': '반차'}]},
        {'id': 'period', 'label': '기간', 'type': 'dateRange', 'width': 'half', 'required': true},
        {'id': 'reason', 'label': '사유', 'type': 'textarea', 'width': 'full'},
      ]),
      _tpl(2, '지출결의서', '비용 지출 전 결재', '회계', 'form', true),
      _tpl(3, '출장 신청서', '외부 교육·출장 사전 신청', '인사', 'form', true),
      _tpl(4, '비품 구매 요청서', '센터 운영 비품 구매 요청', '총무', 'form', true),
      _tpl(5, '차량 운행일지', '배차 차량 운행 기록', '총무', 'hybrid', true),
      _tpl(6, '교육 이수 확인서', '보수교육 이수 결과 첨부', '인사', 'file', true),
      _tpl(7, '장기요양기관 평가 대비 서류 일체_최종본_수정본(v3)', '평가 준비용 종합 서류 묶음', '평가', 'file', false),
      _tpl(8, '기관 운영위원회 회의록 양식', '월례 운영위원회 회의록', '총무', 'hybrid', false),
    ];

// ───────── 결재 문서 ─────────
List<Map<String, dynamic>> _line(List<(String, String, String, String)> steps, {String? rejectReason}) => [
      for (var i = 0; i < steps.length; i++)
        {
          'id': i + 1,
          'stepOrder': i + 1,
          'approverType': steps[i].$1,
          'approverId': steps[i].$2,
          'approverName': steps[i].$3,
          'roleLabel': i == steps.length - 1 ? 'FINAL' : 'REVIEWER',
          'status': steps[i].$4,
          'processedAt': steps[i].$4 == 'PENDING' ? null : iso(daysFromNow(-2, 10)),
          if (steps[i].$4 == 'REJECTED') 'rejectReason': rejectReason,
          if (steps[i].$4 == 'APPROVED' && i == 0) 'comment': '확인했습니다.',
        }
    ];

Map<String, dynamic> _doc(int id, int tpl, String title, String by, int byId, String status, int days, Map<String, dynamic> form,
        List<Map<String, dynamic>> line,
        {String? reason}) =>
    {
      'id': id,
      'companyId': 1,
      'templateId': tpl,
      'title': title,
      'requesterId': '$byId',
      'requesterName': by,
      'status': status,
      'formData': form,
      'createdAt': iso(daysFromNow(days, 13)),
      'updatedAt': iso(daysFromNow(days, 13)),
      'hasApprovalLine': line.isNotEmpty,
      'approvalLine': line,
      if (status == 'APPROVED' || status == 'REJECTED') 'processedAt': iso(daysFromNow(days + 1, 10)),
      if (status == 'APPROVED' || status == 'REJECTED') 'processedByName': '김관리',
      if (reason != null) 'rejectReason': reason,
      if (status != 'DRAFT') 'docNumber': '2026-$id',
      if (status != 'DRAFT') 'docNumberDisplay': '제2026-${id.toString().padLeft(3, '0')}호',
      'documentFooter': {
        'postalCode': '61945',
        'address': '광주광역시 서구 상무대로 120 햇살주간보호센터',
        'phoneNumber': '062-123-4567',
        'faxNumber': '062-123-4568',
        'contactEmail': 'admin@carev.kr',
        'disclosureType': '공개',
      },
      'viewers': <dynamic>[],
    };

List<Map<String, dynamic>> approvals() => [
      _doc(2, 2, '비품 구매 지출결의서', '한소연', 9, 'PENDING', -2,
          {'item': '프로그램실 물품(색칠 도구·점토)', 'amount': '182000', 'usedAt': ymd(daysFromNow(-2)), 'kind': 'card', 'reason': '프로그램실 소모품이 부족하여 구매합니다. 견적서는 첨부 파일을 확인해 주세요.'},
          _line([('ADMIN', adminId, '김관리', 'PENDING')])),
      _doc(3, 3, '보수교육 참석 출장 신청서', '조은비', 7, 'PENDING', -1,
          {'item': '광주 평생교육원 보수교육', 'amount': '30000', 'usedAt': ymd(daysFromNow(4)), 'kind': 'card', 'reason': '요양보호사 보수교육 참석'},
          _line([('MEMBER', '9', '한소연', 'APPROVED'), ('ADMIN', adminId, '김관리', 'PENDING')])),
      _doc(1, 1, '김민지 연차 신청서', '김민지', 1, 'APPROVED', -6,
          {'kind': 'annual', 'period': {'start': ymd(daysFromNow(3)), 'end': ymd(daysFromNow(3))}, 'reason': '개인 사유'},
          _line([('ADMIN', adminId, '김관리', 'APPROVED')])),
      _doc(4, 1, '박지훈 연차 신청서', '박지훈', 3, 'REJECTED', -8,
          {'kind': 'annual', 'period': {'start': ymd(daysFromNow(-5)), 'end': ymd(daysFromNow(-5))}, 'reason': '개인 사유'},
          _line([('ADMIN', adminId, '김관리', 'REJECTED')], rejectReason: '해당 주 근무 인원 부족'),
          reason: '해당 주 근무 인원 부족'),
      _doc(5, 4, '정수기 필터 구매 요청', '임재현', 10, 'APPROVED', -7,
          {'item': '정수기 필터 3개', 'amount': '96000', 'reason': '교체 주기 도래'},
          _line([('ADMIN', adminId, '김관리', 'APPROVED')])),
      _doc(6, 5, '차량 운행일지', '오하늘', 11, 'DRAFT', 0, {'item': '2호차'}, const []),
    ];

void registerDocs() {
  final on = FixtureRouter.on;
  final role = FixtureRouter.role;

  on('GET', '/v1/notices', (u, b, m) => {'notices': notices(), 'totalPages': 1});
  on('GET', '/v1/notices/published', (u, b, m) => {'notices': notices().where((n) => n['status'] == 'PUBLISHED').toList(), 'totalPages': 1});
  on('GET', '/v1/notices/unread-count', (u, b, m) => {'unreadCount': 2});
  on('GET', '/v1/notices/\\d+', (u, b, m) {
    final id = int.parse(u.pathSegments.last);
    return {'notice': notices().firstWhere((n) => n['id'] == id, orElse: () => notices().first)};
  });
  on('GET', '/v1/notices/\\d+/comments', (u, b, m) => {
        'comments': [
          {'id': 1, 'noticeId': 1, 'authorId': '4', 'authorName': '최유진', 'content': '확인했습니다. 참석하겠습니다!', 'createdAt': iso(DateTime.now().subtract(const Duration(hours: 3)))},
          {'id': 2, 'noticeId': 1, 'authorId': '2', 'authorName': '이서연', 'content': '체크리스트는 몇 부 출력해 갈까요?', 'createdAt': iso(DateTime.now().subtract(const Duration(hours: 1)))},
        ]
      });
  on('GET', '/v1/notices/\\d+/readers', (u, b, m) => {
        'readers': [
          for (final s in staff.take(6)) {'id': s.$1, 'noticeId': 1, 'userId': '${s.$1}', 'userName': s.$2, 'readAt': iso(daysFromNow(0, 8 + s.$1 % 3))}
        ]
      });

  on('GET', '/v1/approvals', (u, b, m) => {'approvals': approvals(), 'totalPages': 1});
  on('GET', '/v1/approvals/my', (u, b, m) {
    final mine = approvals().where((a) => a['requesterId'] == '1' || role == Role.adm).toList();
    // 직원 화면: 내 문서 + 내 차례인 문서가 함께 보이도록 한 건 더
    return {'approvals': role == Role.emp ? [...mine, ...approvals().where((a) => a['requesterName'] != '김민지').take(3)] : mine, 'totalPages': 1};
  });
  on('GET', '/v1/approvals/\\d+', (u, b, m) {
    final id = int.parse(u.pathSegments.last);
    return {'approval': approvals().firstWhere((a) => a['id'] == id, orElse: () => approvals().first)};
  });
  on('GET', '/v1/approval-templates', (u, b, m) => {'templates': templates()});
  on('GET', '/v1/approval-templates/active', (u, b, m) => {'templates': templates().where((t) => t['isActive'] == true).toList()});
  on('GET', '/v1/approval-templates/\\d+', (u, b, m) {
    final id = int.parse(u.pathSegments.last);
    return templates().firstWhere((t) => t['id'] == id, orElse: () => templates().first);
  });
  on('GET', '/v1/signatures/me', (u, b, m) => {'signatureUrl': null});
}
