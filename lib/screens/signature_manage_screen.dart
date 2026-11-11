import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/approval/signature_pad.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_skeleton.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/common/carev_app_bar.dart';
import '../widgets/seed/seed_button.dart';

/// 결재 서명 관리 화면.
/// 서명을 그려 등록해두면 결재 승인 시 결재란에 자동으로 날인된다.
class SignatureManageScreen extends StatefulWidget {
  const SignatureManageScreen({super.key});

  @override
  State<SignatureManageScreen> createState() => _SignatureManageScreenState();
}

class _SignatureManageScreenState extends State<SignatureManageScreen> {
  final SignaturePadController _padController = SignaturePadController();
  String? _signatureUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _padEmpty = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await ApiService().getMySignature();
      if (mounted) {
        setState(() {
          _signatureUrl = response['signatureUrl']?.toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('서명 조회 실패: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _register() async {
    final dataUrl = await _padController.exportPngDataUrl();
    if (dataUrl == null) {
      AppSnackBar.showError(context, message: '서명을 먼저 그려주세요');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final response = await ApiService().registerMySignature(
        imageBase64: dataUrl,
      );
      if (mounted) {
        setState(() {
          _signatureUrl = response['signatureUrl']?.toString();
        });
        _padController.clear();
        AppSnackBar.showSuccess(
          context,
          message: '서명이 등록되었습니다. 결재 승인 시 자동으로 날인됩니다.',
        );
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, message: '서명 등록에 실패했습니다');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _isSaving = true);
    try {
      await ApiService().deleteMySignature();
      if (mounted) {
        setState(() => _signatureUrl = null);
        AppSnackBar.showSuccess(context, message: '서명이 삭제되었습니다');
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, message: '서명 삭제에 실패했습니다');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSignature = _signatureUrl != null && _signatureUrl!.isNotEmpty;
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundCanvas,
      appBar: const CareVAppBar(title: '결재 서명 관리'),
      body: _isLoading
          // 첫 불러오기 — 등록된 서명 카드 + 서명 그리기 카드 모양 뼈대(같은 여백)
          ? const _SignatureSkeleton()
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.space3,
                AppSpacing.screenGutter,
                AppSpacing.space6 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 등록된 서명 — B안: 테두리 없는 흰 카드, 서명 그림은 회색 채움 칸 위에
                  if (hasSignature) ...[
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              '등록된 서명',
                              style: AppTypography.heading6.copyWith(
                                color: AppSemanticColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space3),
                          Container(
                            height: 130, // 스케일 밖 값 — 대응 토큰 없음, 유지
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppSemanticColors.fillDefault,
                              border: Border.all(
                                color: AppSemanticColors.borderHairline,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppBorderRadius.control,
                              ),
                            ),
                            child: Image.network(
                              _signatureUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  '서명 이미지를 불러올 수 없습니다',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppSemanticColors.textTertiary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space3),
                          Align(
                            alignment: Alignment.centerRight,
                            // 서명 삭제는 되돌릴 수 없는 파괴적 행위 — critical SeedButton으로 표준화
                            child: SeedButton(
                              label: '서명 삭제',
                              variant: SeedButtonVariant.critical,
                              size: SeedButtonSize.small,
                              prefixIcon: Icons.delete_outline,
                              isDisabled: _isSaving,
                              onPressed: _isSaving ? null : _delete,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    AppCard(
                      backgroundColor: AppSemanticColors.statusInfoBackground,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppSpacing.space0_5,
                            ),
                            child: Icon(
                              Icons.info_outline,
                              size: 22,
                              color: AppSemanticColors.statusInfoIcon,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.space2_5),
                          Expanded(
                            child: Text(
                              '등록된 서명이 없습니다.\n서명을 등록하면 결재 승인 시 결재란에 자동으로 날인됩니다.',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppSemanticColors.statusInfoText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.cardGap),

                  // 새 서명 그리기
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            _signatureUrl != null
                                ? '새 서명 등록 (기존 서명 대체)'
                                : '서명 그리기',
                            style: AppTypography.heading6.copyWith(
                              color: AppSemanticColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space3),
                        SignaturePad(
                          controller: _padController,
                          height: 200,
                          onChanged: (isEmpty) =>
                              setState(() => _padEmpty = isEmpty),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space5),
                  SizedBox(
                    width: double.infinity,
                    child: SeedButton(
                      label: '서명 등록',
                      variant: SeedButtonVariant.brandSolid,
                      size: SeedButtonSize.large,
                      isLoading: _isSaving,
                      isDisabled: _padEmpty,
                      onPressed: _isSaving || _padEmpty ? null : _register,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// 서명 관리 첫 불러오기 뼈대 — 흰 카드 두 장(제목 + 서명 그림 칸 130 / 서명 그리기 칸 200).
class _SignatureSkeleton extends StatelessWidget {
  const _SignatureSkeleton();

  Widget _card(double boxHeight) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppBorderRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSkeletonLine(widthFactor: 0.32, height: AppSpacing.space5),
          const SizedBox(height: AppSpacing.space3),
          AppSkeletonBox(height: boxHeight, radius: AppBorderRadius.control),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      // 흰 카드 안의 뼈는 한 단계 옅은 색
      baseColor: AppSemanticColors.skeletonBaseOnCard,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          AppSpacing.space3,
          AppSpacing.screenGutter,
          AppSpacing.space6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _card(130),
            const SizedBox(height: AppSpacing.cardGap),
            _card(200),
          ],
        ),
      ),
    );
  }
}
