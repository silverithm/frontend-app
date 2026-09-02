import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// 동영상 첫 프레임을 **재생 시점에 영상에서 직접** 뽑아 온다. 서버에 저장하지 않는다.
///
/// 서버 저장을 택하지 않은 이유: 그러면 앞으로 올리는 동영상만 썸네일이 생기고
/// **이미 올라간 동영상은 영영 안 생긴다.** 영상 파일에서 그때그때 뽑으면 옛 동영상까지
/// 전부 나온다. 서버에 ffmpeg를 넣지 않아도 되는 건 덤이다.
///
/// 이 클래스가 지키는 것:
///  - **두 겹 캐시**: 메모리(같은 화면 재빌드) + 디스크(앱을 다시 켜도 유지).
///    사진이 cached_network_image로 하는 것과 같은 취지다.
///  - **동시 실행 제한**: 목록을 빠르게 훑어 동영상 열 개를 만나도 한 번에
///    [_maxConcurrent]개만 디코딩한다. 나머지는 줄을 선다.
///  - **같은 URL 중복 요청 합치기**: 진행 중인 작업이 있으면 그 Future를 함께 쓴다.
///  - **실패도 기억한다**: 못 뽑는 영상을 스크롤할 때마다 다시 시도하지 않는다.
///
/// 데이터 사용: video_thumbnail은 iOS AVAssetImageGenerator / Android
/// MediaMetadataRetriever를 쓴다. 둘 다 원격 URL을 HTTP 범위 요청으로 읽어
/// 필요한 앞부분(+moov 상자)만 받는다. 영상 전체를 내려받지 않는다.
class VideoThumbnailCache {
  VideoThumbnailCache._();

  /// 한 번에 돌릴 최대 디코딩 수. 현장 기기가 넉넉하지 않아 넉넉히 잡지 않는다.
  static const int _maxConcurrent = 2;

  /// 메모리에 들고 있을 최대 장수. 넘으면 오래된 것부터 버린다.
  static const int _maxMemoryEntries = 60;

  /// 뽑아낼 최대 가로 픽셀. 말풍선 폭이 300dp를 넘지 않으므로 이 정도면 충분하다.
  static const int _maxWidth = 640;

  /// 첫 프레임(0ms) 대신 살짝 뒤를 노린다 — 페이드인으로 시작하는 영상이 흔해
  /// 0ms를 뽑으면 새까만 그림이 나온다. 실패하면 아래에서 0ms로 다시 시도한다.
  static const int _preferredTimeMs = 500;

  /// null 값은 "해봤는데 안 되더라"는 뜻이다(다시 시도하지 않는다).
  static final LinkedHashMap<String, Uint8List?> _memory =
      LinkedHashMap<String, Uint8List?>();

  static final Map<String, Future<Uint8List?>> _inFlight = {};

  static int _running = 0;
  static final Queue<Completer<void>> _waiting = Queue<Completer<void>>();

  static Directory? _diskDir;

  /// 테스트에서 실제 디코딩 대신 끼워 넣는 통로. 평소에는 null이다.
  @visibleForTesting
  static Future<Uint8List?> Function(String url, int timeMs)? extractorOverride;

  /// 지금 동시에 돌고 있는 디코딩 수(테스트에서 상한을 확인한다).
  @visibleForTesting
  static int get runningCount => _running;

  /// 이미 메모리에 있으면 즉시 돌려준다(깜빡임 없이 바로 그리기 위한 통로).
  /// 아직 없으면 null — 그렇다고 "실패"라는 뜻은 아니다. [isKnownFailure]로 구분한다.
  static Uint8List? peek(String url) => _memory[url];

  /// 뽑기를 시도했고 실패로 확정된 URL인지.
  static bool isKnownFailure(String url) =>
      _memory.containsKey(url) && _memory[url] == null;

  static bool isCached(String url) => _memory.containsKey(url);

