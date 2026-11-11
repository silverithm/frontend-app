import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/admin_utils.dart';
import '../utils/app_haptics.dart';
import '../widgets/common/index.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_callout.dart';
import '../widgets/seed/seed_text_field.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'register_screen.dart';
import 'main_screen.dart';

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

    // B안: 가운데 대화상자 대신 아래에서 올라오는 시트(입력칸이 있어 키보드만큼 올라간다)
    showAppSheet<void>(
      context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) => AppSheetFrame(
          title: '비밀번호 찾기',
          message: '가입하신 이메일을 입력하시면 임시 비밀번호를 전송해드립니다.',
          children: [
            const SizedBox(height: AppSpacing.space5),

            // 사용자 타입 선택 토글
            Text(
              '사용자 타입',
              style: AppTypography.titleSmall.copyWith(
                color: AppSemanticColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.space2),
            _buildTypeSegments(
              isAdmin: isAdminPasswordReset,
              onChanged: (isAdmin) =>
                  setState(() => isAdminPasswordReset = isAdmin),
            ),
            const SizedBox(height: AppSpacing.space4),

            // 이메일 입력 — 본문 폼(SeedTextField)과 동일 컴포넌트로 통일
            SeedTextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              label: '이메일',
              placeholder: 'example@email.com',
              prefixIcon: Icons.email_outlined,
            ),
          ],
          actions: AppSheetActions(
            cancel: SeedButton(
              label: '취소',
              size: SeedButtonSize.large,
              variant: SeedButtonVariant.neutralWeak,
              onPressed: () => Navigator.of(context).pop(),
            ),
            confirm: Consumer<AuthProvider>(
              builder: (context, authProvider, child) => SeedButton(
                label: '비밀번호 찾기',
                size: SeedButtonSize.large,
                variant: SeedButtonVariant.brandSolid,
                isLoading: authProvider.isLoading,
                onPressed: authProvider.isLoading
                    ? null
                    : () async {
                        final email = emailController.text.trim();
                        if (email.isEmpty) {
                          AppSnackBar.showError(
                            context,
                            message: '이메일을 입력해주세요',
                          );
                          return;
                        }
                        Navigator.of(context).pop();
                        if (isAdminPasswordReset) {
                          await authProvider.findAdminPassword(
                            email,
                            context,
                          );
                        } else {
                          await authProvider.findPassword(
                            email,
                            context,
                          );
                        }
                      },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 직원·관리자 고르기 — B안 나눔 조절(AppSegmentedTabs)과 같은 모습: 회색 띠 위에서 고른 칸만 흰 칸.
  /// 로그인 화면과 비밀번호 찾기 시트가 같이 쓴다. 다른 칸을 누를 때만 selection 햅틱.
  Widget _buildTypeSegments({
    required bool isAdmin,
    required ValueChanged<bool> onChanged,
    bool withIcons = false,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppSemanticColors.fillDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.control),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space1),
        child: Row(
          children: [
            Expanded(
              child: _buildTypeSegment(
                label: '직원',
                icon: withIcons ? Icons.person : null,
                selected: !isAdmin,
                onTap: () => onChanged(false),
              ),
            ),
            Expanded(
              child: _buildTypeSegment(
                label: '관리자',
                icon: withIcons ? Icons.admin_panel_settings : null,
                selected: isAdmin,
                onTap: () => onChanged(true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSegment({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!selected) AppHaptics.selection();
          onTap();
        },
        child: AnimatedContainer(
          duration: AppMotion.tabSwitch,
          curve: AppMotion.standardCurve,
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space2,
            vertical: AppSpacing.space1,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppSemanticColors.surfaceCard
                : AppColors.transparent,
            borderRadius: BorderRadius.circular(AppBorderRadius.inner),
            boxShadow: selected ? AppShadows.raised : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: AppSpacing.space5,
                  color: selected
                      ? AppSemanticColors.brandDefault
                      : AppSemanticColors.iconSubtle,
                ),
                const SizedBox(width: AppSpacing.space1_5),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(
                    color: selected
                        ? AppSemanticColors.textPrimary
                        : AppSemanticColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // B안: 옅은 회색 바탕 위 흰 카드 한 장에 입력 폼을 담는다(회색 입력칸이 흰 카드 위에서 보인다).
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundCanvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenGutter,
            vertical: AppSpacing.space6,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 헤더.
                //
                // 로고 그림과 앱 이름 줄은 뺐다. 쓰던 'app_icon_with_text_3.png'는 813x366 캔버스에
                // 마크만 얹혀 있고 이름 글자가 없어 정사각형 상자에 넣으면 쪼그라들기만 했고,
                // 바로 아래 '로그인' 제목과 말이 겹쳐 답답했다. 그만큼 화면을 위로 끌어올린다.
                const SizedBox(height: AppSpacing.space4),
                Text(
                  '로그인',
                  style: AppTypography.heading4,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.space2),
                Text(
                  _isAdminLogin ? '관리자 계정으로 로그인' : '직원 계정으로 로그인',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textLink,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.space6),

                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 사용자 타입 선택
                      _buildUserTypeToggle(),
                      const SizedBox(height: AppSpacing.space5),

                      // 이메일 입력
                      SeedTextField(
                        label: '이메일',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.person_outline,
                        size: SeedTextFieldSize.large,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '사용자명 또는 이메일을 입력해주세요';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.space1),

                      // 이메일 기억하기 체크박스
                      _buildRememberEmailCheckbox(),
                      const SizedBox(height: AppSpacing.space2),

                      // 비밀번호 입력
                      SeedTextField(
                        label: '비밀번호',
                        controller: _passwordController,
                        obscureText: true,
                        enableObscureToggle: true,
                        prefixIcon: Icons.lock_outline,
                        size: SeedTextFieldSize.large,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '비밀번호를 입력해주세요';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.space1),

                      // 비밀번호 찾기 링크
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildTextLink(
                          label: '비밀번호 찾기',
                          onPressed: _showForgotPasswordDialog,
                          color: AppSemanticColors.textLink,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space4),

                      // 로그인 버튼
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, child) => SeedButton(
                          label: '로그인',
                          variant: SeedButtonVariant.brandSolid,
                          size: SeedButtonSize.large,
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
                              child: SeedCallout(
                                variant: SeedCalloutVariant.danger,
                                title: authProvider.errorMessage,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.space5),

                // 회원가입 링크 — 글자가 커져도 넘치지 않게 줄을 넘길 수 있게 둔다
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '계정이 없으신가요?',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppSemanticColors.textSecondary,
                      ),
                    ),
                    _buildTextLink(
                      label: '회원가입',
                      color: AppSemanticColors.textLink,
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

                const SizedBox(height: AppSpacing.space4),

                // 하단 링크들 (사용법, 웹사이트) — 위계상 폼 아래로 이동
                _buildBottomLinks(),
                const SizedBox(height: AppSpacing.space2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserTypeToggle() {
    return _buildTypeSegments(
      isAdmin: _isAdminLogin,
      withIcons: true,
      onChanged: (isAdmin) {
        setState(() {
          _isAdminLogin = isAdmin;
        });
      },
    );
  }

  Widget _buildRememberEmailCheckbox() {
    // 줄 전체가 눌리는 48 높이 — 체크 상자를 고정 크기 상자에 가두지 않아 글자가 커져도 넘치지 않는다.
    return InkWell(
      borderRadius: BorderRadius.circular(AppBorderRadius.control),
      onTap: () {
        setState(() {
          _rememberEmail = !_rememberEmail;
        });
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppSpacing.minTouchTarget,
        ),
        child: Row(
          children: [
            Checkbox(
              value: _rememberEmail,
              onChanged: (value) {
                setState(() {
                  _rememberEmail = value ?? false;
                });
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: AppSpacing.space1),
            Flexible(
              child: Text(
                '이메일 기억하기',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppSemanticColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 보조 링크 — 회색 상자 단추 대신 글자만. 주 행동(로그인)만 채움으로 남긴다.
  /// 틸 링크는 titleSmall(15/w600), 맨 아래 회색 링크는 [style]로 bodySmall(14)을 준다.
  Widget _buildTextLink({
    required String label,
    required VoidCallback onPressed,
    required Color color,
    TextStyle style = AppTypography.titleSmall,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space2,
          vertical: AppSpacing.space2,
        ),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      // textStyle을 버튼 스타일에 넣으면 테마의 서체(Pretendard)가 빠진다 — 글자에 직접 준다
      child: Text(label, style: style),
    );
  }

  Widget _buildBottomLinks() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildTextLink(
            label: '사용방법 보러가기',
            color: AppSemanticColors.textTertiary,
            style: AppTypography.bodySmall,
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
          Text(
            '·',
            style: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.textTertiary,
            ),
          ),
          _buildTextLink(
            label: '케어브이 웹사이트',
            color: AppSemanticColors.textTertiary,
            style: AppTypography.bodySmall,
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
    );
  }
}
