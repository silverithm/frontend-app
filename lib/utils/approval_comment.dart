/// 결재 승인 의견(코멘트) 정리 규칙 — 서버 계약과 같다.
/// 앞뒤 공백 제거, 비면 보내지 않음, 최대 1000자.
const int kApprovalCommentMaxLength = 1000;

/// 보낼 값으로 정리한다. 비어 있으면 null(본문에서 생략).
String? normalizeApprovalComment(String? raw) {
  final trimmed = raw?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

/// 정리한 뒤 길이가 한도를 넘는지
bool isApprovalCommentTooLong(String? raw) =>
    (normalizeApprovalComment(raw)?.length ?? 0) > kApprovalCommentMaxLength;

/// 승인 요청 본문. 서명·의견이 모두 없으면 null(본문 없이 전송).
Map<String, dynamic>? buildApproveBody({String? signatureBase64, String? comment}) {
  final normalized = normalizeApprovalComment(comment);
  final hasSignature = signatureBase64 != null && signatureBase64.isNotEmpty;
  if (!hasSignature && normalized == null) return null;
  return {
    if (hasSignature) 'signatureBase64': signatureBase64,
    if (normalized != null) 'comment': normalized,
  };
}
