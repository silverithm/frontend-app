import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/company.dart';
import 'package:frontend_app/models/notice.dart';
import 'package:frontend_app/models/user.dart';
import 'package:frontend_app/providers/admin_provider.dart';
import 'package:frontend_app/providers/auth_provider.dart';
import 'package:frontend_app/providers/notice_provider.dart';
import 'package:frontend_app/providers/subscription_provider.dart';
import 'package:frontend_app/screens/admin_company_settings_screen.dart';
import 'package:frontend_app/screens/admin_notice_form_screen.dart';
import 'package:frontend_app/screens/admin_notice_management_screen.dart';
import 'package:frontend_app/screens/admin_user_management_screen.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/theme/app_theme.dart';
import 'package:frontend_app/widgets/common/app_fab.dart';
import 'package:frontend_app/widgets/common/app_segmented_tabs.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 묶음 ⑥ 관리자 화면 B안(2026-11-12) — 회색 바탕 위 흰 카드, 상단 바 안 TabBar 대신 나눔 조절,
/// 알약 FAB. 좁은 폰에서 글자를 1.6배로 키워도 넘치지 않아야 한다.
class _FakeAuth extends AuthProvider {
  _FakeAuth(this._user);
  final User _user;

  @override
  User? get currentUser => _user;
}

class _FakeAdmin extends AdminProvider {
  _FakeAdmin(this._members, this._pending);
  final List<User> _members;
  final List<User> _pending;

  @override
  List<User> get companyMembers => _members;

  @override
  List<User> get pendingUsers => _pending;

  @override
  bool get isLoading => false;

  @override
  String get errorMessage => '';

  @override
  Future<void> loadPendingUsers(String companyId) async {}

  @override
  Future<void> loadCompanyMembers(String companyId) async {}
}

class _FakeNotice extends NoticeProvider {
  _FakeNotice(this._items);
  final List<Notice> _items;

  @override
  List<Notice> get notices => _items;

  @override
  bool get isLoading => false;

  @override
  bool get hasMore => false;

  @override
  String get errorMessage => '';

  @override
  Future<void> loadNotices({
    required String companyId,
    bool refresh = false,
  }) async {}
}

class _FakeSubscription extends SubscriptionProvider {
  @override
  Future<bool> loadSubscription() async => true;

  @override
  Future<bool> loadPaymentFailures({int page = 0, int size = 10}) async =>
      true;
}

final _company = Company(
  id: '4',
  name: '햇살주간보호센터',
  addressName: '서울특별시 관악구 신림로 14길 23 햇살빌딩 2층',
  companyCode: 'SUN2026',
);

User _user(String id, String name, {String status = 'active'}) => User(
  id: id,
  email: '$name@example.com',
  name: name,
  role: 'caregiver',
  username: 'user$id',
  status: status,
  createdAt: DateTime(2026, 11, 1),
  company: _company,
);

final _admin = User(
  id: '3',
  email: 'admin@example.com',
  name: '김관리',
  role: 'admin',
  username: 'admin',
  createdAt: DateTime(2026, 11, 12),
  position: '센터장',
  company: _company,
);

List<Notice> _notices() => [
  Notice(
    id: 1,
    title: '[필독] 11월 안전점검의 날 안내 — 모든 직원은 오전 9시까지 모여 주세요',
    content: '본문',
    priority: NoticePriority.high,
    status: NoticeStatus.published,
    isPinned: true,
    authorId: '3',
    authorName: '김관리',
    companyId: 4,
    viewCount: 128,
    createdAt: DateTime(2026, 11, 7, 9),
    updatedAt: DateTime(2026, 11, 7, 9),
  ),
  Notice(
    id: 2,
    title: '추석 연휴 운영 안내',
    content: '본문',
    authorId: '3',
    authorName: '김관리',
    companyId: 4,
    createdAt: DateTime(2026, 11, 5, 9),
    updatedAt: DateTime(2026, 11, 5, 9),
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required double textScale,
  required Widget home,
}) async {
  tester.view.physicalSize = Size(width * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuth(_admin)),
        ChangeNotifierProvider<AdminProvider>(
          create: (_) => _FakeAdmin(
            [_user('10', '김민지'), _user('11', '한소연', status: 'inactive')],
            [_user('12', '조은비', status: 'pending')],
          ),
        ),
        ChangeNotifierProvider<NoticeProvider>(
          create: (_) => _FakeNotice(_notices()),
        ),
        ChangeNotifierProvider<SubscriptionProvider>(
          create: (_) => _FakeSubscription(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.withAppChrome(ThemeData()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1));
}

Color? _scaffoldColor(WidgetTester tester) =>
    tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      testWidgets('종사자 관리 — 폭 $width · 글자 $scale배', (tester) async {
        await _pump(
          tester,
          width: width,
          textScale: scale,
          home: const AdminUserManagementScreen(),
        );
        expect(tester.takeException(), isNull);
        expect(_scaffoldColor(tester), AppSemanticColors.backgroundCanvas);
        // 상단 바 안 TabBar 대신 본문 맨 위 나눔 조절
        expect(find.byType(TabBar), findsNothing);
        expect(find.byType(AppSegmentedTabs), findsOneWidget);
        expect(find.text('승인 대기'), findsOneWidget);
        expect(find.text('전체 종사자'), findsOneWidget);
        expect(find.text('조은비'), findsOneWidget);

        // 다른 칸으로 넘기면 전체 종사자 목록이 보인다
        await tester.tap(find.text('전체 종사자'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('김민지'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('회사 정보 — 폭 $width · 글자 $scale배', (tester) async {
        await _pump(
          tester,
          width: width,
          textScale: scale,
          home: const AdminCompanySettingsScreen(),
        );
        expect(tester.takeException(), isNull);
        expect(_scaffoldColor(tester), AppSemanticColors.backgroundCanvas);
        expect(find.text('회사 상세 정보'), findsOneWidget);
        expect(find.text('구독 정보'), findsOneWidget);
        expect(find.text('계정 관리'), findsOneWidget);
      });

      testWidgets('공지 관리 — 폭 $width · 글자 $scale배', (tester) async {
        await _pump(
          tester,
          width: width,
          textScale: scale,
          home: const AdminNoticeManagementScreen(),
        );
        expect(tester.takeException(), isNull);
        expect(_scaffoldColor(tester), AppSemanticColors.backgroundCanvas);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.byType(AppFab), findsOneWidget);
        expect(find.byTooltip('새 공지 작성'), findsOneWidget);
        expect(find.text('추석 연휴 운영 안내'), findsOneWidget);
      });

      testWidgets('공지 쓰기 — 폭 $width · 글자 $scale배', (tester) async {
        await _pump(
          tester,
          width: width,
          textScale: scale,
          home: const AdminNoticeFormScreen(),
        );
        expect(tester.takeException(), isNull);
        expect(_scaffoldColor(tester), AppSemanticColors.backgroundCanvas);
        expect(find.text('상단 고정'), findsOneWidget);
        expect(find.text('공지사항 목록 최상단에 고정됩니다'), findsOneWidget);
      });
    }
  }
}
