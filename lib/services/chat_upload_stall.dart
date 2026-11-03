import 'dart:async';

import 'package:dio/dio.dart' as dio;

/// 채팅 사진·동영상 업로드의 시간 규칙.
///
/// 예전에는 dio `sendTimeout` 60초를 걸었는데, dio 5는 이 값을 **본문 전체를 다 보내는 시간**에
/// 건다(IOHttpClientAdapter가 `addStream` 전체에 `timeout`). 모바일 데이터로 30~50MB 동영상을
/// 올리면 60초 안에 못 끝나 앱이 스스로 연결을 끊었다 — 2026-10-28 한 기관에서 3시간 동안
/// 400·408만 58번 났다(nginx 기록). 그래서 전체 시간에는 제한을 두지 않고, **진행이 멈춘 시간**만 잰다.
class ChatUploadTiming {
  /// 조각을 하나도 더 못 보낸 채 이만큼 지나면 끊긴 것으로 본다.
  /// nginx가 본문 읽기를 60초 기다리므로(client_body_timeout 기본값) 그보다 조금 짧게 둔다.
  static const Duration stallTimeout = Duration(seconds: 45);

  /// 본문을 다 보낸 뒤 서버 답을 기다리는 시간 — 서버가 받은 파일을 저장소에 옮기는 동안이다.
  static const Duration receiveTimeout = Duration(seconds: 120);

  static const Duration connectTimeout = Duration(seconds: 30);
}

/// 채팅 업로드용 dio — `sendTimeout`을 두지 않는다(위 설명). 401/403은 예외가 아니라 응답으로 받아
/// 토큰을 갱신하고 한 번 더 올린다.
dio.Dio createChatUploadDio() {
  final client = dio.Dio();
  client.options.connectTimeout = ChatUploadTiming.connectTimeout;
  client.options.receiveTimeout = ChatUploadTiming.receiveTimeout;
  client.options.sendTimeout = null;
  client.options.validateStatus = (status) => status != null && status < 500;
  return client;
}

/// 업로드가 멈춘 것을 알려 주는 예외 — 화면에는 '전송 실패'로 남고 '다시 보내기'로 이어 올린다.
class ChatUploadStalledException implements Exception {
  final Duration after;
  const ChatUploadStalledException(this.after);

  @override
  String toString() => '업로드가 ${after.inSeconds}초 동안 진행되지 않아 멈췄습니다. 네트워크를 확인하고 다시 보내 주세요';
}

/// multipart 업로드 한 번. 진행이 [stallTimeout] 동안 없으면 요청을 거두고
/// [ChatUploadStalledException]을 던진다. 본문을 다 보낸 뒤부터는 dio의 receiveTimeout이 맡는다.
Future<dio.Response> postWithStallGuard(
  dio.Dio client,
  String url, {
  required dio.FormData data,
  Map<String, String>? headers,
  Duration stallTimeout = ChatUploadTiming.stallTimeout,
  void Function(int sent, int total)? onProgress,
}) async {
  final cancel = dio.CancelToken();
  Timer? timer;
  var stalled = false;
  var bodySent = false;

  void arm() {
    timer?.cancel();
    if (bodySent) return;
    timer = Timer(stallTimeout, () {
      stalled = true;
      cancel.cancel('upload stalled');
    });
  }

  arm();
  try {
    return await client.post(
      url,
      data: data,
      cancelToken: cancel,
      options: dio.Options(headers: headers),
      onSendProgress: (sent, total) {
        if (total > 0 && sent >= total) {
          bodySent = true;
          timer?.cancel();
        } else {
          arm();
        }
        onProgress?.call(sent, total);
      },
    );
  } on dio.DioException catch (e) {
    if (stalled && e.type == dio.DioExceptionType.cancel) {
      throw ChatUploadStalledException(stallTimeout);
    }
    rethrow;
  } finally {
    timer?.cancel();
  }
}
