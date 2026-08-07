import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/approval.dart';

/// 표준 기안문(공문) 형태의 결재 문서 뷰 (모바일 축약판).
/// 웹 관리자와 동일한 구성: 기관명 레터헤드 → 문서번호/일자 + 결재란 → 제목 → 본문 → 발신명의(직인) → 붙임
class OfficialDocumentView extends StatelessWidget {
  final ApprovalRequest approval;
  final ApprovalTemplate? template;
  final String companyName;

  const OfficialDocumentView({
    super.key,
    required this.approval,
    this.template,
    required this.companyName,
  });

  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);
  static const _line = Color(0xFF9CA3AF);

  String _formatDate(DateTime? date) =>
      date == null ? '-' : DateFormat('yyyy년 MM월 dd일').format(date);

  String _formatShort(DateTime? date) =>
      date == null ? '' : DateFormat('yy.MM.dd').format(date);

  String _formatDotted(DateTime? date) =>
      date == null ? '' : DateFormat('yyyy . MM. dd.').format(date);

  @override
  Widget build(BuildContext context) {
    final isApproved = approval.status == ApprovalStatus.approved;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 레터헤드
          Center(
            child: Text(
              companyName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 2, color: _ink),
          const SizedBox(height: 12),

          // 문서정보
          Text('문서번호 : ${approval.docNumberDisplay ?? approval.docNumber ?? '-'}',
              style: const TextStyle(fontSize: 11, color: _muted)),
          Text('기안일자 : ${_formatDate(approval.createdAt)}',
              style: const TextStyle(fontSize: 11, color: _muted)),
          Text('시행일자 : ${isApproved ? _formatDate(approval.processedAt) : '-'}',
              style: const TextStyle(fontSize: 11, color: _muted)),
          const SizedBox(height: 12),

          // 결재란
          Align(
            alignment: Alignment.centerRight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildApprovalTable(),
            ),
          ),
          const SizedBox(height: 16),

          // 제목
          Center(
            child: Text(
              approval.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 반려 사유
          if (approval.status == ApprovalStatus.rejected &&
              (approval.rejectReason?.isNotEmpty ?? false)) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                border: Border.all(color: const Color(0xFFFCA5A5)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '반려 사유: ${approval.rejectReason}',
                style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 본문
          if (approval.formData != null && approval.formData!.isNotEmpty)
            _buildFieldsTable()
          else
            const Text(
              '위 건에 대하여 붙임과 같이 기안하오니 결재하여 주시기 바랍니다.\n(본문: 별첨 문서 참조)',
              style: TextStyle(fontSize: 13, height: 1.7, color: _muted),
            ),
          const SizedBox(height: 28),

          // 발신명의 + 직인
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Text(
                  companyName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    color: _ink,
                  ),
                ),
                if (isApproved && approval.companySealUrl != null)
                  Positioned(
                    right: -34,
                    top: -16,
                    child: Opacity(
                      opacity: 0.9,
                      child: Image.network(
                        approval.companySealUrl!,
                        width: 52,
                        height: 52,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 붙임
          if (approval.attachmentFileName != null) ...[
            const SizedBox(height: 20),
            Container(height: 1, color: const Color(0xFFD1D5DB)),
            const SizedBox(height: 8),
            Text(
              '붙임 : ${approval.attachmentFileName} 1부. 끝.',
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
          ],

          // 발신부 — 표준 공문 하단 시행/접수·주소·연락처 (값이 없으면 통째로 생략)
          _buildFooter(isApproved),
        ],
      ),
    );
  }

  /// 공문 하단 발신부. 기관 정보가 하나도 없고 문서번호도 없으면 아예 렌더링하지 않는다
  /// (웹 OfficialDocument.tsx의 DocumentFooterBlock과 동일한 조건).
  Widget _buildFooter(bool isApproved) {
    final footer = approval.documentFooter;
    final docNumber = approval.docNumberDisplay ?? approval.docNumber;
    final hasDocNumber = docNumber != null && docNumber.isNotEmpty;
    final hasCompanyInfo = footer?.hasAnyValue ?? false;
    if (!hasCompanyInfo && !hasDocNumber) return const SizedBox.shrink();

    final receivedAt = isApproved ? approval.processedAt : null;
    final addressLine = [footer?.address]
        .where((v) => v != null && v.isNotEmpty)
        .join('  ');
    final postalCode = footer?.postalCode?.isNotEmpty == true ? footer!.postalCode : null;
    final contactsParts = <String>[
      if (footer?.phoneNumber?.isNotEmpty == true) '전화  ${footer!.phoneNumber}',
      if (footer?.faxNumber?.isNotEmpty == true) '전송  ${footer!.faxNumber}',
    ];
    final contacts = contactsParts.join('  ');
    final hasEmail = footer?.contactEmail?.isNotEmpty == true;
    final disclosureType = footer?.disclosureType?.isNotEmpty == true
        ? footer!.disclosureType!
        : '공개';

    final rows = <Widget>[];

    if (hasDocNumber || receivedAt != null) {
      rows.add(_footerRow([
        _footerTerm('시행'),
        _footerVal(docNumber ?? ''),
        _footerTerm('접수'),
        _footerVal(_formatDotted(receivedAt)),
      ]));
    }

    if (postalCode != null || addressLine.isNotEmpty || (footer?.homepageUrl?.isNotEmpty == true)) {
      rows.add(_footerRow([
        if (postalCode != null || addressLine.isNotEmpty) ...[
          _footerTerm('우'),
          _footerVal([postalCode, addressLine].where((v) => v != null && v.isNotEmpty).join('  ')),
        ],
        if (footer?.homepageUrl?.isNotEmpty == true) _footerVal('/ ${footer!.homepageUrl}'),
      ]));
    }

    if (contacts.isNotEmpty || hasEmail) {
      rows.add(_footerRow([
        if (contacts.isNotEmpty) _footerVal(contacts),
        if (hasEmail) _footerVal(', 담당자 E-MAIL : ${footer!.contactEmail}'),
        _footerVal('/ $disclosureType'),
      ]));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: const Color(0xFFD1D5DB)),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _footerRow(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }

  Widget _footerTerm(String text) => Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _ink),
      );

  Widget _footerVal(String text) => Text(
        text,
        style: const TextStyle(fontSize: 10, color: _muted),
      );

  /// 결재란 표: 첫 칸=기안자, 이후 결재선 (legacy는 결재 1칸)
  Widget _buildApprovalTable() {
    final boxes = <_ApprovalBox>[
      _ApprovalBox(
        label: '기안',
        name: approval.requesterName,
        date: approval.createdAt,
        state: _BoxState.approved,
      ),
    ];

    if (approval.approvalLine.isNotEmpty) {
      for (final step in approval.approvalLine) {
        boxes.add(_ApprovalBox(
          label: step.roleText,
          name: step.approverName,
          date: step.processedAt,
          signatureUrl: step.signatureUrl,
          state: step.isApproved
              ? _BoxState.approved
              : step.isRejected
                  ? _BoxState.rejected
                  : (approval.currentStep?.stepOrder == step.stepOrder
                      ? _BoxState.inProgress
                      : _BoxState.waiting),
        ));
      }
    } else {
      boxes.add(_ApprovalBox(
        label: '결재',
        name: approval.processedByName ?? '',
        date: approval.processedAt,
        state: approval.status == ApprovalStatus.approved
            ? _BoxState.approved
            : approval.status == ApprovalStatus.rejected
                ? _BoxState.rejected
                : _BoxState.inProgress,
      ));
    }

    return Table(
      defaultColumnWidth: const FixedColumnWidth(66),
      border: TableBorder.all(color: _ink, width: 0.8),
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
          children: boxes
              .map((b) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(b.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700, color: _ink)),
                  ))
              .toList(),
        ),
        TableRow(
          children: boxes.map((b) => _buildSignCell(b)).toList(),
        ),
        TableRow(
          children: boxes
              .map((b) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(
                      children: [
                        Text(b.name.isEmpty ? '-' : b.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 9, color: _ink)),
                        Text(
                          b.state == _BoxState.approved ||
                                  b.state == _BoxState.rejected
                              ? _formatShort(b.date)
                              : '',
                          style: const TextStyle(fontSize: 8, color: _muted),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSignCell(_ApprovalBox box) {
    Widget child;
    switch (box.state) {
      case _BoxState.rejected:
        child = const Text('반려',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB91C1C)));
        break;
      case _BoxState.approved:
        if (box.signatureUrl != null) {
          child = Image.network(
            box.signatureUrl!,
            width: 38,
            height: 38,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Text('${box.name} (인)',
                style: const TextStyle(fontSize: 9, color: _ink)),
          );
        } else {
          child = Text(box.label == '기안' ? box.name : '${box.name} (인)',
              style: const TextStyle(fontSize: 9, color: _ink),
              textAlign: TextAlign.center);
        }
        break;
      case _BoxState.inProgress:
        child = const Text('결재중',
            style: TextStyle(fontSize: 9, color: _muted));
        break;
      case _BoxState.waiting:
        child = const SizedBox.shrink();
        break;
    }

    return Container(
      height: 46,
      alignment: Alignment.center,
      decoration: box.state == _BoxState.rejected
          ? const BoxDecoration(color: Color(0xFFFEE2E2))
          : null,
      child: child,
    );
  }

  /// 폼 데이터 본문 표 (템플릿 스키마로 라벨/순서 해석, 없으면 키 그대로)
  Widget _buildFieldsTable() {
    final formData = approval.formData!;
    final fields = template?.formFields ?? const [];

    final rows = <TableRow>[];

    void addRow(String label, String value, {bool isSection = false}) {
      if (isSection) {
        rows.add(TableRow(
          decoration: const BoxDecoration(color: Color(0xFFE5E7EB)),
          children: [
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: _ink)),
            ),
            const SizedBox.shrink(),
          ],
        ));
        return;
      }
      rows.add(TableRow(
        children: [
          Container(
            color: const Color(0xFFF3F4F6),
            padding: const EdgeInsets.all(7),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: _ink)),
          ),
          Padding(
            padding: const EdgeInsets.all(7),
            child: Text(value, style: const TextStyle(fontSize: 11, color: _ink)),
          ),
        ],
      ));
    }

    String formatValue(Map<String, dynamic>? field, dynamic value) {
      if (value == null || (value is String && value.isEmpty)) return '-';
      if (value is List) return value.map((v) => v.toString()).join(', ');
      if (value is Map) {
        final start = value['start'] ?? value['startDate'];
        final end = value['end'] ?? value['endDate'];
        if (start != null || end != null) {
          return '${start ?? '-'} ~ ${end ?? '-'}';
        }
        return value.toString();
      }
      // select/radio 옵션 라벨 치환
      final options = field?['options'];
      if (options is List) {
        for (final option in options.whereType<Map>()) {
          if (option['value']?.toString() == value.toString()) {
            return option['label']?.toString() ?? value.toString();
          }
        }
      }
      return value.toString();
    }

    if (fields.isNotEmpty) {
      final usedKeys = <String>{};
      for (final field in fields) {
        final type = field['type']?.toString();
        final id = field['id']?.toString() ?? '';
        final label = field['label']?.toString() ?? id;
        if (type == 'section') {
          addRow(label, '', isSection: true);
          continue;
        }
        dynamic value = formData[id];
        // dateRange는 {id}_start/{id}_end로 평탄화 저장될 수 있음
        if (value == null && type == 'dateRange') {
          final start = formData['${id}_start'];
          final end = formData['${id}_end'];
          if (start != null || end != null) value = {'start': start, 'end': end};
          usedKeys.addAll(['${id}_start', '${id}_end']);
        }
        usedKeys.add(id);
        addRow(label, formatValue(field, value));
      }
      // 스키마에 없는 잔여 키
      for (final entry in formData.entries) {
        if (!usedKeys.contains(entry.key)) {
          addRow(entry.key, formatValue(null, entry.value));
        }
      }
    } else {
      for (final entry in formData.entries) {
        addRow(entry.key, formatValue(null, entry.value));
      }
    }

    return Table(
      columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(2.2)},
      border: TableBorder.all(color: _line, width: 0.6),
      children: rows,
    );
  }
}

enum _BoxState { approved, rejected, inProgress, waiting }

class _ApprovalBox {
  final String label;
  final String name;
  final DateTime? date;
  final String? signatureUrl;
  final _BoxState state;

  _ApprovalBox({
    required this.label,
    required this.name,
    this.date,
    this.signatureUrl,
    required this.state,
  });
}
