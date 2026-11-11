import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/company.dart';
import 'package:frontend_app/models/notice.dart';
import 'package:frontend_app/models/user.dart';
import 'package:frontend_app/models/work_task.dart';
import 'package:frontend_app/providers/admin_provider.dart';
import 'package:frontend_app/providers/auth_provider.dart';
import 'package:frontend_app/providers/notice_provider.dart';
import 'package:frontend_app/providers/work_task_provider.dart';
import 'package:frontend_app/screens/admin_user_management_screen.dart';
import 'package:frontend_app/screens/notice_list_screen.dart';
import 'package:frontend_app/screens/work_task_list_screen.dart';
import 'package:frontend_app/theme/app_theme.dart';
import 'package:frontend_app/widgets/common/app_list_entrance.dart';
import 'package:frontend_app/widgets/common/app_refresh.dart';
import 'package:frontend_app/widgets/common/app_skeleton.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 4단계(손에 닿는 반응) — 화면 첫 불러오기는 스피너 대신 뼈대, 내용이 있는 채로 다시 불러올 때는
/// 예전 스피너 그대로(내용이 깜빡 사라지지 않게), 목록은 당겨서 새로고침(AppRefreshIndicator)과
/// 첫 등장 연출(AppListEntranceItem)을 쓴다. 뼈대는 빛이 계속 돌아 pumpAndSettle 대신 pump(시간).
final _company = Company(
  id: '4',
  name: '햇살주간보호센터',
  addressName: '서울특별시 관악구 신림로 14길 23',
  companyCode: 'SUN2026',
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

User _member(String id, String name) => User(
  id: id,
  email: '$name@example.com',
  name: name,
  role: 'caregiver',
  username: 'user$id',
  status: 'active',
  createdAt: DateTime(2026, 11, 1),
  company: _company,
);

class _FakeAuth extends AuthProvider {
  _FakeAuth(this._user);
  final User _user;

  @override
  User? get currentUser => _user;
}

class _FakeNotice extends NoticeProvider {
  _FakeNotice({required this.loading, required this.items});
  final bool loading;
  final List<Notice> items;

  @override
  List<Notice> get publishedNotices => items;

  @override
  bool get isLoading => loading;

  @override
  bool get hasMore => false;

  @override
  String get errorMessage => '';

  @override
  Future<void> loadPublishedNotices({
    required String companyId,
    bool refresh = false,
  }) async {}
}

class _FakeAdmin extends AdminProvider {
  _FakeAdmin({required this.loading, required this.members});
  final bool loading;

  /// 승인 대기·전체 종사자 두 칸에 같은 사람을 둔다(첫 칸이 승인 대기라 그 칸으로 확인한다)
  final List<User> members;

  @override
  List<User> get companyMembers => members;

  @override
  List<User> get pendingUsers => members;

  @override
  bool get isLoading => loading;

  @override
  String get errorMessage => '';

  @override
  Future<void> loadPendingUsers(String companyId) async {}

  @override
  Future<void> loadCompanyMembers(String companyId) async {}
}

class _FakeWorkTasks extends WorkTaskProvider {
  _FakeWorkTasks({
    this.fakeStatus = WorkTaskLoadStatus.loading,
    this.fakeTasks = const [],
  });
  final WorkTaskLoadStatus fakeStatus;
  final List<WorkTask> fakeTasks;

  @override
  WorkTaskLoadStatus get status => fakeStatus;

  @override
  List<WorkTask> get tasks => fakeTasks;

  // 진행 중·끝낸 업무 나눔은 원래 필드(_tasks)를 보므로 같이 갈아 끼운다
  @override
  List<WorkTask> get inProgress => splitWorkTasks(fakeTasks).inProgress;

  @override
  List<WorkTask> get done => splitWorkTasks(fakeTasks).done;

  @override
  int myInProgressCount(String? meId) =>
      myInProgressWorkTaskCount(fakeTasks, meId);

  @override
  Future<void> load() async {}
}

Notice _notice(int id, String title) => Notice(
  id: id,
  title: title,
  content: '본문',
  priority: NoticePriority.normal,
  status: NoticeStatus.published,
  isPinned: false,
  authorId: '3',
  authorName: '김관리',
  companyId: 4,
  viewCount: 3,
  createdAt: DateTime(2026, 11, 7, 9),
  updatedAt: DateTime(2026, 11, 7, 9),
);

WorkTask _task(int id, String content, {int progress = 40, DateTime? done}) =>
    WorkTask(
      id: id,
      content: content,
      importance: WorkTaskImportance.high,
      progress: progress,
      dueDate: DateTime(2026, 11, 14),
      assignees: const [
        WorkTaskPerson(id: '12', name: '박소향'),
        WorkTaskPerson(id: '7', name: '이순자'),
      ],
      createdBy: const WorkTaskPerson(id: 'admin_3', name: '김관리'),
      completedAt: done,
    );

Future<void> _pump(
  WidgetTester tester, {
  required Widget home,
  double width = 390,
  NoticeProvider? notice,
  AdminProvider? admin,
  WorkTaskProvider? workTasks,
}) async {
  tester.view.physicalSize = Size(width * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuth(_admin)),
        ChangeNotifierProvider<NoticeProvider>.value(
          value: notice ?? _FakeNotice(loading: false, items: const []),
        ),
        ChangeNotifierProvider<AdminProvider>.value(
          value: admin ?? _FakeAdmin(loading: false, members: const []),
        ),
        ChangeNotifierProvider<WorkTaskProvider>.value(
          value: workTasks ?? _FakeWorkTasks(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.withAppChrome(ThemeData()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('공지 목록 — 처음 불러오는 동안은 스피너 대신 뼈대', (tester) async {
    await _pump(
      tester,
      home: const NoticeListScreen(),
      notice: _FakeNotice(loading: true, items: const []),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(AppSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // 상단 바 제목은 그대로
    expect(find.text('공지사항'), findsOneWidget);
  });

  testWidgets('공지 목록 — 다 불러오면 당겨서 새로고침 + 카드 첫 등장 연출, 글자 그대로', (tester) async {
    await _pump(
      tester,
      home: const NoticeListScreen(),
      notice: _FakeNotice(
        loading: false,
        items: [_notice(1, '11월 안전점검의 날 안내'), _notice(2, '김장 나눔 행사')],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(AppSkeleton), findsNothing);
    expect(find.byType(AppRefreshIndicator), findsOneWidget);
    expect(find.byType(AppListEntranceItem), findsNWidgets(2));
    expect(find.text('11월 안전점검의 날 안내'), findsOneWidget);
    expect(find.text('김장 나눔 행사'), findsOneWidget);
  });

  testWidgets('종사자 관리 — 처음 불러올 때는 뼈대, 목록이 있는 채로 다시 불러올 때는 예전 스피너', (
    tester,
  ) async {
    await _pump(
      tester,
      home: const AdminUserManagementScreen(),
      admin: _FakeAdmin(loading: true, members: const []),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(AppSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await _pump(
      tester,
      home: const AdminUserManagementScreen(),
      admin: _FakeAdmin(loading: true, members: [_member('10', '김민지')]),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(AppSkeleton), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('업무진행도 — 처음 불러오는 동안은 뼈대, 등록 단추는 그대로', (tester) async {
    await _pump(
      tester,
      home: const WorkTaskListScreen(),
      workTasks: _FakeWorkTasks(),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(AppSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('업무 등록'), findsOneWidget);
  });

  testWidgets('업무진행도 — 폭 320·글자 1.3배에서 넘치지 않고, 진행 중 줄만 첫 등장 연출', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 320,
      home: const WorkTaskListScreen(),
      workTasks: _FakeWorkTasks(
        fakeStatus: WorkTaskLoadStatus.loaded,
        fakeTasks: [
          _task(1, '11월 사업계획서 작성 — 프로그램 일정표까지 같이 정리'),
          _task(2, '송영 차량 정기 점검 예약', progress: 60),
          _task(3, '김장 나눔 행사 물품 확인', done: DateTime(2026, 11, 10)),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(AppSkeleton), findsNothing);
    expect(find.byType(AppRefreshIndicator), findsOneWidget);
    // 끝낸 업무는 접혀 있고, 진행 중 두 줄만 연출을 탄다
    expect(find.byType(AppListEntranceItem), findsNWidgets(2));
    expect(find.textContaining('진행 중 2건'), findsOneWidget);
    expect(find.text('끝낸 업무 1건'), findsOneWidget);
  });
}
