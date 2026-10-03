import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/approval.dart';
import 'package:frontend_app/providers/approval_provider.dart';

/// 하단 전자결재 배지와 결재 관리 탭 배지가 세는 "내 차례" 규약을 고정한다.
/// 예전 배지는 회사 전체 대기 결재를 셌다 — 결재선에서 남의 차례인 문서까지 들어가
/// 관리자 화면에 "승인할 게 없는데 숫자가 뜬다"는 제보가 왔다.
ApprovalStepModel _step(int order, String approverId, String status) {
  return ApprovalStepModel(
    id: order,
    stepOrder: order,
    approverType: approverId.startsWith('admin_') ? 'ADMIN' : 'MEMBER',
    approverId: approverId,
    approverName: '결재자$order',
    roleLabel: 'REVIEWER',
    status: status,
  );
}

ApprovalRequest _request({
  ApprovalStatus status = ApprovalStatus.pending,
  List<ApprovalStepModel> line = const [],
}) {
  return ApprovalRequest(
    id: 1,
    companyId: 1,
    templateId: 1,
    title: '위생용품 구매 신청',
    requesterId: '9',
    requesterName: '신청자',
    status: status,
    createdAt: DateTime(2026, 10, 1),
    updatedAt: DateTime(2026, 10, 1),
    hasApprovalLine: line.isNotEmpty,
    approvalLine: line,
  );
}

void main() {
  final provider = ApprovalProvider();

  test('관리자라도 결재선에서 다른 사람 차례인 대기 문서는 내 차례가 아니다', () {
    final r = _request(line: [
      _step(1, '7', 'PENDING'), // 팀장(직원 7) 검토 대기
      _step(2, 'admin_1', 'PENDING'),
    ]);
    expect(provider.isMyTurn(r, myId: '1', isAdmin: true), isFalse);
  });

  test('앞 단계가 끝나 현재 단계가 나(관리자형 id)면 내 차례다', () {
    final r = _request(line: [
      _step(1, '7', 'APPROVED'),
      _step(2, 'admin_1', 'PENDING'),
    ]);
    expect(provider.isMyTurn(r, myId: '1', isAdmin: true), isTrue);
  });

  test('결재선 없는 옛 대기 문서는 관리자만 처리할 차례로 본다', () {
    final r = _request();
    expect(provider.isMyTurn(r, myId: '1', isAdmin: true), isTrue);
    expect(provider.isMyTurn(r, myId: '7', isAdmin: false), isFalse);
  });

  test('이미 끝난 문서는 누구의 차례도 아니다', () {
    final r = _request(
      status: ApprovalStatus.approved,
      line: [_step(1, 'admin_1', 'APPROVED')],
    );
    expect(provider.isMyTurn(r, myId: '1', isAdmin: true), isFalse);
  });

  test('불러온 결재가 없으면 배지는 0이다', () {
    expect(provider.myTurnCount(myId: '1', isAdmin: true), 0);
  });
}
