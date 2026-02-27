import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../models/user.dart';
import '../services/analytics_service.dart';
import '../services/in_app_review_service.dart';
import '../utils/admin_utils.dart';
import 'admin_company_settings_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';
import '../widgets/common/index.dart';
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
      duration: AppTransitions.slowest,
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
              content: Text(
                '링크를 열 수 없습니다: $url',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppSemanticColors.textInverse,
                ),
              ),
              backgroundColor: AppSemanticColors.statusErrorIcon,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '링크 열기 중 오류가 발생했습니다',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppSemanticColors.textInverse,
                ),
              ),
              backgroundColor: AppSemanticColors.statusErrorIcon,
            ),
          );
        }
    }
  }

  void _showLogoutDialog(BuildContext context) {
    AppDialog.showConfirm(
      context,
      title: '로그아웃',
      message: '정말 로그아웃하시겠습니까?',
      confirmText: '로그아웃',
      confirmVariant: AppButtonVariant.primary,
    ).then((confirmed) async {
      if (confirmed != true) return;

      final authProvider = context.read<AuthProvider>();
      await authProvider.logout();

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    });
  }

  void _showPasswordChangeDialog(BuildContext dialogContext) {
    showDialog(
      context: dialogContext,
      builder: (BuildContext context) {
        final currentPasswordController = TextEditingController();
        final newPasswordController = TextEditingController();
        final confirmPasswordController = TextEditingController();
        bool isChanging = false;

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space2),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.statusSuccessBackground,
                    borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  ),
                  child: const Icon(
                    Icons.lock,
                    color: AppSemanticColors.statusSuccessIcon,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.space3),
                Text(
                  '비밀번호 변경',
                  style: AppTypography.heading5.copyWith(
                    color: AppSemanticColors.textPrimary,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppPasswordInput(
                    label: '현재 비밀번호',
                    controller: currentPasswordController,
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  AppPasswordInput(
                    label: '새 비밀번호',
                    controller: newPasswordController,
                    helperText: '6자 이상 입력하세요',
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  AppPasswordInput(
                    label: '새 비밀번호 확인',
                    controller: confirmPasswordController,
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  AppStatusCard(
                    status: AppStatusType.info,
                    padding: const EdgeInsets.all(AppSpacing.space3),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppSemanticColors.statusInfoIcon,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.space2),
                        Expanded(
                          child: Text(
                            '비밀번호는 영문, 숫자, 특수문자를 포함하여 6자 이상으로 설정하는 것을 권장합니다.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppSemanticColors.textSecondary,
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
              AppButton(
                text: '취소',
                variant: AppButtonVariant.outline,
                onPressed: isChanging ? null : () => Navigator.pop(context),
              ),
              AppButton(
                text: '변경',
                isLoading: isChanging,
                onPressed: isChanging
                    ? null
                    : () async {
                        if (currentPasswordController.text.isEmpty) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '현재 비밀번호를 입력해주세요',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppSemanticColors.textInverse,
                                ),
                              ),
                              backgroundColor:
                                  AppSemanticColors.statusErrorIcon,
                            ),
                          );
                          return;
                        }

                        if (newPasswordController.text.isEmpty) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '새 비밀번호를 입력해주세요',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppSemanticColors.textInverse,
                                ),
                              ),
                              backgroundColor:
                                  AppSemanticColors.statusErrorIcon,
                            ),
                          );
                          return;
                        }

                        if (newPasswordController.text.length < 6) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '비밀번호는 6자 이상이어야 합니다',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppSemanticColors.textInverse,
                                ),
                              ),
                              backgroundColor:
                                  AppSemanticColors.statusErrorIcon,
                            ),
                          );
                          return;
                        }

                        if (newPasswordController.text !=
                            confirmPasswordController.text) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '새 비밀번호가 일치하지 않습니다',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppSemanticColors.textInverse,
                                ),
                              ),
                              backgroundColor:
                                  AppSemanticColors.statusErrorIcon,
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
                  color: AppSemanticColors.backgroundTertiary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.swap_horiz, color: AppSemanticColors.textSecondary, size: 24),
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
                  color: AppSemanticColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: Row(
                        children: [
                          Icon(Icons.favorite, color: AppSemanticColors.statusErrorIcon, size: 20),
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
                          Icon(Icons.business, color: AppSemanticColors.textSecondary, size: 20),
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
                    color: AppSemanticColors.statusWarningBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppSemanticColors.statusWarningBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppSemanticColors.statusWarningIcon, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '역할 변경 시 권한이 변경됩니다.',
                          style: TextStyle(
                            color: AppSemanticColors.statusWarningText,
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
            shadcn.OutlineButton(
              onPressed: isChanging ? null : () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            shadcn.PrimaryButton(
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
                      backgroundColor: AppSemanticColors.statusSuccessIcon,
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
                      backgroundColor: AppSemanticColors.statusErrorIcon,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              },
              child: isChanging
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
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
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.space2),
                decoration: BoxDecoration(
                  color: AppSemanticColors.statusErrorBackground,
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                ),
                child: Icon(
                  Icons.person_remove,
                  color: AppSemanticColors.statusErrorIcon,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              Text(
                '회원탈퇴',
                style: AppTypography.heading5.copyWith(
                  color: AppSemanticColors.textPrimary,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.space4),
                decoration: BoxDecoration(
                  color: AppSemanticColors.statusErrorBackground,
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  border: Border.all(
                    color: AppSemanticColors.statusErrorBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ 주의사항',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppSemanticColors.statusErrorText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    Text(
                      '• 계정이 영구적으로 삭제됩니다\n• 모든 휴무 신청 내역이 삭제됩니다\n• 삭제된 데이터는 복구할 수 없습니다\n• 재가입을 원하시면 새로 신청해야 합니다',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppSemanticColors.statusErrorText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
              Text(
                '정말로 회원탈퇴를 진행하시겠습니까?',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppSemanticColors.textPrimary,
                ),
              ),
            ],
          ),
          actions: [
            AppButton(
              text: '취소',
              variant: AppButtonVariant.outline,
              onPressed: isWithdrawing ? null : () => Navigator.pop(context),
            ),
            AppButton(
              text: '탈퇴하기',
              variant: AppButtonVariant.primary,
              isLoading: isWithdrawing,
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
                              borderRadius:
                                  BorderRadius.circular(AppBorderRadius.xl),
                            ),
                            content: Container(
                              padding: const EdgeInsets.all(AppSpacing.space6),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: AppSpacing.space14,
                                    height: AppSpacing.space14,
                                    decoration: BoxDecoration(
                                      color: AppSemanticColors
                                          .statusSuccessBackground,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: AppSemanticColors
                                          .statusSuccessIcon,
                                      size: 40,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.space5),
                                  Text(
                                    '회원탈퇴 완료',
                                    style: AppTypography.heading5.copyWith(
                                      color:
                                          AppSemanticColors.statusSuccessIcon,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.space3),
                                  Text(
                                    '그동안 이용해주셔서 감사했습니다.',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppSemanticColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.space5),
                                  AppButton(
                                    text: '확인',
                                    isFullWidth: true,
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
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppSemanticColors.textInverse,
                              ),
                            ),
                            backgroundColor: AppSemanticColors.statusErrorIcon,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppBorderRadius.xl),
                            ),
                          ),
                        );
                      }
                    },
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
      backgroundColor: AppSemanticColors.backgroundSecondary,
      body: CustomScrollView(
        slivers: [
          // 흰색 배경 앱바
          SliverAppBar(
            expandedHeight: 56.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: AppSemanticColors.backgroundPrimary,
            centerTitle: true,
            title: Text(
              '프로필',
              style: AppTypography.heading6.copyWith(
                color: AppSemanticColors.textPrimary,
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
                      padding: const EdgeInsets.all(AppSpacing.space5),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.surfaceDefault,
                        borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
                        border: Border.all(
                          color: AppSemanticColors.borderDefault,
                          width: 1,
                        ),
                      ),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppSemanticColors.interactivePrimaryDefault,
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
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: shadcn.Card(
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
                                    color: AppSemanticColors.backgroundTertiary,
                                    border: Border.all(
                                      color: AppSemanticColors.borderDefault,
                                      width: 2,
                                    ),
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
                                  color: AppSemanticColors.surfaceDefault,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppSemanticColors.borderDefault,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '기본 정보',
                                      style: AppTypography.heading6.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppSemanticColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // 이름
                                    _buildInfoRow(
                                      icon: Icons.person,
                                      iconColor: AppSemanticColors.statusInfoIcon,
                                      title: '이름',
                                      value: user.name,
                                    ),
                                    const SizedBox(height: 16),

                                    // 이메일
                                    _buildInfoRow(
                                      icon: Icons.email,
                                      iconColor: AppSemanticColors.statusSuccessIcon,
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
                                                    ? AppSemanticColors.statusErrorIcon
                                                    : AppSemanticColors.textSecondary,
                                                title: '직원 유형',
                                                value: _getRoleDisplayName(user.role),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: AppSemanticColors.backgroundTertiary,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.edit,
                                                size: 16,
                                                color: AppSemanticColors.textSecondary,
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
                                            iconColor: AppSemanticColors.statusWarningIcon,
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
                                      iconColor: AppSemanticColors.textSecondary,
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
                                            iconColor: AppSemanticColors.textSecondary,
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: shadcn.Card(
                        padding: EdgeInsets.zero,
                        child: Column(
                        children: [
                          // 관리자 회사 정보 메뉴
                          if (AdminUtils.canAccessAdminPages(user))
                            _buildSettingTile(
                              icon: Icons.business,
                              title: '회사 정보',
                              subtitle: '회사 정보 및 구독 관리',
                              trailing: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppSemanticColors.interactiveSecondaryDefault.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.chevron_right,
                                  color: AppSemanticColors.interactiveSecondaryDefault,
                                  size: 20,
                                ),
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const AdminCompanySettingsScreen(),
                                  ),
                                );
                              },
                            ),

                          if (AdminUtils.canAccessAdminPages(user))
                            const Divider(height: 1, color: AppColors.transparent),

                          _buildSettingTile(
                            icon: Icons.lock,
                            title: '비밀번호 변경',
                            subtitle: '계정 보안을 위해 주기적으로 변경하세요',
                            trailing: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppSemanticColors.backgroundTertiary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.chevron_right,
                                color: AppSemanticColors.textSecondary,
                                size: 20,
                              ),
                            ),
                            onTap: () => _showPasswordChangeDialog(context),
                          ),

                          const Divider(height: 1, color: AppColors.transparent),

                          _buildSettingTile(
                            icon: Icons.notifications,
                            title: '알림 설정',
                            subtitle: _notificationsEnabled
                                ? '푸시 알림이 활성화되어 있습니다'
                                : '푸시 알림이 비활성화되어 있습니다',
                            trailing: Switch(
                              value: _notificationsEnabled,
                              onChanged: (value) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('알림 설정 기능은 준비 중입니다'),
                                    backgroundColor: AppSemanticColors.statusWarningIcon,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              },
                              activeColor: AppSemanticColors.interactivePrimaryDefault,
                            ),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('알림 설정 기능은 준비 중입니다'),
                                  backgroundColor: AppSemanticColors.statusWarningIcon,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            },
                          ),

                          const Divider(height: 1, color: AppColors.transparent),
                          
                          _buildSettingTile(
                            icon: Icons.star_rate,
                            title: '앱 평가하기',
                            subtitle: '평점과 리뷰를 남겨주세요',
                            trailing: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppSemanticColors.backgroundTertiary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.chevron_right,
                                color: AppSemanticColors.textSecondary,
                                size: 20,
                              ),
                            ),
                            onTap: () async {
                              // Analytics 이벤트 로깅
                              AnalyticsService().logCustomEvent(
                                eventName: 'rate_app_clicked',
                                parameters: {'source': 'profile_screen'},
                              );
                              
                              // 리뷰 요청
                              await InAppReviewService().requestReviewManually();
                              
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('앱 평가 페이지로 이동합니다'),
                                    backgroundColor: AppSemanticColors.statusSuccessIcon,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),

                          const Divider(height: 1, color: AppColors.transparent),

                          _buildSettingTile(
                            icon: Icons.help,
                            title: '도움말',
                            subtitle: '자주 묻는 질문 및 지원',
                            trailing: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppSemanticColors.backgroundTertiary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.chevron_right,
                                color: AppSemanticColors.textSecondary,
                                size: 20,
                              ),
                            ),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('도움말 기능은 준비 중입니다'),
                                  backgroundColor: AppSemanticColors.statusWarningIcon,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            },
                          ),

                          const Divider(height: 1, color: AppColors.transparent),

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
                                  backgroundColor: AppSemanticColors.statusWarningIcon,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            },
                          ),

                          const Divider(height: 1, color: AppColors.transparent),

                          _buildSettingTile(
                            icon: Icons.person_remove,
                            title: '회원탈퇴',
                            subtitle: '계정을 영구적으로 삭제합니다',
                            trailing: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppSemanticColors.backgroundTertiary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.chevron_right,
                                color: AppSemanticColors.textSecondary,
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
                  ),

                  const SizedBox(height: 24),

                  // 약관 및 정책 섹션
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: shadcn.Card(
                          padding: EdgeInsets.zero,
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
                                      color: AppSemanticColors.backgroundTertiary,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.gavel,
                                      color: AppSemanticColors.textSecondary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '약관 및 정책',
                                    style: AppTypography.heading6.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppSemanticColors.textPrimary,
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
                              iconColor: AppSemanticColors.statusInfoIcon,
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
                              color: AppSemanticColors.borderDefault,
                            ),

                            _buildPolicyTile(
                              icon: Icons.description,
                              title: '서비스 이용약관',
                              subtitle: '서비스 이용에 대한 약관 및 조건',
                              iconColor: AppSemanticColors.statusSuccessIcon,
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
                  ),

                  const SizedBox(height: 24),

                  // 로그아웃 버튼
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: shadcn.DestructiveButton(
                          onPressed: () => _showLogoutDialog(context),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.logout, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '로그아웃',
                                style: AppTypography.labelLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
                      child: Text(
                        'Version 1.0.0',
                        style: AppTypography.caption.copyWith(
                          color: AppSemanticColors.textTertiary,
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
        color: AppSemanticColors.backgroundTertiary,
      ),
      child: Icon(Icons.person, size: 60, color: AppSemanticColors.textSecondary),
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
            color: AppSemanticColors.backgroundTertiary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppSemanticColors.textSecondary, size: 24),
        ),
        title: Text(
          title,
          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.bodySmall.copyWith(color: AppSemanticColors.textSecondary),
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
          width: 60,
          child: Text(
            title,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
              color: AppSemanticColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
              color: AppSemanticColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'CAREGIVER':
        return AppSemanticColors.statusErrorIcon;
      case 'OFFICE':
        return AppSemanticColors.textSecondary;
      case 'admin':
        return AppSemanticColors.textSecondary;
      default:
        return AppSemanticColors.textTertiary;
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
          color: AppSemanticColors.backgroundTertiary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppSemanticColors.textSecondary, size: 24),
      ),
      title: Text(
        title,
        style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.bodySmall.copyWith(color: AppSemanticColors.textSecondary),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: AppSemanticColors.textTertiary,
        size: 20,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSubscriptionInfo(SubscriptionProvider subscriptionProvider) {
    // 구독 정보가 로드되지 않은 경우 로딩 중 표시
    if (subscriptionProvider.isLoading) {
      return _buildInfoRow(
        icon: Icons.workspace_premium,
        iconColor: AppSemanticColors.textDisabled,
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
                  color: AppSemanticColors.backgroundTertiary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.workspace_premium,
                  color: AppSemanticColors.statusWarningIcon,
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
                        color: AppSemanticColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '구독이 필요합니다 (탭하여 구독하기)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppSemanticColors.statusWarningIcon,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppSemanticColors.statusWarningIcon,
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
        ? AppSemanticColors.statusSuccessIcon 
        : subscription.isExpired 
            ? AppSemanticColors.statusErrorIcon 
            : AppSemanticColors.statusWarningIcon;
    
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
                color: statusColor.withValues(alpha:0.1),
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
                      color: AppSemanticColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        subscription.planDisplayName,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppSemanticColors.textPrimary,
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
                            color: AppColors.white,
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
              color: AppSemanticColors.textDisabled,
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
                  ? AppSemanticColors.statusSuccessIcon 
                  : AppSemanticColors.statusWarningIcon,
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
            shadcn.PrimaryButton(
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
          shadcn.GhostButton(
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
              color: AppSemanticColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
