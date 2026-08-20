import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// 통합테스트 스크린샷 수신 드라이버.
/// `flutter drive --driver=test_driver/integration_test.dart
///  --target=integration_test/screenshots_test.dart` 로 실행하면
/// 테스트가 찍은 화면이 screenshots/ 아래 PNG로 저장된다.
Future<void> main() => integrationDriver(
      onScreenshot: (String name, List<int> bytes,
          [Map<String, Object?>? args]) async {
        final dir = Directory('screenshots');
        await dir.create(recursive: true);
        await File('${dir.path}/$name.png').writeAsBytes(bytes);
        return true;
      },
    );
