import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';
import 'harness.dart';
import 'specs.dart';

void main() {
  setUpAll(setUpAudit);
  testWidgets('관리자 화면', (tester) async {
    final a = AuditApp(tester, Role.adm);
    await a.boot();
    await shellSpecs(a, 'adm');
    await commonSpecs(a, 'adm');
    await admSpecs(a, 'adm');
    await sheetSpecs(a, 'adm');
    writeReport('adm');
  }, timeout: const Timeout(Duration(minutes: 20)));
}
