import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/vacation_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/notification_provider.dart';
import '../services/fcm_service.dart';
import '../services/subscription_guard.dart';
import '../utils/admin_utils.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'admin_unified_approval_screen.dart';
import 'admin_user_management_screen.dart';
import 'approval_list_screen.dart';
import 'calendar_screen.dart';
import 'chat_room_list_screen.dart';
import 'home_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      duration: AppTransitions.slow,
      vsync: this,
    );

    _currentIndex = 0;

    // 사용자 정보가 있으면 구독 체크, 휴무 데이터 로드 및 FCM 토큰 전송
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = context.read<AuthProvider>();
      final vacationProvider = context.read<VacationProvider>();
      final subscriptionProvider = context.read<SubscriptionProvider>();

      debugPrint('[MainScreen] 메인 화면 초기화 - 사용자 정보 확인');
      debugPrint('[MainScreen] currentUser: ${authProvider.currentUser}');

      if (authProvider.currentUser != null) {
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
        }

        if (!mounted) return;
        // 초기 알림 로드
        context.read<NotificationProvider>().loadNotifications(
          authProvider.currentUser!.id.toString(),
        );

        // FCM 포그라운드 메시지 콜백 설정
        FCMService().onForegroundMessage = (message) {
          if (mounted && authProvider.currentUser != null) {
            context.read<NotificationProvider>().loadNotifications(
              authProvider.currentUser!.id.toString(),
            );
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
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
      _animationController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final isAdmin = AdminUtils.canAccessAdminPages(
          authProvider.currentUser,
        );
        final screens = _buildScreens(isAdmin);
        final navItems = _buildNavItems(isAdmin);
        final safeIndex = _currentIndex.clamp(0, screens.length - 1);

        return Scaffold(
          body: IndexedStack(index: safeIndex, children: screens),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: AppSemanticColors.surfaceDefault,
              border: Border(
                top: BorderSide(
                  color: AppSemanticColors.borderDefault,
                  width: 1,
                ),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: safeIndex,
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed,
              backgroundColor: AppColors.transparent,
              elevation: 0,
              selectedItemColor: AppSemanticColors.interactivePrimaryDefault,
              unselectedItemColor: AppSemanticColors.textTertiary,
              selectedLabelStyle: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: AppTypography.labelSmall,
              items: navItems,
            ),
          ),
        );
      },
    );
  }

  BottomNavigationBarItem _buildNavItem(
    int index,
    IconData selectedIcon,
    IconData unselectedIcon,
    String label,
  ) {
    final isSelected = _currentIndex == index;

    Color iconColor = AppSemanticColors.textTertiary;

    if (isSelected) {
      iconColor = AppSemanticColors.interactivePrimaryDefault;
    }

    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: AppTransitions.normal,
        padding: EdgeInsets.all(
          isSelected ? AppSpacing.space2 : AppSpacing.space1,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? iconColor.withValues(alpha: 0.1)
              : AppColors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isSelected ? selectedIcon : unselectedIcon,
          color: iconColor,
          size: isSelected ? 24 : 22,
        ),
      ),
      label: label,
    );
  }

  List<Widget> _buildScreens(bool isAdmin) {
    return [
      HomeScreen(onNavigateToTab: _onItemTapped),
      const ChatRoomListScreen(),
      isAdmin ? const AdminUnifiedApprovalScreen() : const ApprovalListScreen(),
      const CalendarScreen(),
      if (isAdmin) const AdminUserManagementScreen(showBackButton: false),
    ];
  }

  List<BottomNavigationBarItem> _buildNavItems(bool isAdmin) {
    return [
      _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, '홈'),
      _buildNavItem(
        1,
        Icons.chat_rounded,
        Icons.chat_bubble_outline_rounded,
        '채팅',
      ),
      _buildNavItem(
        2,
        Icons.fact_check_rounded,
        Icons.fact_check_outlined,
        '전자결재',
      ),
      _buildNavItem(3, Icons.schedule_rounded, Icons.schedule_outlined, '근무조정'),
      if (isAdmin)
        _buildNavItem(
          4,
          Icons.people_alt_rounded,
          Icons.people_outline_rounded,
          '회원관리',
        ),
    ];
  }
}
