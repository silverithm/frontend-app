import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/admin_utils.dart';
import '../widgets/common/index.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'register_screen.dart';
import 'main_screen.dart';
import 'design_test_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberEmail = false;
  bool _isAdminLogin = false;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedEmail() async {
    await StorageService().init();
    final savedEmail = StorageService().getRememberedEmail();
    final rememberEmail = StorageService().getRememberEmailEnabled();

    // rememberEmail이 true이고 savedEmail이 있으면 이메일 복원
    if (rememberEmail && savedEmail != null && savedEmail.isNotEmpty) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberEmail = true;
      });
      print('[LoginScreen] 저장된 이메일 복원: $savedEmail');
    } else {
      // rememberEmail 상태만 복원 (이메일은 복원하지 않음)
      setState(() {
        _rememberEmail = rememberEmail;
      });
      print('[LoginScreen] 이메일 기억하기 상태: $rememberEmail');
    }
  }

  Future<void> _saveEmailPreference() async {
    if (_rememberEmail && _emailController.text.trim().isNotEmpty) {
      // 이메일 기억하기가 체크되어 있고 이메일이 입력되어 있으면 저장
      await StorageService().saveRememberedEmail(_emailController.text.trim());
      await StorageService().saveRememberEmailEnabled(true);
      print('[LoginScreen] 이메일 기억하기 저장: ${_emailController.text.trim()}');
    } else {
      // 체크 해제되거나 이메일이 비어있으면 삭제
      await StorageService().clearRememberedEmail();
      print('[LoginScreen] 이메일 기억하기 해제');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    await _saveEmailPreference();

    final authProvider = context.read<AuthProvider>();
    bool success;

    if (_isAdminLogin) {
      success = await authProvider.adminLogin(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } else {
      success = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }

    if (success && mounted) {
      final currentUser = authProvider.currentUser;

      await AnalyticsService().logLogin();

      print('[LoginScreen] 로그인 성공 - 사용자 정보:');
      print('[LoginScreen] - 이름: ${currentUser?.name}');
      print('[LoginScreen] - 역할: ${currentUser?.role}');
      print('[LoginScreen] - 회사: ${currentUser?.company?.name}');
      print(
        '[LoginScreen] - canAccessAdminPages: ${AdminUtils.canAccessAdminPages(currentUser)}',
      );

      // 모든 사용자는 동일한 MainScreen으로 이동 (역할별 화면은 MainScreen에서 처리)
      print('[LoginScreen] 메인 화면으로 이동 (역할: ${currentUser?.role})');
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
    }
  }

  void _showForgotPasswordDialog() {
    bool isAdminPasswordReset = false;
    final emailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => shadcn.AlertDialog(
          title: Row(
            children: [
              Icon(Icons.lock_reset, color: AppSemanticColors.statusInfoIcon),
              const SizedBox(width: AppSpacing.space2),
              Text(
                '비밀번호 찾기',
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
              Text(
                '가입하신 이메일을 입력하시면 임시 비밀번호를 전송해드립니다.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppSemanticColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
              
              // 사용자 타입 선택
              Text(
                '사용자 타입 선택',
                style: AppTypography.labelLarge.copyWith(
                  color: AppSemanticColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: !isAdminPasswordReset
                              ? AppSemanticColors.interactivePrimaryDefault
                              : AppSemanticColors.borderSubtle,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                      ),
                      child: RadioListTile<bool>(
                        title: Text(
                          '직원',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppSemanticColors.textPrimary,
                          ),
                        ),
                        value: false,
                        groupValue: isAdminPasswordReset,
                        onChanged: (value) {
                          setState(() {
                            isAdminPasswordReset = value ?? false;
                          });
                        },
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isAdminPasswordReset
                              ? AppSemanticColors.interactivePrimaryDefault
                              : AppSemanticColors.borderSubtle,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                      ),
                      child: RadioListTile<bool>(
                        title: Text(
                          '관리자',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppSemanticColors.textPrimary,
                          ),
                        ),
                        value: true,
                        groupValue: isAdminPasswordReset,
                        onChanged: (value) {
                          setState(() {
                            isAdminPasswordReset = value ?? false;
                          });
                        },
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space4),
              
              // 이메일 입력
              AppInput(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                label: '이메일',
                hintText: 'example@email.com',
                prefixIcon: const Icon(Icons.email),
              ),
            ],
          ),
          actions: [
            AppButton(
              text: '취소',
              variant: AppButtonVariant.outline,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) => AppButton(
                text: '비밀번호 찾기',
                isLoading: authProvider.isLoading,
                variant: isAdminPasswordReset
                    ? AppButtonVariant.secondary
                    : AppButtonVariant.primary,
                onPressed: authProvider.isLoading
                    ? null
                    : () async {
                        final email = emailController.text.trim();
                        if (email.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '이메일을 입력해주세요',
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

                        Navigator.of(dialogContext).pop();

                        if (isAdminPasswordReset) {
                          await authProvider.findAdminPassword(email, context);
                        } else {
                          await authProvider.findPassword(email, context);
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.interactivePrimaryDefault,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              // 로고 및 제목
              Image.asset(
                'assets/images/app_icon_with_text_3.png',
                width: 80,
                height: 80,
              ),
              const SizedBox(height: AppSpacing.space4),
              // 개인정보처리방침 및 서비스 이용약관 링크
              _buildBottomLinks(),
              // 로그인 폼
              AppCard(
                elevation: 8,
                borderRadius: AppBorderRadius.xl,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 헤더
                      Column(
                        children: [
                          Text(
                            '로그인',
                            style: AppTypography.heading4,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.space2),
                          Text(
                            _isAdminLogin ? '관리자 계정으로 로그인' : '직원 계정으로 로그인',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppSemanticColors.interactivePrimaryDefault,
                              fontWeight: AppTypography.fontWeightMedium,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.space8),

                      // 사용자 타입 선택
                      _buildUserTypeToggle(),
                      const SizedBox(height: AppSpacing.space6),

                      // 이메일 입력
                      AppInput(
                        label: '이메일',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.person_outline),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '사용자명 또는 이메일을 입력해주세요';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.space4),

                      // 이메일 기억하기 체크박스
                      _buildRememberEmailCheckbox(),
                      const SizedBox(height: AppSpacing.space4),

                      // 비밀번호 입력
                      AppPasswordInput(
                        label: '비밀번호',
                        controller: _passwordController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '비밀번호를 입력해주세요';
                          }
                          if (value.length < 6) {
                            return '비밀번호는 6자 이상이어야 합니다';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.space2),

                      // 비밀번호 찾기 링크
                      Align(
                        alignment: Alignment.centerRight,
                        child: AppButton(
                          text: '비밀번호 찾기',
                          variant: AppButtonVariant.text,
                          size: AppButtonSize.small,
                          onPressed: _showForgotPasswordDialog,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space8),

                      // 로그인 버튼
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, child) => AppButton(
                          text: '로그인',
                          isFullWidth: true,
                          isLoading: authProvider.isLoading,
                          onPressed: authProvider.isLoading ? null : _login,
                        ),
                      ),

                      // 에러 메시지
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, child) {
                          if (authProvider.errorMessage.isNotEmpty) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.space4,
                              ),
                              child: AppStatusCard(
                                status: AppStatusType.error,
                                padding: const EdgeInsets.all(
                                  AppSpacing.space3,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: AppSemanticColors.statusErrorIcon,
                                      size: 20,
                                    ),
                                    const SizedBox(width: AppSpacing.space2),
                                    Expanded(
                                      child: Text(
                                        authProvider.errorMessage,
                                        style: AppTypography.bodySmall.copyWith(
                                          color:
                                              AppSemanticColors.statusErrorText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(height: AppSpacing.space6),

                      // 회원가입 링크
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '계정이 없으신가요? ',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppSemanticColors.textSecondary,
                            ),
                          ),
                          AppButton(
                            text: '회원가입',
                            variant: AppButtonVariant.text,
                            size: AppButtonSize.small,
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserTypeToggle() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppSemanticColors.borderDefault),
        color: AppSemanticColors.backgroundSecondary,
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isAdminLogin = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.space3,
                ),
                decoration: BoxDecoration(
                  color: !_isAdminLogin
                      ? AppSemanticColors.interactivePrimaryDefault
                      : AppColors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppBorderRadius.lg),
                    bottomLeft: Radius.circular(AppBorderRadius.lg),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person,
                      color: !_isAdminLogin
                          ? AppSemanticColors.textInverse
                          : AppSemanticColors.textTertiary,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    Text(
                      '직원',
                      style: AppTypography.buttonMedium.copyWith(
                        color: !_isAdminLogin
                            ? AppSemanticColors.textInverse
                            : AppSemanticColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isAdminLogin = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.space3,
                ),
                decoration: BoxDecoration(
                  color: _isAdminLogin
                      ? AppSemanticColors.interactivePrimaryDefault
                      : AppColors.transparent,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(AppBorderRadius.lg),
                    bottomRight: Radius.circular(AppBorderRadius.lg),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.admin_panel_settings,
                      color: _isAdminLogin
                          ? AppSemanticColors.textInverse
                          : AppSemanticColors.textTertiary,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    Text(
                      '관리자',
                      style: AppTypography.buttonMedium.copyWith(
                        color: _isAdminLogin
                            ? AppSemanticColors.textInverse
                            : AppSemanticColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRememberEmailCheckbox() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        onTap: () {
          setState(() {
            _rememberEmail = !_rememberEmail;
          });
        },
        child: Row(
          children: [
            SizedBox(
              width: AppSpacing.space8,
              height: AppSpacing.space8,
              child: Checkbox(
                value: _rememberEmail,
                onChanged: (value) {
                  setState(() {
                    _rememberEmail = value ?? false;
                  });
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: AppSpacing.space2),
            Text(
              '이메일 기억하기',
              style: AppTypography.bodySmall.copyWith(
                color: AppSemanticColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomLinks() {
    return Column(
      children: [
        // 상단 링크들 (사용법, 웹사이트) - Wrap 사용하여 화면에 맞게 배치
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppButton(
              text: '사용방법 보러가기',
              size: AppButtonSize.small,
              onPressed: () async {
                const url = 'https://youtu.be/x2cJedS6vaU';
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
            ),
            Container(
              width: 1,
              height: 12,
              color: AppSemanticColors.textInverse.withValues(alpha: 0.3),
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
            ),
            AppButton(
              text: '케어브이 웹사이트',
              size: AppButtonSize.small,
              onPressed: () async {
                const url = 'https://carev.kr';
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}
