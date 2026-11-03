// 채팅 업로드 시간 규칙 — 전체 시간이 아니라 '진행이 멈춘 시간'으로 끊는다.
// 로컬 서버를 띄워 실제 dio 업로드로 확인한다(외부 네트워크 없음).
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/services/chat_upload_stall.dart';

/// 크기가 [bytes]인 임시 파일
Future<File> _tempFile(int bytes) async {
  final dir = await Directory.systemTemp.createTemp('chat_upload_test');
  final f = File('${dir.path}/clip.mp4');
  await f.writeAsBytes(List<int>.filled(bytes, 7));
  return f;
}

Future<dio.FormData> _form(File f) async => dio.FormData.fromMap({
      'file': await dio.MultipartFile.fromFile(f.path, filename: 'clip.mp4'),
      'senderId': '1',
    });

void main() {
  test('업로드용 dio에는 전체 보내기 제한(sendTimeout)이 없다', () {
    final client = createChatUploadDio();
    expect(client.options.sendTimeout, isNull);
    expect(client.options.receiveTimeout, ChatUploadTiming.receiveTimeout);
  });

  test('천천히 받는 서버 — 전체가 끊김 감시 시간의 몇 배가 걸려도 끝까지 올라간다', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      // 조각마다 쉬어 가며 읽는다 — 받는 쪽이 느리면 보내는 쪽도 그만큼 기다린다
      await for (final _ in req) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write('{"ok":true}');
      await req.response.close();
    });
    final file = await _tempFile(16 * 1024 * 1024);
    final sw = Stopwatch()..start();
    var progressCalls = 0;
    final res = await postWithStallGuard(
      createChatUploadDio(),
      'http://127.0.0.1:${server.port}/files',
      data: await _form(file),
      stallTimeout: const Duration(seconds: 1),
      onProgress: (_, __) => progressCalls++,
    );
    sw.stop();
    await server.close(force: true);

    expect(res.statusCode, 200);
    expect(progressCalls, greaterThan(1));
    // 감시 시간(1초)을 넘겨 걸렸어야 '전체 시간 제한이 없다'는 걸 보여 준다
    expect(sw.elapsed, greaterThan(const Duration(seconds: 2)),
        reason: '서버가 충분히 느리지 않았다 — 걸린 시간 ${sw.elapsed}');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('받기를 멈춘 서버 — 감시 시간이 지나면 멈춤으로 실패한다', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final hold = Completer<void>();
    server.listen((req) async {
      // 첫 조각만 읽고 더는 읽지 않는다(모바일 전파가 끊긴 것과 같다)
      final sub = req.listen((_) {});
      sub.pause();
      await hold.future;
      await sub.cancel();
    });
    final file = await _tempFile(64 * 1024 * 1024);
    final sw = Stopwatch()..start();
    Object? error;
    try {
      await postWithStallGuard(
        createChatUploadDio(),
        'http://127.0.0.1:${server.port}/files',
        data: await _form(file),
        stallTimeout: const Duration(seconds: 1),
      );
    } catch (e) {
      error = e;
    }
    sw.stop();
    hold.complete();
    await server.close(force: true);

    expect(error, isA<ChatUploadStalledException>());
    expect(sw.elapsed, lessThan(const Duration(seconds: 15)));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
