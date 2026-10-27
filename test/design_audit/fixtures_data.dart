import 'fixtures.dart';
import 'fx_admin.dart';
import 'fx_chat.dart';
import 'fx_core.dart';
import 'fx_docs.dart';

export 'fx_core.dart' show today, ymd, iso, daysFromNow, Fixtures, staff, adminId;

void registerAll() {
  registerCore();
  registerChat();
  registerDocs();
  registerAdmin();
}
