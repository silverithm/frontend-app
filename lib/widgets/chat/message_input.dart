import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_theme.dart';

class MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSend;
  final VoidCallback? onAttachment;
  final bool isAdmin;

  const MessageInput({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onSend,
    this.onAttachment,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.space4,
        right: AppSpacing.space4,
        top: AppSpacing.space2,
        bottom: AppSpacing.space2 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 파일 첨부 버튼
          if (onAttachment != null)
            IconButton(
              onPressed: onAttachment,
              icon: Icon(
                Icons.add_circle_outline,
                color: AppSemanticColors.textTertiary,
              ),
            ),

          // 메시지 입력 필드
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space3),
              decoration: BoxDecoration(
                color: AppSemanticColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(AppBorderRadius.xl),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: '메시지를 입력하세요',
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
                ),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),

          const SizedBox(width: AppSpacing.space2),

          // 전송 버튼
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppSemanticColors.interactivePrimaryDefault,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_rounded,
                color: AppSemanticColors.textInverse,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
