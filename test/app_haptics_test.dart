import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/utils/app_haptics.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 햅틱은 뜻(selection·tap·impact·success·warning·error)으로만 부르고, 그 뜻이 플랫폼
/// 햅틱 하나로 정확히 이어지는지 — 그리고 '진동 반응'을 끄면 아무것도 울리지 않는지.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> platformCalls = <MethodCall>[];

  setUp(() {
    platformCalls.clear();
    AppHaptics.enabled.value = true;
    AppHaptics.debugPerformOverride = null;
    TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    AppHaptics.debugPerformOverride = null;
    AppHaptics.enabled.value = true;
  });

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  group('뜻 → 플랫폼 햅틱', () {
    final expected = <AppHapticKind, String>{
      AppHapticKind.selection: 'HapticFeedbackType.selectionClick',
      AppHapticKind.tap: 'HapticFeedbackType.lightImpact',
      AppHapticKind.impact: 'HapticFeedbackType.mediumImpact',
      AppHapticKind.success: 'HapticFeedbackType.successNotification',
      AppHapticKind.warning: 'HapticFeedbackType.warningNotification',
      AppHapticKind.error: 'HapticFeedbackType.errorNotification',
    };

    for (final entry in expected.entries) {
      test('${entry.key.name} → ${entry.value}', () async {
        AppHaptics.play(entry.key);
        await flush();
        expect(platformCalls, hasLength(1));
        expect(platformCalls.single.method, 'HapticFeedback.vibrate');
        expect(platformCalls.single.arguments, entry.value);
      });
    }

    test('이름으로 부르는 함수도 같은 뜻을 울린다', () async {
      final heard = <AppHapticKind>[];
      AppHaptics.debugPerformOverride = (kind) async => heard.add(kind);
      AppHaptics.selection();
      AppHaptics.tap();
      AppHaptics.impact();
      AppHaptics.success();
      AppHaptics.warning();
      AppHaptics.error();
      await flush();
      expect(heard, AppHapticKind.values);
    });
  });

  test('꺼 두면 아무것도 울리지 않는다', () async {
    AppHaptics.enabled.value = false;
    for (final kind in AppHapticKind.values) {
      AppHaptics.play(kind);
    }
    await flush();
    expect(platformCalls, isEmpty);
  });

  test('테스트용 가로채기가 있으면 플랫폼을 부르지 않는다', () async {
    final heard = <AppHapticKind>[];
    AppHaptics.debugPerformOverride = (kind) async => heard.add(kind);
    AppHaptics.warning();
    await flush();
    expect(heard, [AppHapticKind.warning]);
    expect(platformCalls, isEmpty);
  });

  test('햅틱이 실패해도 부른 쪽으로 오류가 새지 않는다', () async {
    AppHaptics.debugPerformOverride = (kind) async => throw PlatformException(code: 'x');
    expect(() => AppHaptics.error(), returnsNormally);
    await flush();
    AppHaptics.debugPerformOverride = (kind) => throw StateError('sync');
    expect(() => AppHaptics.tap(), returnsNormally);
    await flush();
  });

  group('설정 저장', () {
    test('저장된 값이 없으면 켠 채로 둔다', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      AppHaptics.enabled.value = false;
      await AppHaptics.load();
      expect(AppHaptics.enabled.value, isTrue);
    });

    test('꺼 둔 값을 읽어 온다', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppHaptics.prefsKey: false,
      });
      await AppHaptics.load();
      expect(AppHaptics.enabled.value, isFalse);
    });

    test('setEnabled는 바로 바꾸고 기기에 적어 둔다', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await AppHaptics.setEnabled(false);
      expect(AppHaptics.enabled.value, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppHaptics.prefsKey), isFalse);

      await AppHaptics.setEnabled(true);
      expect(prefs.getBool(AppHaptics.prefsKey), isTrue);
    });
  });
}
