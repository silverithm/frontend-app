import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/company.dart';
import 'package:frontend_app/models/notice.dart';
import 'package:frontend_app/models/user.dart';
import 'package:frontend_app/providers/auth_provider.dart';
import 'package:frontend_app/providers/notice_provider.dart';
import 'package:frontend_app/screens/notice_detail_screen.dart';
import 'package:frontend_app/theme/app_theme.dart';
import 'package:frontend_app/widgets/common/app_skeleton.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 공지 상세 — 화면은 조회수·읽음 기록을 먼저 보내고 나서 글을 받는다. 그 사이 provider의
/// isLoading은 아직 false라, 예전에는 '공지사항을 찾을 수 없습니다'(또는 앞서 본 다른 글)가
/// 잠깐 먼저 보였다. 이 글을 받을 때까지는 뼈대를 보인다.
final _company = Company(
  id: '4',
  name: '햇살주간보호센터',
  addressName: '서울특별시 관악구 신림로 14길 23',
  companyCode: 'SUN2026',
);

final _user = User(
  id: '3',
  email: 'admin@example.com',
  name: '김관리',
  role: 'admin',
  username: 'admin',
  createdAt: DateTime(2026, 11, 12),
  position: '센터장',
  company: _company,
);

class _FakeAuth extends AuthProvider {
  @override
  User? get currentUser => _user;
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

class _FakeNotice extends NoticeProvider {
  _FakeNotice({this.selected, this.result});

  /// 화면이 열릴 때 provider에 남아 있던 글
  Notice? selected;

  /// 상세 조회가 돌려줄 글(null이면 실패)
  final Notice? result;

  /// 조회수 증가 요청 — 풀어 줄 때까지 기다린다
  final viewCount = Completer<void>();

  /// 상세 조회 요청 — 풀어 줄 때까지 기다린다
  final detail = Completer<void>();

  bool loading = false;

  @override
  Notice? get selectedNotice => selected;

  @override
  bool get isLoading => loading;

  @override
  List<NoticeComment> get comments => const [];

  @override
  List<NoticeReader> get readers => const [];

  @override
  String get errorMessage => '';

  @override
  Future<void> incrementViewCount({required int noticeId}) => viewCount.future;

  @override
  Future<void> markAsRead({
    required int noticeId,
    required String userId,
    required String userName,
  }) async {}

  @override
  Future<Notice?> loadNoticeDetail({required int noticeId}) async {
    loading = true;
    notifyListeners();
    await detail.future;
    selected = result ?? selected;
    loading = false;
    notifyListeners();
    return result;
  }

  @override
  Future<void> loadComments({required int noticeId}) async {}

  @override
  Future<void> loadReaders({required int noticeId}) async {}
}

Future<void> _open(WidgetTester tester, _FakeNotice notice) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuth()),
        ChangeNotifierProvider<NoticeProvider>.value(value: notice),
      ],
      child: MaterialApp(
        theme: AppTheme.withAppChrome(ThemeData()),
        home: const NoticeDetailScreen(noticeId: 7),
      ),
    ),
  );
  // 첫 프레임 뒤 불러오기가 시작된다. 뼈대는 빛이 계속 돌아 pumpAndSettle을 쓰지 않는다.
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('조회수·읽음 기록을 보내는 동안에도 뼈대 — 찾을 수 없습니다가 먼저 뜨지 않는다', (tester) async {
    final notice = _FakeNotice(result: _notice(7, '11월 안전점검의 날 안내'));
    await _open(tester, notice);

    // 아직 조회수 요청 중: provider는 isLoading=false, 글도 없다
    expect(notice.isLoading, isFalse);
    expect(find.byType(AppSkeleton), findsOneWidget);
    expect(find.text('공지사항을 찾을 수 없습니다'), findsNothing);

    // 상세 조회로 넘어간 뒤에도 뼈대
    notice.viewCount.complete();
    await _settle(tester);
    expect(notice.isLoading, isTrue);
    expect(find.byType(AppSkeleton), findsOneWidget);
    expect(find.text('공지사항을 찾을 수 없습니다'), findsNothing);

    // 글이 오면 내용
    notice.detail.complete();
    await _settle(tester);
    expect(find.byType(AppSkeleton), findsNothing);
    expect(find.text('11월 안전점검의 날 안내'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('앞서 본 다른 글이 남아 있어도 이 글을 받을 때까지는 뼈대', (tester) async {
    final notice = _FakeNotice(
      selected: _notice(3, '김장 나눔 행사'),
      result: _notice(7, '11월 안전점검의 날 안내'),
    );
    await _open(tester, notice);

    expect(find.byType(AppSkeleton), findsOneWidget);
    expect(find.text('김장 나눔 행사'), findsNothing);

    notice.viewCount.complete();
    notice.detail.complete();
    await _settle(tester);
    expect(find.byType(AppSkeleton), findsNothing);
    expect(find.text('11월 안전점검의 날 안내'), findsOneWidget);
    expect(find.text('김장 나눔 행사'), findsNothing);
  });

  testWidgets('같은 글을 다시 열면 남아 있던 내용이 바로 보인다', (tester) async {
    final notice = _FakeNotice(
      selected: _notice(7, '11월 안전점검의 날 안내'),
      result: _notice(7, '11월 안전점검의 날 안내'),
    );
    await _open(tester, notice);

    expect(find.byType(AppSkeleton), findsNothing);
    expect(find.text('11월 안전점검의 날 안내'), findsOneWidget);
  });

  testWidgets('끝내 받지 못하면 찾을 수 없습니다', (tester) async {
    final notice = _FakeNotice();
    await _open(tester, notice);
    expect(find.byType(AppSkeleton), findsOneWidget);

    notice.viewCount.complete();
    notice.detail.complete();
    await _settle(tester);
    expect(find.byType(AppSkeleton), findsNothing);
    expect(find.text('공지사항을 찾을 수 없습니다'), findsOneWidget);
  });
}
