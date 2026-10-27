// 디자인 감사용 스크린샷 하니스.
// 실행: OUT=<출력폴더> flutter test test/design_audit/   (또는 --dart-define=OUT=<폴더>)
// 실제 위젯·실제 프로바이더·실제 ApiService 를 그대로 돌리고, dart:io HttpClient 만
// 가짜로 바꿔 JSON 픽스처로 응답한다. lib/ 는 수정하지 않는다.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' show debugDisableShadows;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/services/analytics_service.dart';
import 'package:frontend_app/services/fcm_service.dart';
import 'package:frontend_app/services/storage_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import 'audit_app.dart';
import 'fake_http.dart';
import 'fixtures.dart';
import 'fixtures_data.dart';

const _outDefine = String.fromEnvironment('OUT');
String get outDir {
  final d = _outDefine.isNotEmpty ? _outDefine : (Platform.environment['OUT'] ?? '');
  return d.isNotEmpty ? d : '${Directory.current.path}/build/design_audit_out';
}

class _FakePathProvider extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  final String dir = Directory.systemTemp.createTempSync('design_audit_').path;
  @override
  Future<String?> getTemporaryPath() async => dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  Future<String?> getApplicationSupportPath() async => dir;
  @override
  Future<String?> getApplicationCachePath() async => dir;
  @override
  Future<String?> getExternalStoragePath() async => dir;
}

final List<String> renderedOk = [];
final Map<String, String> renderFailed = {};
final List<String> captureLog = [];
String currentShot = '';

/// 폰트 로드 — Pretendard + Material 아이콘
Future<void> loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      final bytes = await File(p).readAsBytes();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Pretendard', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'])
      'assets/fonts/Pretendard-$w.otf'
  ]);
  final flutterBin = Platform.environment['FLUTTER_ROOT'] ?? _flutterRoot();
  final icons = '$flutterBin/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  if (File(icons).existsSync()) await load('MaterialIcons', [icons]);
}

String _flutterRoot() {
  final r = Process.runSync('flutter', ['--version', '--machine']);
  final m = RegExp(r'"flutterRoot":\s*"([^"]+)"').firstMatch('${r.stdout}');
  return m?.group(1) ?? '';
}

/// 모든 플랫폼 채널을 조용한 기본값으로 막는다.
void mockChannels() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const nullChannels = [
    'plugins.it_nomads.com/flutter_secure_storage',
    'dexterous.com/flutter/local_notifications',
    'plugins.flutter.io/firebase_messaging',
    'plugins.flutter.io/firebase_analytics',
    'plugins.flutter.io/url_launcher',
    'dev.fluttercommunity.plus/connectivity',
    'dev.fluttercommunity.plus/connectivity_status',
    'dev.fluttercommunity.plus/share',
    'plugins.flutter.io/image_picker',
    'flutter_image_compress',
    'gal',
    'in_app_review',
    'open_filex',
    'video_thumbnail',
    'plugins.flutter.io/file_selector',
    'plugins.flutter.io/webview_flutter',
  ];
  for (final c in nullChannels) {
    messenger.setMockMethodCallHandler(MethodChannel(c), (call) async {
      if (call.method == 'check') return ['wifi'];
      if (call.method == 'getToken') return 'fake-fcm-token';
      return null;
    });
  }
  const analytics =
      'dev.flutter.pigeon.firebase_analytics_platform_interface.FirebaseAnalyticsHostApi';
  for (final m in [
    'getAppInstanceId', 'getSessionId', 'initiateOnDeviceConversionMeasurement', 'logEvent',
    'logTransaction', 'resetAnalyticsData', 'setAnalyticsCollectionEnabled', 'setConsent',
    'setDefaultEventParameters', 'setSessionTimeoutDuration', 'setUserId', 'setUserProperty',
  ]) {
    messenger.setMockMessageHandler('$analytics.$m', (ByteData? message) async {
      return const StandardMessageCodec().encodeMessage(<Object?>[null]);
    });
  }
  // sqflite(이미지 캐시 DB) — 빈 DB 로 응답
  messenger.setMockMethodCallHandler(const MethodChannel('com.tekartik.sqflite'), (call) async {
    switch (call.method) {
      case 'getDatabasesPath':
        return Directory.systemTemp.path;
      case 'openDatabase':
        return 1;
      case 'query':
        return <String, Object?>{'columns': <String>[], 'rows': <Object?>[]};
      case 'insert':
      case 'update':
      case 'delete':
        return 1;
      default:
        return null;
    }
  });
  PathProviderPlatform.instance = _FakePathProvider();
  PackageInfo.setMockInitialValues(
    appName: '케어브이',
    packageName: 'kr.carev.app',
    version: '1.19.0',
    buildNumber: '61',
    buildSignature: '',
  );
}

