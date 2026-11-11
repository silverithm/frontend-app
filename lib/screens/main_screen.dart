import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/vacation_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/approval_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/admin_provider.dart';
import '../providers/work_task_provider.dart';
import '../models/vacation_request.dart';
import '../services/fcm_service.dart';
import '../services/permission_sync_service.dart';
import '../services/subscription_guard.dart';
import '../utils/admin_utils.dart';
import '../utils/app_haptics.dart';
import '../widgets/common/app_bottom_tab_bar.dart';
import '../utils/permissions.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'approval_hub_screen.dart';
import 'calendar_screen.dart';
import 'chat_room_list_screen.dart';
import 'home_screen.dart';
import 'menu_screen.dart';

/// 하단 탭 인덱스 — 홈 등 다른 화면에서 탭 이동 시 이 상수를 쓴다 (매직넘버 금지).
/// 직원·관리자 모두 같은 5탭 구조라 인덱스가 역할에 따라 달라지지 않는다.
/// 순서: 홈 → 채팅 → 일정 → 전자결재 → 전체 (2026-08 개편)
class MainTabs {
  static const int home = 0;
  static const int chat = 1;
  static const int calendar = 2;
  static const int approval = 3;
  static const int menu = 4;
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _currentIndex = 0;

    // 사용자 정보가 있으면 구독 체크, 휴무 데이터 로드 및 FCM 토큰 전송
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = context.read<AuthProvider>();
      final vacationProvider = context.read<VacationProvider>();
      final subscriptionProvider = context.read<SubscriptionProvider>();

      debugPrint('[MainScreen] 메인 화면 초기화 - 사용자 정보 확인');
      debugPrint('[MainScreen] currentUser: ${authProvider.currentUser}');

