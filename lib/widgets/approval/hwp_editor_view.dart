import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 셀프호스팅 rhwp-studio(HWP 웹 에디터)를 WebView로 임베드하고
/// postMessage 프로토콜(rhwp-request / rhwp-response)로 제어하는 컨트롤러.
///
/// 웹(frontend-admin)의 @rhwp/editor 래퍼와 동일한 프로토콜을 사용한다.
/// 대용량 바이트는 base64 청크로 나눠 JS 브릿지를 통과시킨다.
class HwpEditorController {
  HwpEditorController({String? studioUrl})
      : studioUrl = studioUrl ?? defaultStudioUrl {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF3F4F6))
      ..addJavaScriptChannel('RhwpBridge', onMessageReceived: (message) {
        _handleBridgeMessage(message.message);
      })
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _onPageFinished(),
        onWebResourceError: (error) {
          debugPrint('[HwpEditor] 리소스 로드 실패: ${error.description}');
        },
      ))
      ..loadRequest(Uri.parse(this.studioUrl));
  }

  /// frontend-admin(carev.kr)의 public/rhwp/ 에서 서빙되는 셀프호스팅 에디터
  static const String defaultStudioUrl = 'https://carev.kr/rhwp/index.html';

  final String studioUrl;
  late final WebViewController _webViewController;

  WebViewController get webViewController => _webViewController;

  final Map<int, Completer<dynamic>> _pending = {};
  final Map<int, StringBuffer> _binaryBuffers = {};
  int _requestSeq = 0;
  bool _shimInjected = false;
  bool _disposed = false;

  /// JS 브릿지 청크 크기 (base64 문자 기준). Android evaluateJavascript
  /// 문자열 크기 제한을 넉넉히 피하는 값이다.
  static const int _chunkSize = 256 * 1024;

  Future<void> _onPageFinished() async {
    if (_shimInjected || _disposed) return;
    _shimInjected = true;
    // 스튜디오는 응답을 event.source(보낸 창)로 보내므로, WebView 최상위 창에서
    // 자기 자신에게 postMessage하면 같은 창의 message 리스너로 응답이 돌아온다.
    await _webViewController.runJavaScript('''
(function () {
  if (window.__rhwpShim) return;
  window.__rhwpShim = true;
  var inBuf = '';
  window.__rhwpAppend = function (b64) { inBuf += b64; };
  window.__rhwpSend = function (id, method, paramsJson, useBuf, fileName) {
    var params = paramsJson ? JSON.parse(paramsJson) : {};
    if (useBuf) {
      var bin = atob(inBuf); inBuf = '';
      var bytes = new Uint8Array(bin.length);
      for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
      params.data = Array.from(bytes);
      if (fileName) params.fileName = fileName;
    }
    window.postMessage({ type: 'rhwp-request', id: id, method: method, params: params }, '*');
  };
  function toB64(bytes) {
    var CHUNK = 0x8000, s = '';
    for (var i = 0; i < bytes.length; i += CHUNK) {
      s += String.fromCharCode.apply(null, bytes.subarray(i, i + CHUNK));
    }
    return btoa(s);
  }
  window.addEventListener('message', function (e) {
    var d = e.data;
    if (!d || d.type !== 'rhwp-response' || d.id == null) return;
    var r = d.result;
    var isBinary = r instanceof Uint8Array || (Array.isArray(r) && r.length > 4096);
    if (isBinary && !d.error) {
      var bytes = r instanceof Uint8Array ? r : new Uint8Array(r);
      var b64 = toB64(bytes);
      var SEG = $_chunkSize;
      for (var i = 0; i < b64.length; i += SEG) {
        RhwpBridge.postMessage(JSON.stringify({ id: d.id, kind: 'chunk', data: b64.substring(i, i + SEG) }));
      }
      RhwpBridge.postMessage(JSON.stringify({ id: d.id, kind: 'binEnd' }));
    } else {
      RhwpBridge.postMessage(JSON.stringify({
        id: d.id,
        kind: 'result',
        result: r === undefined ? null : r,
        error: d.error || null,
      }));
    }
  });
})();
''');
  }

  void _handleBridgeMessage(String raw) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final id = msg['id'] as int?;
    if (id == null) return;

    switch (msg['kind']) {
      case 'chunk':
        (_binaryBuffers[id] ??= StringBuffer()).write(msg['data'] as String);
        break;
      case 'binEnd':
        final buf = _binaryBuffers.remove(id);
        _pending.remove(id)?.complete(base64Decode(buf?.toString() ?? ''));
        break;
      case 'result':
        _binaryBuffers.remove(id);
        final completer = _pending.remove(id);
        if (completer == null) return;
        final error = msg['error'];
        if (error != null) {
          completer.completeError(HwpEditorException(error.toString()));
        } else {
          completer.complete(msg['result']);
        }
        break;
    }
  }

  Future<dynamic> _request(
    String method, {
    Map<String, dynamic>? params,
    Uint8List? data,
    String? fileName,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_disposed) throw HwpEditorException('에디터가 이미 종료되었습니다.');
    final id = ++_requestSeq;
    final completer = Completer<dynamic>();
    _pending[id] = completer;

    if (data != null) {
      final b64 = base64Encode(data);
      for (var i = 0; i < b64.length; i += _chunkSize) {
        final end = (i + _chunkSize < b64.length) ? i + _chunkSize : b64.length;
        await _webViewController
            .runJavaScript('__rhwpAppend("${b64.substring(i, end)}")');
      }
    }

    final paramsJson = params == null ? 'null' : jsonEncode(jsonEncode(params));
    final fileNameJs = fileName == null ? 'null' : jsonEncode(fileName);
    await _webViewController.runJavaScript(
      '__rhwpSend($id, ${jsonEncode(method)}, '
      '${params == null ? 'null' : paramsJson}, '
      '${data != null}, $fileNameJs)',
    );

    return completer.future.timeout(timeout, onTimeout: () {
      _pending.remove(id);
      _binaryBuffers.remove(id);
      throw HwpEditorTimeoutException(method);
    });
  }

  /// WASM 초기화 완료까지 대기한다 (@rhwp/editor의 _waitReady와 동일: 0.5초 × 30회).
  Future<void> waitReady() async {
    for (var i = 0; i < 30; i++) {
      try {
        final result =
            await _request('ready', timeout: const Duration(seconds: 2));
        if (result == true) return;
      } catch (_) {
        // 아직 준비 안 됨 — 재시도
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    throw HwpEditorException('에디터 초기화에 실패했습니다. 네트워크 상태를 확인해주세요.');
  }

  /// HWP/HWPX 파일을 에디터에 로드한다.
  ///
  /// 에디터가 "자동 보정" 확인 대화상자를 띄우면 사용자가 선택할 때까지 응답이
  /// 지연되어 타임아웃이 날 수 있다. 문서는 이미 전달된 상태이므로 웹 구현과
  /// 동일하게 타임아웃은 성공으로 간주한다.
  Future<void> loadFile(Uint8List bytes, String fileName) async {
    try {
      await _request(
        'loadFile',
        data: bytes,
        fileName: fileName,
        timeout: const Duration(seconds: 30),
      );
    } on HwpEditorTimeoutException {
      debugPrint('[HwpEditor] loadFile 타임아웃 — 확인 대화상자 대기로 간주하고 계속');
    }
  }

  Future<int> pageCount() async =>
      (await _request('pageCount') as num).toInt();

  /// 현재 문서를 HWP 바이너리로 내보낸다.
  Future<Uint8List> exportHwp() => _exportBinary('exportHwp');

  /// 현재 문서를 HWPX(ZIP+XML) 바이너리로 내보낸다.
  Future<Uint8List> exportHwpx() => _exportBinary('exportHwpx');

  Future<Uint8List> _exportBinary(String method) async {
    final result =
        await _request(method, timeout: const Duration(seconds: 30));
    if (result is Uint8List) return result;
    if (result is List) return Uint8List.fromList(result.cast<int>());
    throw HwpEditorException('문서 내보내기 결과가 올바르지 않습니다.');
  }

  void dispose() {
    _disposed = true;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(HwpEditorException('에디터가 종료되었습니다.'));
      }
    }
    _pending.clear();
    _binaryBuffers.clear();
  }
}

class HwpEditorException implements Exception {
  HwpEditorException(this.message);
  final String message;

  @override
  String toString() => message;
}

class HwpEditorTimeoutException extends HwpEditorException {
  HwpEditorTimeoutException(String method) : super('요청 시간 초과: $method');
}

/// HWP 에디터 WebView 위젯. 컨트롤러의 생명주기는 호출자가 관리한다.
class HwpEditorView extends StatelessWidget {
  const HwpEditorView({super.key, required this.controller});

  final HwpEditorController controller;

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: controller.webViewController);
  }
}
