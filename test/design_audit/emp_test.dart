import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';
import 'harness.dart';
import 'specs.dart';

void main() {
  setUpAll(setUpAudit);
  testWidgets('직원 화면', (tester) async {
    final a = AuditApp(tester, Role.emp);
    await a.boot();
    await shellSpecs(a, 'emp');
    await commonSpecs(a, 'emp');
    await sheetSpecs(a, 'emp');
    writeReport('emp');
  }, timeout: const Timeout(Duration(minutes: 20)));
}
