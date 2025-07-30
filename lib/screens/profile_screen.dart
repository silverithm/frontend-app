import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../models/user.dart';
import '../services/analytics_service.dart';
import '../utils/admin_utils.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'subscription_check_screen.dart';

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

      // Analytics 프로필 화면 조회 이벤트
      AnalyticsService().logScreenView(screenName: 'profile_screen');
      AnalyticsService().logProfileView();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // URL 열기 메서드
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('링크를 열 수 없습니다: $url'),
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('링크 열기 중 오류가 발생했습니다'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
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

  void _showPasswordChangeDialog(BuildContext dialogContext) {
    showDialog(
      context: dialogContext,
      builder: (BuildContext context) {
        final currentPasswordController = TextEditingController();
        final newPasswordController = TextEditingController();
        final confirmPasswordController = TextEditingController();
        bool isChanging = false;
        bool showCurrentPassword = false;
        bool showNewPassword = false;
        bool showConfirmPassword = false;

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.lock, color: Colors.green.shade600, size: 24),
              ),
              const SizedBox(width: 12),
              const Text('비밀번호 변경', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 현재 비밀번호
                TextFormField(
                  controller: currentPasswordController,
                  obscureText: !showCurrentPassword,
                  decoration: InputDecoration(
                    labelText: '현재 비밀번호',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showCurrentPassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          showCurrentPassword = !showCurrentPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // 새 비밀번호
                TextFormField(
                  controller: newPasswordController,
                  obscureText: !showNewPassword,
                  decoration: InputDecoration(
                    labelText: '새 비밀번호',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showNewPassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          showNewPassword = !showNewPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText: '6자 이상 입력하세요',
                  ),
                ),
                const SizedBox(height: 16),
                
                // 새 비밀번호 확인
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: !showConfirmPassword,
                  decoration: InputDecoration(
                    labelText: '새 비밀번호 확인',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          showConfirmPassword = !showConfirmPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '비밀번호는 영문, 숫자, 특수문자를 포함하여 6자 이상으로 설정하는 것을 권장합니다.',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isChanging ? null : () {
                Navigator.pop(context);
              },
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: isChanging ? null : () async {
                // 유효성 검사
                if (currentPasswordController.text.isEmpty) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('현재 비밀번호를 입력해주세요'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                if (newPasswordController.text.isEmpty) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('새 비밀번호를 입력해주세요'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                if (newPasswordController.text.length < 6) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('비밀번호는 6자 이상이어야 합니다'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                if (newPasswordController.text != confirmPasswordController.text) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('새 비밀번호가 일치하지 않습니다'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                setState(() {
                  isChanging = true;
                });
                
                final authProvider = context.read<AuthProvider>();
                final success = await authProvider.changePassword(
                  currentPassword: currentPasswordController.text,
                  newPassword: newPasswordController.text,
                  context: context,
                );
                
                if (context.mounted) {
                  if (success) {
                    Navigator.pop(context);
                  } else {
                    setState(() {
                      isChanging = false;
                    });
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
              child: isChanging
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('변경'),
            ),
          ],
        ),
      );
      },
    ).then((_) {
      // Dialog가 닫힌 후 자동으로 controller들이 dispose됩니다
    });
  }

  void _showRoleChangeDialog(BuildContext context, User user) {
    String selectedRole = user.role;
    bool isChanging = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.swap_horiz, color: Colors.blue.shade600, size: 24),
              ),
              const SizedBox(width: 12),
              const Text('역할 변경', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: Row(
                        children: [
                          Icon(Icons.favorite, color: Colors.pink.shade600, size: 20),
                          const SizedBox(width: 8),
                          const Text('요양보호사'),
                        ],
                      ),
                      subtitle: const Text('요양 서비스 제공 직원'),
                      value: 'CAREGIVER',
                      groupValue: selectedRole,
                      onChanged: isChanging ? null : (value) {
                        setState(() {
                          selectedRole = value!;
                        });
                      },
                    ),
                    const Divider(),
                    RadioListTile<String>(
                      title: Row(
                        children: [
                          Icon(Icons.business, color: Colors.indigo.shade600, size: 20),
                          const SizedBox(width: 8),
                          const Text('사무직'),
                        ],
                      ),
                      subtitle: const Text('사무실 근무 직원'),
                      value: 'OFFICE',
                      groupValue: selectedRole,
                      onChanged: isChanging ? null : (value) {
                        setState(() {
                          selectedRole = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (selectedRole != user.role)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '역할 변경 시 권한이 변경됩니다.',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isChanging ? null : () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: (isChanging || selectedRole == user.role) ? null : () async {
                setState(() {
                  isChanging = true;
                });

                final authProvider = context.read<AuthProvider>();
                final success = await authProvider.updateMemberRole(selectedRole);

                if (success && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('역할이 성공적으로 변경되었습니다.'),
                      backgroundColor: Colors.green.shade600,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                } else if (context.mounted) {
                  setState(() {
                    isChanging = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        authProvider.errorMessage.isNotEmpty
                            ? authProvider.errorMessage
                            : '역할 변경에 실패했습니다',
                      ),
                      backgroundColor: Colors.red.shade600,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
              child: isChanging
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('변경'),
            ),
          ],
        ),
      ),
    );
  }

  void _showWithdrawalDialog(BuildContext context) {
    bool isWithdrawing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_remove,
                  color: Colors.red.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text('회원탈퇴', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ 주의사항',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 계정이 영구적으로 삭제됩니다\n• 모든 휴무 신청 내역이 삭제됩니다\n• 삭제된 데이터는 복구할 수 없습니다\n• 재가입을 원하시면 새로 신청해야 합니다',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '정말로 회원탈퇴를 진행하시겠습니까?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isWithdrawing ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: isWithdrawing
                  ? null
                  : () async {
                      setState(() {
                        isWithdrawing = true;
                      });

                      final authProvider = context.read<AuthProvider>();
                      final success = await authProvider.withdrawMember();

                      if (success && context.mounted) {
                        Navigator.pop(context);

                        // 성공 메시지 표시
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            content: Container(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.green.shade400,
                                          Colors.green.shade600,
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    '회원탈퇴 완료',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '그동안 이용해주셔서 감사했습니다.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(
                                          context,
                                        ).pushAndRemoveUntil(
                                          MaterialPageRoute(
                                            builder: (_) => const LoginScreen(),
                                          ),
                                          (route) => false,
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade600,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        '확인',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      } else if (context.mounted) {
                        setState(() {
                          isWithdrawing = false;
                        });

                        // 에러 메시지 표시
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              authProvider.errorMessage.isNotEmpty
                                  ? authProvider.errorMessage
                                  : '회원탈퇴에 실패했습니다',
                            ),
                            backgroundColor: Colors.red.shade600,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: isWithdrawing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('탈퇴하기'),
            ),
          ],
        ),
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
      backgroundColor: const Color(0xFFEFF6FF), // blue.50 - 파란계열 배경
      body: CustomScrollView(
        slivers: [
          // 파란계열 그라데이션 앱바
          SliverAppBar(
            expandedHeight: 64.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            centerTitle: true,
            title: const Text(
              '프로필',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: 20,
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2563EB), // blue.600
                    Color(0xFF3B82F6), // blue.500
                    Color(0xFF60A5FA), // blue.400
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

                                    // 직원 유형 (클릭 가능)
                                    InkWell(
                                      onTap: () => _showRoleChangeDialog(context, user),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: _buildInfoRow(
                                                icon: user.role == 'CAREGIVER'
                                                    ? Icons.favorite
                                                    : Icons.business,
                                                iconColor: user.role == 'CAREGIVER'
                                                    ? Colors.pink.shade600
                                                    : Colors.indigo.shade600,
                                                title: '직원 유형',
                                                value: _getRoleDisplayName(user.role),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.edit,
                                                size: 16,
                                                color: Colors.blue.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
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
                                            iconColor: AppSemanticColors.interactiveSecondaryDefault,
                                            title: '직책',
                                            value: user.position!,
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      ),

                                    // 구독 정보는 관리자에게만 표시 (직원에게는 표시하지 않음)
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
                            icon: Icons.lock,
                            title: '비밀번호 변경',
                            subtitle: '계정 보안을 위해 주기적으로 변경하세요',
                            trailing: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.chevron_right,
                                color: Colors.green.shade600,
                                size: 20,
                              ),
                            ),
                            onTap: () => _showPasswordChangeDialog(context),
                          ),

                          const Divider(height: 1, color: Colors.transparent),

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
                                  // 기존 상태로 되돌리기
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('알림 설정 기능은 준비 중입니다'),
                                      backgroundColor: Colors.orange.shade600,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('알림 설정 기능은 준비 중입니다'),
                                  backgroundColor: Colors.orange.shade600,
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
                                  content: const Text('도움말 기능은 준비 중입니다'),
                                  backgroundColor: Colors.orange.shade600,
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
                                color: AppSemanticColors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.chevron_right,
                                color: AppSemanticColors.interactiveSecondaryDefault,
                                size: 20,
                              ),
                            ),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('앱 정보 기능은 준비 중입니다'),
                                  backgroundColor: Colors.orange.shade600,
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
                            icon: Icons.person_remove,
                            title: '회원탈퇴',
                            subtitle: '계정을 영구적으로 삭제합니다',
                            trailing: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.chevron_right,
                                color: Colors.red.shade600,
                                size: 20,
                              ),
                            ),
                            onTap: () => _showWithdrawalDialog(context),
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 약관 및 정책 섹션
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
                            colors: [Colors.white, Colors.grey.shade50],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // 섹션 헤더
                            Container(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.grey.shade100,
                                          Colors.grey.shade200,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.gavel,
                                      color: Colors.grey.shade700,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '약관 및 정책',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 약관 링크들
                            _buildPolicyTile(
                              icon: Icons.privacy_tip,
                              title: '개인정보 처리방침',
                              subtitle: '개인정보 수집 및 이용에 대한 정책',
                              iconColor: Colors.blue.shade600,
                              onTap: () => _launchURL(
                                'https://plip.kr/pcc/d9017bf3-00dc-4f8f-b750-f7668e2b7bb7/privacy/1.html',
                              ),
                              isFirst: true,
                            ),

                            Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              color: Colors.grey.shade200,
                            ),

                            _buildPolicyTile(
                              icon: Icons.description,
                              title: '서비스 이용약관',
                              subtitle: '서비스 이용에 대한 약관 및 조건',
                              iconColor: Colors.green.shade600,
                              onTap: () => _launchURL(
                                'https://relic-baboon-412.notion.site/silverithm-13c766a8bb468082b91ddbd2dd6ce45d',
                              ),
                              isLast: true,
                            ),
                          ],
                        ),
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
        return AppSemanticColors.interactiveSecondaryDefault;
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

  Widget _buildPolicyTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade100, Colors.blue.shade100],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
      onTap: onTap,
    );
  }

  Widget _buildSubscriptionInfo(SubscriptionProvider subscriptionProvider) {
    // 구독 정보가 로드되지 않은 경우 로딩 중 표시
    if (subscriptionProvider.isLoading) {
      return _buildInfoRow(
        icon: Icons.workspace_premium,
        iconColor: Colors.grey.shade400,
        title: '구독 정보',
        value: '로딩 중...',
      );
    }

    // 구독이 없는 경우
    if (subscriptionProvider.subscription == null) {
      return InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const SubscriptionCheckScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.workspace_premium,
                  color: Colors.orange.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '구독 정보',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '구독이 필요합니다 (탭하여 구독하기)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.orange.shade600,
                size: 20,
              ),
            ],
          ),
        ),
      );
    }

    // 구독이 있는 경우
    final subscription = subscriptionProvider.subscription!;
    final statusColor = subscription.isActive 
        ? Colors.green.shade600 
        : subscription.isExpired 
            ? Colors.red.shade600 
            : Colors.orange.shade600;
    
    final statusIcon = subscription.isActive 
        ? Icons.check_circle 
        : subscription.isExpired 
            ? Icons.error 
            : Icons.warning;

    return InkWell(
      onTap: () {
        _showSubscriptionDetails(subscription);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                statusIcon,
                color: statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '구독 정보',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        subscription.planDisplayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          subscription.statusDisplayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showSubscriptionDetails(subscription) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.workspace_premium,
              color: subscription.isActive 
                  ? Colors.green.shade600 
                  : Colors.orange.shade600,
            ),
            const SizedBox(width: 8),
            const Text('구독 정보'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('플랜', subscription.planDisplayName),
            const SizedBox(height: 12),
            _buildDetailRow('상태', subscription.statusDisplayName),
            const SizedBox(height: 12),
            if (subscription.endDate != null) ...{
              _buildDetailRow(
                '만료일', 
                _formatDate(subscription.endDate!),
              ),
              const SizedBox(height: 12),
              if (subscription.isActive)
                _buildDetailRow(
                  '남은 일수', 
                  '${subscription.daysRemaining}일',
                ),
            },
            if (subscription.startDate != null) ...{
              const SizedBox(height: 12),
              _buildDetailRow(
                '시작일', 
                _formatDate(subscription.startDate!),
              ),
            },
          ],
        ),
        actions: [
          if (!subscription.isActive)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SubscriptionCheckScreen(),
                  ),
                );
              },
              child: const Text('구독 갱신'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            '$label:',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
