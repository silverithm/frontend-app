import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/vacation_provider.dart';
import 'calendar_screen.dart';
import 'my_vacation_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 1; // 달력을 기본으로 설정
  late AnimationController _animationController;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // 순서 변경: 내 휴무 -> 달력 -> 프로필
    _screens = [
      const MyVacationScreen(),
      const CalendarScreen(),
      const ProfileScreen(),
    ];

    // 사용자 정보가 있으면 휴가 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final vacationProvider = context.read<VacationProvider>();

      if (authProvider.currentUser != null) {
        vacationProvider.loadCalendarData(DateTime.now());
        vacationProvider.loadMyVacationRequests(authProvider.currentUser!.id);
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
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.blue.shade50],
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
            selectedItemColor: Colors.blue.shade600,
            unselectedItemColor: Colors.grey.shade400,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            items: [
              BottomNavigationBarItem(
                icon: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.all(_currentIndex == 0 ? 8 : 4),
                  decoration: BoxDecoration(
                    color: _currentIndex == 0
                        ? Colors.blue.shade600.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _currentIndex == 0
                        ? Icons.list_alt
                        : Icons.list_alt_outlined,
                    size: _currentIndex == 0 ? 24 : 22,
                  ),
                ),
                label: '내 휴무',
              ),
              BottomNavigationBarItem(
                icon: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.all(_currentIndex == 1 ? 10 : 6),
                  decoration: BoxDecoration(
                    color: _currentIndex == 1
                        ? Colors.blue.shade600.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _currentIndex == 1
                        ? Icons.calendar_month
                        : Icons.calendar_month_outlined,
                    color: _currentIndex == 1
                        ? Colors.blue.shade600
                        : Colors.grey.shade400,
                    size: _currentIndex == 1 ? 26 : 22,
                  ),
                ),
                label: '달력',
              ),
              BottomNavigationBarItem(
                icon: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.all(_currentIndex == 2 ? 8 : 4),
                  decoration: BoxDecoration(
                    color: _currentIndex == 2
                        ? Colors.blue.shade600.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _currentIndex == 2 ? Icons.person : Icons.person_outline,
                    size: _currentIndex == 2 ? 24 : 22,
                  ),
                ),
                label: '프로필',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