      if (authProvider.currentUser != null) {
        // 웹에서 바뀐 세부 권한을 재로그인 없이 반영한다(실패해도 저장된 권한 유지).
        await PermissionSyncService.refresh(authProvider);
        if (!mounted) return;

        final userId = authProvider.currentUser!.id;
        final companyId = authProvider.currentUser!.company?.id ?? '1';
        final isAdmin = AdminUtils.canAccessAdminPages(
          authProvider.currentUser,
        );

        debugPrint('[MainScreen] 로그인된 사용자 ID: $userId');
        debugPrint('[MainScreen] 회사 ID: $companyId');
        debugPrint('[MainScreen] 관리자 여부: $isAdmin');

        if (isAdmin) {
          // 관리자인 경우에만 구독 정보 로드
          debugPrint('[MainScreen] 관리자 - 구독 정보 실시간 로드 시작');
          await subscriptionProvider.loadSubscription();
          if (!mounted) return;
          debugPrint('[MainScreen] 관리자 - 구독 정보 실시간 로드 완료');

          // FCM 토큰 서버 전송 (구독 상태와 무관하게 항상 전송)
          debugPrint('[MainScreen] 관리자 FCM 토큰 서버 전송 시작');
          FCMService().sendAdminTokenToServer(userId);

          // 구독 상태 확인 및 필요시 리다이렉트 (관리자만)
          final canProceed =
              await SubscriptionGuard.checkSubscriptionAndRedirect(context);
          if (!mounted) return;

          if (canProceed) {
            // 구독 체크를 통과한 경우에만 데이터 로드
            vacationProvider.loadCalendarData(
              DateTime.now(),
              companyId: companyId,
            );
            vacationProvider.loadMyVacationRequests(userId);
            // 구독이 막힌 관리자를 알림 탭이 결제 화면 너머로 데려가면 안 된다 — 통과한 뒤에만 연다
            _attachPushNavigation();
          }
        } else {
          // 직원인 경우 구독 체크 없이 바로 데이터 로드
          debugPrint('[MainScreen] 직원 - 구독 체크 건너뛰고 데이터 로드');
          vacationProvider.loadCalendarData(
            DateTime.now(),
            companyId: companyId,
          );
          vacationProvider.loadMyVacationRequests(userId);

          // FCM 토큰 서버 전송
          debugPrint('[MainScreen] FCM 토큰 서버 전송 시작');
          FCMService().sendTokenToServer(userId);
          _attachPushNavigation();
        }

        if (!mounted) return;
        // 초기 알림 로드
        context.read<NotificationProvider>().loadNotifications(
          authProvider.currentUser!.id.toString(),
          // 관리자는 알림이 두 식별자로 나뉘어 저장된다 — 한쪽만 보면 절반이 안 보인다
          alsoUserId: authProvider.currentUser!.chatUserId,
        );

        // FCM 포그라운드 메시지 콜백 설정
        FCMService().onForegroundMessage = (message) {
          if (mounted && authProvider.currentUser != null) {
            context.read<NotificationProvider>().loadNotifications(
              authProvider.currentUser!.id.toString(),
              alsoUserId: authProvider.currentUser!.chatUserId,
            );

            // 채팅 푸시면 목록도 갱신 — 소켓 구독이 이미 대부분 처리하지만,
            // 아직 참여자로 반영 안 된 새 방 등을 위한 안전망. 디바운스로 과호출 방지.
            if (message.data['type'] == 'chat') {
              context.read<ChatProvider>().refreshRoomListDebounced(
                companyId: companyId,
                // 채팅은 관리자를 'admin_3'으로 부른다 — 숫자 id를 넘기면 내가 보낸
                // 마지막 메시지를 남의 것으로 보고 안 읽음을 다시 켠다
                userId: authProvider.currentUser!.chatUserId,
              );
            }

            // 결재 푸시(승인/반려/상신/삭제 등)를 받았을 때도 목록을 새로 받는다 —
            // 안 그러면 웹에서 이미 삭제·처리된 문서가 기기에 계속 "내 차례"로 남는다
            // (2026-09-22 운영 사고: 삭제된 결재 777이 앱에서 계속 표시됨).
            if (message.data['type'] == 'approval') {
              _refreshApprovalData();
            }

            // 업무를 맡았다는 알림 — 홈 업무진행도 칸이 다음 진입까지 옛 목록으로 남지 않게
            if (message.data['type'] == 'work_task') {
              context.read<WorkTaskProvider>().load();
            }
          }
        };
      } else {
        debugPrint('[MainScreen] 사용자 정보 없음 - FCM 토큰 전송 건너뜀');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.currentUser != null) {
        context.read<NotificationProvider>().loadNotifications(
          authProvider.currentUser!.id.toString(),
          // 관리자는 알림이 두 식별자로 나뉘어 저장된다 — 한쪽만 보면 절반이 안 보인다
          alsoUserId: authProvider.currentUser!.chatUserId,
        );

        // 백그라운드에 있는 동안 놓친 채팅 메시지(소켓 미연결 구간)를 위한 안전망
        final companyId = authProvider.currentUser!.company?.id ?? '1';
        final chatProvider = context.read<ChatProvider>();
        // 화면이 꺼진 동안 소켓이 조용히 죽어 있으면 하트비트가 알아채기 전에 바로 다시 붙는다.
        // 그 사이에 보낸 메시지가 사라지던 것이 2026-09-14 "메시지가 안 보내져요"의 원인이다.
        chatProvider.ensureConnected();
        chatProvider.loadChatRooms(
          companyId: companyId,
          userId: authProvider.currentUser!.chatUserId,
        );

        // 백그라운드에 있는 동안 결재 문서가 웹에서 승인/반려/삭제됐을 수 있다 —
        // 복귀할 때마다 다시 받아 캐시를 서버와 맞춘다(안 그러면 이미 없어진
        // 문서가 "내 차례"로 계속 남는다. 2026-09-22 운영 사고 참고).
        _refreshApprovalData();
      }
    }
  }

  @override
  void dispose() {
    if (_pushNavigationAttached) FCMService().detachSession();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _pushNavigationAttached = false;

  /// 알림 탭 이동을 연다 — 로그인 정보가 채워진 뒤라야 채팅방·결재 문서를 찾을 수 있다.
  /// 그 전에 누른 알림(꺼진 앱을 알림으로 켠 경우)은 지금 그 화면으로 간다.
  void _attachPushNavigation() {
    if (_pushNavigationAttached || !mounted) return;
    _pushNavigationAttached = true;
    FCMService().attachSession();
  }

  /// 결재함·내 결재 목록을 서버에서 다시 받는다 — 개수(myTurnCount 등)가 로컬에
  /// 남은 stale 문서 때문에 실제와 어긋나는 것을 막는 공통 새로고침.
  Future<void> _refreshApprovalData() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;
    final companyId = user.company?.id ?? '1';
    final canManageApprovals = PermissionUtils.has(
      user,
      AppPermission.approvalManage,
    );
    final approvalProvider = context.read<ApprovalProvider>();
    final futures = <Future<void>>[
      approvalProvider.loadApprovalRequests(companyId: companyId, refresh: true),
    ];
    if (!canManageApprovals) {
      futures.add(
        approvalProvider.loadMyApprovalRequests(
          requesterId: user.id,
          refresh: true,
        ),
      );
    }
    await Future.wait(futures);
  }

  /// 하단 탭을 손으로 눌렀을 때 — 다른 탭으로 옮길 때만 selection 햅틱.
  /// (홈 카드에서 탭을 옮기는 _onItemTapped 직접 호출에는 울리지 않는다.)
  void _onNavBarTapped(int index) {
    if (index != _currentIndex) AppHaptics.selection();
    _onItemTapped(index);
  }

  void _onItemTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
      // 새로 보이는 탭이 옅게 나타나는 연출은 MainTabStack이 index 변화를 보고 한다.
      // 홈·전자결재 탭은 결재 "내 차례" 강조/뱃지를 보여주는 화면이다 —
      // 탭을 열 때마다 최신 상태로 맞춘다(가려져 있던 탭은 다시 보일 때까지
      // 저절로 새로고침되지 않는다: IndexedStack이 위젯을 계속 살려둔다).
      if (index == MainTabs.home || index == MainTabs.approval) {
        _refreshApprovalData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // 전자결재 탭의 기본 화면·뱃지는 '결재 관리' 권한 기준이다.
        // 관리자는 PermissionUtils가 모든 권한을 가진 것으로 보므로 지금과 동일하다.
        final canManageApprovals = PermissionUtils.has(
          authProvider.currentUser,
          AppPermission.approvalManage,
        );
        final screens = _buildScreens(canManageApprovals);
        final navItems = _buildNavItems(canManageApprovals);
        final safeIndex = _currentIndex.clamp(0, screens.length - 1);

        return Scaffold(
          // B안: 탭 화면 사이·전환 중에 비치는 바탕도 옅은 회색(테마 값과 같지만 명시해 둔다)
          backgroundColor: AppSemanticColors.backgroundCanvas,
          body: MainTabStack(index: safeIndex, children: screens),
          // B안(2026-11-12): 흰 바탕 + 위 옅은 선, 고르면 채운 아이콘 + 틸(선택 알약 바탕 없음)
          bottomNavigationBar: AppBottomTabBar(
            items: navItems,
            currentIndex: safeIndex,
            onTap: _onNavBarTapped,
          ),
        );
      },
    );
  }

  AppBottomTabItem _buildNavItem(
    IconData selectedIcon,
    IconData unselectedIcon,
    String label, {
    int badgeCount = 0,
  }) {
    return AppBottomTabItem(
      icon: unselectedIcon,
      selectedIcon: selectedIcon,
      label: label,
      badgeCount: badgeCount,
    );
  }

  List<Widget> _buildScreens(bool canManageApprovals) {
    // MainTabs 순서와 반드시 일치해야 한다: 홈·채팅·일정·전자결재·전체
    return [
      HomeScreen(onNavigateToTab: _onItemTapped),
      const ChatRoomListScreen(),
      const CalendarScreen(),
      // 결재 관리 권한자(관리자 포함)는 승인할 문서가 기본, 그 외는 신청이 기본
      canManageApprovals
          ? const ApprovalHubScreen(initialTab: 1)
          : const ApprovalHubScreen(),
      const MenuScreen(),
    ];
  }

  List<AppBottomTabItem> _buildNavItems(bool canManageApprovals) {
    // 미확인 건수 뱃지 — 전자결재는 결재+휴무+가입 대기 합산, 채팅은 미읽음
    final authProvider = context.watch<AuthProvider>();
    final approvalProvider = context.watch<ApprovalProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final vacationProvider = context.watch<VacationProvider>();
    final adminProvider = context.watch<AdminProvider>();
    // 결재함(approvalRequests)은 관리자에게 기관 전체 문서를 보여준다(서버 설계상
    // 의도된 동작) — 여기서 pendingCount를 그대로 쓰면 내 차례가 아닌 문서(다른
    // 결재자 단계, 다른 관리자가 처리할 legacy 문서 등)까지 합쳐져 "처리할 게
    // 없는데 뱃지가 뜬다"는 오탐이 생긴다. 실제로 내 차례인 건수(myTurnCount)만
    // 센다 — 홈 화면 강조·결재함 탭 뱃지와 동일한 기준.
    final approvalBadge = canManageApprovals
        ? approvalProvider.myTurnCount(
              myId: authProvider.currentUser?.id,
              isAdmin: canManageApprovals,
            ) +
            vacationProvider.vacationRequests
                .where((r) => r.status == VacationStatus.pending)
                .length +
            adminProvider.pendingUsers.length
        : approvalProvider.myPendingCount;
    final chatBadge = chatProvider.totalUnreadCount;

    return [
      _buildNavItem(
        Icons.home_rounded,
        Icons.home_outlined,
        '홈',
      ),
      _buildNavItem(
        Icons.chat_rounded,
        Icons.chat_bubble_outline_rounded,
        '채팅',
        badgeCount: chatBadge,
      ),
      _buildNavItem(
        Icons.calendar_month_rounded,
        Icons.calendar_month_outlined,
        '일정',
      ),
      _buildNavItem(
        Icons.fact_check_rounded,
        Icons.fact_check_outlined,
        '전자결재',
        badgeCount: approvalBadge,
      ),
      // 시안: '전체'는 네 칸 격자 아이콘(고르면 채움)
      _buildNavItem(
        Icons.grid_view_rounded,
        Icons.grid_view_outlined,
        '전체',
      ),
    ];
  }
}

