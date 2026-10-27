// 가짜 서버 픽스처. 응답 형태는 lib/services/api_service.dart·providers 의 파싱 코드를 읽고 맞췄다.
// 시설: 햇살주간보호센터 / 관리자 김관리 / 직원 김민지 … (웹 목업 mocks.py 와 같은 가상 시설)
// 날짜는 DateTime.now() 기준으로 이동한다(앱에 시계 주입이 없다).
import 'dart:convert';
import 'dart:io';

import 'fake_http.dart';
import 'fixtures_data.dart';

enum Role { emp, adm }

typedef Handler = Object? Function(Uri uri, Map<String, dynamic> body, String method);

class FixtureRouter {
  static final List<(String, RegExp, Handler)> _routes = [];
  static Role role = Role.adm;

  static void on(String method, String pattern, Handler h) =>
      _routes.add((method, RegExp('^$pattern\$'), h));

  static void install(Role r) {
    role = r;
    _routes.clear();
    registerAll();
    HttpOverrides.global = FakeHttpOverrides(_route);
  }

  static FakeReply? _route(String method, Uri uri, String bodyStr) {
    // 이미지 등 외부 리소스는 단색 PNG
    if (uri.host != 'silverithm.site') {
      return FakeReply(200, solidPng, contentType: 'image/png');
    }
    var path = uri.path;
    if (path.startsWith('/api')) path = path.substring(4);
    final lower = path.toLowerCase();
    if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return FakeReply(200, solidPng, contentType: 'image/png');
    }
    Map<String, dynamic> body = {};
    if (bodyStr.isNotEmpty) {
      try {
        final d = jsonDecode(bodyStr);
        if (d is Map<String, dynamic>) body = d;
      } catch (_) {}
    }
    for (final (m, re, h) in _routes) {
      if (m != method && m != '*') continue;
      if (re.hasMatch(path)) {
        final r = h(uri, body, method);
        if (r == null) return null;
        return FakeReply(200, r);
      }
    }
    return null;
  }
}
