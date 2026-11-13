import 'package:flutter/material.dart';

import '../models/voice_message.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_lines.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_empty_state.dart';
import '../widgets/common/app_loading.dart';
import '../widgets/common/app_refresh.dart';
import '../widgets/common/app_skeleton.dart';
import '../widgets/common/carev_app_bar.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_callout.dart';
import '../widgets/seed/seed_list_cell.dart';
import 'voice_box_write_screen.dart';
import '../widgets/common/app_tag.dart';

/// 고충·신고 / 건의함 — 직원용.
/// 제출은 소속 기관 인증 사용자 누구나 가능하고, 열람·처리는 기관 관리자만 할 수 있다
/// (VoiceMessageController·VoiceMessageService). 이 화면은 제출 + 본인 제출 내역 확인만 다룬다.
class VoiceBoxScreen extends StatefulWidget {
  const VoiceBoxScreen({super.key});

  @override
  State<VoiceBoxScreen> createState() => _VoiceBoxScreenState();
}

class _VoiceBoxScreenState extends State<VoiceBoxScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<VoiceMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiService().getMyVoiceBoxMessages();
      final raw = response['messages'];
      final list = raw is List ? raw : <dynamic>[];
      final messages = list
          .whereType<Map<String, dynamic>>()
          .map(VoiceMessage.fromJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '내역을 불러오지 못했습니다';
        _isLoading = false;
      });
    }
  }

  Future<void> _openWriteScreen() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const VoiceBoxWriteScreen()),
    );
    if (submitted == true) {
      _load();
    }
  }

  void _showDetail(VoiceMessage message) {
    AppBottomSheet.show(
      context,
      // 원래 isScrollControlled: true였던 전체높이 확장 동작을 유지 — height를
      // 주면 AppBottomSheet 내부적으로 isScrollControlled true로 연결된다.
      height: MediaQuery.of(context).size.height * 0.9,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space5),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Row(
                    children: [
                      _StatusBadge(status: message.status),
                      const SizedBox(width: AppSpacing.space2),
                      Text(
                        message.type.label,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppSemanticColors.textTertiary,
                        ),
                      ),
                      if (message.isAnonymous) ...[
                        const SizedBox(width: AppSpacing.space2),
                        const Icon(
                          Icons.visibility_off_outlined,
                          size: 16,
                          color: AppSemanticColors.textTertiary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  // 시트 안 상세 제목(B안 heading5 18/w700)
                  Text(
                    message.title,
                    style: AppTypography.heading5.copyWith(
                      color: AppSemanticColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  Text(
                    message.content,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                  ),
                  if (message.hasReply) ...[
                    const SizedBox(height: AppSpacing.space5),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.space4),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.fillDefault,
                        borderRadius:
                            BorderRadius.circular(AppBorderRadius.control),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '관리자 답변',
                            style: AppTypography.titleSmall.copyWith(
                              color: AppSemanticColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space1_5),
                          Text(
                            message.adminReply!,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppSemanticColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.space4),
                ],
              ),
            ),
          ),
        ),
      );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // B안: 옅은 회색 바탕 위 흰 목록 카드(SeedListSection)
      backgroundColor: AppSemanticColors.backgroundCanvas,
      appBar: const CareVAppBar(title: '고충·신고 · 건의함'),
      body: SafeArea(
        child: AppRefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.space4),
            children: [
              const SeedCallout(
                variant: SeedCalloutVariant.info,
                title: '고충·신고, 건의를 남겨보세요',
                description:
                    '작성한 글은 기관 관리자(대표·시설장·사무국장급)만 열람해요. 익명으로 제출하면 관리자 화면에는 작성자가 "익명"으로만 표시돼요.',
              ),
              const SizedBox(height: AppSpacing.space4),
              SizedBox(
                width: double.infinity,
                child: SeedButton(
                  label: '새로 작성하기',
                  prefixIcon: Icons.edit_outlined,
                  size: SeedButtonSize.large,
                  onPressed: _openWriteScreen,
                ),
              ),
              const SizedBox(height: AppSpacing.space6),

              // 묶음 제목 — SeedListSection 제목과 같은 모양(14/w600 회색)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space1,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    '내 제출 내역',
                    style: AppTypography.titleSmall.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.space2),

              // 처음 불러올 때(아직 보일 내역이 없을 때)만 뼈대 — 내역이 있는 채로 다시 불러올 때는 예전 스피너
              if (_isLoading && _messages.isEmpty)
                const _VoiceBoxListSkeleton()
              else if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.space8),
                  child: AppLoading(),
                )
              else if (_errorMessage != null)
                _buildErrorState(_errorMessage!)
              else if (_messages.isEmpty)
                _buildEmptyState()
              else
                SeedListSection(
                  children: [
                    for (final message in _messages)
                      SeedListCell(
                        leadingIcon: message.type == VoiceMessageType.grievance
                            ? Icons.report_gmailerrorred_outlined
                            : Icons.lightbulb_outline,
                        title: message.title,
                        description:
                            '${message.type.label} · ${_formatDate(message.createdAt)}${message.hasReply ? ' · 답변 있음' : ''}',
                        trailing: _StatusBadge(status: message.status),
                        onTap: () => _showDetail(message),
                      ),
                  ],
                ),
              const SizedBox(height: AppSpacing.space8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const AppEmptyState(
      icon: Icons.mark_email_read_outlined,
      title: '아직 제출한 내역이 없어요',
      topSpacing: AppSpacing.space8,
    );
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space6),
      child: Center(
        child: Column(
          children: [
            Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.space3),
            SeedButton(
              label: '다시 시도',
              variant: SeedButtonVariant.neutralWeak,
              onPressed: _load,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final VoiceMessageStatus status;

  const _StatusBadge({required this.status});

  AppTagTone get _tone {
    // 파랑은 앱 팔레트에 없다 — 접수됨은 중립, 확인중 경고, 처리완료 성공
    switch (status) {
      case VoiceMessageStatus.received:
        return AppTagTone.neutral;
      case VoiceMessageStatus.inReview:
        return AppTagTone.warning;
      case VoiceMessageStatus.resolved:
        return AppTagTone.success;
      case VoiceMessageStatus.onHold:
        return AppTagTone.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppTag(label: status.label, tone: _tone);
  }
}

/// 내 제출 내역 첫 불러오기 뼈대 — 흰 목록 카드(SeedListSection) 모양
class _VoiceBoxListSkeleton extends StatelessWidget {
  const _VoiceBoxListSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      baseColor: AppSemanticColors.skeletonBaseOnCard,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.space2),
        decoration: BoxDecoration(
          color: AppSemanticColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppBorderRadius.card),
          border: AppLines.cardBorder,
        ),
        child: const Column(
          children: [
            AppSkeletonListTile(
              titleWidthFactor: 0.62,
              subtitleWidthFactor: 0.38,
            ),
            AppSkeletonListTile(
              titleWidthFactor: 0.48,
              subtitleWidthFactor: 0.3,
            ),
            AppSkeletonListTile(
              titleWidthFactor: 0.7,
              subtitleWidthFactor: 0.42,
            ),
          ],
        ),
      ),
    );
  }
}