/// 하단 탭 화면 묶음 — 탭 화면을 모두 살려 둔 채(IndexedStack, 스크롤·입력 상태 유지)
/// [index]가 바뀌면 새로 보이는 탭이 [AppMotion.tabSwitch](200ms)로 옅게 나타난다(겹쳐 바뀜).
///
/// - 앱이 처음 뜰 때는 연출 없이 바로 보인다(처음 값 1).
/// - '동작 줄이기'면 연출 없이 바로 바뀐다.
/// - 탭 전환 햅틱은 하단 탭(AppBottomTabBar 쪽 _onNavBarTapped)이 울린다 — 여기서는 울리지 않는다.
class MainTabStack extends StatefulWidget {
  const MainTabStack({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<MainTabStack> createState() => _MainTabStackState();
}

class _MainTabStackState extends State<MainTabStack>
    with SingleTickerProviderStateMixin {
  // 처음 값 1 — 앱이 처음 뜰 때 탭 내용이 투명하면 안 된다.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.tabSwitch,
    value: 1,
  );
  late final CurvedAnimation _opacity = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.enterCurve,
  );

  @override
  void didUpdateWidget(covariant MainTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    if (AppMotion.reduceMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _opacity.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      // 옅게 나타나는 200ms 동안에도 화면 낭독기가 탭 내용을 놓치지 않게
      alwaysIncludeSemantics: true,
      child: IndexedStack(index: widget.index, children: widget.children),
    );
  }
}
