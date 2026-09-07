import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 채팅 사진 한 장. **깨져 오면 스스로 다시 받는다.**
///
/// 웹과 같은 이유다(제보: "종종 사진 깨짐"). 저장된 파일은 멀쩡한데 받거나 그리는 도중에
/// 깨지는데, 앱은 한 술 더 뜬다 — CachedNetworkImage가 그 깨진 응답을 **캐시에 저장**해
/// 다음에 열어도 계속 깨진 채로 나온다. 사람이 앱을 지웠다 깔아야 고쳐지는 것은
/// 고쳐진 게 아니다.
///
/// 실패하면 그 URL의 캐시를 지우고 다시 받는다. 정해진 횟수를 넘기면 안내 그림을 둔다.
class ChatPhoto extends StatefulWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Widget Function(BuildContext context)? placeholder;
  final Widget Function(BuildContext context)? brokenBuilder;

  const ChatPhoto({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
    this.placeholder,
    this.brokenBuilder,
  });

  /// 몇 번까지 다시 받아볼지 — 무한 재시도로 서버를 두드리지 않는다
  static const int maxAttempts = 3;

  /// 이번 실패에 다시 받아볼지. 상한을 넘으면 멈추고 안내 그림을 둔다.
  static bool shouldRetry(int attempt) => attempt < maxAttempts;

  /// 다시 받을 때 위젯이 새로 만들어지도록 시도 번호를 키에 넣는다.
  /// 키가 그대로면 Flutter가 같은 위젯으로 보고 깨진 그림을 그대로 둔다.
  static String cacheKeyFor(String url, int attempt) => '$url#$attempt';

  @override
  State<ChatPhoto> createState() => _ChatPhotoState();
}

class _ChatPhotoState extends State<ChatPhoto> {
  int _attempt = 0;

  @override
  void didUpdateWidget(covariant ChatPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 다른 사진으로 바뀌면 처음부터 다시 센다
    if (oldWidget.imageUrl != widget.imageUrl) {
      _attempt = 0;
    }
  }

  Widget _broken(BuildContext context) {
    if (widget.brokenBuilder != null) return widget.brokenBuilder!(context);
    return Container(
      width: widget.width,
      height: widget.height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined, size: 20),
    );
  }

  Future<void> _retry(String url) async {
    // 캐시에 남은 깨진 응답을 지워야 다시 받는 의미가 있다
    try {
      await CachedNetworkImage.evictFromCache(url);
    } catch (_) {
      // 캐시를 못 지워도 재시도 자체는 해본다
    }
    if (!mounted) return;
    setState(() => _attempt += 1);
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) return _broken(context);

    if (!ChatPhoto.shouldRetry(_attempt)) return _broken(context);

    return CachedNetworkImage(
      // 시도 번호를 키에 넣어, 다시 받을 때 위젯이 새로 만들어지게 한다
      key: ValueKey(ChatPhoto.cacheKeyFor(url, _attempt)),
      imageUrl: url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      memCacheWidth: widget.memCacheWidth,
      memCacheHeight: widget.memCacheHeight,
      placeholder: widget.placeholder == null
          ? null
          : (context, _) => widget.placeholder!(context),
      errorWidget: (context, _, _) {
        // 그리는 도중에 setState를 부를 수 없으므로 다음 프레임에 다시 받는다
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ChatPhoto.shouldRetry(_attempt)) _retry(url);
        });
        return widget.placeholder?.call(context) ?? _broken(context);
      },
    );
  }
}
