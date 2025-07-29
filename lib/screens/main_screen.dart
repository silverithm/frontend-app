import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/vacation_provider.dart';
import '../services/fcm_service.dart';
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
import '../widgets/common/index.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 1; // 달력을 기본으로 설정
  late AnimationController _animationController;

  late final List<Widget> _screens;
  late final List<BottomNavigationBarItem> _navItems;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // 사용자 역할에 따라 화면 구성
    final authProvider = context.read<AuthProvider>();
    final isAdmin = AdminUtils.canAccessAdminPages(authProvider.currentUser);

    if (isAdmin) {
      // 관리자는 AdminDashboardScreen을 직접 사용하도록 변경될 예정
      // 현재는 임시로 기존 구조 유지
      _screens = [
        const AdminDashboardScreen(),
      ];
      _navItems = [];
      _currentIndex = 0;
    } else {
      // 일반 사용자용: 내 휴무 -> 달력 -> 프로필
      _screens = [
        const MyVacationScreen(),
        const CalendarScreen(),
        const ProfileScreen(),
      ];
      _navItems = [
        _buildNavItem(0, Icons.list_alt, Icons.list_alt_outlined, '내 휴무'),
        _buildNavItem(
          1,
          Icons.calendar_month,
          Icons.calendar_month_outlined,
          '달력',
        ),
        _buildNavItem(2, Icons.person, Icons.person_outline, '프로필'),
      ];
      // 일반 사용자는 달력을 기본으로 설정
      _currentIndex = 1;
    }

    // 사용자 정보가 있으면 휴가 데이터 로드 및 FCM 토큰 전송
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final vacationProvider = context.read<VacationProvider>();

      print('[MainScreen] 메인 화면 초기화 - 사용자 정보 확인');
      print('[MainScreen] currentUser: ${authProvider.currentUser}');

      if (authProvider.currentUser != null) {
        final userId = authProvider.currentUser!.id;
        final companyId = authProvider.currentUser!.company?.id ?? '1';

        print('[MainScreen] 로그인된 사용자 ID: $userId');
        print('[MainScreen] 회사 ID: $companyId');

        vacationProvider.loadCalendarData(DateTime.now(), companyId: companyId);
        vacationProvider.loadMyVacationRequests(userId);

        // FCM 토큰 서버 전송
        print('[MainScreen] FCM 토큰 서버 전송 시작');
        FCMService().sendTokenToServer(userId);
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
        
        // 일반 사용자는 기존 구조 유지
        return Scaffold(
          body: IndexedStack(index: _currentIndex, children: _screens),
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
                currentIndex: _currentIndex,
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
                items: _navItems,
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
