import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 햅틱의 뜻. 세기는 뜻이 정한다 — 부르는 쪽은 "얼마나 세게"가 아니라 "무슨 일인지"만 고른다.
/// 기준표: frontend-admin/.unlazy/modern-1112/PLAN.md "햅틱 (AppHaptics)".
enum AppHapticKind {
  /// 하단 탭·칩·토글·체크·날짜 고르기·탭 전환 — 가장 약함.
  selection,

  /// 주요 버튼, 줄 눌러 들어가기 — 약함.
  tap,

  /// 길게 누르기 메뉴, 당겨서 새로고침이 걸림, FAB — 중간.
  impact,

  /// 결재 승인·서명, 휴무 신청, 글·메시지 전송, 저장.
  success,

  /// 삭제·반려 확인 창이 뜰 때.
  warning,

  /// 실패 알림.
  error,
}

/// 햅틱을 실제로 울리는 함수. 테스트에서 [AppHaptics.debugPerformOverride]로 갈아 끼운다.
typedef AppHapticPerformer = Future<void> Function(AppHapticKind kind);

/// 앱의 모든 햅틱은 여기서만 부른다 — 화면에서 `HapticFeedback`을 직접 부르지 않는다.
///
/// - 설정 › 알림 설정의 '진동 반응' 스위치로 끈다(SharedPreferences, 기본 켬).
/// - 스크롤·타이핑에는 넣지 않는다(과하면 싸구려처럼 느껴진다).
/// - 기기 자체에서 '터치 진동'·'시스템 햅틱'을 꺼 두었으면 OS가 알아서 울리지 않는다.
abstract final class AppHaptics {
  /// SharedPreferences 키.
  static const String prefsKey = 'app_haptics_enabled';

  /// 지금 켜져 있는지. 설정 화면이 이 값을 듣는다.
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  /// 테스트용 — 넣으면 플랫폼 대신 이 함수가 불린다. 끝나면 null로 되돌린다.
  @visibleForTesting
  static AppHapticPerformer? debugPerformOverride;

  /// 앱 시작 때 한 번 저장된 설정을 읽는다. 못 읽으면 켠 채로 둔다.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool(prefsKey) ?? true;
    } catch (e) {
      debugPrint('[AppHaptics] 설정 읽기 실패(켠 채로 둔다): $e');
    }
  }

  /// '진동 반응' 스위치. 화면은 바로 바뀌고 저장은 뒤따른다.
  static Future<void> setEnabled(bool value) async {
    enabled.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsKey, value);
    } catch (e) {
      debugPrint('[AppHaptics] 설정 저장 실패: $e');
    }
  }

  static void selection() => play(AppHapticKind.selection);
  static void tap() => play(AppHapticKind.tap);
  static void impact() => play(AppHapticKind.impact);
  static void success() => play(AppHapticKind.success);
  static void warning() => play(AppHapticKind.warning);
  static void error() => play(AppHapticKind.error);

  /// 뜻으로 울린다. 꺼져 있으면 아무것도 하지 않는다.
  /// 기다리지 않는다 — 햅틱이 늦거나 실패해도 화면 동작이 막히면 안 된다.
  static void play(AppHapticKind kind) {
    if (!enabled.value) return;
    final AppHapticPerformer perform = debugPerformOverride ?? _performOnPlatform;
    Future<void> run() async {
      try {
        await perform(kind);
      } catch (e) {
        // 테스트 환경·플러그인 없는 플랫폼에서는 채널이 없을 수 있다 — 조용히 넘긴다.
        debugPrint('[AppHaptics] $kind 실패: $e');
      }
    }

    unawaited(run());
  }

  /// 뜻 → 플랫폼 햅틱.
  ///
  /// Flutter 3.41.9 SDK(services/haptic_feedback.dart)에 알림형 햅틱
  /// successNotification·warningNotification·errorNotification이 있다.
  /// iOS는 UINotificationFeedbackGenerator(success/warning/error)로 바로 이어진다.
  /// Android 엔진(PlatformPlugin.vibrateHapticFeedback)은 이 셋을 API 30(Android 11)
  /// 이상에서만 CONFIRM·KEYBOARD_TAP·REJECT로 울리고, 그 아래에서는 아무것도 하지 않는다.
  static Future<void> _performOnPlatform(AppHapticKind kind) {
    switch (kind) {
      case AppHapticKind.selection:
        return HapticFeedback.selectionClick();
      case AppHapticKind.tap:
        return HapticFeedback.lightImpact();
      case AppHapticKind.impact:
        return HapticFeedback.mediumImpact();
      case AppHapticKind.success:
        return HapticFeedback.successNotification();
      case AppHapticKind.warning:
        return HapticFeedback.warningNotification();
      case AppHapticKind.error:
        return HapticFeedback.errorNotification();
    }
  }
}
