// 로그인 전 화면(로그인·회원가입) + 업데이트 다이얼로그 + 구독 확인 화면
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/screens/register_screen.dart';
import 'package:frontend_app/widgets/update_dialog.dart';

import 'fixtures.dart';
import 'harness.dart';
import 'specs.dart';

void main() {
  setUpAll(setUpAudit);
  testWidgets('로그인 전 공통 화면', (tester) async {
    final a = AuditApp(tester, Role.emp);
    await a.boot(loggedIn: false);
    currentShot = 'common-01-login-employee';
    await a.shot('common-01-login-employee');

    try {
      await tapText(a, '관리자', wait: 1);
      await a.shot('common-02-login-admin');
    } catch (e) {
      renderFailed['common-02-login-admin'] = '$e';
    }
    try {
      await tapText(a, '직원', wait: 1);
    } catch (_) {}

    Future<void> scrollDown(double dy) async {
      await tester.drag(find.byType(Scrollable).first, Offset(0, -dy), warnIfMissed: false);
      await a.settle(seconds: 1);
    }

    await pushShot(a, 'common-03-register-top', () => const RegisterScreen());
    await pushShot(a, 'common-04-register-employee-code', () => const RegisterScreen(), after: () => scrollDown(700));
    await pushShot(a, 'common-05-register-employee-code-bottom', () => const RegisterScreen(), after: () => scrollDown(1400));
    await pushShot(a, 'common-06-register-admin', () => const RegisterScreen(), after: () async {
      await scrollDown(700);
      await tapText(a, '관리자', wait: 2);
    });

    currentShot = 'common-08-update-dialog';
    try {
      final ctx = tester.element(find.byType(Scaffold).first);
      showDialog<void>(
        context: ctx,
        builder: (_) => const UpdateDialog(
          currentVersion: '1.18.0',
          latestVersion: '1.19.0',
          updateMessage: '새 버전이 나왔어요. 업무진행도와 알림 이동이 추가되었습니다.',
          forceUpdate: false,
        ),
      );
      await a.settle(seconds: 1.5);
      await a.shot('common-08-update-dialog');
    } catch (e) {
      renderFailed['common-08-update-dialog'] = '$e';
    }
    writeReport('common');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
