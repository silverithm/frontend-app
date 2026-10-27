// dart:io HttpClient 가짜 — 앱의 REST 호출을 네트워크 없이 JSON 픽스처로 응답한다.
// 실제 백엔드(https://silverithm.site)에는 절대 접속하지 않는다.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// (status, body) — body 는 JSON 직렬화 가능한 객체이거나 Uint8List(이미지).
class FakeReply {
  final int status;
  final Object? body;
  final String contentType;
  const FakeReply(this.status, this.body, {this.contentType = 'application/json; charset=utf-8'});
}

typedef Router = FakeReply? Function(String method, Uri uri, String body);

/// 로그: 라우터가 모르는 요청(→ 빈 {} 200)
final List<String> unmatchedRequests = [];
final List<String> allRequests = [];

// 1x1이 아닌 작은 단색 PNG (파스텔 회색-청록) — 이미지 URL 응답용
Uint8List solidPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAgUlEQVR4nNXOMREAIBDAsFL/YhDBgCxE/MA1CrL2uZRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMRJnMT5OzD1ABG4ArxDEOG8AAAAAElFTkSuQmCC');

class FakeHttpOverrides extends HttpOverrides {
  final Router router;
  FakeHttpOverrides(this.router);
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeClient(router);
}

class _FakeClient implements HttpClient {
  final Router router;
  _FakeClient(this.router);

  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  bool autoUncompress = true;
  @override
  String? userAgent;

  Future<HttpClientRequest> _open(String method, Uri url) async {
    return _FakeRequest(method, url, router);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => _open(method, url);
  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) =>
      _open(method, Uri(scheme: 'https', host: host, port: port, path: path));
  @override
  Future<HttpClientRequest> getUrl(Uri url) => _open('GET', url);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => _open('POST', url);
  @override
  Future<HttpClientRequest> putUrl(Uri url) => _open('PUT', url);
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => _open('DELETE', url);
  @override
  Future<HttpClientRequest> patchUrl(Uri url) => _open('PATCH', url);
  @override
  Future<HttpClientRequest> headUrl(Uri url) => _open('HEAD', url);
  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHeaders implements HttpHeaders {
  final Map<String, List<String>> _m = {};
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) =>
      (_m[name.toLowerCase()] ??= []).add(value.toString());
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      _m[name.toLowerCase()] = [value.toString()];
  @override
  String? value(String name) => _m[name.toLowerCase()]?.join(',');
  @override
  List<String>? operator [](String name) => _m[name.toLowerCase()];
  @override
  void forEach(void Function(String name, List<String> values) action) => _m.forEach(action);
  @override
  ContentType? contentType;
  @override
  int contentLength = -1;
  @override
  bool chunkedTransferEncoding = false;
  @override
  bool persistentConnection = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeRequest implements HttpClientRequest {
  final String method_;
  final Uri url;
  final Router router;
  final BytesBuilder _body = BytesBuilder();
  final _FakeHeaders _headers = _FakeHeaders();
  _FakeRequest(this.method_, this.url, this.router);

  @override
  String get method => method_;
  @override
  Uri get uri => url;
  @override
  HttpHeaders get headers => _headers;
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;
  @override
  int contentLength = -1;
  @override
  bool bufferOutput = true;
  @override
  Encoding encoding = utf8;

  @override
  void add(List<int> data) => _body.add(data);
  @override
  void write(Object? object) => _body.add(encoding.encode('$object'));
  @override
  void writeln([Object? object = '']) => _body.add(encoding.encode('$object\n'));
  @override
  void writeAll(Iterable objects, [String separator = '']) =>
      _body.add(encoding.encode(objects.join(separator)));
  @override
  void writeCharCode(int charCode) => _body.add(encoding.encode(String.fromCharCode(charCode)));
  @override
  Future addStream(Stream<List<int>> stream) async {
    await for (final c in stream) {
      _body.add(c);
    }
  }

  @override
  Future flush() async {}
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}
  @override
  HttpConnectionInfo? get connectionInfo => null;
  @override
  List<Cookie> get cookies => [];

  @override
  Future<HttpClientResponse> close() async {
    final bodyStr = utf8.decode(_body.toBytes(), allowMalformed: true);
    final key = '$method_ ${url.path}${url.hasQuery ? '?${url.query}' : ''}';
    allRequests.add(key);
    var reply = router(method_, url, bodyStr);
    if (reply == null) {
      unmatchedRequests.add(key);
      reply = const FakeReply(200, <String, dynamic>{});
    }
    return _FakeResponse(reply, url);
  }

  @override
  Future<HttpClientResponse> get done => close();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  final FakeReply reply;
  final Uri url;
  late final Uint8List _bytes;
  final _FakeHeaders _h = _FakeHeaders();
  _FakeResponse(this.reply, this.url) {
    final b = reply.body;
    _bytes = b is Uint8List ? b : Uint8List.fromList(utf8.encode(jsonEncode(b)));
    _h.set('content-type', reply.contentType);
  }

  @override
  int get statusCode => reply.status;
  @override
  String get reasonPhrase => reply.status == 200 ? 'OK' : 'ERR';
  @override
  int get contentLength => _bytes.length;
  @override
  HttpHeaders get headers => _h;
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => false;
  @override
  List<RedirectInfo> get redirects => [];
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  X509Certificate? get certificate => null;
  @override
  HttpConnectionInfo? get connectionInfo => null;
  @override
  List<Cookie> get cookies => [];

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.fromIterable([_bytes])
          .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
