import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/app_version_provider.dart';
import '../providers/subscription_provider.dart';
import '../models/user.dart';
import '../services/analytics_service.dart';
import '../services/api_service.dart';
import '../services/in_app_review_service.dart';
import '../utils/admin_utils.dart';
import '../utils/role_utils.dart';
import 'admin_company_settings_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';
import '../widgets/common/index.dart';
import '../widgets/seed/seed_button.dart';
import 'login_screen.dart';
import 'subscription_check_screen.dart';
import 'signature_manage_screen.dart';

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
  bool _isUploadingPhoto = false;

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
          AppSnackBar.showError(context, message: '링크를 열 수 없습니다: $url');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: '링크 열기 중 오류가 발생했습니다');
      }
    }
  }

  void _showLogoutDialog(BuildContext context) {
    AppDialog.showConfirm(
      context,
      title: '로그아웃',
      message: '정말 로그아웃하시겠습니까?',
      confirmText: '로그아웃',
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

  Future<void> _copyCompanyCode(String companyCode) async {
    await Clipboard.setData(ClipboardData(text: companyCode));

    if (!mounted) return;

    // 복사 완료는 단순 안내이지 성공 알림이 아니다 — 빨강/초록 금지
    AppSnackBar.showInfo(context, message: '회사 코드가 복사되었습니다');
  }

  /// 프로필 사진 업로드/삭제는 Member(직원) 계정만 가능하다 — 백엔드
  /// MemberController.uploadProfileImage가 members 테이블 id로 조회하는데,
  /// 기관 대표 로그인(AppUser, 회사 코드 보유)은 대응하는 Member 행이 없다.
  bool _canEditProfileImage(User user) {
    final isCompanyOwnerLogin = AdminUtils.canAccessAdminPages(user) &&
        (user.company?.companyCode?.isNotEmpty ?? false);
    return !isCompanyOwnerLogin;
  }

  User _withProfileImageUrl(User user, String? url) {
    return User(
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      profileImage: user.profileImage,
      profileImageUrl: url,
      createdAt: user.createdAt,
      isActive: user.isActive,
      username: user.username,
      status: user.status,
      department: user.department,
      position: user.position,
      company: user.company,
      lastLoginAt: user.lastLoginAt,
      tokenInfo: user.tokenInfo,
    );
  }

  void _showProfileImageOptions(BuildContext context, User user) {
    final hasImage = (user.profileImageUrl ?? '').isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppSemanticColors.surfaceDefault,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppBorderRadius.xl2)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.space4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.space2),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.statusInfoBackground,
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    ),
                    child: Icon(
                      Icons.photo_library_outlined,
                      color: AppSemanticColors.statusInfoIcon,
                    ),
                  ),
                  title: Text(
                    '앨범에서 선택',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppSemanticColors.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAndUploadProfileImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.space2),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.statusSuccessBackground,
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    ),
                    child: Icon(
                      Icons.photo_camera_outlined,
                      color: AppSemanticColors.statusSuccessIcon,
                    ),
                  ),
                  title: Text(
                    '사진 촬영',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppSemanticColors.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAndUploadProfileImage(ImageSource.camera);
                  },
                ),
                if (hasImage)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(AppSpacing.space2),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.statusErrorBackground,
                        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        color: AppSemanticColors.statusErrorIcon,
                      ),
                    ),
                    title: Text(
                      '사진 삭제',
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppSemanticColors.statusErrorText,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _confirmDeleteProfileImage();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadProfileImage(ImageSource source) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || _isUploadingPhoto) return;

    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 85,
      );
      if (picked == null) return;

      final extension = picked.path.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        if (mounted) {
          AppSnackBar.showError(
            context,
            message: '허용되지 않는 파일 형식입니다. (jpg, png, webp만 가능)',
          );
        }
        return;
      }

      final size = await File(picked.path).length();
      if (size > 5 * 1024 * 1024) {
        if (mounted) {
          AppSnackBar.showError(context, message: '파일 크기는 5MB를 초과할 수 없습니다');
        }
        return;
      }

      setState(() => _isUploadingPhoto = true);

      final response = await ApiService().uploadMemberProfileImage(
        memberId: user.id,
        filePath: picked.path,
      );

      final newUrl = response['profileImageUrl']?.toString();
      if (mounted) {
        context
            .read<AuthProvider>()
            .updateUser(_withProfileImageUrl(user, newUrl));
        AppSnackBar.showSuccess(context, message: '프로필 사진이 업로드되었습니다');
      }
    } catch (e) {
      if (mounted) {
        final message = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('ApiException: ', '');
        AppSnackBar.showError(
          context,
          message: message.isNotEmpty ? message : '프로필 사진 업로드에 실패했습니다',
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _confirmDeleteProfileImage() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || _isUploadingPhoto) return;

    final confirmed = await AppDialog.showConfirm(
      context,
      title: '프로필 사진 삭제',
      message: '프로필 사진을 삭제하시겠습니까?',
      confirmText: '삭제',
      confirmVariant: SeedButtonVariant.critical,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isUploadingPhoto = true);
    try {
      await ApiService().deleteMemberProfileImage(memberId: user.id);
      if (mounted) {
        context
            .read<AuthProvider>()
            .updateUser(_withProfileImageUrl(user, null));
        AppSnackBar.showSuccess(context, message: '프로필 사진이 삭제되었습니다');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: '프로필 사진 삭제에 실패했습니다');
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showPasswordChangeDialog(BuildContext dialogContext) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isChanging = false;

    AppDialog.showCustom<void>(
      dialogContext,
      barrierColor: AppColors.black.withValues(alpha: 0.5),
      child: StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(AppSpacing.space6),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                const SizedBox(height: AppSpacing.space4),
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
                const SizedBox(height: AppSpacing.space6),
                Row(
                  children: [
                    Expanded(
                      child: SeedButton(
                        label: '취소',
                        variant: SeedButtonVariant.neutralOutline,
                        isDisabled: isChanging,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space3),
                    Expanded(
                      child: SeedButton(
                        label: '변경',
                        variant: SeedButtonVariant.brandSolid,
                        isLoading: isChanging,
                        isDisabled: isChanging,
                        onPressed: () async {
                          if (currentPasswordController.text.isEmpty) {
                            if (!context.mounted) return;
                            AppSnackBar.showError(
                              context,
                              message: '현재 비밀번호를 입력해주세요',
                            );
                            return;
                          }

                          if (newPasswordController.text.isEmpty) {
                            if (!context.mounted) return;
                            AppSnackBar.showError(
                              context,
                              message: '새 비밀번호를 입력해주세요',
                            );
                            return;
                          }

                          if (newPasswordController.text.length < 6) {
                            if (!context.mounted) return;
                            AppSnackBar.showError(
                              context,
                              message: '비밀번호는 6자 이상이어야 합니다',
                            );
                            return;
                          }

                          if (newPasswordController.text !=
                              confirmPasswordController.text) {
                            if (!context.mounted) return;
                            AppSnackBar.showError(
                              context,
                              message: '새 비밀번호가 일치하지 않습니다',
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
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      // Dialog가 닫힌 후 자동으로 controller들이 dispose됩니다
    });
  }

  void _showRoleChangeDialog(BuildContext context, User user) {
    String selectedRole = user.role;
    bool isChanging = false;

    AppDialog.showCustom<void>(
      context,
      barrierColor: AppColors.black.withValues(alpha: 0.5),
      child: StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(AppSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.space2),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.backgroundTertiary,
                      borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                    ),
                    child: const Icon(
                      Icons.swap_horiz,
                      color: AppSemanticColors.textSecondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Text(
                    '역할 변경',
                    style: AppTypography.heading5.copyWith(
                      color: AppSemanticColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space4),
              Container(
                padding: const EdgeInsets.all(AppSpacing.space4),
                decoration: BoxDecoration(
                  color: AppSemanticColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                ),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: Row(
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: AppSemanticColors.statusErrorIcon,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.space2),
                          Text(
                            '요양보호사',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppSemanticColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        '요양 서비스 제공 직원',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppSemanticColors.textSecondary,
                        ),
                      ),
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
                          const Icon(
                            Icons.business,
                            color: AppSemanticColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.space2),
                          Text(
                            '사무직',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppSemanticColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        '사무실 근무 직원',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppSemanticColors.textSecondary,
                        ),
                      ),
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
              const SizedBox(height: AppSpacing.space4),
              if (selectedRole != user.role)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space3),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.statusWarningBackground,
                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    border: Border.all(color: AppSemanticColors.statusWarningBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppSemanticColors.statusWarningIcon,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.space2),
                      Expanded(
                        child: Text(
                          '역할 변경 시 권한이 변경됩니다.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppSemanticColors.statusWarningText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.space6),
              Row(
                children: [
                  Expanded(
                    child: SeedButton(
                      label: '취소',
                      variant: SeedButtonVariant.neutralOutline,
                      isDisabled: isChanging,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: SeedButton(
                      label: '변경',
                      variant: SeedButtonVariant.brandSolid,
                      isLoading: isChanging,
                      isDisabled: isChanging || selectedRole == user.role,
                      onPressed: () async {
                        setState(() {
                          isChanging = true;
                        });

                        final authProvider = context.read<AuthProvider>();
                        final success = await authProvider.updateMemberRole(
                          selectedRole,
                        );

                        if (success && context.mounted) {
                          Navigator.pop(context);
                          AppSnackBar.showSuccess(
                            context,
                            message: '역할이 성공적으로 변경되었습니다.',
                          );
                        } else if (context.mounted) {
                          setState(() {
                            isChanging = false;
                          });
                          AppSnackBar.showError(
                            context,
                            message: authProvider.errorMessage.isNotEmpty
                                ? authProvider.errorMessage
                                : '역할 변경에 실패했습니다',
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWithdrawalDialog(BuildContext context) {
    bool isWithdrawing = false;

    AppDialog.showCustom<void>(
      context,
      barrierDismissible: false,
      barrierColor: AppColors.black.withValues(alpha: 0.5),
      child: StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(AppSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
              const SizedBox(height: AppSpacing.space4),
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
              const SizedBox(height: AppSpacing.space6),
              Row(
                children: [
                  Expanded(
                    child: SeedButton(
                      label: '취소',
                      variant: SeedButtonVariant.neutralOutline,
                      isDisabled: isWithdrawing,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: SeedButton(
                      label: '탈퇴하기',
                      variant: SeedButtonVariant.critical,
                      isLoading: isWithdrawing,
                      isDisabled: isWithdrawing,
                      onPressed: () async {
                        setState(() {
                          isWithdrawing = true;
                        });

                        final authProvider = context.read<AuthProvider>();
                        final success = await authProvider.withdrawMember();

                        if (success && context.mounted) {
                          Navigator.pop(context);

                          // 성공 메시지 표시
                          AppDialog.showCustom<void>(
                            context,
                            barrierDismissible: false,
                            child: Container(
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
                                  SizedBox(
                                    width: double.infinity,
                                    child: SeedButton(
                                      label: '확인',
                                      variant: SeedButtonVariant.brandSolid,
                                      onPressed: () {
                                        Navigator.of(
                                          context,
                                        ).pushAndRemoveUntil(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const LoginScreen(),
                                          ),
                                          (route) => false,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        } else if (context.mounted) {
                          setState(() {
                            isWithdrawing = false;
                          });

                          // 에러 메시지 표시
                          AppSnackBar.showError(
                            context,
                            message: authProvider.errorMessage.isNotEmpty
                                ? authProvider.errorMessage
                                : '회원탈퇴에 실패했습니다',
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
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
          // 슬림 상단 — 타이틀 1개만 (다른 화면과 동일한 흰 배경 AppBar)
          SliverAppBar(
            expandedHeight: 56.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: AppSemanticColors.backgroundPrimary,
            title: Text('프로필', style: AppTypography.heading5),
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
                        padding: const EdgeInsets.all(AppSpacing.space4),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppSemanticColors.surfaceDefault,
                            borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
                            border: Border.all(
                              color: AppSemanticColors.borderDefault,
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(AppSpacing.space6),
                          child: Column(
                            children: [
                              // 프로필 이미지 — 우측 하단 카메라 버튼으로 업로드/삭제
                              // (Member 계정만; AppUser 대표 로그인은 대응 회원 행이 없어 비활성)
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
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
                                      child: (user.profileImageUrl ?? '').isNotEmpty
                                          ? ClipOval(
                                              child: Image.network(
                                                user.profileImageUrl!,
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
                                  if (_isUploadingPhoto)
                                    Positioned.fill(
                                      child: ClipOval(
                                        child: Container(
                                          color: AppColors.black.withValues(alpha: 0.4),
                                          alignment: Alignment.center,
                                          child: const SizedBox(
                                            width: 28,
                                            height: 28,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                AppColors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (_canEditProfileImage(user))
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: GestureDetector(
                                        onTap: _isUploadingPhoto
                                            ? null
                                            : () =>
                                                _showProfileImageOptions(context, user),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppSemanticColors.brandDefault,
                                            border: Border.all(
                                              color: AppSemanticColors.surfaceDefault,
                                              width: 2,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.photo_camera,
                                            size: 18,
                                            color: AppSemanticColors.textInverse,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: AppSpacing.space6),
                              Divider(
                                height: 1,
                                color: AppSemanticColors.borderSubtle,
                              ),
                              const SizedBox(height: AppSpacing.space6),

                              // 사용자 정보 섹션 — 카드 안에 또 카드를 두지 않는다 (구분선만)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text(
                                      '기본 정보',
                                      style: AppTypography.heading6.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppSemanticColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.space5),

                                    // 이름
                                    _buildInfoRow(
                                      icon: Icons.person,
                                      iconColor: AppSemanticColors.statusInfoIcon,
                                      title: '이름',
                                      value: user.name,
                                    ),
                                    const SizedBox(height: AppSpacing.space4),

                                    // 이메일
                                    _buildInfoRow(
                                      icon: Icons.email,
                                      iconColor: AppSemanticColors.statusSuccessIcon,
                                      title: '이메일',
                                      value: user.email,
                                    ),
                                    const SizedBox(height: AppSpacing.space4),

                                    // 직원 유형 (클릭 가능)
                                    InkWell(
                                      onTap: () => _showRoleChangeDialog(context, user),
                                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space1),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: _buildInfoRow(
                                                icon: _getRoleIcon(
                                                  _effectiveRole(user),
                                                ),
                                                iconColor: _getRoleColor(
                                                  _effectiveRole(user),
                                                ),
                                                title: '직원 유형',
                                                value: _getRoleDisplayName(
                                                  _effectiveRole(user),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.all(AppSpacing.space1),
                                              decoration: BoxDecoration(
                                                color: AppSemanticColors.backgroundTertiary,
                                                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
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
                                    const SizedBox(height: AppSpacing.space4),

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
                                          const SizedBox(height: AppSpacing.space4),
                                        ],
                                      ),

                                    // 직책 (있는 경우)
                                    if (user.position != null &&
                                        user.position!.isNotEmpty)
                                      Column(
                                        children: [
                                          _buildInfoRow(
                                            icon: Icons.work,
                                            iconColor: AppSemanticColors.textSecondary,
                                            title: '직책',
                                            value: user.position!,
                                          ),
                                          const SizedBox(height: AppSpacing.space4),
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
                                          const SizedBox(height: AppSpacing.space4),
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
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.space2),

                  if (AdminUtils.canAccessAdminPages(user) &&
                      (user.company?.companyCode?.isNotEmpty ?? false))
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppSemanticColors.surfaceDefault,
                            borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
                            border: Border.all(
                              color: AppSemanticColors.borderDefault,
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(AppSpacing.space5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.space3),
                                    decoration: BoxDecoration(
                                      color: AppSemanticColors.statusWarningBackground,
                                      borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
                                    ),
                                    child: const Icon(
                                      Icons.key,
                                      color: AppSemanticColors.statusWarningIcon,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.space3),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '회사 코드',
                                          style: AppTypography.heading6.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppSemanticColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          '직원 가입 신청용 코드입니다',
                                          style: AppTypography.bodySmall.copyWith(
                                            color: AppSemanticColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.space4),
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.space4),
                                decoration: BoxDecoration(
                                  color: AppSemanticColors.backgroundSecondary,
                                  borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: SelectableText(
                                        user.company!.companyCode!,
                                        style: AppTypography.heading5.copyWith(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 2,
                                          color: AppSemanticColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _copyCompanyCode(
                                        user.company!.companyCode!,
                                      ),
                                      icon: const Icon(Icons.copy, size: 18),
                                      label: const Text('복사'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.space2_5),
                              Text(
                                '직원은 회원가입 화면에서 이 코드를 입력해 기존 회사 선택과 같은 방식으로 가입 요청을 보낼 수 있습니다.',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppSemanticColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if (AdminUtils.canAccessAdminPages(user) &&
                      (user.company?.companyCode?.isNotEmpty ?? false))
                    const SizedBox(height: AppSpacing.space2),

                  // 설정 섹션
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppSemanticColors.surfaceDefault,
                          borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
                          border: Border.all(
                            color: AppSemanticColors.borderDefault,
                            width: 1,
                          ),
                        ),
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
                                padding: const EdgeInsets.all(AppSpacing.space2),
                                decoration: BoxDecoration(
                                  color: AppSemanticColors.backgroundSecondary,
                                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                                ),
                                child: Icon(
                                  Icons.chevron_right,
                                  color: AppSemanticColors.textTertiary,
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
                            icon: Icons.draw,
                            title: '결재 서명 관리',
                            subtitle: '서명을 등록하면 결재 승인 시 자동으로 날인됩니다',
                            trailing: Container(
                              padding: const EdgeInsets.all(AppSpacing.space2),
                              decoration: BoxDecoration(
                                color: AppSemanticColors.backgroundTertiary,
                                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                              ),
                              child: Icon(
                                Icons.chevron_right,
                                color: AppSemanticColors.textSecondary,
                                size: 20,
                              ),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SignatureManageScreen(),
                                ),
                              );
                            },
                          ),

                          const Divider(height: 1, color: AppColors.transparent),

                          _buildSettingTile(
                            icon: Icons.lock,
                            title: '비밀번호 변경',
                            subtitle: '계정 보안을 위해 주기적으로 변경하세요',
                            trailing: Container(
                              padding: const EdgeInsets.all(AppSpacing.space2),
                              decoration: BoxDecoration(
                                color: AppSemanticColors.backgroundTertiary,
                                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
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
                            icon: Icons.star_rate,
                            title: '앱 평가하기',
                            subtitle: '평점과 리뷰를 남겨주세요',
                            trailing: Container(
                              padding: const EdgeInsets.all(AppSpacing.space2),
                              decoration: BoxDecoration(
                                color: AppSemanticColors.backgroundTertiary,
                                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
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
                                // 단순 이동 안내이지 성공 알림이 아니다
                                AppSnackBar.showInfo(
                                  context,
                                  message: '앱 평가 페이지로 이동합니다',
                                  duration: const Duration(seconds: 2),
                                );
                              }
                            },
                          ),

                          

                          

                          const Divider(height: 1, color: AppColors.transparent),

                          _buildSettingTile(
                            icon: Icons.person_remove,
                            title: '회원탈퇴',
                            subtitle: '계정을 영구적으로 삭제합니다',
                            trailing: Container(
                              padding: const EdgeInsets.all(AppSpacing.space2),
                              decoration: BoxDecoration(
                                color: AppSemanticColors.backgroundTertiary,
                                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
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

                  const SizedBox(height: AppSpacing.space6),

                  // 약관 및 정책 섹션
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.space4),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppSemanticColors.surfaceDefault,
                            borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
                            border: Border.all(
                              color: AppSemanticColors.borderDefault,
                              width: 1,
                            ),
                          ),
                          padding: EdgeInsets.zero,
                          child: Column(
                          children: [
                            // 섹션 헤더
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.space5),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.space3),
                                    decoration: BoxDecoration(
                                      color: AppSemanticColors.backgroundTertiary,
                                      borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
                                    ),
                                    child: Icon(
                                      Icons.gavel,
                                      color: AppSemanticColors.textSecondary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.space3),
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
                                horizontal: AppSpacing.space5,
                              ),
                              color: AppSemanticColors.borderSubtle,
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

                  const SizedBox(height: AppSpacing.space6),

                  // 로그아웃 버튼
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
                      child: SizedBox(
                        width: double.infinity,
                        child: SeedButton(
                          label: '로그아웃',
                          variant: SeedButtonVariant.neutralOutline,
                          size: SeedButtonSize.large,
                          prefixIcon: Icons.logout,
                          onPressed: () => _showLogoutDialog(context),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.space6),

                  // 앱 버전 정보
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Center(
                      child: Text(
                        // 실제 앱 버전 표시 (하드코딩 금지)
                        'Version ${context.watch<AppVersionProvider>().currentVersion.isEmpty ? '-' : context.watch<AppVersionProvider>().currentVersion}',
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
          top: isFirst ? const Radius.circular(AppBorderRadius.xl2) : Radius.zero,
          bottom: isLast ? const Radius.circular(AppBorderRadius.xl2) : Radius.zero,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space5,
          vertical: AppSpacing.space2,
        ),
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.space3),
          decoration: BoxDecoration(
            color: AppSemanticColors.backgroundTertiary,
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
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
        const SizedBox(width: AppSpacing.space2),
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
        const SizedBox(width: AppSpacing.space2),
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

  /// 배정된 역할이 있으면 그것을, 없으면 기존 분류를 쓴다
  String _effectiveRole(User user) {
    return user.position?.isNotEmpty == true ? user.position! : user.role;
  }

  Color _getRoleColor(String role) {
    switch (RoleUtils.normalize(role)) {
      case 'caregiver':
        return AppSemanticColors.statusErrorIcon;
      case 'office':
        return AppSemanticColors.textSecondary;
      case 'admin':
        return AppSemanticColors.textSecondary;
      default:
        return AppSemanticColors.textTertiary;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (RoleUtils.normalize(role)) {
      case 'caregiver':
        return Icons.favorite;
      case 'office':
        return Icons.business;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.badge_outlined;
    }
  }

  String _getRoleDisplayName(String role) {
    return RoleUtils.displayName(role);
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
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space5,
          vertical: AppSpacing.space2,
        ),
      leading: Container(
        padding: const EdgeInsets.all(AppSpacing.space3),
        decoration: BoxDecoration(
          color: AppSemanticColors.backgroundTertiary,
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
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
        iconColor: AppSemanticColors.textTertiary,
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
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space1),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppSemanticColors.backgroundTertiary,
                  borderRadius: BorderRadius.circular(AppBorderRadius.full),
                ),
                child: Icon(
                  Icons.workspace_premium,
                  color: AppSemanticColors.statusWarningIcon,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.space4),
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
                    const SizedBox(height: AppSpacing.space0_5),
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
      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space1),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(AppBorderRadius.full),
              ),
              child: Icon(
                statusIcon,
                color: statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.space4),
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
                  const SizedBox(height: AppSpacing.space0_5),
                  Row(
                    children: [
                      Text(
                        subscription.planDisplayName,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppSemanticColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space1_5,
                          vertical: AppSpacing.space0_5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
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
              color: AppSemanticColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showSubscriptionDetails(subscription) {
    AppDialog.showCustom<void>(
      context,
      barrierColor: AppColors.black.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.workspace_premium,
                  color: subscription.isActive
                      ? AppSemanticColors.statusSuccessIcon
                      : AppSemanticColors.statusWarningIcon,
                ),
                const SizedBox(width: AppSpacing.space2),
                Text(
                  '구독 정보',
                  style: AppTypography.heading5.copyWith(
                    color: AppSemanticColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space4),
            _buildDetailRow('플랜', subscription.planDisplayName),
            const SizedBox(height: AppSpacing.space3),
            _buildDetailRow('상태', subscription.statusDisplayName),
            const SizedBox(height: AppSpacing.space3),
            if (subscription.endDate != null) ...{
              _buildDetailRow(
                '만료일',
                _formatDate(subscription.endDate!),
              ),
              const SizedBox(height: AppSpacing.space3),
              if (subscription.isActive)
                _buildDetailRow(
                  '남은 일수',
                  '${subscription.daysRemaining}일',
                ),
            },
            if (subscription.startDate != null) ...{
              const SizedBox(height: AppSpacing.space3),
              _buildDetailRow(
                '시작일',
                _formatDate(subscription.startDate!),
              ),
            },
            const SizedBox(height: AppSpacing.space6),
            Row(
              children: [
                if (!subscription.isActive) ...[
                  Expanded(
                    child: SeedButton(
                      label: '구독 갱신',
                      variant: SeedButtonVariant.brandSolid,
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SubscriptionCheckScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                ],
                Expanded(
                  child: SeedButton(
                    label: '확인',
                    variant: SeedButtonVariant.neutralOutline,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ],
        ),
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
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
