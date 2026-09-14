import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:frontend_app/main.dart' as app;
import 'package:frontend_app/screens/menu_screen.dart';

/// 글자 크기 검증 캡처 — 기기 글꼴 배율을 호스트(adb/simctl)가 바꿔 둔 상태에서
/// 앱의 네 가지 크기를 차례로 골라 설정 화면과 채팅방을 찍는다.
///
/// 실행: flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/font_scale_capture_test.dart \
///   --dart-define=SHOT_EMAIL=... --dart-define=SHOT_PASSWORD=... -d <device>
/// 호스트는 로그의 `[SHOT] 이름`을 보고 화면을 캡처한다.
/// 체험 기관에 기본으로 만들어지는 채팅방
final _roomTile = find.text('전체 공지방');

/// 결재 관리 목록의 카드 (카드마다 '요청자:' 줄이 있다)
final _approvalCard = find.textContaining('요청자:');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const email = String.fromEnvironment('SHOT_EMAIL');
  const password = String.fromEnvironment('SHOT_PASSWORD');

  Future<void> settle(WidgetTester tester, {double seconds = 3}) async {
    final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<bool> waitFor(WidgetTester tester, Finder finder, {int maxSeconds = 30}) async {
    final end = DateTime.now().add(Duration(seconds: maxSeconds));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (finder.evaluate().isNotEmpty) return true;
    }
    return false;
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester, seconds: 1.5);
    // 넘침 오류 로그에 화면 이름을 붙이기 위해 기록
    debugPrint('[SCREEN] $name');
    debugPrint('[SHOT] $name');
    await settle(tester, seconds: 4);
  }

  /// 하단 '전체' 탭 → 메뉴에서 '글자 크기'를 연다.
  /// 탭 화면들이 겹쳐 살아 있어(IndexedStack) 첫 Scrollable이 메뉴가 아닐 수 있다 — 메뉴 안에서 찾는다.
  Future<void> openTextSize(WidgetTester tester) async {
    await tester.tap(find.text('전체').last, warnIfMissed: false);
    await settle(tester, seconds: 2);
    final menuList = find.descendant(
      of: find.byType(MenuScreen),
      matching: find.byType(Scrollable),
    );
    for (var i = 0; i < 15 && find.text('글자 크기').hitTestable().evaluate().isEmpty; i++) {
      await tester.drag(menuList.first, const Offset(0, -250), warnIfMissed: false);
      await settle(tester, seconds: 0.6);
    }
    await tester.tap(find.text('글자 크기').hitTestable().first, warnIfMissed: false);
    await settle(tester, seconds: 2);
  }

  testWidgets('글자 크기 캡처', (tester) async {
    app.main();
    // 캡처 조건 확인용 — 호스트가 기기 배율을 제대로 걸었는지 로그로 남긴다
    debugPrint('[SCALE] system=${WidgetsBinding.instance.platformDispatcher.textScaleFactor}');
    // 글자가 넘치면 Flutter가 오류를 낸다. 테스트를 멈추지 말고 어느 화면에서 났는지 모은다.
    var currentScreen = 'start';
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString().split('\n').first;
      debugPrint('[OVERFLOW] $currentScreen :: $text');
      if (!text.contains('overflowed')) original?.call(details);
    };
    // 새로 깔았으면 로그인 화면, 덮어 깔았으면(체험 계정으로 이미 로그인) 홈이 뜬다
    final either = find.byWidgetPredicate((w) =>
        w is Text && (w.data == '로그인' || w.data == '전자결재'));
    expect(await waitFor(tester, either, maxSeconds: 180), isTrue,
        reason: '로그인 화면도 홈도 뜨지 않았다');
    await settle(tester, seconds: 1);
    final needsLogin = find.text('전자결재').evaluate().isEmpty;
    await shot(tester, needsLogin ? '00_login' : '00_home');
    if (needsLogin) {

    final adminToggle = find.text('관리자');
    if (adminToggle.evaluate().isNotEmpty) {
      await tester.tap(adminToggle.first);
      await settle(tester, seconds: 1);
    }
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), email);
    await tester.enterText(fields.at(1), password);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('로그인').last);
    await waitFor(tester, find.text('전자결재'), maxSeconds: 25);
    }
    await settle(tester, seconds: 4);
    // 안전장치: 체험 기관이 아니면 멈춘다. 덮어 설치한 기기에 실제 기관 계정이 로그인돼 있던 적이 있다 —
    // 그 상태로 화면을 누르고 다니면 실제 결재·채팅에 손이 갈 수 있다.
    final isDemo = find.textContaining('체험 관리자').evaluate().isNotEmpty;
    if (!isDemo) {
      debugPrint('[ABORT] 체험 계정이 아니다 — 캡처를 중단한다');
    }
    expect(isDemo, isTrue, reason: '체험 계정(체험 관리자)으로만 캡처한다');
    final close = find.text('닫기');
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close.first, warnIfMissed: false);
      await settle(tester, seconds: 2);
    }

    const sizes = ['작게', '보통', '크게', '아주 크게'];
    for (var i = 0; i < sizes.length; i++) {
      final label = sizes[i];
      // 설정 화면에서 크기를 고른다
      await openTextSize(tester);
      await tester.tap(find.text(label).last, warnIfMissed: false);
      await settle(tester, seconds: 1);
      final preview = find.text('미리보기');
      if (preview.evaluate().isNotEmpty) {
        final applied = MediaQuery.textScalerOf(tester.element(preview.first)).scale(1.0);
        debugPrint('[EFFECTIVE] $label = ${applied.toStringAsFixed(3)}');
      }
      await shot(tester, '1${i}_settings_$label');
      await tester.binding.handlePopRoute();
      await settle(tester, seconds: 2);

      // 채팅방 입력창과 말풍선
      await tester.tap(find.text('채팅').last, warnIfMissed: false);
      await settle(tester, seconds: 3);
      if (await waitFor(tester, _roomTile, maxSeconds: 15)) {
        await tester.tap(_roomTile.first, warnIfMissed: false);
        await settle(tester, seconds: 5);
        await shot(tester, '2${i}_chat_$label');
        await tester.binding.handlePopRoute();
        await settle(tester, seconds: 2);
      }
    }

    // 가장 큰 크기로 주요 화면을 모두 돈다 — 채팅만 보고 다 됐다고 하지 않는다
    currentScreen = 'max';
    await openTextSize(tester);
    await tester.tap(find.text('아주 크게').last, warnIfMissed: false);
    await settle(tester, seconds: 1);
    await tester.binding.handlePopRoute();
    await settle(tester, seconds: 2);
    for (final tab in ['홈', '채팅', '일정', '전자결재', '전체']) {
      final f = find.text(tab);
      if (f.evaluate().isEmpty) continue;
      currentScreen = 'max_$tab';
      await tester.tap(f.last, warnIfMissed: false);
      await settle(tester, seconds: 4);
      await shot(tester, '3_max_$tab');
      // 긴 화면은 한 번 내려서 아래쪽도 찍는다
      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        await tester.drag(scrollables.first, const Offset(0, -500), warnIfMissed: false);
        await settle(tester, seconds: 2);
        await shot(tester, '3_max_${tab}_아래');
      }
    }
    for (final sub in ['결재 관리', '월간일정']) {
      final tabName = sub == '결재 관리' ? '전자결재' : '일정';
      await tester.tap(find.text(tabName).last, warnIfMissed: false);
      await settle(tester, seconds: 3);
      final f = find.text(sub);
      if (f.evaluate().isEmpty) continue;
      currentScreen = 'max_$sub';
      await tester.tap(f.first, warnIfMissed: false);
      await settle(tester, seconds: 4);
      await shot(tester, '3_max_$sub');
      // 결재 문서 하나를 열어 공문 모양이 서체 교체로 어긋나지 않았는지 본다
      if (sub == '결재 관리' && _approvalCard.evaluate().isNotEmpty) {
        currentScreen = 'max_결재상세';
        await tester.tap(_approvalCard.first, warnIfMissed: false);
        await settle(tester, seconds: 5);
        await shot(tester, '3_max_결재상세');
        final sc = find.byType(Scrollable);
        if (sc.evaluate().isNotEmpty) {
          await tester.drag(sc.last, const Offset(0, -600), warnIfMissed: false);
          await settle(tester, seconds: 2);
          await shot(tester, '3_max_결재상세_아래');
        }
        await tester.binding.handlePopRoute();
        await settle(tester, seconds: 2);
      }
    }
    // 채팅방에서 한글·숫자·기호를 섞어 입력해 서체가 한 벌로 그려지는지 본다
    await tester.tap(find.text('채팅').last, warnIfMissed: false);
    await settle(tester, seconds: 3);
    if (_roomTile.evaluate().isNotEmpty) {
      currentScreen = 'max_chat_typing';
      await tester.tap(_roomTile.first, warnIfMissed: false);
      await settle(tester, seconds: 5);
      await tester.enterText(find.byType(TextField).last,
          '♡이은주어르신 식사특이사항♡ 점심 12시\n김도재 어르신은 고기 대신 계란프라이 3개 ~');
      await settle(tester, seconds: 2);
      await shot(tester, '3_max_chat_typing');
      await tester.enterText(find.byType(TextField).last, '');
      await tester.binding.handlePopRoute();
      await settle(tester, seconds: 2);
    }

    // 다음 실행이 '보통'에서 시작하도록 되돌린다
    await openTextSize(tester);
    await tester.tap(find.text('보통').last, warnIfMissed: false);
    await settle(tester, seconds: 2);
    FlutterError.onError = original;
    debugPrint('[DONE]');
  }, timeout: const Timeout(Duration(minutes: 20)));
}
