import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/utils/video_thumbnail_cache.dart';

/// 동영상 첫 프레임 캐시 단위 테스트.
///
/// 실제 디코딩(플랫폼 채널) 대신 extractorOverride를 끼워 넣어,
/// "몇 번 뽑는지 / 언제 안 뽑는지 / 동시에 몇 개나 도는지"를 확인한다.
/// 디스크 캐시는 테스트 환경에 path_provider가 없어 자동으로 건너뛴다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final frame = Uint8List.fromList([1, 2, 3]);

  setUp(VideoThumbnailCache.resetForTest);
  tearDown(VideoThumbnailCache.resetForTest);

  test('한 번 뽑은 썸네일은 다시 뽑지 않는다', () async {
    var calls = 0;
    VideoThumbnailCache.extractorOverride = (url, timeMs) async {
      calls++;
      return frame;
    };

    final first = await VideoThumbnailCache.load('https://x/a.mp4');
    final second = await VideoThumbnailCache.load('https://x/a.mp4');

    expect(first, frame);
    expect(second, frame);
    expect(calls, 1, reason: '두 번째는 메모리 캐시에서 나와야 한다');
    expect(VideoThumbnailCache.peek('https://x/a.mp4'), frame);
  });

  test('같은 URL을 동시에 요청하면 한 번만 뽑는다', () async {
    var calls = 0;
    final gate = Completer<void>();
    VideoThumbnailCache.extractorOverride = (url, timeMs) async {
      calls++;
      await gate.future;
      return frame;
    };

    final a = VideoThumbnailCache.load('https://x/b.mp4');
    final b = VideoThumbnailCache.load('https://x/b.mp4');
    gate.complete();

    expect(await a, frame);
    expect(await b, frame);
    expect(calls, 1, reason: '진행 중인 작업에 합류해야 한다');
  });

  test('못 뽑은 영상은 실패로 기억하고 다시 시도하지 않는다', () async {
    var calls = 0;
    VideoThumbnailCache.extractorOverride = (url, timeMs) async {
      calls++;
      return null;
    };

    expect(await VideoThumbnailCache.load('https://x/c.mp4'), isNull);
    // 500ms 실패 → 0ms 재시도까지 두 번이 정상
    expect(calls, 2);

    expect(await VideoThumbnailCache.load('https://x/c.mp4'), isNull);
    expect(calls, 2, reason: '스크롤할 때마다 다시 시도하면 안 된다');
    expect(VideoThumbnailCache.isKnownFailure('https://x/c.mp4'), isTrue);
  });

  test('첫 프레임이 안 나오면 맨 앞(0ms)으로 다시 시도한다', () async {
    final tried = <int>[];
    VideoThumbnailCache.extractorOverride = (url, timeMs) async {
      tried.add(timeMs);
      return timeMs == 0 ? frame : null;
    };

    expect(await VideoThumbnailCache.load('https://x/d.mp4'), frame);
    expect(tried, [500, 0], reason: '페이드인 영상을 피해 500ms를 먼저 노린다');
  });

  test('동시에 도는 디코딩 수가 상한을 넘지 않는다', () async {
    var peak = 0;
    final gate = Completer<void>();
    VideoThumbnailCache.extractorOverride = (url, timeMs) async {
      peak = peak > VideoThumbnailCache.runningCount
          ? peak
          : VideoThumbnailCache.runningCount;
      await gate.future;
      return frame;
    };

    final futures = [
      for (var i = 0; i < 8; i++) VideoThumbnailCache.load('https://x/e$i.mp4'),
    ];
    // 앞선 것들이 자리를 잡을 틈을 준다.
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    await Future.wait(futures);

    expect(peak, lessThanOrEqualTo(2), reason: '목록을 훑을 때 한꺼번에 디코딩하면 안 된다');
    expect(futures.length, 8);
  });

  test('아직 안 뽑은 URL은 실패가 아니다', () {
    expect(VideoThumbnailCache.peek('https://x/f.mp4'), isNull);
    expect(VideoThumbnailCache.isKnownFailure('https://x/f.mp4'), isFalse);
    expect(VideoThumbnailCache.isCached('https://x/f.mp4'), isFalse);
  });
}
