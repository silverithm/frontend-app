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
import '../widgets/common/app_card.dart';
import '../widgets/common/app_empty_state.dart';
import '../widgets/common/app_skeleton.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_callout.dart';

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
      AppSnackBar.showSuccess(context, message: '서명을 완료했어요.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSigning = false);
      AppSnackBar.showError(context, message: '서명에 실패했어요. 잠시 후 다시 시도해주세요.');
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
      backgroundColor: AppSemanticColors.backgroundCanvas,
      appBar: AppBar(title: const Text('회의록')),
      body: _isLoading
          ? const _MeetingMinutesDetailSkeleton()
          : _error != null
              ? AppEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: _error!,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenGutter,
                    AppSpacing.space3,
                    AppSpacing.screenGutter,
                    AppSpacing.space6,
                  ),
                  children: [
                    // 서명 필요 배너 — 아래로 스크롤하면 하단 서명 버튼을 놓치기 쉬워
                    // 진입 즉시 눈에 띄게 알려준다.
                    // B안 안내 상자(옅은 틸 바탕·모서리 12·테두리 없음)
                    if (canSign) ...[
                      const SeedCallout(
                        variant: SeedCalloutVariant.brand,
                        icon: Icons.draw_outlined,
                        title: '내 서명이 필요한 회의록이에요. 내용을 확인한 뒤 하단 버튼으로 서명해주세요.',
                      ),
                      const SizedBox(height: AppSpacing.cardGap),
                    ],
                    // 머리 정보
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            minutes?['title']?.toString() ?? '',
                            style: AppTypography.heading5.copyWith(
                              color: AppSemanticColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space2),
                          Text(
                            [
                              when,
                              if ((minutes?['location']?.toString() ?? '').isNotEmpty)
                                minutes!['location'].toString(),
                              '작성 ${minutes?['authorName'] ?? ''}',
                            ].join(' · '),
                            style: AppTypography.bodySmall.copyWith(
                              color: AppSemanticColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.cardGap),

                    // 회의 내용
                    ..._sections().map(
                      (section) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
                        child: _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 카드·구역 제목(B안 16/w700)
                              Semantics(
                                header: true,
                                child: Text(
                                  '${section['label'] ?? ''}',
                                  style: AppTypography.heading6.copyWith(
                                    color: AppSemanticColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.space2),
                              Text(
                                section['content'].toString(),
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppSemanticColors.textPrimary,
                                  height: 1.6,
                                ),
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
                          Semantics(
                            header: true,
                            child: Text(
                              '참석자 서명',
                              style: AppTypography.heading6.copyWith(
                                color: AppSemanticColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space2),
                          ..._attendees.map((raw) {
                            final attendee = raw as Map<String, dynamic>;
                            final signed = attendee['signedAt'] != null;
                            final isExternal = attendee['attendeeType'] == 'EXTERNAL';
                            return ConstrainedBox(
                              // 한 사람 한 줄 — 48 이상(서명 그림이 들어가도 줄 높이가 흔들리지 않게)
                              constraints: const BoxConstraints(
                                minHeight: AppSpacing.minTouchTarget,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    signed ? Icons.check_circle : Icons.radio_button_unchecked,
                                    size: 22,
                                    color: signed
                                        ? AppSemanticColors.brandDefault
                                        : AppSemanticColors.iconSubtle,
                                  ),
                                  const SizedBox(width: AppSpacing.space2_5),
                                  Expanded(
                                    child: Text(
                                      '${attendee['attendeeName'] ?? ''}${isExternal ? ' (외부)' : ''}',
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: AppSemanticColors.textPrimary,
                                      ),
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
                                      style: AppTypography.bodySmall.copyWith(
                                        color: signed
                                            ? AppSemanticColors.textLink
                                            : AppSemanticColors.textTertiary,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: canSign
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  AppSpacing.space3,
                  AppSpacing.screenGutter,
                  AppSpacing.space3,
                ),
                // 화면 맨 아래 주 단추 — 큰 것(52), 가로 꽉 채움
                child: SizedBox(
                  width: double.infinity,
                  child: SeedButton(
                    label: _isSigning ? '서명 중...' : '확인했습니다 · 서명하기',
                    onPressed: _isSigning ? null : _sign,
                    isLoading: _isSigning,
                    prefixIcon: Icons.draw_outlined,
                    size: SeedButtonSize.large,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  // B안 카드 — 테두리 없는 흰 상자, 모서리 16, 안쪽 16
  Widget _card({required Widget child}) {
    return SizedBox(
      width: double.infinity,
      child: AppCard(child: child),
    );
  }
}

/// 회의록 상세 첫 불러오기 뼈대 — 회색 바탕 위 흰 카드(머리 정보·회의 내용과 같은 여백·간격)
class _MeetingMinutesDetailSkeleton extends StatelessWidget {
  const _MeetingMinutesDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      baseColor: AppSemanticColors.skeletonBaseOnCard,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          AppSpacing.space3,
          AppSpacing.screenGutter,
          AppSpacing.space6,
        ),
        children: List.generate(
          3,
          (_) => const AppSkeletonCard(
            standalone: false,
            margin: EdgeInsets.only(bottom: AppSpacing.cardGap),
          ),
        ),
      ),
    );
  }
}
