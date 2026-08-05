import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../seed/seed_button.dart';
import 'signature_pad.dart';

/// 승인 시 서명 확인 시트.
/// 등록된 서명이 있으면 그대로 날인(반환값 'registered'), 즉석 그리기면 base64 data URL 반환.
/// 취소 시 null.
class SignatureConfirmResult {
  final bool useRegistered;
  final String? signatureBase64;

  SignatureConfirmResult.registered()
      : useRegistered = true,
        signatureBase64 = null;

  SignatureConfirmResult.drawn(this.signatureBase64) : useRegistered = false;
}

Future<SignatureConfirmResult?> showSignatureConfirmSheet(
  BuildContext context, {
  String title = '결재 승인',
}) {
  return showModalBottomSheet<SignatureConfirmResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppSemanticColors.surfaceDefault,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _SignatureConfirmSheet(title: title),
  );
}

class _SignatureConfirmSheet extends StatefulWidget {
  final String title;

  const _SignatureConfirmSheet({required this.title});

  @override
  State<_SignatureConfirmSheet> createState() => _SignatureConfirmSheetState();
}

class _SignatureConfirmSheetState extends State<_SignatureConfirmSheet> {
  final SignaturePadController _padController = SignaturePadController();
  String? _registeredUrl;
  bool _isLoading = true;
  bool _useRegistered = true;
  bool _padEmpty = true;

  @override
  void initState() {
    super.initState();
    _loadRegistered();
  }

  Future<void> _loadRegistered() async {
    try {
      final response = await ApiService().getMySignature();
      if (mounted) {
        setState(() {
          _registeredUrl = response['signatureUrl']?.toString();
          _useRegistered = _registeredUrl != null && _registeredUrl!.isNotEmpty;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('등록 서명 조회 실패: $e');
      if (mounted) {
        setState(() {
          _registeredUrl = null;
          _useRegistered = false;
          _isLoading = false;
        });
      }
    }
  }

  bool get _hasRegistered => _registeredUrl != null && _registeredUrl!.isNotEmpty;

  Future<void> _confirm() async {
    if (_useRegistered && _hasRegistered) {
      Navigator.pop(context, SignatureConfirmResult.registered());
      return;
    }
    final dataUrl = await _padController.exportPngDataUrl();
    if (dataUrl == null) return;
    if (!mounted) return;
    Navigator.pop(context, SignatureConfirmResult.drawn(dataUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.space4,
        right: AppSpacing.space4,
        top: AppSpacing.space4,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.space4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: AppTypography.heading6.copyWith(
                  color: AppSemanticColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: AppSemanticColors.textSecondary),
              ),
            ],
          ),
          Text(
            '승인과 함께 결재란에 서명이 날인됩니다.',
            style: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ))
          else ...[
            if (_hasRegistered) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildModeButton('등록된 서명 사용', _useRegistered, () {
                      setState(() => _useRegistered = true);
                    }),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: _buildModeButton('직접 그리기', !_useRegistered, () {
                      setState(() => _useRegistered = false);
                    }),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space3),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.space3),
                decoration: BoxDecoration(
                  color: AppSemanticColors.statusInfoBackground,
                  borderRadius: BorderRadius.circular(AppSpacing.space3),
                ),
                child: Text(
                  '등록된 서명이 없습니다. 이번에는 직접 그려 승인하세요.\n프로필 > 결재 서명 관리에서 등록하면 다음부터 바로 승인할 수 있습니다.',
                  style: AppTypography.caption.copyWith(
                    color: AppSemanticColors.statusInfoIcon,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.space3),
            ],
            if (_useRegistered && _hasRegistered)
              Center(
                child: Container(
                  height: 110,
                  width: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppSemanticColors.borderDefault),
                    borderRadius: BorderRadius.circular(AppSpacing.space3),
                  ),
                  child: Image.network(
                    _registeredUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text('서명 미리보기 실패',
                          style: AppTypography.caption
                              .copyWith(color: AppSemanticColors.textTertiary)),
                    ),
                  ),
                ),
              )
            else
              SignaturePad(
                controller: _padController,
                onChanged: (isEmpty) => setState(() => _padEmpty = isEmpty),
              ),
            const SizedBox(height: AppSpacing.space3),
            SizedBox(
              width: double.infinity,
              child: SeedButton(
                label: '서명하고 승인',
                variant: SeedButtonVariant.brandSolid,
                size: SeedButtonSize.large,
                isDisabled: !((_useRegistered && _hasRegistered) || !_padEmpty),
                onPressed: (_useRegistered && _hasRegistered) || !_padEmpty
                    ? _confirm
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeButton(String text, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
        decoration: BoxDecoration(
          color: selected
              ? AppSemanticColors.interactivePrimaryDefault
              : AppSemanticColors.backgroundTertiary,
          borderRadius: BorderRadius.circular(AppSpacing.space3),
        ),
        child: Center(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              color: selected
                  ? AppSemanticColors.textInverse
                  : AppSemanticColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
