import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/approval/signature_pad.dart';
import '../widgets/common/app_snackbar.dart';
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
      final response = await ApiService().registerMySignature(imageBase64: dataUrl);
      if (mounted) {
        setState(() {
          _signatureUrl = response['signatureUrl']?.toString();
        });
        _padController.clear();
        AppSnackBar.showSuccess(context,
            message: '서명이 등록되었습니다. 결재 승인 시 자동으로 날인됩니다.');
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
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: Text('결재 서명 관리',
            style: AppTypography.heading6
                .copyWith(color: AppSemanticColors.textInverse)),
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        foregroundColor: AppSemanticColors.textInverse,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 등록된 서명
                  if (_signatureUrl != null && _signatureUrl!.isNotEmpty) ...[
                    Text('등록된 서명',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppSemanticColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: AppSpacing.space2),
                    Container(
                      height: 130, // 스케일 밖 값 — 대응 토큰 없음, 유지
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        border: Border.all(color: AppSemanticColors.borderDefault),
                        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                      ),
                      child: Image.network(
                        _signatureUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text('서명 이미지를 불러올 수 없습니다',
                              style: AppTypography.caption.copyWith(
                                  color: AppSemanticColors.textTertiary)),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space2),
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
                    const SizedBox(height: AppSpacing.space4),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.space3),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.statusInfoBackground,
                        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                      ),
                      child: Text(
                        '등록된 서명이 없습니다.\n서명을 등록하면 결재 승인 시 결재란에 자동으로 날인됩니다.',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppSemanticColors.statusInfoIcon),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space4),
                  ],

                  // 새 서명 그리기
                  Text(
                    _signatureUrl != null ? '새 서명 등록 (기존 서명 대체)' : '서명 그리기',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppSemanticColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  SignaturePad(
                    controller: _padController,
                    height: 200,
                    onChanged: (isEmpty) => setState(() => _padEmpty = isEmpty),
                  ),
                  const SizedBox(height: AppSpacing.space3),
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
