import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class AppInput extends StatefulWidget {
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final EdgeInsets? contentPadding;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final AutovalidateMode? autovalidateMode;
  final bool autofocus;

  const AppInput({
    super.key,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.controller,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
    this.onTap,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.contentPadding,
    this.inputFormatters,
    this.validator,
    this.autovalidateMode,
    this.autofocus = false,
  });

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          // B안: 라벨 15/w600 검정, 칸과 8 띄움(시안 .sh-label)
          Text(
            widget.label!,
            style: AppTypography.titleSmall.copyWith(
              color: AppSemanticColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
        ],
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          obscureText: widget.obscureText,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          onChanged: widget.onChanged,
          onTap: widget.onTap,
          onFieldSubmitted: widget.onSubmitted,
          inputFormatters: widget.inputFormatters,
          validator: widget.validator,
          autovalidateMode: widget.autovalidateMode,
          autofocus: widget.autofocus,
          style: AppTypography.bodyMedium.copyWith(
            color: widget.enabled
                ? AppSemanticColors.textPrimary
                : AppSemanticColors.textDisabled,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            helperText: widget.helperText,
            errorText: widget.errorText,
            prefixIcon: widget.prefixIcon,
            suffixIcon: widget.suffixIcon,
            contentPadding: widget.contentPadding ??
                const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space4,
                  vertical: 13,
                ),
            // B안: 회색으로 채운 칸, 평소엔 테두리 없음(시안 .field)
            filled: true,
            fillColor: widget.enabled
                ? AppSemanticColors.fillDefault
                : AppSemanticColors.surfaceDisabled,
            border: _getBorder(),
            enabledBorder: _getBorder(),
            focusedBorder: _getFocusedBorder(),
            errorBorder: _getErrorBorder(),
            focusedErrorBorder: _getFocusedErrorBorder(),
            disabledBorder: _getDisabledBorder(),
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textTertiary,
            ),
            helperStyle: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.textTertiary,
            ),
            errorStyle: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.statusErrorText,
            ),
            counterStyle: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  static const BorderRadius _radius =
      BorderRadius.all(Radius.circular(AppBorderRadius.control));

  OutlineInputBorder _getBorder() {
    return const OutlineInputBorder(
      borderRadius: _radius,
      borderSide: BorderSide.none,
    );
  }

  OutlineInputBorder _getFocusedBorder() {
    return const OutlineInputBorder(
      borderRadius: _radius,
      borderSide: BorderSide(color: AppSemanticColors.borderFocus, width: 2),
    );
  }

  OutlineInputBorder _getErrorBorder() {
    return const OutlineInputBorder(
      borderRadius: _radius,
      borderSide: BorderSide(color: AppSemanticColors.statusErrorText, width: 2),
    );
  }

  OutlineInputBorder _getFocusedErrorBorder() => _getErrorBorder();

  OutlineInputBorder _getDisabledBorder() => _getBorder();
}

class AppPasswordInput extends StatefulWidget {
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final AutovalidateMode? autovalidateMode;

  const AppPasswordInput({
    super.key,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.autovalidateMode,
  });

  @override
  State<AppPasswordInput> createState() => _AppPasswordInputState();
}

class _AppPasswordInputState extends State<AppPasswordInput> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return AppInput(
      label: widget.label,
      hintText: widget.hintText,
      helperText: widget.helperText,
      errorText: widget.errorText,
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscureText,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      suffixIcon: IconButton(
        tooltip: _obscureText ? '비밀번호 표시' : '비밀번호 숨기기',
        icon: Icon(
          _obscureText ? Icons.visibility_off : Icons.visibility,
          color: AppSemanticColors.textTertiary,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      ),
    );
  }
}

class AppTextArea extends StatelessWidget {
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool enabled;
  final bool readOnly;
  final int maxLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final AutovalidateMode? autovalidateMode;

  const AppTextArea({
    super.key,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.controller,
    this.focusNode,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 4,
    this.maxLength,
    this.onChanged,
    this.validator,
    this.autovalidateMode,
  });

  @override
  Widget build(BuildContext context) {
    return AppInput(
      label: label,
      hintText: hintText,
      helperText: helperText,
      errorText: errorText,
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: onChanged,
      validator: validator,
      autovalidateMode: autovalidateMode,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
    );
  }
}
