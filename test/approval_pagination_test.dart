import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/providers/approval_provider.dart';
import 'package:frontend_app/services/api_service.dart';

Map<String, dynamic> _doc(int id, String requesterId) => {
  'id': id,
  'companyId': 1,
  'templateId': 1,
  'title': '문서$id',
  'requesterId': requesterId,
  'requesterName': '기안자',
  'status': 'PENDING',
  'createdAt': '2026-10-20T09:00:00',
  'updatedAt': '2026-10-20T09:00:00',
};

/// 결재함(기관)과 내 결재를 따로 흉내 낸다 — 각각 몇 쪽인지 정할 수 있다
class _FakeApprovalApi implements ApiService {
  int inboxPages = 1;
  int minePages = 1;
  final List<String> calls = [];

  @override
  Future<Map<String, dynamic>> getApprovalRequests({
    required String companyId,
    String? status,
    int page = 0,
    int size = 20,
  }) async {
    calls.add('inbox:$page');
    return {
      'content': [_doc(100 + page, '7')],
      'totalPages': inboxPages,
    };
  }

  @override
  Future<Map<String, dynamic>> getMyApprovalRequests({
    required String requesterId,
    String? status,
    int page = 0,
    int size = 20,
  }) async {
    calls.add('mine:$page');
    return {
      'content': [_doc(200 + page, requesterId)],
      'totalPages': minePages,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeApprovalApi api;
  late ApprovalProvider provider;

  setUp(() {
    api = _FakeApprovalApi();
    provider = ApprovalProvider(apiService: api);
  });

  test('결재함을 먼저 다 받아도 내 결재 첫 목록은 받는다 — 결재 신청 탭이 비어 보이던 것', () async {
    // 관리자 앱 시작: 결재함만 새로 받음(한 쪽뿐이라 결재함은 '더 없음')
    await provider.loadApprovalRequests(companyId: '1', refresh: true);
    expect(provider.hasMore, isFalse);

    // 결재 신청 탭 첫 진입: refresh 없이 부른다
    await provider.loadMyApprovalRequests(requesterId: 'admin_1');

    expect(api.calls, ['inbox:0', 'mine:0']);
    expect(provider.myApprovalRequests.map((r) => r.id), [200]);
    expect(provider.approvalRequests.map((r) => r.id), [100]);
  });

  test('두 목록의 쪽 번호가 서로 밀지 않는다', () async {
    api.inboxPages = 3;
    api.minePages = 2;

    await provider.loadApprovalRequests(companyId: '1', refresh: true); // inbox 0
    await provider.loadApprovalRequests(companyId: '1'); // inbox 1
    await provider.loadMyApprovalRequests(requesterId: '9', refresh: true); // mine 0
    await provider.loadMyApprovalRequests(requesterId: '9'); // mine 1
    await provider.loadMyApprovalRequests(requesterId: '9'); // 더 없음 — 부르지 않는다
    await provider.loadApprovalRequests(companyId: '1'); // inbox 2

    expect(api.calls, ['inbox:0', 'inbox:1', 'mine:0', 'mine:1', 'inbox:2']);
    expect(provider.myHasMore, isFalse);
    expect(provider.hasMore, isFalse);
  });

  test('reset하면 두 목록 모두 처음부터', () async {
    await provider.loadApprovalRequests(companyId: '1', refresh: true);
    await provider.loadMyApprovalRequests(requesterId: '9', refresh: true);
    provider.reset();
    await provider.loadMyApprovalRequests(requesterId: '9');
    await provider.loadApprovalRequests(companyId: '1');
    expect(api.calls.sublist(2), ['mine:0', 'inbox:0']);
  });
}
