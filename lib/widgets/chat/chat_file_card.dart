import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 파일 크기를 "33KB"·"1.2MB"로 줄여 쓴다. 모르면 빈 문자열.
String formatChatFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()}KB';
  final mb = bytes / (1024 * 1024);
  return mb >= 10 ? '${mb.round()}MB' : '${mb.toStringAsFixed(1)}MB';
}

/// 파일 이름의 확장자를 대문자로("xlsx" → "XLSX"). 없으면 빈 문자열.
String chatFileExtension(String? name) {
  if (name == null) return '';
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1 || name.length - dot > 6) return '';
  return name.substring(dot + 1).toUpperCase();
}

/// 말풍선 안 파일 한 장 — 밑줄 친 글자 한 줄 대신 아이콘 칸 + 이름 + (크기 · 종류).
/// 카드 전체가 눌리는 자리다.
class ChatFileCard extends StatelessWidget {
  final String name;
  final int? fileSize;
  final bool isVideo;

  /// 내 말풍선(틸 바탕) 안인지 — 글자·칸 색이 바뀐다.
  final bool onBrand;
  final VoidCallback onTap;

  const ChatFileCard({
    super.key,
    required this.name,
    required this.fileSize,
    required this.isVideo,
    required this.onBrand,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor =
        onBrand ? AppSemanticColors.textInverse : AppSemanticColors.textPrimary;
    final metaColor = onBrand
        ? AppSemanticColors.textInverse.withValues(alpha: 0.8)
        : AppSemanticColors.textTertiary;
    final tileColor = onBrand
        ? AppSemanticColors.textInverse.withValues(alpha: 0.16)
        : AppSemanticColors.backgroundTertiary;
    final iconColor =
        onBrand ? AppSemanticColors.textInverse : AppSemanticColors.textSecondary;

    final meta = [
      if (isVideo) '동영상',
      formatChatFileSize(fileSize),
      if (!isVideo) chatFileExtension(name),
    ].where((e) => e.isNotEmpty).join(' · ');

    return Semantics(
      button: true,
      label: '${isVideo ? '동영상' : '파일'} 열기: $name',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppSpacing.space10,
              height: AppSpacing.space10,
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: BorderRadius.circular(AppBorderRadius.xl),
              ),
              child: Icon(
                isVideo
                    ? Icons.play_circle_outline
                    : Icons.insert_drive_file_outlined,
                size: AppSpacing.space5,
                color: iconColor,
              ),
            ),
            const SizedBox(width: AppSpacing.space2),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleSmall.copyWith(color: titleColor),
                  ),
                  if (meta.isNotEmpty)
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(color: metaColor),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
