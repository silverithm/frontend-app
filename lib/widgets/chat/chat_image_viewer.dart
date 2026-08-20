import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 채팅에서 보낸 사진을 앱 안에서 바로 크게 본다.
/// 확대·축소만 하고, 저장은 호출하는 쪽의 [onDownload]에 맡긴다.
class ChatImageViewer extends StatelessWidget {
  final String imageUrl;
  final String fileName;
  final VoidCallback? onDownload;

  const ChatImageViewer({
    super.key,
    required this.imageUrl,
    required this.fileName,
    this.onDownload,
  });

  static Future<void> open(
    BuildContext context, {
    required String imageUrl,
    required String fileName,
    VoidCallback? onDownload,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ChatImageViewer(
          imageUrl: imageUrl,
          fileName: fileName,
          onDownload: onDownload,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          fileName,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (onDownload != null)
            IconButton(
              onPressed: onDownload,
              icon: const Icon(Icons.download_outlined),
              tooltip: '저장',
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const CircularProgressIndicator(color: AppColors.white);
            },
            errorBuilder: (context, error, stackTrace) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.white.withValues(alpha: 0.54),
                    size: 48,
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  Text(
                    '사진을 불러오지 못했습니다',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.white70,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
