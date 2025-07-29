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
          Text(
            widget.label!,
            style: AppTypography.labelMedium.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space1_5),
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
                  vertical: AppSpacing.space3,
                ),
            filled: true,
            fillColor: widget.enabled
                ? AppSemanticColors.surfaceDefault
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
            helperStyle: AppTypography.labelSmall.copyWith(
              color: AppSemanticColors.textTertiary,
            ),
            errorStyle: AppTypography.labelSmall.copyWith(
              color: AppSemanticColors.statusErrorText,
            ),
            counterStyle: AppTypography.labelSmall.copyWith(
              color: AppSemanticColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _getBorder() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      borderSide: const BorderSide(
        color: AppSemanticColors.borderDefault,
        width: 1,
      ),
    );
  }

  OutlineInputBorder _getFocusedBorder() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      borderSide: const BorderSide(
        color: AppSemanticColors.borderFocus,
        width: 2,
      ),
    );
  }

  OutlineInputBorder _getErrorBorder() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      borderSide: const BorderSide(
        color: AppSemanticColors.statusErrorIcon,
        width: 1,
      ),
    );
  }

  OutlineInputBorder _getFocusedErrorBorder() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      borderSide: const BorderSide(
        color: AppSemanticColors.statusErrorIcon,
        width: 2,
      ),
    );
  }

  OutlineInputBorder _getDisabledBorder() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      borderSide: const BorderSide(
        color: AppSemanticColors.borderDisabled,
        width: 1,
      ),
    );
  }
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