import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 당근 Seed 디자인 시스템 — Text Input (Outline variant).
/// 스펙 참조: docs/seed-component-specs.md §2 Text Input
/// (Outline Large/Medium minHeight·padding·radius·font, 상태별 stroke 색)
enum SeedTextFieldSize { medium, large }

class SeedTextField extends StatefulWidget {
  final String label;
  final String? placeholder;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final bool enableObscureToggle;
  final bool isDisabled;
  final bool isReadOnly;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap;
  final TextInputType? keyboardType;
  final SeedTextFieldSize size;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// Form 통합용. 지정 시 내부적으로 [FormField]로 감싸 Form.validate()와 연동되고,
  /// 검증 실패 메시지가 [errorText]와 동일한 방식으로 표시된다.
  final FormFieldValidator<String>? validator;

  /// null(기본)이면 1줄. 2 이상이면 여러 줄 입력(예: 공지 본문).
  final int? maxLines;

  final TextCapitalization textCapitalization;

  /// 읽기전용 필드를 탭했을 때(예: 주소 검색 시트 열기) 동작.
  final VoidCallback? onTap;

  final AutovalidateMode? autovalidateMode;

  /// false면 라벨 텍스트를 렌더링하지 않는다 — 이미 섹션 헤더가 같은 라벨을
  /// 보여주는 화면에서 라벨 중복을 피할 때 사용 (`label`은 여전히 required,
  /// 접근성 문맥 유지용).
  final bool showLabel;

  const SeedTextField({
    super.key,
    required this.label,
    this.placeholder,
    this.helperText,
    this.errorText,
    this.controller,
    this.onChanged,
    this.obscureText = false,
    this.enableObscureToggle = false,
    this.isDisabled = false,
    this.isReadOnly = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.keyboardType,
    this.size = SeedTextFieldSize.medium,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
    this.maxLines,
    this.textCapitalization = TextCapitalization.none,
    this.onTap,
    this.autovalidateMode,
    this.showLabel = true,
  });

  @override
  State<SeedTextField> createState() => _SeedTextFieldState();
}

class _SeedTextFieldState extends State<SeedTextField> {
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;
  bool _isFocused = false;
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  // minHeight — spec §2: Outline Large x13 / Medium x10
  double get _minHeight => widget.size == SeedTextFieldSize.large ? 52 : 40;

  // Padding X — spec §2: Large x4 / Medium x3.5
  EdgeInsets get _padding => widget.size == SeedTextFieldSize.large
      ? const EdgeInsets.symmetric(horizontal: AppSpacing.space4)
      : const EdgeInsets.symmetric(horizontal: AppSpacing.space3_5);

  // Radius — spec §2: Large r3 / Medium r2
  double get _radius =>
      widget.size == SeedTextFieldSize.large ? AppBorderRadius.xl : AppBorderRadius.lg;

  // Font-size — spec §2: Large t5 / Medium t4
  double get _fontSize =>
      widget.size == SeedTextFieldSize.large ? 15 : AppTypography.fontSizeBase;

  Color _strokeColor(bool hasError) {
    if (widget.isDisabled) return AppSemanticColors.borderDisabled;
    if (hasError) return AppSemanticColors.statusErrorIcon;
    if (_isFocused) return AppSemanticColors.borderFocus;
    return AppSemanticColors.borderDefault;
  }

  // Enabled 1px / Focused·Error 2px — spec §2 상태별 색상 표
  double _strokeWidth(bool hasError) => (_isFocused || hasError) ? 2 : 1;

  @override
  Widget build(BuildContext context) {
    if (widget.validator != null) {
      return FormField<String>(
        validator: widget.validator,
        initialValue: widget.controller?.text,
        autovalidateMode: widget.autovalidateMode ?? AutovalidateMode.onUserInteraction,
        builder: (field) {
          return _buildField(
            errorText: field.errorText ?? widget.errorText,
            onChanged: (value) {
              field.didChange(value);
              widget.onChanged?.call(value);
            },
          );
        },
      );
    }

    return _buildField(errorText: widget.errorText, onChanged: widget.onChanged);
  }

  Widget _buildField({required String? errorText, required ValueChanged<String>? onChanged}) {
    final hasError = errorText != null && errorText.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLabel) ...[
          Text(
            widget.label,
            style: TextStyle(
              fontSize: AppTypography.fontSizeSm,
              fontWeight: AppTypography.fontWeightMedium,
              color: widget.isDisabled
                  ? AppSemanticColors.textDisabled
                  : AppSemanticColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space1_5),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 100), // stroke 전환 duration
          constraints: BoxConstraints(minHeight: _minHeight),
          padding: _padding,
          decoration: BoxDecoration(
            color: (widget.isDisabled || widget.isReadOnly)
                ? AppSemanticColors.surfaceDisabled
                : AppColors.transparent,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: _strokeColor(hasError), width: _strokeWidth(hasError)),
          ),
          child: Row(
            crossAxisAlignment:
                (widget.maxLines != null && widget.maxLines! > 1)
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
            children: [
              if (widget.prefixIcon != null) ...[
                Padding(
                  padding: EdgeInsets.only(top: (widget.maxLines ?? 1) > 1 ? 2 : 0),
                  child: Icon(widget.prefixIcon, size: 18, color: AppSemanticColors.textTertiary),
                ),
                const SizedBox(width: AppSpacing.space2),
              ],
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  onChanged: widget.isDisabled ? null : onChanged,
                  onTap: widget.isDisabled ? null : widget.onTap,
                  obscureText: _obscure,
                  enabled: !widget.isDisabled,
                  readOnly: widget.isReadOnly,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  onSubmitted: widget.onSubmitted,
                  maxLines: widget.obscureText ? 1 : (widget.maxLines ?? 1),
                  textCapitalization: widget.textCapitalization,
                  style: TextStyle(
                    fontSize: _fontSize,
                    color: widget.isDisabled
                        ? AppSemanticColors.textDisabled
                        : AppSemanticColors.textPrimary,
                  ),
                  cursorColor: AppSemanticColors.brandDefault,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: widget.placeholder,
                    hintStyle: TextStyle(
                      fontSize: _fontSize,
                      color: widget.isDisabled
                          ? AppSemanticColors.textDisabled
                          : AppSemanticColors.textTertiary,
                    ),
                  ),
                ),
              ),
              if (widget.enableObscureToggle) ...[
                const SizedBox(width: AppSpacing.space2),
                GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Icon(
                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18,
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
              ] else if (widget.suffixIcon != null) ...[
                const SizedBox(width: AppSpacing.space2),
                GestureDetector(
                  onTap: widget.onSuffixIconTap,
                  child: Icon(widget.suffixIcon, size: 18, color: AppSemanticColors.textTertiary),
                ),
              ],
            ],
          ),
        ),
        if (hasError || (widget.helperText != null && widget.helperText!.isNotEmpty)) ...[
          const SizedBox(height: AppSpacing.space1_5),
          Text(
            hasError ? errorText : widget.helperText!,
            style: TextStyle(
              fontSize: AppTypography.fontSizeXs,
              color: hasError
                  ? AppSemanticColors.statusErrorText
                  : AppSemanticColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}
