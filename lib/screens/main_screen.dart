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
import 'calendar_screen.dart';
import 'profile_screen.dart';
import 'chat_room_list_screen.dart';
import 'home_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  late AnimationController _animationController;

  final List<Widget> _screens = const [
    HomeScreen(),
    CalendarScreen(),
    ChatRoomListScreen(),
    ProfileScreen(),
  ];

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

      print('[MainScreen] 메인 화면 초기화 - 사용자 정보 확인');
      print('[MainScreen] currentUser: ${authProvider.currentUser}');

      if (authProvider.currentUser != null) {
        final userId = authProvider.currentUser!.id;
        final companyId = authProvider.currentUser!.company?.id ?? '1';
        final isAdmin = AdminUtils.canAccessAdminPages(authProvider.currentUser);

        print('[MainScreen] 로그인된 사용자 ID: $userId');
        print('[MainScreen] 회사 ID: $companyId');
        print('[MainScreen] 관리자 여부: $isAdmin');

        if (isAdmin) {
          // 관리자인 경우에만 구독 정보 로드
          print('[MainScreen] 관리자 - 구독 정보 실시간 로드 시작');
          await subscriptionProvider.loadSubscription();
          print('[MainScreen] 관리자 - 구독 정보 실시간 로드 완료');

          // FCM 토큰 서버 전송 (구독 상태와 무관하게 항상 전송)
          print('[MainScreen] 관리자 FCM 토큰 서버 전송 시작');
          FCMService().sendAdminTokenToServer(userId);

          // 구독 상태 확인 및 필요시 리다이렉트 (관리자만)
          final canProceed = await SubscriptionGuard.checkSubscriptionAndRedirect(context);

          if (canProceed) {
            // 구독 체크를 통과한 경우에만 데이터 로드
            vacationProvider.loadCalendarData(DateTime.now(), companyId: companyId);
            vacationProvider.loadMyVacationRequests(userId);
          }
        } else {
          // 직원인 경우 구독 체크 없이 바로 데이터 로드
          print('[MainScreen] 직원 - 구독 체크 건너뛰고 데이터 로드');
          vacationProvider.loadCalendarData(DateTime.now(), companyId: companyId);
          vacationProvider.loadMyVacationRequests(userId);

          // FCM 토큰 서버 전송
          print('[MainScreen] FCM 토큰 서버 전송 시작');
          FCMService().sendTokenToServer(userId);
        }
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
        print('[MainScreen] 사용자 정보 없음 - FCM 토큰 전송 건너뜀');
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
        final isAdmin = AdminUtils.canAccessAdminPages(authProvider.currentUser);

        final selectedColor = isAdmin
            ? AppSemanticColors.interactiveSecondaryDefault
            : AppSemanticColors.interactivePrimaryDefault;

        final navItems = [
          _buildNavItem(0, Icons.home, Icons.home_outlined, '홈', isAdmin),
          _buildNavItem(1, Icons.calendar_month, Icons.calendar_month_outlined, '달력', isAdmin),
          _buildNavItem(2, Icons.chat_bubble, Icons.chat_bubble_outline, '채팅', isAdmin),
          _buildNavItem(3, Icons.person, Icons.person_outline, '프로필', isAdmin),
        ];

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex.clamp(0, _screens.length - 1),
            children: _screens,
          ),
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
              currentIndex: _currentIndex.clamp(0, navItems.length - 1),
              onTap: _onItemTapped,
              type: BottomNavigationBarType.fixed,
              backgroundColor: AppColors.transparent,
              elevation: 0,
              selectedItemColor: selectedColor,
              unselectedItemColor: AppSemanticColors.textDisabled,
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
    bool isAdmin,
  ) {
    final isSelected = _currentIndex == index;

    Color iconColor = AppSemanticColors.textDisabled;

    if (isSelected) {
      iconColor = isAdmin
          ? AppSemanticColors.interactiveSecondaryDefault
          : AppSemanticColors.interactivePrimaryDefault;
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
}
