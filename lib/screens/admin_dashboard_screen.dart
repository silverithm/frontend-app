import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/admin_utils.dart';
import '../utils/constants.dart';
import '../widgets/common/index.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';
import 'admin_user_management_screen.dart';
import 'admin_all_members_screen.dart';
import 'admin_vacation_management_screen.dart';
import 'admin_vacation_limits_screen.dart';
import 'admin_vacation_history_screen.dart';
import 'admin_calendar_screen.dart';
import 'admin_company_settings_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _buildUserManagementTab(null),
      const AdminVacationManagementScreen(),
      _buildCalendarTab(),
      const AdminCompanySettingsScreen(),
    ];
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser;

        // 관리자 권한 확인
        if (!AdminUtils.canAccessAdminPages(user)) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('관리자 페이지'),
              backgroundColor: Colors.red.shade600,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '관리자 권한이 필요합니다',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '이 페이지에 접근하려면 관리자 권한이 필요합니다.',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        _pages = [
          _buildUserManagementTab(user),
          const AdminVacationManagementScreen(),
          _buildCalendarTab(),
          const AdminCompanySettingsScreen(),
        ];

        return Scaffold(
          backgroundColor: AppSemanticColors.backgroundPrimary,
          body: IndexedStack(index: _currentIndex, children: _pages),
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
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedItemColor:
                    AppSemanticColors.interactiveSecondaryDefault,
                unselectedItemColor: Colors.grey.shade400,
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 11),
                items: [
                  _buildNavItem(0, Icons.people, Icons.people_outline, '회원관리'),
                  _buildNavItem(
                    1,
                    Icons.calendar_today,
                    Icons.calendar_today_outlined,
                    '휴무관리',
                  ),
                  _buildNavItem(2, Icons.event, Icons.event_outlined, '달력'),
                  _buildNavItem(
                    3,
                    Icons.business,
                    Icons.business_outlined,
                    '회사정보',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserManagementTab(user) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원 관리', style: TextStyle(color: Colors.white)),
        backgroundColor: AppSemanticColors.interactiveSecondaryDefault,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.people_alt_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '가입 승인 및 회원 관리',
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ADMIN',
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Constants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  _buildActionCard(
                    '승인 대기',
                    '새로운 가입 요청',
                    Icons.pending_actions,
                    AppColors.purple600,
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminUserManagementScreen(),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    '전체 회원',
                    '회원 목록 관리',
                    Icons.people,
                    AppColors.green600,
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminAllMembersScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVacationManagementTab(user) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('휴무 관리', style: TextStyle(color: Colors.white),),
        backgroundColor: AppSemanticColors.interactiveSecondaryDefault,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.event_note_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '휴무 요청 승인 및 한도 설정',
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ADMIN',
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Constants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  _buildActionCard(
                    '휴무 승인',
                    '대기 중인 휴무 요청',
                    Icons.approval,
                    Colors.orange.shade600,
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminVacationManagementScreen(),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    '휴무 한도',
                    '일일 휴무 한도 설정',
                    Icons.event_available,
                    Colors.blue.shade600,
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminVacationLimitsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    '휴무 내역',
                    '전체 휴무 내역 조회',
                    Icons.history,
                    Colors.green.shade600,
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminVacationHistoryScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      height: 100,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              border: Border.all(
                color: AppSemanticColors.borderDefault.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppSemanticColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Flexible(
                        child: Text(
                          subtitle,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppSemanticColors.textSecondary,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppSemanticColors.textTertiary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarTab() {
    return const AdminCalendarScreen();
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.construction, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            const Text('개발 중'),
          ],
        ),
        content: Text('$feature 기능은 현재 개발 중입니다.\n곧 출시될 예정입니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(
    int index,
    IconData selectedIcon,
    IconData unselectedIcon,
    String label,
  ) {
    final isSelected = _currentIndex == index;

    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(isSelected ? 8 : 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppSemanticColors.interactiveSecondaryDefault.withValues(
                  alpha: 0.1,
                )
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isSelected ? selectedIcon : unselectedIcon,
          color: isSelected
              ? AppSemanticColors.interactiveSecondaryDefault
              : Colors.grey.shade400,
          size: isSelected ? 24 : 22,
        ),
      ),
      label: label,
    );
  }
}