/// 앱 부팅 전 1회 설정
Future<void> setUpAudit() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  WidgetsApp.debugAllowBannerOverride = false;
  // flutter_test 기본값(true)은 그림자를 검은 선으로 그린다 — 실제 그림자로 렌더
  debugDisableShadows = false;
  await loadFonts();
  mockChannels();
  sqflite.databaseFactory = sqflite.databaseFactorySqflitePlugin;
  setupFirebaseCoreMocks();
  await Firebase.initializeApp();
  AnalyticsService().initialize();
  SharedPreferences.setMockInitialValues({});
  await StorageService().init();
  Directory(outDir).createSync(recursive: true);
}

/// 한 역할로 로그인된 상태의 앱을 띄우고 화면별 캡처를 도와준다.
class AuditApp {
  final WidgetTester tester;
  final Role role;
  final GlobalKey boundaryKey = GlobalKey();
  AuditApp(this.tester, this.role);

  NavigatorState get nav => FCMService.navigatorKey.currentState!;

  /// 폰 크기 390x844 @2x, 상단 상태바·하단 홈바 안전영역 포함
  void setPhone() {
    final v = tester.view;
    v.devicePixelRatio = 2;
    v.physicalSize = const Size(780, 1688);
    v.padding = const FakeViewPadding(top: 94, bottom: 68);
    v.viewPadding = const FakeViewPadding(top: 94, bottom: 68);
  }

  Future<void> boot({bool loggedIn = true}) async {
    FixtureRouter.install(role);
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    final originalOnError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = originalOnError);
    // 프레임워크 에러(오버플로·빌드 중 setState 등)는 테스트를 실패시키지 않고 기록만 한다
    FlutterError.onError = (d) {
      captureLog.add('$currentShot: ${d.exceptionAsString().split('\n').first}');
      // ignore: avoid_print
      print('AUDITERR $currentShot: ${d.exceptionAsString().split('\n').first}');
    };
    // StorageService 는 싱글톤 — 이전 역할 값 제거
    await StorageService().removeAll();
    if (loggedIn) {
      await StorageService().saveToken('fake-access-token');
      await StorageService().saveRefreshToken('fake-refresh-token');
      await StorageService().saveUserData(Fixtures.signinResponse(role));
    }
    setPhone();
    await tester.pumpWidget(RepaintBoundary(key: boundaryKey, child: const AuditMyApp()));
    await settle(seconds: 3);
  }

  /// 비동기 응답(가짜 HTTP)과 애니메이션이 끝나도록 실제 시간을 조금 흘린다.
  Future<void> settle({double seconds = 1.5}) async {
    final n = (seconds * 1000 / 100).round();
    for (var i = 0; i < n; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> push(Widget screen) async {
    nav.push(MaterialPageRoute<void>(builder: (_) => screen));
    await settle(seconds: 2.5);
  }

  /// 푸시된 화면·다이얼로그를 모두 닫고 첫 화면으로
  Future<void> popToRoot() async {
    for (var i = 0; i < 8 && nav.canPop(); i++) {
      nav.pop();
      await settle(seconds: 0.5);
    }
  }

  Future<void> shot(String name) async {
    // 이미지 캐시(실제 파일 IO)가 끝날 시간을 준다
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final file = '$outDir/$name.png';
    try {
      final ro = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final img = await ro.toImage(pixelRatio: 2);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      });
      File(file).writeAsBytesSync(bytes!);
      renderedOk.add(name);
    } catch (e) {
      renderFailed[name] = '$e';
    }
  }

  /// push → 캡처 → 닫기. 예외가 나도 다음 화면으로 넘어간다.
  Future<void> capture(String name, Widget Function() build,
      {double wait = 2.5, Future<void> Function()? after}) async {
    currentShot = name;
    try {
      nav.push(MaterialPageRoute<void>(builder: (_) => build()));
      await settle(seconds: wait);
      if (after != null) await after();
      await shot(name);
    } catch (e, st) {
      renderFailed[name] = '$e\n$st';
    }
    await popToRoot();
  }

  /// 렌더 중 난 프레임워크 에러(오버플로 등)를 기록용으로 가져온다.
  void flushFlutterErrors(String name) {
    dynamic ex;
    while ((ex = tester.takeException()) != null) {
      captureLog.add('$name: ${'$ex'.split('\n').first}');
    }
  }
}

void writeReport(String suite) {
  // 테스트 본문이 끝나기 전에 flutter_test 의 기본값으로 되돌려 둔다(불변식 검사가 본문 직후 실행된다)
  debugDisableShadows = true;
  final f = File('$outDir/_report_$suite.txt');
  final b = StringBuffer()
    ..writeln('OK ${renderedOk.length}: ${renderedOk.join(', ')}')
    ..writeln('FAILED ${renderFailed.length}');
  renderFailed.forEach((k, v) => b.writeln('  $k: ${v.split('\n').first}'));
  b.writeln('FLUTTER ERRORS (first line)');
  for (final l in captureLog) {
    b.writeln('  $l');
  }
  b.writeln('ALL REQUESTS');
  for (final u in allRequests.map((e) => e.split('?').first).toSet()) {
    b.writeln('  $u');
  }
  b.writeln('UNMATCHED REQUESTS');
  for (final u in unmatchedRequests.toSet()) {
    b.writeln('  $u');
  }
  f.writeAsStringSync(b.toString());
}
