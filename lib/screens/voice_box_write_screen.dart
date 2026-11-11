import 'package:flutter/material.dart';

import '../models/voice_message.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/common/carev_app_bar.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_callout.dart';
import '../widgets/seed/seed_chip.dart';
import '../widgets/seed/seed_text_field.dart';

/// 고충·신고 / 건의 작성 화면.
/// 제출은 소속 기관의 인증된 직원 누구나 가능하며(VoiceMessageController),
/// 열람은 기관 관리자만 할 수 있다 — 익명 여부는 사용자가 직접 선택한다.
class VoiceBoxWriteScreen extends StatefulWidget {
  const VoiceBoxWriteScreen({super.key});

  @override
  State<VoiceBoxWriteScreen> createState() => _VoiceBoxWriteScreenState();
}

class _VoiceBoxWriteScreenState extends State<VoiceBoxWriteScreen> {
  VoiceMessageType _type = VoiceMessageType.grievance;
  bool _isAnonymous = true;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _selectType(VoiceMessageType type) {
    setState(() {
      _type = type;
      // 고충·신고는 기본 익명, 건의는 기본 실명 — 두 경우 모두 사용자가 다시 바꿀 수 있다.
      _isAnonymous = type == VoiceMessageType.grievance;
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty) {
      AppSnackBar.showError(context, message: '제목을 입력해주세요');
      return;
    }
    if (content.isEmpty) {
      AppSnackBar.showError(context, message: '내용을 입력해주세요');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ApiService().submitVoiceBoxMessage(
        type: _type.apiValue,
        title: title,
        content: content,
        isAnonymous: _isAnonymous,
      );

      if (!mounted) return;
      AppSnackBar.showSuccess(context, message: '접수되었습니다');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final message = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('ApiException: ', '');
      AppSnackBar.showError(
        context,
        message: message.isNotEmpty ? message : '제출 중 오류가 발생했습니다',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // B안: 옅은 회색 바탕 위 흰 카드(유형 / 익명 / 제목·내용) — 회색 입력칸은 흰 카드 안에 둔다
      backgroundColor: AppSemanticColors.backgroundCanvas,
      appBar: const CareVAppBar(title: '고충·신고 · 건의함'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '유형',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppSemanticColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    Wrap(
                      spacing: AppSpacing.space2,
                      runSpacing: AppSpacing.space2,
                      children: [
                        SeedChip(
                          label: VoiceMessageType.grievance.label,
                          selected: _type == VoiceMessageType.grievance,
                          onTap: () => _selectType(VoiceMessageType.grievance),
                        ),
                        SeedChip(
                          label: VoiceMessageType.suggestion.label,
                          selected: _type == VoiceMessageType.suggestion,
                          onTap: () => _selectType(VoiceMessageType.suggestion),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),

              SeedCallout(
                variant: SeedCalloutVariant.info,
                title: '이 글은 기관 관리자만 볼 수 있어요',
                description: _isAnonymous
                    ? '대표·시설장·사무국장급 관리자만 열람하며, 관리자 화면에는 작성자가 "익명"으로 표시돼요. 본인은 제출 내역에서 언제든 확인할 수 있어요.'
                    : '대표·시설장·사무국장급 관리자만 열람해요. "익명으로 제출"을 켜면 관리자 화면에서 작성자 이름이 가려져요.',
              ),
              const SizedBox(height: AppSpacing.cardGap),

              // 익명 켜고 끄기 — 테두리 상자 대신 흰 카드
              AppCard(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.cardPadding,
                  AppSpacing.space4,
                  AppSpacing.space3,
                  AppSpacing.space4,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.visibility_off_outlined,
                      color: _isAnonymous
                          ? AppSemanticColors.brandDefault
                          : AppSemanticColors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '익명으로 제출',
                            style: AppTypography.titleMedium.copyWith(
                              color: AppSemanticColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space0_5),
                          Text(
                            '관리자 화면에 작성자 이름을 표시하지 않아요',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppSemanticColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    Switch(
                      value: _isAnonymous,
                      onChanged: (value) => setState(() => _isAnonymous = value),
                      activeTrackColor: AppSemanticColors.brandDefault.withValues(alpha: 0.5),
                      activeThumbColor: AppSemanticColors.brandDefault,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SeedTextField(
                      label: '제목',
                      placeholder: '제목을 입력해주세요',
                      controller: _titleController,
                    ),
                    const SizedBox(height: AppSpacing.space5),
                    SeedTextField(
                      label: '내용',
                      placeholder: _type == VoiceMessageType.grievance
                          ? '어떤 고충·신고 사항인지 자세히 적어주세요'
                          : '개선했으면 하는 내용을 자세히 적어주세요',
                      controller: _contentController,
                      maxLines: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space6),

              SizedBox(
                width: double.infinity,
                child: SeedButton(
                  label: '제출하기',
                  size: SeedButtonSize.large,
                  isLoading: _isSubmitting,
                  isDisabled: _isSubmitting,
                  onPressed: _submit,
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
            ],
          ),
        ),
      ),
    );
  }
}
