import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMyMessage;
  final bool showSenderName;
  final bool isAdmin;
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMyMessage,
    this.showSenderName = false,
    this.isAdmin = false,
    this.onLongPress,
  });

  String _formatMessageTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? '오전' : '오후';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$period $displayHour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMyMessage
        ? AppSemanticColors.interactivePrimaryDefault
        : AppSemanticColors.surfaceDefault;

    final textColor = isMyMessage
        ? AppSemanticColors.textInverse
        : AppSemanticColors.textPrimary;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.space2),
        child: Row(
          mainAxisAlignment: isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMyMessage) const SizedBox(width: AppSpacing.space1),

            // 내 메시지: 시간 + 읽음 표시
            if (isMyMessage) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (message.readCount > 0)
                    Text(
                      '${message.readCount}',
                      style: AppTypography.labelSmall.copyWith(
                        color: isAdmin
                            ? AppSemanticColors.textSecondary
                            : AppSemanticColors.interactivePrimaryDefault,
                      ),
                    ),
                  Text(
                    _formatMessageTime(message.createdAt),
                    style: AppTypography.labelSmall.copyWith(
                      color: AppSemanticColors.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.space1),
            ],

            // 메시지 버블
            Flexible(
              child: Column(
                crossAxisAlignment: isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (showSenderName && !isMyMessage)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.space2, bottom: AppSpacing.space1),
                      child: Text(
                        message.senderName,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppSemanticColors.textSecondary,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space3,
                      vertical: AppSpacing.space2,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(AppBorderRadius.xl),
                        topRight: const Radius.circular(AppBorderRadius.xl),
                        bottomLeft: Radius.circular(isMyMessage ? AppBorderRadius.xl : AppBorderRadius.base),
                        bottomRight: Radius.circular(isMyMessage ? AppBorderRadius.base : AppBorderRadius.xl),
                      ),
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    child: message.type == MessageType.system
                        ? Text(
                            message.displayContent,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppSemanticColors.textTertiary,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        : _buildMessageContent(textColor),
                  ),
                ],
              ),
            ),

            // 상대 메시지: 시간
            if (!isMyMessage) ...[
              const SizedBox(width: AppSpacing.space1),
              Text(
                _formatMessageTime(message.createdAt),
                style: AppTypography.labelSmall.copyWith(
                  color: AppSemanticColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(Color textColor) {
    if (message.isDeleted) {
      return Text(
        '삭제된 메시지입니다',
        style: AppTypography.bodyMedium.copyWith(
          color: textColor.withValues(alpha: 0.5),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    switch (message.type) {
      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.fileUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                child: Image.network(
                  message.fileUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const SizedBox(
                      width: 100,
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 100,
                      height: 100,
                      color: AppSemanticColors.backgroundTertiary,
                      child: Icon(Icons.broken_image, color: AppSemanticColors.textTertiary),
                    );
                  },
                ),
              ),
          ],
        );

      case MessageType.file:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.attach_file, color: textColor, size: 18),
            const SizedBox(width: AppSpacing.space1),
            Flexible(
              child: Text(
                message.fileName ?? '파일',
                style: AppTypography.bodyMedium.copyWith(
                  color: textColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        );

      case MessageType.text:
      case MessageType.system:
      default:
        return Text(
          message.content ?? '',
          style: AppTypography.bodyMedium.copyWith(color: textColor),
        );
    }
  }
}
