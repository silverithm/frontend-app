import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 전체화면으로 볼 사진 한 장.
class ChatImageItem {
  /// **원본** URL. 축소본(thumbnailUrl)을 여기 넣으면 안 된다 —
  /// 확대해서 보는데 축소본이 뜨면 안 되기 때문이다.
  final String imageUrl;
  final String fileName;

  const ChatImageItem({required this.imageUrl, required this.fileName});
}

/// 채팅에서 보낸 사진을 앱 안에서 바로 크게 본다.
/// 확대·축소만 하고, 저장은 호출하는 쪽의 [onDownload]에 맡긴다.
/// 디스크 캐시가 있어(cached_network_image) 목록 썸네일에서 이미 받아둔
/// 사진이면 방을 다시 열거나 풀스크린을 다시 열 때 즉시 뜬다.
///
/// 사진 묶음(격자)에서 열면 [items]에 그 묶음이 통째로 들어와 **좌우로 넘겨**
/// 같은 묶음의 다른 사진을 볼 수 있다. 한 장짜리면 넘길 것이 없으므로
/// 예전과 똑같이 보인다.
class ChatImageViewer extends StatefulWidget {
  final List<ChatImageItem> items;
  final int initialIndex;

  /// 지금 보고 있는 사진을 저장한다. 인자는 화면에 떠 있는 사진.
  final void Function(ChatImageItem item)? onDownload;

  /// 이 묶음의 사진을 **한 번에** 저장한다.
  /// 서른 장을 한 장씩 누르게 두면 쓸 수 없는 기능이나 마찬가지다.
  final void Function(List<ChatImageItem> items)? onDownloadAll;

  const ChatImageViewer({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.onDownload,
    this.onDownloadAll,
  });

  /// 사진 한 장을 연다(예전부터 쓰던 형태 — 호출부를 바꾸지 않아도 된다).
  static Future<void> open(
    BuildContext context, {
    required String imageUrl,
    required String fileName,
    VoidCallback? onDownload,
  }) {
    return openGallery(
      context,
      items: [ChatImageItem(imageUrl: imageUrl, fileName: fileName)],
      onDownload: onDownload == null ? null : (_) => onDownload(),
    );
  }

  /// 사진 묶음을 [initialIndex]부터 연다.
  static Future<void> openGallery(
    BuildContext context, {
    required List<ChatImageItem> items,
    int initialIndex = 0,
    void Function(ChatImageItem item)? onDownload,
    void Function(List<ChatImageItem> items)? onDownloadAll,
  }) {
    if (items.isEmpty) return Future.value();
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ChatImageViewer(
          items: items,
          initialIndex: initialIndex,
          onDownload: onDownload,
          onDownloadAll: onDownloadAll,
        ),
      ),
    );
  }

  @override
  State<ChatImageViewer> createState() => _ChatImageViewerState();
}

class _ChatImageViewerState extends State<ChatImageViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.items.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;
    final current = widget.items[_index];

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              current.fileName,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (total > 1)
              Text(
                '${_index + 1} / $total',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.white70,
                ),
              ),
          ],
        ),
        actions: [
          if (widget.onDownload != null)
            IconButton(
              onPressed: () => widget.onDownload!(current),
              icon: const Icon(Icons.download_outlined),
              tooltip: '저장',
            ),
          // 두 장 이상일 때만 — 한 장짜리에 '전체 저장'은 같은 버튼이 둘인 셈이다
          if (widget.onDownloadAll != null && widget.items.length > 1)
            IconButton(
              onPressed: () => widget.onDownloadAll!(widget.items),
              icon: const Icon(Icons.download_for_offline_outlined),
              tooltip: '${widget.items.length}장 모두 저장',
            ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: total,
        // 한 장뿐이면 넘길 것이 없다. 확대 중에도 옆으로 끌려가지 않게
        // 페이지 넘김은 InteractiveViewer 바깥에서만 받는다.
        physics: total > 1
            ? const PageScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (context, i) => Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: CachedNetworkImage(
              imageUrl: widget.items[i].imageUrl,
              fit: BoxFit.contain,
              progressIndicatorBuilder: (context, url, progress) =>
                  CircularProgressIndicator(
                    color: AppColors.white,
                    value: progress.progress,
                  ),
              errorWidget: (context, url, error) {
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
      ),
    );
  }
}