  /// 썸네일을 얻는다. 실패하면 null — **호출부는 null이어도 반드시 재생 표시를 그려야 한다.**
  static Future<Uint8List?> load(String url) {
    if (_memory.containsKey(url)) {
      return Future.value(_memory[url]);
    }
    final existing = _inFlight[url];
    if (existing != null) return existing;

    final future = _loadUncached(url);
    _inFlight[url] = future;
    return future.whenComplete(() => _inFlight.remove(url));
  }

  static Future<Uint8List?> _loadUncached(String url) async {
    // 1) 디스크에 지난번에 뽑아둔 것이 있으면 디코딩 자체를 건너뛴다.
    final file = await _diskFileFor(url);
    if (file != null) {
      try {
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) {
            _remember(url, bytes);
            return bytes;
          }
        }
      } catch (_) {
        // 캐시가 깨졌을 뿐이다. 아래에서 새로 뽑는다.
      }
    }

    await _acquireSlot();
    try {
      Uint8List? bytes = await _extract(url, _preferredTimeMs);
      // 짧은 영상이라 500ms가 끝을 넘었을 수 있다. 그때는 맨 앞을 노린다.
      bytes ??= await _extract(url, 0);

      _remember(url, bytes);

      if (bytes != null && file != null) {
        // 디스크 기록 실패는 조용히 넘긴다 — 다음에 다시 뽑으면 그만이다.
        unawaited(
          file.writeAsBytes(bytes, flush: false).catchError((Object _) => file),
        );
      }
      return bytes;
    } finally {
      _releaseSlot();
    }
  }

  static Future<Uint8List?> _extract(String url, int timeMs) async {
    final override = extractorOverride;
    if (override != null) {
      return override(url, timeMs);
    }
    try {
      return await VideoThumbnail.thumbnailData(
        video: url,
        imageFormat: ImageFormat.JPEG,
        maxWidth: _maxWidth,
        timeMs: timeMs,
        quality: 70,
      );
    } catch (e) {
      debugPrint('[VideoThumbnail] 첫 프레임 추출 실패($timeMs ms): $e');
      return null;
    }
  }

  static void _remember(String url, Uint8List? bytes) {
    _memory.remove(url);
    _memory[url] = bytes;
    while (_memory.length > _maxMemoryEntries) {
      _memory.remove(_memory.keys.first);
    }
  }

  // --- 동시 실행 제한 -------------------------------------------------------

  static Future<void> _acquireSlot() {
    if (_running < _maxConcurrent) {
      _running++;
      return Future.value();
    }
    final completer = Completer<void>();
    _waiting.add(completer);
    return completer.future;
  }

  static void _releaseSlot() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
      return;
    }
    _running--;
  }

  // --- 디스크 캐시 ----------------------------------------------------------

  static Future<Directory?> _ensureDir() async {
    if (_diskDir != null) return _diskDir;
    try {
      final base = await getTemporaryDirectory();
      final dir = Directory('${base.path}/chat_video_thumbs');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _diskDir = dir;
      return dir;
    } catch (e) {
      debugPrint('[VideoThumbnail] 캐시 폴더를 만들지 못했습니다: $e');
      return null;
    }
  }

  static Future<File?> _diskFileFor(String url) async {
    final dir = await _ensureDir();
    if (dir == null) return null;
    return File('${dir.path}/${_stableHash(url)}.jpg');
  }

  /// FNV-1a 32비트. Dart의 String.hashCode는 실행마다 달라질 수 있어
  /// 디스크 캐시 파일명으로 쓸 수 없다(앱을 다시 켜면 캐시를 못 찾는다).
  static String _stableHash(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    // 길이까지 섞어 충돌 가능성을 더 줄인다.
    return '${hash.toRadixString(16)}_${input.length}';
  }

  /// 테스트용 — 캐시를 비운다.
  @visibleForTesting
  static void resetForTest() {
    _memory.clear();
    _inFlight.clear();
    _waiting.clear();
    _running = 0;
    _diskDir = null;
    extractorOverride = null;
  }
}
