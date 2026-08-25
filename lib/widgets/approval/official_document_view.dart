import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/approval.dart';
import '../../utils/form_field_width.dart';
import '../../theme/app_colors.dart';

/// 표준 기안문(공문) 형태의 결재 문서 뷰.
///
/// 웹 관리자(OfficialDocument.tsx)의 A4 794px 레이아웃을 같은 치수로 그린 뒤
/// FittedBox로 화면 폭에 맞춰 통째로 축소한다 — 폰에서도 웹·인쇄물과 비율이
/// 완전히 같아진다(채팅 공지에 올라가는 공문 JPG와 같은 모양).
/// 폰트·간격 상수는 웹 globals.css의 carev-doc-* px 값을 그대로 옮긴 것이다.
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

  /// 웹 .carev-doc-page 폭 (A4 210mm @96dpi)
  static const double _docWidth = 794;

  // 문서 팩시밀리 전용 잉크/보조/선 색상 — Tailwind gray-900/500/400 값이며
  // 앱 Seed 팔레트(AppColors.gray*)와 스케일이 달라 대응하는 동일값 토큰이 없다.
  // 실제 결재 출력물과 동일하게 보여야 하므로 값은 그대로 유지한다.
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);
  static const _line = Color(0xFF9CA3AF);

  String _formatDate(DateTime? date) =>
      date == null ? '-' : DateFormat('yyyy년 MM월 dd일').format(date);

  String _formatDotted(DateTime? date) =>
      date == null ? '' : DateFormat('yyyy . MM. dd.').format(date);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite && constraints.maxWidth > 0
          ? constraints.maxWidth
          : _docWidth;
      return SizedBox(
        width: width,
        child: FittedBox(
          fit: BoxFit.fitWidth,
          alignment: Alignment.topLeft,
          // 문서는 축소 전제라 시스템 글자 크기 설정을 타면 배치가 깨진다 —
          // 화면 UI가 아니라 인쇄물 팩시밀리이므로 텍스트 스케일을 고정한다.
          child: MediaQuery.withNoTextScaling(
            child: SizedBox(width: _docWidth, child: _buildPage(context)),
          ),
        ),
      );
    });
  }

  Widget _buildPage(BuildContext context) {
    final isApproved = approval.status == ApprovalStatus.approved;

    return Container(
      width: _docWidth,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 44),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)), // Tailwind gray-200
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 레터헤드 — 웹 .carev-doc-letterhead (24px / 자간 0.35em / 밑줄 2px)
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                companyName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 24 * 0.35,
                  color: _ink,
                ),
              ),
            ),
          ),
          Container(height: 2, color: _ink),
          const SizedBox(height: 16),

          // 문서정보 + 결재란 — 웹 .carev-doc-topbar (좌: 메타, 우: 결재란)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _metaLine('문서번호 : ${approval.docNumberDisplay ?? approval.docNumber ?? '-'}'),
                    _metaLine('기안일자 : ${_formatDate(approval.createdAt)}'),
                    _metaLine('시행일자 : ${isApproved ? _formatDate(approval.processedAt) : '-'}'),
                  ],
                ),
              ),
              _buildApprovalTable(),
            ],
          ),
          const SizedBox(height: 24),

          // 제목 — 웹 .carev-doc-title (20px, margin 28/24)
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: Text(
              approval.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _ink),
            ),
          ),
          const SizedBox(height: 24),

          // 반려 사유
          if (approval.status == ApprovalStatus.rejected &&
              (approval.rejectReason?.isNotEmpty ?? false)) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2), // Tailwind red-50
                border: Border.all(color: const Color(0xFFFCA5A5)), // red-300
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '반려 사유: ${approval.rejectReason}',
                style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C)), // red-700
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 본문 — 웹 .carev-doc-fields (13px / 패딩 8×10)
          if (approval.formData != null && approval.formData!.isNotEmpty)
            _buildFieldsTable()
          else
            const Text(
              '위 건에 대하여 붙임과 같이 기안하오니 결재하여 주시기 바랍니다.\n(본문: 별첨 문서 참조)',
              style: TextStyle(fontSize: 13, height: 1.8, color: _muted),
            ),

          // 발신명의 + 직인 — 웹 .carev-doc-issuer (44px 위 여백, 20px/자간 0.25em,
          // 도장은 마지막 글자에 살짝 겹치게)
          const SizedBox(height: 44),
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerRight,
              children: [
                Text(
                  companyName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 20 * 0.25,
                    color: _ink,
                  ),
                ),
                if (isApproved && approval.companySealUrl != null)
                  Positioned(
                    right: -16,
                    child: Opacity(
                      opacity: 0.85,
                      child: Image.network(
                        approval.companySealUrl!,
                        width: 62,
                        height: 62,
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
            Container(height: 1, color: const Color(0xFFD1D5DB)), // Tailwind gray-300
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

  Widget _metaLine(String text) => Text(
        text,
        style: const TextStyle(fontSize: 12, height: 1.9, color: Color(0xFF374151)), // gray-700
      );

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

    // 웹 .carev-doc-footer — 위 여백 48, 굵은 가로줄(8px) 아래 12px 줄들
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 8, color: _line),
          const SizedBox(height: 14),
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
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink),
      );

  Widget _footerVal(String text) => Text(
        text,
        style: const TextStyle(fontSize: 12, color: _muted),
      );

  /// 결재란 표: 첫 칸=기안자, 이후 결재선 (legacy는 결재 1칸).
  /// 웹 .carev-doc-approval-table과 같은 2행 구성 — 헤더(기안/검토/결재) + 서명 칸 하나.
  /// (예전에는 밑에 이름·날짜 행이 하나 더 있어 웹과 모양이 달랐다)
  Widget _buildApprovalTable() {
    final boxes = <_ApprovalBox>[
      _ApprovalBox(
        label: '기안',
        name: approval.requesterName,
        signatureUrl: null,
        state: _BoxState.approved,
      ),
    ];

    if (approval.approvalLine.isNotEmpty) {
      for (final step in approval.approvalLine) {
        boxes.add(_ApprovalBox(
          label: step.roleText,
          name: step.approverName,
          signatureUrl: step.signatureUrl,
          state: step.isApproved
              ? _BoxState.approved
              : step.isRejected
                  ? _BoxState.rejected
                  : step.status == 'SKIPPED'
                      ? _BoxState.skipped
                      : (approval.currentStep?.stepOrder == step.stepOrder
                          ? _BoxState.inProgress
                          : _BoxState.waiting),
        ));
      }
    } else {
      boxes.add(_ApprovalBox(
        label: '결재',
        name: approval.processedByName ?? '',
        signatureUrl: null,
        state: approval.status == ApprovalStatus.approved
            ? _BoxState.approved
            : approval.status == ApprovalStatus.rejected
                ? _BoxState.rejected
                : _BoxState.inProgress,
      ));
    }

    // 웹: 칸 72px, 헤더 24px, 서명 칸 52px, 글자 11px
    return Table(
      defaultColumnWidth: const FixedColumnWidth(72),
      border: TableBorder.all(color: _ink, width: 1),
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF3F4F6)), // Tailwind gray-100
          children: boxes
              .map((b) => Container(
                    height: 24,
                    alignment: Alignment.center,
                    child: Text(b.label,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600, color: _ink)),
                  ))
              .toList(),
        ),
        TableRow(
          children: boxes.map((b) => _buildSignCell(b)).toList(),
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
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB91C1C))); // Tailwind red-700
        break;
      case _BoxState.approved:
        if (box.signatureUrl != null) {
          child = Image.network(
            box.signatureUrl!,
            width: 44,
            height: 44,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Text('${box.name} (인)',
                style: const TextStyle(fontSize: 11, color: _ink)),
          );
        } else {
          child = Text(box.label == '기안' ? box.name : '${box.name} (인)',
              style: const TextStyle(fontSize: 11, color: _ink),
              textAlign: TextAlign.center);
        }
        break;
      case _BoxState.skipped:
        // 관리자 직권 승인(전결)으로 건너뛴 단계
        child = const Text('전결', style: TextStyle(fontSize: 11, color: _muted));
        break;
      case _BoxState.inProgress:
        child = const Text('결재중', style: TextStyle(fontSize: 11, color: _muted));
        break;
      case _BoxState.waiting:
        child = const SizedBox.shrink();
        break;
    }

    return Container(
      height: 52,
      alignment: Alignment.center,
      decoration: box.state == _BoxState.rejected
          ? const BoxDecoration(color: Color(0xFFFEE2E2)) // Tailwind red-100
          : null,
      child: child,
    );
  }

  /// 폼 데이터 본문 표 (템플릿 스키마로 라벨/순서 해석, 없으면 키 그대로).
  ///
  /// Table을 쓰지 않는다 — Table은 열 폭을 모든 행이 공유해서 "이 줄은 1/3+2/3,
  /// 저 줄은 반반"처럼 행마다 다른 비율을 표현할 수 없다. 웹 공문(OfficialDocument)도
  /// 같은 이유로 행 단위 레이아웃을 쓴다. 양식 관리에서 정해둔 비율을 그대로 보여주려면
  /// 행마다 따로 나눠야 한다.
  Widget _buildFieldsTable() {
    final formData = approval.formData!;
    final fields = template?.formFields ?? const [];

    // 선택지 값(내부 ID) → 사람이 읽는 라벨. 목록에 없으면 원본을 그대로 보여준다.
    String lookupOptionLabel(Map<String, dynamic>? field, dynamic raw) {
      final options = field?['options'];
      if (options is List) {
        for (final option in options.whereType<Map>()) {
          if (option['value']?.toString() == raw.toString()) {
            return option['label']?.toString() ?? raw.toString();
          }
        }
      }
      return raw.toString();
    }

    String formatValue(Map<String, dynamic>? field, dynamic value) {
      if (value == null || (value is String && value.isEmpty)) return '-';

      final type = field?['type']?.toString();
      if (type == 'dateRange' && value is Map) {
        final start = value['start']?.toString() ?? '';
        final end = value['end']?.toString() ?? '';
        if (start.isEmpty && end.isEmpty) return '-';
        return '$start ~ $end';
      }
      if (value is bool) return value ? 'O' : 'X';
      // 체크박스처럼 여러 개를 고른 값 — 항목마다 라벨로 바꿔야 한다.
      // (예전에는 ID를 그대로 이어붙여 "msplrdcq…" 같은 내부 값이 문서에 나왔다)
      if (value is List) {
        if (value.isEmpty) return '-';
        return value.map((e) => lookupOptionLabel(field, e)).join(', ');
      }
      return lookupOptionLabel(field, value);
    }

    // 그릴 항목을 먼저 모은다 (라벨 · 값 · 폭 · 구분선 여부)
    final entries = <_DocFieldEntry>[];
    if (fields.isNotEmpty) {
      final usedKeys = <String>{};
      for (final field in fields) {
        final type = field['type']?.toString();
        final id = field['id']?.toString() ?? '';
        final label = field['label']?.toString() ?? id;
        if (type == 'section') {
          entries.add(_DocFieldEntry(label, '', 12, isSection: true));
          continue;
        }
        dynamic value = formData[id];
        if (value == null && type == 'dateRange') {
          final start = formData['${id}_start'];
          final end = formData['${id}_end'];
          if (start != null || end != null) value = {'start': start, 'end': end};
          usedKeys.addAll(['${id}_start', '${id}_end']);
        }
        usedKeys.add(id);
        entries.add(_DocFieldEntry(
            label, formatValue(field, value), fieldWidthSpan(field['width'])));
      }
      for (final entry in formData.entries) {
        if (!usedKeys.contains(entry.key)) {
          entries.add(_DocFieldEntry(entry.key, formatValue(null, entry.value), 12));
        }
      }
    } else {
      for (final entry in formData.entries) {
        entries.add(_DocFieldEntry(entry.key, formatValue(null, entry.value), 12));
      }
    }

    // 12칼럼이 찰 때까지 한 줄에 묶는다 — 웹 공문과 같은 규칙이라
    // 1/3 셋, 1/4 넷도 한 줄에 들어간다 (예전에는 둘까지만 묶어 나머지가 밀려 내려갔다)
    final rows = groupIntoRowsBySpan<_DocFieldEntry>(
      entries,
      spanOf: (entry) => entry.span,
      isBlock: (entry) => entry.isSection,
      maxPerRow: 4,
    );

    return Container(
      decoration: BoxDecoration(border: Border.all(color: _line, width: 1)),
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _rowCells(rows[r], isLastRow: r == rows.length - 1),
              ),
            ),
        ],
      ),
    );
  }

  /// 한 줄을 라벨/값 칸들로 편다. 값 칸의 폭은 그 줄 안에서 각 필드의 비율대로 나눈다.
  List<Widget> _rowCells(List<_DocFieldEntry> row, {required bool isLastRow}) {
    final bottom = isLastRow ? BorderSide.none : const BorderSide(color: _line, width: 1);

    if (row.length == 1 && row[0].isSection) {
      return [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB), // Tailwind gray-200
              border: Border(bottom: bottom),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: Text(row[0].label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 13 * 0.15,
                    color: _ink)),
          ),
        ),
      ];
    }

    final cells = <Widget>[];
    // 웹의 docRowColumnTemplate과 같은 배분 — 라벨은 개수가 늘수록 좁히고(2개면 18%씩),
    // 남는 자리를 각 필드의 폭 비율대로 나눈다
    final labelPercent = (44 / row.length).clamp(0, 18).toDouble();
    final labelFlex = (labelPercent * 100).round();
    final valueFlexTotal = ((100 - labelPercent * row.length) * 100).round();
    final spanTotal = row.fold<int>(0, (sum, e) => sum + e.span);

    for (var c = 0; c < row.length; c++) {
      final entry = row[c];
      final isLastCell = c == row.length - 1;
      final valueFlex = (valueFlexTotal * entry.span / (spanTotal == 0 ? 1 : spanTotal))
          .round()
          .clamp(1, 100000);

      cells.add(Expanded(
        flex: labelFlex,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6), // Tailwind gray-100
            border: Border(bottom: bottom, right: const BorderSide(color: _line, width: 1)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          alignment: Alignment.center,
          child: Text(entry.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _ink)),
        ),
      ));
      cells.add(Expanded(
        flex: valueFlex,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: bottom,
              right: isLastCell ? BorderSide.none : const BorderSide(color: _line, width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: Text(entry.value,
              style: const TextStyle(fontSize: 13, color: _ink)),
        ),
      ));
    }
    return cells;
  }
}

/// 공문 본문 한 칸 — 라벨과 값, 그리고 한 줄에서 차지할 폭
class _DocFieldEntry {
  const _DocFieldEntry(this.label, this.value, this.span, {this.isSection = false});

  final String label;
  final String value;
  final int span;
  final bool isSection;
}

enum _BoxState { approved, rejected, skipped, inProgress, waiting }

class _ApprovalBox {
  final String label;
  final String name;
  final String? signatureUrl;
  final _BoxState state;

  _ApprovalBox({
    required this.label,
    required this.name,
    this.signatureUrl,
    required this.state,
  });
}
