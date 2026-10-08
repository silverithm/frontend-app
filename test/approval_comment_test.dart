import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/approval.dart';
import 'package:frontend_app/utils/approval_comment.dart';

/// 결재 승인 의견: 서버 계약(공백 제거·빈 값 생략·1000자)과 결재선 단계 파싱을 고정한다.
void main() {
  group('normalizeApprovalComment', () {
    test('앞뒤 공백을 지우고 비면 null', () {
      expect(normalizeApprovalComment('  확인했습니다 \n'), '확인했습니다');
      expect(normalizeApprovalComment('   '), isNull);
      expect(normalizeApprovalComment(null), isNull);
    });

    test('1000자까지는 통과, 넘으면 초과 (공백 패딩은 세지 않음)', () {
      expect(isApprovalCommentTooLong('가' * kApprovalCommentMaxLength), isFalse);
      expect(isApprovalCommentTooLong('가' * (kApprovalCommentMaxLength + 1)), isTrue);
      expect(isApprovalCommentTooLong(' ${'가' * kApprovalCommentMaxLength} '), isFalse);
    });
  });

  group('buildApproveBody', () {
    test('서명·의견이 없으면 본문 없음', () {
      expect(buildApproveBody(), isNull);
      expect(buildApproveBody(comment: '  ', signatureBase64: ''), isNull);
    });

    test('의견만 / 서명만 / 둘 다', () {
      expect(buildApproveBody(comment: ' 검토 완료 '), {'comment': '검토 완료'});
      expect(buildApproveBody(signatureBase64: 'data:x'), {'signatureBase64': 'data:x'});
      expect(
        buildApproveBody(signatureBase64: 'data:x', comment: 'ok'),
        {'signatureBase64': 'data:x', 'comment': 'ok'},
      );
    });
  });

  group('ApprovalStepModel.comment', () {
    Map<String, dynamic> json(Map<String, dynamic> extra) => {
          'id': 1,
          'stepOrder': 1,
          'approverType': 'MEMBER',
          'approverId': '7',
          'approverName': '김팀장',
          'roleLabel': 'REVIEWER',
          'status': 'APPROVED',
          ...extra,
        };

    test('comment를 읽는다', () {
      expect(ApprovalStepModel.fromJson(json({'comment': '확인했습니다'})).comment, '확인했습니다');
    });

    test('없거나 null이면 null (옛 응답과 호환)', () {
      expect(ApprovalStepModel.fromJson(json({})).comment, isNull);
      expect(ApprovalStepModel.fromJson(json({'comment': null})).comment, isNull);
    });

    test('rejectReason과 섞이지 않는다', () {
      final step = ApprovalStepModel.fromJson(json({'rejectReason': '사유', 'comment': '의견'}));
      expect(step.rejectReason, '사유');
      expect(step.comment, '의견');
    });
  });
}
