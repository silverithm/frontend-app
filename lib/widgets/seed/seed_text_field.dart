import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_typography.dart';

/// 입력칸 — B안(2026-11-12, 시안 .field).
/// 회색(#F2F4F6)으로 채운 칸, 테두리 없음, 모서리 14, 글자 16. 누르고 있으면(포커스) 틸 2px 테두리,
/// 틀리면 빨강 2px + 아래 14 안내. 라벨은 14/w600 검정. 높이 보통 48·큰 54.
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

  /// 입력 글자 수 상한. null이면 제한 없음. 카운터는 그리지 않는다.
  final int? maxLength;

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
    this.maxLength,
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

  double get _minHeight => widget.size == SeedTextFieldSize.large
      ? AppSpacing.buttonHeightLarge
      : AppSpacing.buttonHeight;

  bool get _isMultiline => (widget.maxLines ?? 1) > 1;

  // 여러 줄이면 위아래 13(시안 .field), 한 줄이면 높이 48·54 안에서 가운데
  EdgeInsets get _padding => EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: _isMultiline ? 13 : 0,
      );

  double get _radius => AppBorderRadius.control;

  // 입력값은 본문 16(w400) — 라벨 titleSmall 14/w600과 굵기로 구분된다
  TextStyle get _inputStyle => AppTypography.bodyMedium;

  // 테두리는 늘 2px 자리를 차지하고(평소엔 투명) 색만 바뀐다 — 포커스 때 글자가 밀리지 않게
  Color _strokeColor(bool hasError) {
    if (widget.isDisabled) return AppColors.transparent;
    if (hasError) return AppSemanticColors.statusErrorText;
    if (_isFocused) return AppSemanticColors.borderFocus;
    return AppColors.transparent;
  }

  double _strokeWidth(bool hasError) => 2;

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
            style: AppTypography.titleSmall.copyWith(
              color: widget.isDisabled
                  ? AppSemanticColors.textDisabled
                  : AppSemanticColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
        ],
        AnimatedContainer(
          duration: AppMotion.press, // 테두리 색 전환
          constraints: BoxConstraints(minHeight: _minHeight),
          // 뒤 아이콘 단추가 있으면 오른쪽 여백을 줄여 48 터치 칸이 칸 끝에 붙게 한다
          padding: (widget.enableObscureToggle || widget.suffixIcon != null)
              ? _padding.copyWith(right: AppSpacing.space1)
              : _padding,
          decoration: BoxDecoration(
            color: widget.isDisabled
                ? AppSemanticColors.surfaceDisabled
                : AppSemanticColors.fillDefault,
            borderRadius: BorderRadius.circular(_radius),
          ),
          // 테두리는 위에 겹쳐 그린다(자리를 차지하지 않아 높이 48 안에 48 아이콘 칸이 들어간다)
          foregroundDecoration: BoxDecoration(
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
                  child: Icon(widget.prefixIcon, size: 20, color: AppSemanticColors.textTertiary),
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
                  maxLength: widget.maxLength,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  textCapitalization: widget.textCapitalization,
                  style: _inputStyle.copyWith(
                    color: widget.isDisabled
                        ? AppSemanticColors.textDisabled
                        : AppSemanticColors.textPrimary,
                  ),
                  cursorColor: AppSemanticColors.brandDefault,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    // 테마가 칸 테두리·바탕·안쪽 여백을 기본으로 주므로 전부 꺼 둔다 —
                    // 안 끄면 회색 칸 안에 테두리 칸이 하나 더 그려진다
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    hintText: widget.placeholder,
                    hintStyle: _inputStyle.copyWith(
                      color: widget.isDisabled
                          ? AppSemanticColors.textDisabled
                          : AppSemanticColors.textTertiary,
                    ),
                  ),
                ),
              ),
              if (widget.enableObscureToggle) ...[
                const SizedBox(width: AppSpacing.space2),
                Semantics(
                  button: true,
                  label: _obscure ? '비밀번호 표시' : '비밀번호 숨기기',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: SizedBox.square(
                      dimension: AppSpacing.minTouchTarget,
                      child: Icon(
                        _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: AppSemanticColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ] else if (widget.suffixIcon != null) ...[
                const SizedBox(width: AppSpacing.space2),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onSuffixIconTap,
                  child: SizedBox.square(
                    dimension: AppSpacing.minTouchTarget,
                    child: Icon(widget.suffixIcon, size: 20, color: AppSemanticColors.textTertiary),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (hasError || (widget.helperText != null && widget.helperText!.isNotEmpty)) ...[
          const SizedBox(height: AppSpacing.space1_5),
          Text(
            hasError ? errorText : widget.helperText!,
            style: AppTypography.bodySmall.copyWith(
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
