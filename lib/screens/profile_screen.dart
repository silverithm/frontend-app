import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutBack,
          ),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.logout, color: Colors.red.shade600, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('로그아웃', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('정말 로그아웃하시겠습니까?', style: TextStyle(fontSize: 16)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final authProvider = context.read<AuthProvider>();
              await authProvider.logout();

              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일 ${date.hour}:${date.minute}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // 현대적인 앱바
          SliverAppBar(
            expandedHeight: 60.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            centerTitle: true,
            title: const Text(
              '프로필',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 18,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(1, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade600,
                    Colors.blue.shade400,
                    Colors.cyan.shade300,
                  ],
                ),
              ),
            ),
          ),

          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              final user = authProvider.currentUser;

              if (user == null) {
                return SliverFillRemaining(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.indigo.shade100,
                            Colors.blue.shade100,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.indigo.shade600,
                        ),
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildListDelegate([
                  // 프로필 카드
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.white, Colors.indigo.shade50],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              // 프로필 이미지
                              Hero(
                                tag: 'profile-image',
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.indigo.shade400,
                                        Colors.blue.shade300,
                                        Colors.cyan.shade200,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.indigo.shade200
                                            .withOpacity(0.5),
                                        blurRadius: 15,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: user.profileImage != null
                                      ? ClipOval(
                                          child: Image.network(
                                            user.profileImage!,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return _buildDefaultAvatar(
                                                    user,
                                                  );
                                                },
                                          ),
                                        )
                                      : _buildDefaultAvatar(user),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // 사용자 정보 섹션
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 20,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '기본 정보',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // 이름
                                    _buildInfoRow(
                                      icon: Icons.person,
                                      iconColor: Colors.blue.shade600,
                                      title: '이름',
                                      value: user.name,
                                    ),
                                    const SizedBox(height: 16),

                                    // 이메일
                                    _buildInfoRow(
                                      icon: Icons.email,
                                      iconColor: Colors.green.shade600,
                                      title: '이메일',
                                      value: user.email,
                                    ),
                                    const SizedBox(height: 16),

                                    // 직원 유형
                                    _buildInfoRow(
                                      icon: user.role == 'CAREGIVER'
                                          ? Icons.favorite
                                          : Icons.business,
                                      iconColor: user.role == 'CAREGIVER'
                                          ? Colors.pink.shade600
                                          : Colors.indigo.shade600,
                                      title: '직원 유형',
                                      value: _getRoleDisplayName(user.role),
                                    ),
                                    const SizedBox(height: 16),

                                    // 부서 (있는 경우)
                                    if (user.department != null &&
                                        user.department!.isNotEmpty)
                                      Column(
                                        children: [
                                          _buildInfoRow(
                                            icon: Icons.business_center,
                                            iconColor: Colors.orange.shade600,
                                            title: '부서',
                                            value: user.department!,
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      ),

                                    // 직책 (있는 경우)
                                    if (user.position != null &&
                                        user.position!.isNotEmpty)
                                      Column(
                                        children: [
                                          _buildInfoRow(
                                            icon: Icons.work,
                                            iconColor: Colors.purple.shade600,
                                            title: '직책',
                                            value: user.position!,
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      ),

                                    // 가입일
                                    _buildInfoRow(
                                      icon: Icons.calendar_today,
                                      iconColor: Colors.teal.shade600,
                                      title: '가입일',
                                      value: _formatDate(user.createdAt),
                                    ),

                                    // 마지막 로그인 (있는 경우)
                                    if (user.lastLoginAt != null)
                                      Column(
                                        children: [
                                          const SizedBox(height: 16),
                                          _buildInfoRow(
                                            icon: Icons.login,
                                            iconColor: Colors.grey.shade600,
                                            title: '마지막 로그인',
                                            value: _formatDateTime(
                                              user.lastLoginAt!,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 설정 섹션
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildSettingTile(
                            icon: Icons.notifications,
                            title: '알림 설정',
                            subtitle: _notificationsEnabled
                                ? '푸시 알림이 활성화되어 있습니다'
                                : '푸시 알림이 비활성화되어 있습니다',
                            trailing: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _notificationsEnabled
                                      ? [
                                          Colors.blue.shade400,
                                          Colors.blue.shade600,
                                        ]
                                      : [
                                          Colors.grey.shade300,
                                          Colors.grey.shade400,
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: _notificationsEnabled
                                    ? [
                                        BoxShadow(
                                          color: Colors.blue.shade300
                                              .withOpacity(0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Switch(
                                value: _notificationsEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    _notificationsEnabled = value;
                                  });

                                  // 알림 상태에 따른 스낵바 표시
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _notificationsEnabled
                                            ? '알림이 활성화되었습니다'
                                            : '알림이 비활성화되었습니다',
                                      ),
                                      backgroundColor: _notificationsEnabled
                                          ? Colors.blue.shade600
                                          : Colors.grey.shade600,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      action: SnackBarAction(
                                        label: '확인',
                                        textColor: Colors.white,
                                        onPressed: () {},
                                      ),
                                    ),
                                  );
                                },
                                activeColor: Colors.white,
                                inactiveThumbColor: Colors.white,
                                trackColor: MaterialStateProperty.all(
                                  Colors.transparent,
                                ),
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                _notificationsEnabled = !_notificationsEnabled;
                              });
                            },
                          ),

                          const Divider(height: 1, color: Colors.transparent),

                          _buildSettingTile(
                            icon: Icons.help,
                            title: '도움말',
                            subtitle: '자주 묻는 질문 및 지원',
                            trailing: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.chevron_right,
                                color: Colors.blue.shade600,
                                size: 20,
                              ),
                            ),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('도움말 페이지는 준비 중입니다'),
                                  backgroundColor: Colors.blue.shade600,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            },
                          ),

                          const Divider(height: 1, color: Colors.transparent),

                          _buildSettingTile(
                            icon: Icons.info,
                            title: '앱 정보',
                            subtitle: '버전 및 개발자 정보',
                            trailing: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.chevron_right,
                                color: Colors.purple.shade600,
                                size: 20,
                              ),
                            ),
                            onTap: () {
                              showAboutDialog(
                                context: context,
                                applicationName: '휴무 관리 시스템',
                                applicationVersion: '1.0.0',
                                applicationIcon: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.indigo.shade400,
                                        Colors.blue.shade600,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_month,
                                    size: 32,
                                    color: Colors.white,
                                  ),
                                ),
                                children: [
                                  const Text('간편하게 휴무를 신청하고 관리할 수 있는 앱입니다.'),
                                ],
                              );
                            },
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 로그아웃 버튼
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.red.shade400,
                              Colors.red.shade600,
                              Colors.red.shade800,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.shade300.withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => _showLogoutDialog(context),
                          icon: const Icon(Icons.logout, color: Colors.white),
                          label: const Text(
                            '로그아웃',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 앱 버전 정보
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 100), // 바텀 패딩
                ]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(User user) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.indigo.shade400,
            Colors.blue.shade300,
            Colors.cyan.shade200,
          ],
        ),
      ),
      child: const Icon(Icons.person, size: 60, color: Colors.white),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(20) : Radius.zero,
          bottom: isLast ? const Radius.circular(20) : Radius.zero,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade100, Colors.blue.shade100],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.indigo.shade600, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        SizedBox(
          width: 60, // 라벨 너비를 더 줄임
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
            // overflow와 maxLines 제거하여 2줄로 표시 가능
          ),
        ),
      ],
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'CAREGIVER':
        return Colors.pink.shade400;
      case 'OFFICE':
        return Colors.blue.shade500;
      case 'admin':
        return Colors.purple.shade500;
      default:
        return Colors.grey.shade500;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'CAREGIVER':
        return Icons.favorite;
      case 'OFFICE':
        return Icons.business;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  String _getRoleDisplayName(String role) {
    print('User role: "$role"'); // 디버그 출력
    switch (role.toUpperCase()) {
      // 대소문자 구분 없이 처리
      case 'CAREGIVER':
        return '요양보호사';
      case 'OFFICE':
        return '사무실';
      case 'ADMIN':
        return '관리자';
      default:
        print('Unknown role: "$role", using default'); // 디버그 출력
        return '직원';
    }
  }
}
