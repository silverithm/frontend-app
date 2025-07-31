import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/vacation_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/fcm_service.dart';
import '../services/subscription_guard.dart';
import '../utils/admin_utils.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';
import 'calendar_screen.dart';
import 'my_vacation_screen.dart';
import 'profile_screen.dart';
import 'admin_dashboard_screen.dart';
import '../providers/admin_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/admin_signin_response.dart';
import '../widgets/common/index.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 1; // 달력을 기본으로 설정
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // 기본 인덱스 설정 (일반 사용자는 달력을 기본으로)
    _currentIndex = 1;

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

          // 구독 상태 확인 및 필요시 리다이렉트 (관리자만)
          final canProceed = await SubscriptionGuard.checkSubscriptionAndRedirect(context);
          
          if (canProceed) {
            // 구독 체크를 통과한 경우에만 데이터 로드
            vacationProvider.loadCalendarData(DateTime.now(), companyId: companyId);
            vacationProvider.loadMyVacationRequests(userId);

            // FCM 토큰 서버 전송
            print('[MainScreen] FCM 토큰 서버 전송 시작');
            FCMService().sendAdminTokenToServer(userId);
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
      } else {
        print('[MainScreen] 사용자 정보 없음 - FCM 토큰 전송 건너뜀');
      }
    });
  }

  @override
  void dispose() {
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
        
        // 관리자는 AdminDashboardScreen 직접 반환
        if (isAdmin) {
          return const AdminDashboardScreen();
        }
        
        // 일반 사용자 화면 및 네비게이션 아이템 정의 (실시간)
        final userScreens = [
          const MyVacationScreen(),
          const CalendarScreen(),
          const ProfileScreen(),
        ];
        
        final userNavItems = [
          _buildNavItem(0, Icons.list_alt, Icons.list_alt_outlined, '내 휴무'),
          _buildNavItem(
            1,
            Icons.calendar_month,
            Icons.calendar_month_outlined,
            '달력',
          ),
          _buildNavItem(2, Icons.person, Icons.person_outline, '프로필'),
        ];
        
        // 일반 사용자는 기존 구조 유지
        return Scaffold(
          body: IndexedStack(
            index: _currentIndex.clamp(0, userScreens.length - 1), 
            children: userScreens,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, AppSemanticColors.backgroundSecondary],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex.clamp(0, userNavItems.length - 1),
                onTap: _onItemTapped,
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedItemColor: AppSemanticColors.interactivePrimaryDefault,
                unselectedItemColor: Colors.grey.shade400,
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 11),
                items: userNavItems,
              ),
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
    final authProvider = context.read<AuthProvider>();
    final isAdmin = AdminUtils.canAccessAdminPages(authProvider.currentUser);

    Color iconColor = Colors.grey.shade400;

    if (isSelected) {
      if (isAdmin) {
        iconColor = AppSemanticColors.interactiveSecondaryDefault;
      } else {
        iconColor = AppSemanticColors.interactivePrimaryDefault;
      }
    }

    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(isSelected ? 8 : 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isAdmin
                    ? AppSemanticColors.interactiveSecondaryDefault.withValues(
                        alpha: 0.1,
                      )
                    : AppSemanticColors.interactivePrimaryDefault.withValues(
                        alpha: 0.1,
                      ))
              : Colors.transparent,
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
