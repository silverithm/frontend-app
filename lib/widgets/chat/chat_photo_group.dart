import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/chat_message.dart';
import '../../utils/video_thumbnail_cache.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/chat_image_url.dart';

/// 같은 사람이 연달아 보낸 사진 여러 장을 한 말풍선 안의 격자로 그린다.
///
/// 묶음 판정 자체는 [buildPhotoGroupMap](utils/chat_message_grouping.dart)이 하고,
/// 여기서는 그리기만 한다.
///
/// **한 장짜리는 이 위젯을 쓰지 않는다.** 한 장은 예전처럼 원본 비율 그대로
/// 그려야 여백(레터박스)이 생기지 않기 때문이다. 격자 칸은 반대로 정사각형
/// 크롭(BoxFit.cover)이 맞다 — 칸마다 비율이 제각각이면 격자가 무너진다.
///
/// 목록에 거는 URL은 [resolveChatImageUrl](축소본 우선)이고, 눌러서 크게 볼 때는
/// 호출부가 원본(fileUrl)을 넘긴다. 이 구분은 유지되어야 한다.
class ChatPhotoGroup extends StatelessWidget {
  final List<ChatMessage> messages;

  /// 말풍선이 쓸 수 있는 최대 폭.
  final double maxWidth;

  /// 몇 번째 사진을 눌렀는지 알려준다([messages]의 인덱스).
  final void Function(int index) onTap;

  /// 길게 누른 사진. 묶음이어도 리액션·답장·삭제는 **누른 그 사진**에 걸려야 하므로
  /// 칸마다 따로 받는다(말풍선 전체에 걸면 어느 사진인지 알 수 없다).
  final void Function(int index)? onLongPress;

  const ChatPhotoGroup({
    super.key,
    required this.messages,
    required this.maxWidth,
    required this.onTap,
    this.onLongPress,
  });

  /// 장수별 열 수. 3×3을 넘지 않으므로 말풍선이 화면 한 칸을 넘지 않는다.
  static int columnsFor(int count) {
    if (count <= 2) return 2;
    if (count == 3) return 3;
    if (count == 4) return 2; // 2×2가 3+1보다 눈에 안정적이다
    return 3;
  }

  /// 칸 사이 간격. 사진끼리 붙어 보이되 경계는 남을 만큼만.
  static const double _gap = 2;

  @override
  Widget build(BuildContext context) {
    final count = messages.length;
    final columns = columnsFor(count);
    final cell = (maxWidth - _gap * (columns - 1)) / columns;
    final rows = (count / columns).ceil();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      child: SizedBox(
        width: maxWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var row = 0; row < rows; row++) ...[
              if (row > 0) const SizedBox(height: _gap),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var col = 0; col < columns; col++)
                    if (row * columns + col < count) ...[
                      if (col > 0) const SizedBox(width: _gap),
                      _cell(row * columns + col, cell),
                    ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cell(int index, double size) {
    final message = messages[index];
    final url = resolveChatImageUrl(message);

    return Semantics(
      button: true,
      label: '${index + 1}번째 사진 크게 보기',
      child: GestureDetector(
        onTap: () => onTap(index),
        onLongPress: onLongPress == null ? null : () => onLongPress!(index),
        child: SizedBox(
          width: size,
          height: size,
          child: url == null
              ? _broken(size)
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  // 칸보다 큰 원본을 그대로 디코드하지 않도록 제한
                  memCacheWidth: (size * 2).round(),
                  placeholder: (context, _) => Container(
                    width: size,
                    height: size,
                    color: AppSemanticColors.backgroundTertiary,
                  ),
                  errorWidget: (context, _, _) => _broken(size),
                ),
        ),
      ),
    );
  }

  Widget _broken(double size) {
    return Container(
      width: size,
      height: size,
      color: AppSemanticColors.backgroundTertiary,
      child: Icon(Icons.broken_image, color: AppSemanticColors.textTertiary),
    );
  }
}

/// 동영상 첨부 말풍선.
///
/// 첫 프레임은 **서버에 저장하지 않고 영상에서 그때그때 뽑는다**
/// ([VideoThumbnailCache]). 서버가 만들어 저장하는 방식이면 앞으로 올리는 것만
/// 썸네일이 생기고 이미 올라간 동영상은 영영 안 생기는데, 이 방식은 옛 동영상까지
/// 전부 살아난다. 서버에 ffmpeg를 넣지 않아도 되는 건 덤이다.
///
/// **재생 표시는 썸네일이 있든 없든 항상 그린다.** 페이드인으로 시작하는 영상은
/// 첫 프레임이 새까매서, 그림만으로는 동영상인지 알 수 없기 때문이다.
/// (웹은 `<video preload="metadata">`로 브라우저가 같은 일을 공짜로 해준다.)
class ChatVideoBubble extends StatefulWidget {
  final ChatMessage message;
  final double maxWidth;
  final VoidCallback onTap;

  const ChatVideoBubble({
    super.key,
    required this.message,
    required this.maxWidth,
    required this.onTap,
  });

  @override
  State<ChatVideoBubble> createState() => _ChatVideoBubbleState();
}

class _ChatVideoBubbleState extends State<ChatVideoBubble> {
  Uint8List? _thumbnail;

  @override
  void initState() {
    super.initState();
    _resolveThumbnail();
  }

  @override
  void didUpdateWidget(covariant ChatVideoBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.fileUrl != widget.message.fileUrl) {
      _thumbnail = null;
      _resolveThumbnail();
    }
  }

  void _resolveThumbnail() {
    final url = widget.message.fileUrl;
    if (url == null || url.isEmpty) return;

    // 이미 뽑아 둔 것이 있으면 프레임 한 번 깜빡이지 않게 그대로 쓴다.
    final cached = VideoThumbnailCache.peek(url);
    if (cached != null) {
      _thumbnail = cached;
      return;
    }
    if (VideoThumbnailCache.isKnownFailure(url)) return;

    // 목록을 막지 않도록 비동기로 맡긴다. 화면에 실제로 그려진 말풍선만
    // 여기 오므로(ListView.builder), 스크롤로 지나친 영상은 뽑지 않는다.
    VideoThumbnailCache.load(url).then((bytes) {
      if (!mounted || bytes == null) return;
      setState(() => _thumbnail = bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final width = widget.maxWidth;
    final thumbnail = _thumbnail;

    return Semantics(
      button: true,
      label: '동영상 재생: ${message.fileName ?? ''}',
      child: GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          child: SizedBox(
            width: width,
            height: width * 9 / 16,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 썸네일을 못 뽑았거나 아직 오지 않았으면 검은 자리로 둔다.
                Container(color: AppColors.black),
                if (thumbnail != null)
                  Image.memory(
                    thumbnail,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                // 첫 프레임이 밝은 영상에서도 재생 표시가 묻히지 않도록 살짝 어둡게.
                if (thumbnail != null)
                  Container(color: AppColors.black.withValues(alpha: 0.18)),
                Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white.withValues(alpha: 0.22),
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.white,
                      size: 34,
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Row(
                    children: [
                      Icon(
                        Icons.videocam_outlined,
                        size: 14,
                        color: AppColors.white70,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          message.fileName ?? '동영상',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
