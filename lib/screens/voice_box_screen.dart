import 'package:flutter/material.dart';

import '../models/voice_message.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_loading.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_callout.dart';
import '../widgets/seed/seed_list_cell.dart';
import 'voice_box_write_screen.dart';

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppSemanticColors.surfaceDefault,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppBorderRadius.xl2)),
      ),
      builder: (context) {
        return SafeArea(
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
                        style: AppTypography.labelSmall.copyWith(
                          color: AppSemanticColors.textTertiary,
                        ),
                      ),
                      if (message.isAnonymous) ...[
                        const SizedBox(width: AppSpacing.space2),
                        Icon(
                          Icons.visibility_off_outlined,
                          size: 14,
                          color: AppSemanticColors.textTertiary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    message.title,
                    style: AppTypography.heading6.copyWith(
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
                        color: AppSemanticColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '관리자 답변',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppSemanticColors.textTertiary,
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
        );
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundSecondary,
      appBar: AppBar(
        title: Text('고충·신고 · 건의함', style: AppTypography.heading5),
        backgroundColor: AppSemanticColors.backgroundPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppSemanticColors.interactivePrimaryDefault,
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

              Text(
                '내 제출 내역',
                style: AppTypography.labelLarge.copyWith(
                  color: AppSemanticColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),

              if (_isLoading)
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space8),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.mark_email_read_outlined,
              size: 48,
              color: AppSemanticColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.space3),
            Text(
              '아직 제출한 내역이 없어요',
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
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

  Color get _color {
    switch (status) {
      case VoiceMessageStatus.received:
        return AppSemanticColors.statusInfoText;
      case VoiceMessageStatus.inReview:
        return AppSemanticColors.statusWarningText;
      case VoiceMessageStatus.resolved:
        return AppSemanticColors.statusSuccessText;
      case VoiceMessageStatus.onHold:
        return AppSemanticColors.textTertiary;
    }
  }

  Color get _background {
    switch (status) {
      case VoiceMessageStatus.received:
        return AppSemanticColors.statusInfoBackground;
      case VoiceMessageStatus.inReview:
        return AppSemanticColors.statusWarningBackground;
      case VoiceMessageStatus.resolved:
        return AppSemanticColors.statusSuccessBackground;
      case VoiceMessageStatus.onHold:
        return AppSemanticColors.backgroundTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space2,
        vertical: AppSpacing.space0_5,
      ),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
      ),
      child: Text(
        status.label,
        style: AppTypography.labelSmall.copyWith(color: _color),
      ),
    );
  }
}
