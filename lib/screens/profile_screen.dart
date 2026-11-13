import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/app_version_provider.dart';
import '../providers/subscription_provider.dart';
import '../models/position_option.dart';
import '../models/user.dart';
import '../services/analytics_service.dart';
import '../services/api_service.dart';
import '../services/in_app_review_service.dart';
import '../utils/admin_utils.dart';
import '../utils/role_utils.dart';
import 'admin_company_settings_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_lines.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/index.dart';
import '../widgets/common/app_action_sheet.dart';
import '../widgets/seed/seed_avatar.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_list_cell.dart';
import '../widgets/seed/seed_section_header.dart';
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

  /// 기관 대표(AppUser) 로그인인가.
  ///
  /// 이 계정은 members 행이 없어 `/members/{id}/profile-image`가 통하지 않는다. 그래서
  /// 앱에서는 관리자만 사진을 못 올렸고 채팅 인원 목록에 이니셜로만 떴다("관리자 프로필이
  /// 뜨게"). 관리자 웹이 쓰는 `/users/profile-image`로 보내면 같은 사진을 쓴다.
  bool _isCompanyOwnerLogin(User user) {
    return AdminUtils.canAccessAdminPages(user) &&
        (user.company?.companyCode?.isNotEmpty ?? false);
  }

  User _withProfileImageUrl(User user, String? url) {
    if (url == null) {
      return user.copyWith(clearProfileImageUrl: true);
    }
    return user.copyWith(profileImageUrl: url);
  }

  void _showProfileImageOptions(BuildContext context, User user) {
    final hasImage = (user.profileImageUrl ?? '').isNotEmpty;

    showAppActionSheet(
      context,
      actions: [
        AppSheetAction(
          icon: Icons.photo_library_outlined,
          label: '앨범에서 선택',
          onSelected: () => _pickAndUploadProfileImage(ImageSource.gallery),
        ),
        AppSheetAction(
          icon: Icons.photo_camera_outlined,
          label: '사진 촬영',
          onSelected: () => _pickAndUploadProfileImage(ImageSource.camera),
        ),
        if (hasImage)
          AppSheetAction(
            icon: Icons.delete_outline,
            label: '사진 삭제',
            isDestructive: true,
            onSelected: _confirmDeleteProfileImage,
          ),
      ],
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

      final response = _isCompanyOwnerLogin(user)
          ? await ApiService().uploadMyProfileImage(filePath: picked.path)
          : await ApiService().uploadMemberProfileImage(
              memberId: user.id,
              filePath: picked.path,
            );

      final newUrl = response['profileImageUrl']?.toString();
      if (mounted) {
        context.read<AuthProvider>().updateUser(
          _withProfileImageUrl(user, newUrl),
        );
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
      if (_isCompanyOwnerLogin(user)) {
        await ApiService().deleteMyProfileImage();
      } else {
        await ApiService().deleteMemberProfileImage(memberId: user.id);
      }
      if (mounted) {
        context.read<AuthProvider>().updateUser(
          _withProfileImageUrl(user, null),
        );
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

    // B안: 가운데 창 대신 아래 시트 — 키보드가 올라오면 시트도 함께 올라온다(AppSheetFrame).
    showAppSheet<void>(
      dialogContext,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AppSheetFrame(
          title: '비밀번호 변경',
          actions: AppSheetActions(
            cancel: SeedButton(
              label: '취소',
              variant: SeedButtonVariant.neutralWeak,
              size: SeedButtonSize.large,
              isDisabled: isChanging,
              onPressed: () => Navigator.pop(context),
            ),
            confirm: SeedButton(
              label: '변경',
              variant: SeedButtonVariant.brandSolid,
              size: SeedButtonSize.large,
              isLoading: isChanging,
              isDisabled: isChanging,
              onPressed: () async {
                if (currentPasswordController.text.isEmpty) {
                  if (!context.mounted) return;
                  AppSnackBar.showError(context, message: '현재 비밀번호를 입력해주세요');
                  return;
                }

                if (newPasswordController.text.isEmpty) {
                  if (!context.mounted) return;
                  AppSnackBar.showError(context, message: '새 비밀번호를 입력해주세요');
                  return;
                }

                if (newPasswordController.text.length < 8) {
                  if (!context.mounted) return;
                  AppSnackBar.showError(context, message: '비밀번호는 8자 이상이어야 합니다');
                  return;
                }

                if (newPasswordController.text !=
                    confirmPasswordController.text) {
                  if (!context.mounted) return;
                  AppSnackBar.showError(context, message: '새 비밀번호가 일치하지 않습니다');
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
          children: [
            const SizedBox(height: AppSpacing.space4),
            AppPasswordInput(
              label: '현재 비밀번호',
              controller: currentPasswordController,
            ),
            const SizedBox(height: AppSpacing.space4),
            AppPasswordInput(
              label: '새 비밀번호',
              controller: newPasswordController,
              helperText: '8자 이상 입력하세요',
            ),
            const SizedBox(height: AppSpacing.space4),
            AppPasswordInput(
              label: '새 비밀번호 확인',
              controller: confirmPasswordController,
            ),
            const SizedBox(height: AppSpacing.space4),
            const _SheetNote(
              background: AppSemanticColors.statusInfoBackground,
              icon: Icons.info_outline,
              iconColor: AppSemanticColors.statusInfoIcon,
              textColor: AppSemanticColors.textSecondary,
              text: '비밀번호는 영문, 숫자, 특수문자를 포함하여 8자 이상으로 설정하는 것을 권장합니다.',
            ),
          ],
        ),
      ),
    ).then((_) {
      // Dialog가 닫힌 후 자동으로 controller들이 dispose됩니다
    });
  }

  void _showRoleChangeDialog(BuildContext context, User user) {
    String selectedRole = user.role;
    bool isChanging = false;

    // B안: 가운데 창 대신 아래 시트(엄지 닿는 곳) + 큰 단추
    showAppSheet<void>(
      context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AppSheetFrame(
          title: '역할 변경',
          actions: AppSheetActions(
            cancel: SeedButton(
              label: '취소',
              variant: SeedButtonVariant.neutralWeak,
              size: SeedButtonSize.large,
              isDisabled: isChanging,
              onPressed: () => Navigator.pop(context),
            ),
            confirm: SeedButton(
              label: '변경',
              variant: SeedButtonVariant.brandSolid,
              size: SeedButtonSize.large,
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
          children: [
            const SizedBox(height: AppSpacing.space4),
            // 두 줄을 한 회색 채움 묶음에 — 줄 사이 선 없이 간격으로
            Container(
              padding: const EdgeInsets.all(AppSpacing.space2),
              decoration: BoxDecoration(
                color: AppSemanticColors.fillDefault,
                borderRadius: BorderRadius.circular(AppBorderRadius.control),
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppBorderRadius.control,
                      ),
                    ),
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
                          style: AppTypography.titleMedium.copyWith(
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
                    onChanged: isChanging
                        ? null
                        : (value) {
                            setState(() {
                              selectedRole = value!;
                            });
                          },
                  ),
                  const SizedBox(height: AppSpacing.space1),
                  RadioListTile<String>(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppBorderRadius.control,
                      ),
                    ),
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
                          style: AppTypography.titleMedium.copyWith(
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
                    onChanged: isChanging
                        ? null
                        : (value) {
                            setState(() {
                              selectedRole = value!;
                            });
                          },
                  ),
                ],
              ),
            ),
            if (selectedRole != user.role) ...[
              const SizedBox(height: AppSpacing.space3),
              const _SheetNote(
                background: AppSemanticColors.statusWarningBackground,
                icon: Icons.info_outline,
                iconColor: AppSemanticColors.statusWarningIcon,
                textColor: AppSemanticColors.statusWarningText,
                text: '역할 변경 시 권한이 변경됩니다.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showWithdrawalDialog(BuildContext context) {
    bool isWithdrawing = false;

    // B안: 가운데 창 대신 경고 아이콘이 있는 아래 시트. 예전처럼 바깥을 눌러도 닫히지 않는다.
    showAppSheet<void>(
      context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AppSheetFrame(
          title: '회원탈퇴',
          warning: true,
          actions: AppSheetActions(
            cancel: SeedButton(
              label: '취소',
              variant: SeedButtonVariant.neutralWeak,
              size: SeedButtonSize.large,
              isDisabled: isWithdrawing,
              onPressed: () => Navigator.pop(context),
            ),
            confirm: SeedButton(
              label: '탈퇴하기',
              variant: SeedButtonVariant.critical,
              size: SeedButtonSize.large,
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

                  // 성공 메시지 표시 — 같은 아래 시트(바깥을 눌러도 닫히지 않는다)
                  showAppSheet<void>(
                    context,
                    isDismissible: false,
                    enableDrag: false,
                    builder: (sheetContext) => AppSheetFrame(
                      actions: SeedButton(
                        label: '확인',
                        variant: SeedButtonVariant.brandSolid,
                        size: SeedButtonSize.large,
                        onPressed: () {
                          Navigator.of(sheetContext).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                      children: [
                        Center(
                          child: Container(
                            width: AppSpacing.space14,
                            height: AppSpacing.space14,
                            decoration: const BoxDecoration(
                              color: AppSemanticColors.statusSuccessBackground,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: AppSemanticColors.statusSuccessIcon,
                              size: 40,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space5),
                        Text(
                          '회원탈퇴 완료',
                          textAlign: TextAlign.center,
                          style: AppTypography.heading5.copyWith(
                            color: AppSemanticColors.statusSuccessIcon,
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
                      ],
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
          children: [
            const SizedBox(height: AppSpacing.space4),
            // 주의사항 — 테두리 없이 옅은 빨강 바탕, 모서리 12
            Container(
              padding: const EdgeInsets.all(AppSpacing.space4),
              decoration: BoxDecoration(
                color: AppSemanticColors.statusErrorBackground,
                borderRadius: BorderRadius.circular(AppBorderRadius.control),
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
      // B안: 옅은 회색 바탕 위 테두리 없는 흰 카드
      backgroundColor: AppSemanticColors.backgroundCanvas,
      body: CustomScrollView(
        slivers: [
          // 슬림 상단 — 타이틀 1개만 (다른 화면과 동일한 흰 배경 AppBar)
          SliverAppBar(
            expandedHeight: 56.0,
            floating: false,
            pinned: true,
            elevation: 0,
            title: Text('프로필', style: AppTypography.appBarTitle),
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
                        color: AppSemanticColors.surfaceCard,
                        borderRadius: BorderRadius.circular(
                          AppBorderRadius.card,
                        ),
                        border: AppLines.cardBorder,
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
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenGutter,
                          AppSpacing.space4,
                          AppSpacing.screenGutter,
                          0,
                        ),
                        // B안: 테두리 없는 흰 카드(모서리 16·여백 16)
                        child: AppCard(
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
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppSemanticColors.fillDefault,
                                      ),
                                      child:
                                          (user.profileImageUrl ?? '')
                                              .isNotEmpty
                                          ? ClipOval(
                                              child: Image.network(
                                                SeedAvatar.resolveImageUrl(
                                                  user.profileImageUrl!,
                                                ),
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
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
                                          color: AppColors.black.withValues(
                                            alpha: 0.4,
                                          ),
                                          alignment: Alignment.center,
                                          child: const SizedBox(
                                            width: 28,
                                            height: 28,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    AppColors.white,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  // 사진은 직원도 관리자도 바꿀 수 있다 (보내는 곳만 다르다)
                                  // 보이는 원은 36, 누르는 자리는 48(원 둘레까지)
                                  Positioned(
                                    right: -AppSpacing.space1_5,
                                    bottom: -AppSpacing.space1_5,
                                    child: Semantics(
                                      button: true,
                                      label: '프로필 사진 변경',
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: _isUploadingPhoto
                                            ? null
                                            : () => _showProfileImageOptions(
                                                context,
                                                user,
                                              ),
                                        child: SizedBox(
                                          width: AppSpacing.minTouchTarget,
                                          height: AppSpacing.minTouchTarget,
                                          child: Center(
                                            child: Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AppSemanticColors
                                                    .brandDefault,
                                                border: Border.all(
                                                  color: AppSemanticColors
                                                      .surfaceDefault,
                                                  width: 2,
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.photo_camera,
                                                size: 18,
                                                color: AppSemanticColors
                                                    .textInverse,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // B안: 구분선 없이 간격으로 사진과 기본 정보를 나눈다
                              const SizedBox(height: AppSpacing.space6),

                              // 사용자 정보 섹션 — 카드 안에 또 카드를 두지 않는다
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '기본 정보',
                                    style: AppTypography.heading6.copyWith(
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
                                    iconColor:
                                        AppSemanticColors.statusSuccessIcon,
                                    title: '이메일',
                                    value: user.email,
                                  ),
                                  const SizedBox(height: AppSpacing.space4),

                                  // 직원 유형 (기관 대표(app_user) 로그인은 members 행이 없어
                                  // 역할 변경 API가 항상 실패한다 — 사진 업로드와 같은 기준으로 숨긴다)
                                  // 직책이 직원 유형 이름과 같으면(센터장/센터장) 한 줄만 보인다 — 직책 쪽이 바꿀 수 있는 자리다
                                  if (!_roleSameAsPosition(user)) ...[
                                    if (_isCompanyOwnerLogin(user))
                                      _buildInfoRow(
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
                                      )
                                    else
                                      InkWell(
                                        onTap: () => _showRoleChangeDialog(
                                          context,
                                          user,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppBorderRadius.control,
                                        ),
                                        child: Container(
                                          // 누르는 줄 — 높이 48 이상
                                          constraints: const BoxConstraints(
                                            minHeight:
                                                AppSpacing.minTouchTarget,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: AppSpacing.space1,
                                          ),
                                          child: Row(
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
                                              const _EditBadge(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: AppSpacing.space4),
                                  ],

                                  // 부서 (있는 경우)
                                  if (user.department != null &&
                                      user.department!.isNotEmpty)
                                    Column(
                                      children: [
                                        _buildInfoRow(
                                          icon: Icons.business_center,
                                          iconColor: AppSemanticColors
                                              .statusWarningIcon,
                                          title: '부서',
                                          value: user.department!,
                                        ),
                                        const SizedBox(
                                          height: AppSpacing.space4,
                                        ),
                                      ],
                                    ),

                                  // 직책 — 관리자는 여기서 바로 바꾼다 (웹 기관정보의 '내 직책'과 같은 자리).
                                  // 직원은 관리자가 배정하므로 값이 있을 때만 읽기로 보여준다.
                                  if (AdminUtils.isAdmin(user))
                                    Column(
                                      children: [
                                        InkWell(
                                          onTap: _isSavingPosition
                                              ? null
                                              : () => _showPositionPicker(user),
                                          borderRadius: BorderRadius.circular(
                                            AppBorderRadius.control,
                                          ),
                                          child: ConstrainedBox(
                                            // 누르는 줄 — 높이 48 이상
                                            constraints: const BoxConstraints(
                                              minHeight:
                                                  AppSpacing.minTouchTarget,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: _buildInfoRow(
                                                    icon: Icons.work,
                                                    iconColor: AppSemanticColors
                                                        .textSecondary,
                                                    title: '직책',
                                                    value:
                                                        user
                                                                .position
                                                                ?.isNotEmpty ==
                                                            true
                                                        ? user.position!
                                                        : '직책 없음 (관리자로 표시)',
                                                  ),
                                                ),
                                                if (_isSavingPosition)
                                                  const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                else
                                                  const _EditBadge(),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                          height: AppSpacing.space1,
                                        ),
                                        Padding(
                                          // 값 글자 시작(라벨 칸 + 8)에 맞춘다
                                          padding: EdgeInsets.only(
                                            left:
                                                _infoLabelWidth(context) +
                                                AppSpacing.space2,
                                          ),
                                          child: Text(
                                            '결재선과 채팅에 이 직책으로 표시됩니다',
                                            style: AppTypography.bodySmall
                                                .copyWith(
                                                  color: AppSemanticColors
                                                      .textTertiary,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(
                                          height: AppSpacing.space4,
                                        ),
                                      ],
                                    )
                                  else if (user.position != null &&
                                      user.position!.isNotEmpty)
                                    Column(
                                      children: [
                                        _buildInfoRow(
                                          icon: Icons.work,
                                          iconColor:
                                              AppSemanticColors.textSecondary,
                                          title: '직책',
                                          value: user.position!,
                                        ),
                                        const SizedBox(
                                          height: AppSpacing.space4,
                                        ),
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
                                        const SizedBox(
                                          height: AppSpacing.space4,
                                        ),
                                        _buildInfoRow(
                                          icon: Icons.login,
                                          iconColor:
                                              AppSemanticColors.textSecondary,
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

                  // B안: 카드끼리는 선 대신 간격 10
                  const SizedBox(height: AppSpacing.cardGap),

                  if (AdminUtils.canAccessAdminPages(user) &&
                      (user.company?.companyCode?.isNotEmpty ?? false))
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenGutter,
                        ),
                        // B안: 테두리 없는 흰 카드
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // 목록 줄 아이콘과 같은 둥근 40
                                  Container(
                                    width: AppSpacing.iconCircle,
                                    height: AppSpacing.iconCircle,
                                    decoration: const BoxDecoration(
                                      color: AppSemanticColors
                                          .statusWarningBackground,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.key,
                                      color:
                                          AppSemanticColors.statusWarningIcon,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.space3),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '회사 코드',
                                          style: AppTypography.heading6
                                              .copyWith(
                                                color: AppSemanticColors
                                                    .textPrimary,
                                              ),
                                        ),
                                        Text(
                                          '직원 가입 신청용 코드입니다',
                                          style: AppTypography.bodySmall
                                              .copyWith(
                                                color: AppSemanticColors
                                                    .textSecondary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.space4),
                              // 코드 칸 — 테두리 없는 회색 채움(입력칸과 같은 바탕·모서리 12)
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.space4,
                                  AppSpacing.space2,
                                  AppSpacing.space2,
                                  AppSpacing.space2,
                                ),
                                constraints: const BoxConstraints(
                                  minHeight:
                                      AppSpacing.buttonHeightLarge +
                                      AppSpacing.space4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppSemanticColors.fillDefault,
                                  borderRadius: BorderRadius.circular(
                                    AppBorderRadius.control,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: SelectableText(
                                        user.company!.companyCode!,
                                        style: AppTypography.heading5.copyWith(
                                          letterSpacing: 2,
                                          color: AppSemanticColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    // 글자만 있는 틸 단추(B안 SeedButton) — 같은 '복사'
                                    SeedButton(
                                      label: '복사',
                                      variant: SeedButtonVariant.brandGhost,
                                      size: SeedButtonSize.small,
                                      prefixIcon: Icons.copy,
                                      onPressed: () => _copyCompanyCode(
                                        user.company!.companyCode!,
                                      ),
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
                    const SizedBox(height: AppSpacing.cardGap),

                  // 설정 섹션
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenGutter,
                      ),
                      // B안: 흰 카드 하나에 줄 여러 개(SeedListSection), 줄 사이 선 없음
                      child: SeedListSection(
                        children: [
                          // 관리자 회사 정보 메뉴
                          if (AdminUtils.canAccessAdminPages(user))
                            _buildSettingTile(
                              icon: Icons.business,
                              title: '회사 정보',
                              subtitle: '회사 정보 및 구독 관리',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const AdminCompanySettingsScreen(),
                                  ),
                                );
                              },
                            ),

                          _buildSettingTile(
                            icon: Icons.draw,
                            title: '결재 서명 관리',
                            subtitle: '서명을 등록하면 결재 승인 시 자동으로 날인됩니다',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SignatureManageScreen(),
                                ),
                              );
                            },
                          ),

                          _buildSettingTile(
                            icon: Icons.lock,
                            title: '비밀번호 변경',
                            subtitle: '계정 보안을 위해 주기적으로 변경하세요',
                            onTap: () => _showPasswordChangeDialog(context),
                          ),

                          _buildSettingTile(
                            icon: Icons.star_rate,
                            title: '앱 평가하기',
                            subtitle: '평점과 리뷰를 남겨주세요',
                            onTap: () async {
                              // Analytics 이벤트 로깅
                              AnalyticsService().logCustomEvent(
                                eventName: 'rate_app_clicked',
                                parameters: {'source': 'profile_screen'},
                              );

                              // 리뷰 요청
                              await InAppReviewService()
                                  .requestReviewManually();

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

                          _buildSettingTile(
                            icon: Icons.person_remove,
                            title: '회원탈퇴',
                            subtitle: '계정을 영구적으로 삭제합니다',
                            onTap: () => _showWithdrawalDialog(context),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.cardGap),

                  // 약관 및 정책 섹션
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenGutter,
                        ),
                        // B안: 흰 카드 하나 — 맨 위 제목 글자(머리 아이콘 상자 없음) + 줄 두 개
                        child: SeedListSection(
                          children: [
                            // 섹션 헤더 — 카드 여백 8 + 12 = 줄 글자 시작 20에 맞춘다
                            const Padding(
                              padding: EdgeInsets.fromLTRB(
                                AppSpacing.space3,
                                AppSpacing.space3,
                                AppSpacing.space3,
                                AppSpacing.space1,
                              ),
                              child: SeedSectionHeader(title: '약관 및 정책'),
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
                            ),

                            _buildPolicyTile(
                              icon: Icons.description,
                              title: '서비스 이용약관',
                              subtitle: '서비스 이용에 대한 약관 및 조건',
                              iconColor: AppSemanticColors.statusSuccessIcon,
                              onTap: () => _launchURL(
                                'https://relic-baboon-412.notion.site/silverithm-13c766a8bb468082b91ddbd2dd6ce45d',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.space6),

                  // 로그아웃 버튼
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space4,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        // B안: 테두리 단추 대신 회색 채움 큰 단추
                        child: SeedButton(
                          label: '로그아웃',
                          variant: SeedButtonVariant.neutralWeak,
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
                        style: AppTypography.bodySmall.copyWith(
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
      child: Icon(
        Icons.person,
        size: 60,
        color: AppSemanticColors.textSecondary,
      ),
    );
  }

  /// 설정 한 줄 — B안 목록 줄: 옅은 틸 둥근 아이콘 40 + 제목 16/w600·설명 12 + 꺾쇠.
  /// (예전의 회색 네모 아이콘·회색 네모 꺾쇠 상자는 없앴다)
  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return SeedListCell(
      leadingIcon: icon,
      title: title,
      description: subtitle,
      onTap: onTap,
    );
  }

  bool _isSavingPosition = false;

  /// 관리자 본인 직책 고르기. 웹 기관정보 화면의 '내 직책' Selector와 같은 동작 —
  /// 고르는 즉시 저장하고, 비우면 '관리자'로 표시된다.
  Future<void> _showPositionPicker(User user) async {
    final companyId = user.company?.id?.toString() ?? '';
    if (companyId.isEmpty) {
      AppSnackBar.showError(context, message: '기관 정보를 찾을 수 없습니다');
      return;
    }

    List<PositionOption> positions = const [];
    try {
      final result = await ApiService().getPositions(companyId: companyId);
      final raw = result['positions'];
      if (raw is List) {
        positions = raw
            .whereType<Map<String, dynamic>>()
            .map(PositionOption.fromJson)
            .toList();
      }
    } catch (e) {
      print('[Profile] 직책 목록 조회 실패: $e');
      if (mounted) {
        AppSnackBar.showError(context, message: '직책 목록을 불러오지 못했습니다');
      }
      return;
    }

    if (!mounted) return;

    if (positions.isEmpty) {
      AppSnackBar.showInfo(context, message: '먼저 직원 관리에서 직책을 등록해주세요');
      return;
    }

    await showAppActionSheet(
      context,
      title: '내 직책',
      actions: [
        for (final position in positions)
          AppSheetAction(
            icon: Icons.work_outline,
            label: position.name,
            onSelected: () => _applyPosition(
              positionId: int.tryParse(position.id),
              positionName: position.name,
            ),
          ),
        AppSheetAction(
          icon: Icons.remove_circle_outline,
          label: '직책 없음 (관리자로 표시)',
          onSelected: () => _applyPosition(positionId: null, positionName: ''),
        ),
      ],
    );
  }

  Future<void> _applyPosition({
    required int? positionId,
    required String positionName,
  }) async {
    setState(() => _isSavingPosition = true);

    try {
      final response = await ApiService().updateMyPosition(
        positionId: positionId,
      );
      // 서버가 확정한 이름을 쓴다 — 직책명이 그새 바뀌었을 수 있다
      final savedName = response['position']?.toString() ?? positionName;

      if (!mounted) return;
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.currentUser;
      if (currentUser != null) {
        // 직책을 해제하면 빈 문자열 — 화면들이 isNotEmpty로 '직책 없음'을 판단한다
        authProvider.updateUser(currentUser.copyWith(position: savedName));
      }

      AppSnackBar.showSuccess(
        context,
        message: positionId == null ? '직책을 해제했습니다' : '직책이 변경되었습니다',
      );
    } catch (e) {
      print('[Profile] 직책 변경 실패: $e');
      if (mounted) {
        AppSnackBar.showError(
          context,
          message: '직책을 바꾸지 못했습니다. 잠시 후 다시 시도해주세요',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingPosition = false);
      }
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    // 줄마다 아이콘을 붙이면 위계가 없어 보였다(D10) — 라벨/값 표로만 보여준다.
    // 이메일처럼 긴 값은 두 줄로 꺾지 않고 한 줄에 줄임표.
    // 라벨 칸은 글자 배율만큼 넓힌다 — 글자를 키워도 '마지막 로그인'이 두 줄로 꺾이지 않게.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _infoLabelWidth(context),
          child: Text(
            title,
            style: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.space2),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  /// 기본 정보 표의 라벨 칸 폭 — 14px 글자 여섯 자(마지막 로그인)가 한 줄에 드는 폭을
  /// 글자 배율만큼 키운다.
  double _infoLabelWidth(BuildContext context) => MediaQuery.textScalerOf(
    context,
  ).scale(AppSpacing.space20 + AppSpacing.space2);

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

  bool _roleSameAsPosition(dynamic user) {
    final position = (user.position as String?)?.trim() ?? '';
    return AdminUtils.isAdmin(user) &&
        position.isNotEmpty &&
        position == _getRoleDisplayName(_effectiveRole(user));
  }

  String _getRoleDisplayName(String role) {
    return RoleUtils.displayName(role);
  }

  /// 약관 한 줄 — 설정 줄과 같은 B안 목록 줄.
  Widget _buildPolicyTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return SeedListCell(
      leadingIcon: icon,
      title: title,
      description: subtitle,
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
            MaterialPageRoute(builder: (_) => const SubscriptionCheckScreen()),
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
                      style: AppTypography.titleSmall.copyWith(
                        color: AppSemanticColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space0_5),
                    Text(
                      '구독이 필요합니다 (탭하여 구독하기)',
                      style: AppTypography.titleSmall.copyWith(
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
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppBorderRadius.full),
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: AppSpacing.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '구독 정보',
                    style: AppTypography.titleSmall.copyWith(
                      color: AppSemanticColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space0_5),
                  Row(
                    children: [
                      Text(
                        subscription.planDisplayName,
                        style: AppTypography.bodyMedium.copyWith(
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
                          borderRadius: BorderRadius.circular(
                            AppBorderRadius.lg,
                          ),
                        ),
                        child: Text(
                          subscription.statusDisplayName,
                          style: AppTag.labelStyle.copyWith(
                            color: AppColors.white,
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
                  style: AppTypography.heading6.copyWith(
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
              _buildDetailRow('만료일', _formatDate(subscription.endDate!)),
              const SizedBox(height: AppSpacing.space3),
              if (subscription.isActive)
                _buildDetailRow('남은 일수', '${subscription.daysRemaining}일'),
            },
            if (subscription.startDate != null) ...{
              const SizedBox(height: AppSpacing.space3),
              _buildDetailRow('시작일', _formatDate(subscription.startDate!)),
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
            ),
          ),
        ),
      ],
    );
  }
}

/// 바꿀 수 있는 줄 끝의 연필 — 옅은 회색 둥근 바탕 32 + 연필 18(B안, 테두리 없음).
/// 줄 전체가 눌리는 자리라 이 동그라미는 표시만 한다.
class _EditBadge extends StatelessWidget {
  const _EditBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.space8,
      height: AppSpacing.space8,
      decoration: const BoxDecoration(
        color: AppSemanticColors.fillDefault,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.edit,
        size: 18,
        color: AppSemanticColors.textSecondary,
      ),
    );
  }
}

/// 시트 안의 작은 안내 상자 — B안: 테두리 없이 옅은 상태색 바탕, 모서리 12, 아이콘 20
/// (SeedCallout과 같은 치수. 글자는 본래 크기 12를 그대로 둔다).
class _SheetNote extends StatelessWidget {
  const _SheetNote({
    required this.background,
    required this.icon,
    required this.iconColor,
    required this.textColor,
    required this.text,
  });

  final Color background;
  final IconData icon;
  final Color iconColor;
  final Color textColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3_5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppBorderRadius.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: AppSpacing.space2_5),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySmall.copyWith(color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}
