import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/admin_utils.dart';
import '../widgets/approval/signature_confirm_sheet.dart';
import '../widgets/seed/seed_button.dart';

/// 회의록 상세 — 내용을 읽고, 내가 참석자면 서명한다.
/// 서명은 결재 승인과 같은 방식: 등록 서명 자동 날인 또는 즉석 그리기.
class MeetingMinutesDetailScreen extends StatefulWidget {
  final int minutesId;

  const MeetingMinutesDetailScreen({super.key, required this.minutesId});

  @override
  State<MeetingMinutesDetailScreen> createState() => _MeetingMinutesDetailScreenState();
}

class _MeetingMinutesDetailScreenState extends State<MeetingMinutesDetailScreen> {
  Map<String, dynamic>? _minutes;
  bool _isLoading = true;
  bool _isSigning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final minutes =
          await ApiService().getMeetingMinutesDetail(minutesId: widget.minutesId);
      if (!mounted) return;
      setState(() {
        _minutes = minutes;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '회의록을 불러오지 못했습니다.';
      });
    }
  }

  List<dynamic> get _attendees => _minutes?['attendees'] as List<dynamic>? ?? [];

  /// 내 참석자 행. 결재선과 같은 규칙 — 직원이면 MEMBER/refId, 관리자 계정이면 ADMIN/refId.
  Map<String, dynamic>? get _myAttendee {
    final user = context.read<AuthProvider>().currentUser;
    final myId = user?.id ?? '';
    if (myId.isEmpty) return null;
    final isAdminAccount = AdminUtils.hasAdminPermission(user);

    for (final raw in _attendees) {
      final attendee = raw as Map<String, dynamic>;
      final type = attendee['attendeeType']?.toString();
      final refId = attendee['refId']?.toString();
      if (refId == null) continue;
      if (type == 'MEMBER' && refId == myId) return attendee;
      if (type == 'ADMIN' && isAdminAccount && refId == myId) return attendee;
    }
    return null;
  }

  Future<void> _sign() async {
    final mine = _myAttendee;
    if (mine == null) return;

    final result = await showSignatureConfirmSheet(context, title: '회의록 서명');
    if (result == null || !mounted) return;

    setState(() => _isSigning = true);
    try {
      final updated = await ApiService().signMeetingMinutes(
        minutesId: widget.minutesId,
        attendeeId: mine['id'] as int,
        signatureBase64: result.signatureBase64,
      );
      if (!mounted) return;
      setState(() {
        _minutes = updated;
        _isSigning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서명을 완료했어요.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSigning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서명에 실패했어요. 잠시 후 다시 시도해주세요.')),
      );
    }
  }

  List<Map<String, dynamic>> _sections() {
    final raw = _minutes?['sectionsJson']?.toString();
    if (raw == null || raw.isEmpty) return [];
    try {
      final parsed = json.decode(raw);
      if (parsed is List) {
        return parsed
            .whereType<Map<String, dynamic>>()
            .where((s) => (s['content']?.toString() ?? '').trim().isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _minutes;
    final mine = _myAttendee;
    final canSign = minutes != null &&
        minutes['status'] == 'REGISTERED' &&
        mine != null &&
        mine['signedAt'] == null;

    final startAt = minutes?['meetingStartAt']?.toString() ?? '';
    final endAt = minutes?['meetingEndAt']?.toString();
    final when = startAt.length >= 16
        ? '${startAt.substring(0, 10)} ${startAt.substring(11, 16)}'
            '${endAt != null && endAt.length >= 16 ? ' ~ ${endAt.substring(11, 16)}' : ''}'
        : startAt;

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(title: const Text('회의록')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.gray600),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.space4),
                  children: [
                    // 머리 정보
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            minutes?['title']?.toString() ?? '',
                            style: AppTypography.heading5.copyWith(color: AppColors.gray900),
                          ),
                          const SizedBox(height: AppSpacing.space2),
                          Text(
                            [
                              when,
                              if ((minutes?['location']?.toString() ?? '').isNotEmpty)
                                minutes!['location'].toString(),
                              '작성 ${minutes?['authorName'] ?? ''}',
                            ].join(' · '),
                            style: AppTypography.bodySmall.copyWith(color: AppColors.gray600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space3),

                    // 회의 내용
                    ..._sections().map(
                      (section) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.space3),
                        child: _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '[${section['label'] ?? ''}]',
                                style: AppTypography.labelLarge
                                    .copyWith(color: AppColors.teal800),
                              ),
                              const SizedBox(height: AppSpacing.space2),
                              Text(
                                section['content'].toString(),
                                style: AppTypography.bodyMedium
                                    .copyWith(color: AppColors.gray800, height: 1.6),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 참석자 서명 현황
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '참석자 서명',
                            style: AppTypography.labelLarge.copyWith(color: AppColors.gray900),
                          ),
                          const SizedBox(height: AppSpacing.space2),
                          ..._attendees.map((raw) {
                            final attendee = raw as Map<String, dynamic>;
                            final signed = attendee['signedAt'] != null;
                            final isExternal = attendee['attendeeType'] == 'EXTERNAL';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    signed ? Icons.check_circle : Icons.radio_button_unchecked,
                                    size: 18,
                                    color: signed ? AppColors.teal600 : AppColors.gray400,
                                  ),
                                  const SizedBox(width: AppSpacing.space2),
                                  Expanded(
                                    child: Text(
                                      '${attendee['attendeeName'] ?? ''}${isExternal ? ' (외부)' : ''}',
                                      style: AppTypography.bodyMedium
                                          .copyWith(color: AppColors.gray800),
                                    ),
                                  ),
                                  if (signed && attendee['signatureUrl'] != null)
                                    Image.network(
                                      attendee['signatureUrl'].toString(),
                                      height: 28,
                                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                    )
                                  else
                                    Text(
                                      signed ? '서명 완료' : '대기',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: signed ? AppColors.teal700 : AppColors.gray500,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space6),
                  ],
                ),
      bottomNavigationBar: canSign
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space4),
                child: SeedButton(
                  label: _isSigning ? '서명 중...' : '확인했습니다 · 서명하기',
                  onPressed: _isSigning ? null : _sign,
                ),
              ),
            )
          : null,
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
