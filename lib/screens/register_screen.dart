import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/auth_provider.dart';
import '../providers/company_provider.dart';
import '../models/company.dart';
import '../utils/constants.dart';
import '../widgets/common/index.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'main_screen.dart';
import 'login_screen.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedRole = 'CAREGIVER';
  String _userType = 'employee'; // 'admin' 또는 'employee'
  Company? _selectedCompany; // 선택된 회사
  String? _companyErrorMessage;
  
  // 관리자 회원가입용 필드
  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();

  // 약관 동의 관련 변수
  bool _agreeToPrivacyPolicy = false;
  bool _agreeToTermsOfService = false;
  String? _agreementErrorMessage;

  @override
  void initState() {
    super.initState();
    // 화면 시작 시 회사 목록 로딩
    print("RegisterScreen initState called");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().loadCompanies();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _companyNameController.dispose();
    _companyAddressController.dispose();
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
              backgroundColor: AppSemanticColors.statusErrorIcon,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('링크 열기 중 오류가 발생했습니다'),
            backgroundColor: AppSemanticColors.statusErrorIcon,
          ),
        );
      }
    }
  }

  // 주소 찾기 메서드
  Future<void> _searchAddress() async {
    print('[RegisterScreen] ============ 주소 검색 시작 ============');
    
    // 우선 WebView 주소 검색 시도
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _AddressSearchScreen(),
        fullscreenDialog: true,
      ),
    );
    
    print('[RegisterScreen] 주소 검색 결과: "$result"');
    print('[RegisterScreen] 결과가 null인가: ${result == null}');
    print('[RegisterScreen] 결과가 비어있는가: ${result?.isEmpty}');
    
    if (result != null && result.isNotEmpty) {
      print('[RegisterScreen] 주소 설정: $result');
      setState(() {
        _companyAddressController.text = result;
      });
      print('[RegisterScreen] 주소 설정 완료');
    } else {
      print('[RegisterScreen] 결과가 없어서 수동 입력 다이얼로그 표시');
      // WebView가 작동하지 않는 경우 직접 입력 다이얼로그 표시
      _showManualAddressInput();
    }
  }

  // 관리자 회원가입 성공 다이얼로그
  void _showAdminRegistrationSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        ),
        backgroundColor: AppSemanticColors.surfaceDefault,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: AppSpacing.space12,
                height: AppSpacing.space12,
                decoration: BoxDecoration(
                  color: AppSemanticColors.statusSuccessBackground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: AppSemanticColors.statusSuccessIcon,
                  size: 30,
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
              Text(
                '회원가입 완료!',
                style: AppTypography.heading5.copyWith(
                  color: AppSemanticColors.statusSuccessIcon,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),
              Text(
                '관리자 계정이 성공적으로 생성되었습니다.\n로그인 화면에서 로그인해주세요.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppSemanticColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.space6),
              AppButton(
                text: '로그인 하러 가기',
                isFullWidth: true,
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 수동 주소 입력 다이얼로그
  Future<void> _showManualAddressInput() async {
    final result = await AppDialog.showInput(
      context,
      title: '회사 주소 입력',
      message: '주소 검색이 지원되지 않는 환경입니다.\n직접 회사 주소를 입력해주세요.',
      hintText: '예: 서울특별시 강남구 테헤란로 123',
      maxLines: 2,
    );
    
    if (result != null && result.isNotEmpty) {
      setState(() {
        _companyAddressController.text = result;
      });
    }
  }

  void _showEmployeeRegistrationPendingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        ),
        backgroundColor: AppSemanticColors.surfaceDefault,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: AppSpacing.space14,
                height: AppSpacing.space14,
                decoration: BoxDecoration(
                  color: AppSemanticColors.statusSuccessBackground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: AppSemanticColors.statusSuccessIcon,
                  size: 40,
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
              Text(
                '회원가입 요청 완료!',
                textAlign: TextAlign.center,
                style: AppTypography.heading5.copyWith(
                  color: AppSemanticColors.statusSuccessIcon,
                ),
              ),
              const SizedBox(height: AppSpacing.space3),
              AppStatusCard(
                status: AppStatusType.info,
                padding: const EdgeInsets.all(AppSpacing.space4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.admin_panel_settings,
                      color: AppSemanticColors.statusInfoIcon,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '관리자 승인 대기 중',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppSemanticColors.statusInfoText,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space1),
                          Text(
                            '회원가입 요청이 관리자에게 전달되었습니다.\n승인 완료 후 로그인이 가능합니다.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppSemanticColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space3),
              AppStatusCard(
                status: AppStatusType.warning,
                padding: const EdgeInsets.all(AppSpacing.space4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.email_outlined,
                      color: AppSemanticColors.statusWarningIcon,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '승인 결과 알림',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppSemanticColors.statusWarningText,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space1),
                          Text(
                            '승인 결과는 등록하신 이메일로 안내해 드리겠습니다.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppSemanticColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space6),
              AppButton(
                text: '로그인 화면으로 이동',
                isFullWidth: true,
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    // 직원인 경우 회사 선택 필수 검사
    if (_userType == 'employee' && _selectedCompany == null) {
      setState(() {
        _companyErrorMessage = '회사를 선택해주세요.';
      });
      return;
    }

    // 약관 동의 필수 검사
    if (!_agreeToPrivacyPolicy || !_agreeToTermsOfService) {
      setState(() {
        _agreementErrorMessage = '개인정보 처리방침과 서비스 이용약관에 모두 동의해주세요.';
      });
      return;
    }

    setState(() {
      _agreementErrorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();
    bool success;
    
    if (_userType == 'admin') {
      // 관리자 회원가입
      success = await authProvider.register(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
        'ADMIN', // 관리자 역할
        companyId: null, // 관리자는 회사 선택 없음
        companyName: _companyNameController.text.trim(),
        companyAddress: _companyAddressController.text.trim(),
      );
    } else {
      // 직원 회원가입 - 기존 로직
      success = await authProvider.register(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
        _selectedRole,
        companyId: _selectedCompany!.id, // 필수로 전달
      );
    }

    if (success && mounted) {
      if (_userType == 'admin') {
        // 관리자 회원가입 성공 - 완료 다이얼로그 표시 후 로그인 화면으로 이동
        _showAdminRegistrationSuccessDialog();
      } else {
        // 직원 회원가입 요청 성공 - 승인 대기 안내
        _showEmployeeRegistrationPendingDialog();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundSecondary,
      appBar: AppBar(
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        iconTheme: IconThemeData(color: AppSemanticColors.textInverse),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppSemanticColors.textInverse),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 제목
              Icon(Icons.person_add, size: 60, color: AppSemanticColors.statusInfoIcon),
              const SizedBox(height: Constants.defaultPadding),

              Text(
                '회원가입',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppSemanticColors.interactivePrimaryDefault,
                ),
              ),
              const SizedBox(height: Constants.smallPadding),

              Text(
                '새 계정을 만들어 시작하세요',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppSemanticColors.textSecondary),
              ),

              const SizedBox(height: 16),

              // 승인 프로세스 안내
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // 가입 프로세스 카드
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.white, AppSemanticColors.backgroundSecondary],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppSemanticColors.backgroundTertiary.withValues(alpha:0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            '회원가입 절차 안내',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppSemanticColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // 프로세스 그리드
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            children: [
                              _buildProcessCard(
                                '1',
                                '[관리자]',
                                '웹사이트 가입',
                                '근무표 관리자가 먼저 앱 또는 carev.kr에서 가입을 완료합니다.',
                                Icons.computer,
                                'from-blue-400 to-indigo-500',
                              ),
                              _buildProcessCard(
                                '2',
                                '[직원]',
                                '앱 가입 요청',
                                '직원은 앱에서 회원가입을 요청합니다.',
                                Icons.phone_android,
                                'from-indigo-400 to-purple-500',
                              ),
                              _buildProcessCard(
                                '3',
                                '[관리자]',
                                '가입 승인',
                                '관리자는 앱 또는 carev.kr에서 직원의 가입 요청을 확인하고 승인합니다.',
                                Icons.check_circle,
                                'from-green-400 to-teal-500',
                              ),
                              _buildProcessCard(
                                '4',
                                '[직원]',
                                '앱 로그인',
                                '관리자의 승인이 완료되면, 직원은 앱에 정상적으로 로그인할 수 있습니다.',
                                Icons.login,
                                'from-purple-400 to-pink-100',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 사용방법 버튼
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppSemanticColors.textTertiary, AppSemanticColors.statusWarningIcon],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppSemanticColors.textDisabled.withValues(alpha:0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: shadcn.GhostButton(
                        onPressed: () => _launchURL('https://youtu.be/x2cJedS6vaU'),
                        leading: const Icon(
                          Icons.play_circle_filled,
                          color: AppColors.white,
                          size: 24,
                        ),
                        child: const Text(
                          '사용방법 보러가기',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 회원가입 폼
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Constants.largePadding),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 사용자 유형 선택
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppSemanticColors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppSemanticColors.borderDefault,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.supervisor_account,
                                    color: AppSemanticColors.statusInfoIcon,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '가입 유형 선택',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppSemanticColors.interactivePrimaryDefault,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _userType = 'admin';
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: _userType == 'admin'
                                              ? AppSemanticColors.statusInfoIcon
                                              : AppColors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _userType == 'admin'
                                                ? AppSemanticColors.statusInfoIcon
                                                : AppSemanticColors.borderHover,
                                            width: 2,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.admin_panel_settings,
                                              color: _userType == 'admin'
                                                  ? AppColors.white
                                                  : AppSemanticColors.statusInfoIcon,
                                              size: 32,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '관리자',
                                              style: TextStyle(
                                                color: _userType == 'admin'
                                                    ? AppColors.white
                                                    : AppSemanticColors.statusInfoIcon,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '근무표 관리',
                                              style: TextStyle(
                                                color: _userType == 'admin'
                                                    ? AppSemanticColors.textInverse.withValues(alpha: 0.7)
                                                    : AppSemanticColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _userType = 'employee';
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: _userType == 'employee'
                                              ? AppSemanticColors.statusSuccessIcon
                                              : AppColors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _userType == 'employee'
                                                ? AppSemanticColors.statusSuccessIcon
                                                : AppSemanticColors.borderHover,
                                            width: 2,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.person,
                                              color: _userType == 'employee'
                                                  ? AppColors.white
                                                  : AppSemanticColors.statusSuccessIcon,
                                              size: 32,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '직원',
                                              style: TextStyle(
                                                color: _userType == 'employee'
                                                    ? AppColors.white
                                                    : AppSemanticColors.statusSuccessIcon,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '근무표 작성',
                                              style: TextStyle(
                                                color: _userType == 'employee'
                                                    ? AppSemanticColors.textInverse.withValues(alpha: 0.7)
                                                    : AppSemanticColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Constants.defaultPadding),

                        // 이름 입력
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: '이름',
                            hintText: '홍길동',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppSemanticColors.borderHover,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppSemanticColors.borderFocus,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '이름을 입력해주세요';
                            }
                            if (value.length < 2) {
                              return '이름은 2자 이상이어야 합니다';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: Constants.defaultPadding),

                        // 이메일 입력
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: '이메일',
                            hintText: 'example@company.com',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppSemanticColors.borderHover,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppSemanticColors.borderFocus,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '이메일을 입력해주세요';
                            }
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(value)) {
                              return '올바른 이메일 형식을 입력해주세요';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: Constants.defaultPadding),

                        // 역할 선택 (직원인 경우에만 표시)
                        if (_userType == 'employee') ...[
                          DropdownButtonFormField<String>(
                            value: _selectedRole,
                            decoration: InputDecoration(
                              labelText: '직원 유형',
                              prefixIcon: const Icon(Icons.work_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppSemanticColors.borderHover,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppSemanticColors.borderFocus,
                                ),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'CAREGIVER',
                                child: Text('요양보호사'),
                              ),
                              DropdownMenuItem(
                                value: 'OFFICE',
                                child: Text('사무실'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedRole = value!;
                              });
                            },
                          ),
                          const SizedBox(height: Constants.defaultPadding),
                        ],

                        // 회사 선택 (직원인 경우에만 표시)
                        if (_userType == 'employee') ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<Company?>(
                                value: _selectedCompany,
                                decoration: InputDecoration(
                                  labelText: '회사 *', // 필수 표시
                                  prefixIcon: const Icon(Icons.business_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: _companyErrorMessage != null
                                          ? AppSemanticColors.statusErrorBorder
                                          : AppSemanticColors.borderHover,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: _companyErrorMessage != null
                                          ? AppSemanticColors.statusErrorIcon
                                          : AppSemanticColors.borderFocus,
                                    ),
                                  ),
                                ),
                                hint: const Text('회사를 선택해주세요'),
                                // 선택된 항목을 표시할 때는 회사명만 보이도록
                                selectedItemBuilder: (BuildContext context) {
                                  return context
                                      .watch<CompanyProvider>()
                                      .companies
                                      .map((company) => DropdownMenuItem<Company?>(
                                            value: company,
                                            child: Text(
                                              company.name,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ))
                                      .toList();
                                },
                                items: context
                                    .watch<CompanyProvider>()
                                    .companies
                                    .map(
                                      (company) => DropdownMenuItem<Company?>(
                                        value: company,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              company.name,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (company.userEmails.isNotEmpty)
                                              Text(
                                                company.userEmails.first,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppSemanticColors.textSecondary,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCompany = value;
                                    _companyErrorMessage = null; // 에러 메시지 초기화
                                  });
                                },
                              ),
                              // 에러 메시지 표시
                              if (_companyErrorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    left: 12,
                                  ),
                                  child: Text(
                                    _companyErrorMessage!,
                                    style: TextStyle(
                                      color: AppSemanticColors.statusErrorIcon,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: Constants.defaultPadding),
                        ],

                        // 관리자인 경우 회사명 입력
                        if (_userType == 'admin') ...[
                          TextFormField(
                            controller: _companyNameController,
                            decoration: InputDecoration(
                              labelText: '회사명 *',
                              hintText: '케어브이 센터',
                              prefixIcon: const Icon(Icons.business),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppSemanticColors.borderHover,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppSemanticColors.borderFocus,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (_userType == 'admin' && (value == null || value.isEmpty)) {
                                return '회사명을 입력해주세요';
                              }
                              if (_userType == 'admin' && value!.length < 2) {
                                return '회사명은 2자 이상이어야 합니다';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: Constants.defaultPadding),
                          
                          // 회사 주소 입력
                          TextFormField(
                            controller: _companyAddressController,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: '회사 주소 *',
                              hintText: '주소를 검색해주세요',
                              prefixIcon: const Icon(Icons.location_on),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.search),
                                onPressed: _searchAddress,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppSemanticColors.borderHover,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: AppSemanticColors.borderFocus,
                                ),
                              ),
                            ),
                            onTap: _searchAddress,
                            validator: (value) {
                              if (_userType == 'admin' && (value == null || value.isEmpty)) {
                                return '회사 주소를 입력해주세요';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: Constants.defaultPadding),
                        ],

                        // 비밀번호 입력
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: '비밀번호',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppSemanticColors.borderHover,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppSemanticColors.borderFocus,
                              ),
                            ),
                          ),
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
                        const SizedBox(height: Constants.defaultPadding),

                        // 비밀번호 확인
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: '비밀번호 확인',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppSemanticColors.borderHover,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppSemanticColors.borderFocus,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '비밀번호를 다시 입력해주세요';
                            }
                            if (value != _passwordController.text) {
                              return '비밀번호가 일치하지 않습니다';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: Constants.largePadding),

                        // 약관 동의 섹션
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppSemanticColors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _agreementErrorMessage != null
                                  ? AppSemanticColors.statusErrorBorder
                                  : AppSemanticColors.borderDefault,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.gavel,
                                    color: AppSemanticColors.statusInfoIcon,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '약관 동의',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppSemanticColors.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '(필수)',
                                    style: TextStyle(
                                      color: AppSemanticColors.statusErrorIcon,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 개인정보 처리방침 동의
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _agreeToPrivacyPolicy =
                                        !_agreeToPrivacyPolicy;
                                    if (_agreeToPrivacyPolicy &&
                                        _agreeToTermsOfService) {
                                      _agreementErrorMessage = null;
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: _agreeToPrivacyPolicy
                                                ? AppSemanticColors.statusInfoIcon
                                                : AppSemanticColors.textDisabled,
                                            width: 2,
                                          ),
                                          color: _agreeToPrivacyPolicy
                                              ? AppSemanticColors.statusInfoIcon
                                              : AppColors.transparent,
                                        ),
                                        child: _agreeToPrivacyPolicy
                                            ? const Icon(
                                                Icons.check,
                                                color: AppColors.white,
                                                size: 14,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text: '개인정보 처리방침',
                                                style: TextStyle(
                                                  color: AppSemanticColors.textPrimary,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              TextSpan(
                                                text: '에 동의합니다',
                                                style: TextStyle(
                                                  color: AppSemanticColors.textSecondary,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => _launchURL(
                                          'https://plip.kr/pcc/d9017bf3-00dc-4f8f-b750-f7668e2b7bb7/privacy/1.html',
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppSemanticColors.backgroundSecondary,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: AppSemanticColors.borderDefault,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            '보기',
                                            style: TextStyle(
                                              color: AppSemanticColors.textSecondary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // 서비스 이용약관 동의
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _agreeToTermsOfService =
                                        !_agreeToTermsOfService;
                                    if (_agreeToPrivacyPolicy &&
                                        _agreeToTermsOfService) {
                                      _agreementErrorMessage = null;
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: _agreeToTermsOfService
                                                ? AppSemanticColors.statusInfoIcon
                                                : AppSemanticColors.textDisabled,
                                            width: 2,
                                          ),
                                          color: _agreeToTermsOfService
                                              ? AppSemanticColors.statusInfoIcon
                                              : AppColors.transparent,
                                        ),
                                        child: _agreeToTermsOfService
                                            ? const Icon(
                                                Icons.check,
                                                color: AppColors.white,
                                                size: 14,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text: '서비스 이용약관',
                                                style: TextStyle(
                                                  color: AppSemanticColors.textPrimary,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              TextSpan(
                                                text: '에 동의합니다',
                                                style: TextStyle(
                                                  color: AppSemanticColors.textSecondary,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => _launchURL(
                                          'https://relic-baboon-412.notion.site/silverithm-13c766a8bb468082b91ddbd2dd6ce45d',
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppSemanticColors.backgroundSecondary,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: AppSemanticColors.borderDefault,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            '보기',
                                            style: TextStyle(
                                              color: AppSemanticColors.textSecondary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // 전체 동의 체크박스
                              const SizedBox(height: 12),
                              Container(height: 1, color: AppSemanticColors.borderHover),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: () {
                                  final newValue =
                                      !(_agreeToPrivacyPolicy &&
                                          _agreeToTermsOfService);
                                  setState(() {
                                    _agreeToPrivacyPolicy = newValue;
                                    _agreeToTermsOfService = newValue;
                                    if (newValue) {
                                      _agreementErrorMessage = null;
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color:
                                                (_agreeToPrivacyPolicy &&
                                                    _agreeToTermsOfService)
                                                ? AppSemanticColors.statusSuccessIcon
                                                : AppSemanticColors.textDisabled,
                                            width: 2,
                                          ),
                                          color:
                                              (_agreeToPrivacyPolicy &&
                                                  _agreeToTermsOfService)
                                              ? AppSemanticColors.statusSuccessIcon
                                              : AppColors.transparent,
                                        ),
                                        child:
                                            (_agreeToPrivacyPolicy &&
                                                _agreeToTermsOfService)
                                            ? const Icon(
                                                Icons.check,
                                                color: AppColors.white,
                                                size: 14,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '위 약관에 모두 동의합니다',
                                        style: TextStyle(
                                          color: AppSemanticColors.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // 에러 메시지
                              if (_agreementErrorMessage != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: AppSemanticColors.statusErrorIcon,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _agreementErrorMessage!,
                                        style: TextStyle(
                                          color: AppSemanticColors.statusErrorIcon,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: Constants.largePadding),

                        // 회원가입 버튼
                        Consumer<AuthProvider>(
                          builder: (context, authProvider, child) {
                            final isFormValid =
                                _agreeToPrivacyPolicy && _agreeToTermsOfService;

                            return shadcn.PrimaryButton(
                              onPressed:
                                  (authProvider.isLoading || !isFormValid)
                                  ? null
                                  : _handleRegister,
                              child: authProvider.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.white,
                                            ),
                                      ),
                                    )
                                  : Text(
                                      isFormValid ? '회원가입' : '약관 동의 후 회원가입 가능',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            );
                          },
                        ),

                        // 에러 메시지
                        Consumer<AuthProvider>(
                          builder: (context, authProvider, child) {
                            if (authProvider.errorMessage.isNotEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  top: Constants.defaultPadding,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppSemanticColors.statusErrorBackground,
                                    border: Border.all(
                                      color: AppSemanticColors.statusErrorBorder,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: AppSemanticColors.statusErrorIcon,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          authProvider.errorMessage,
                                          style: TextStyle(
                                            color: AppSemanticColors.statusErrorText,
                                            fontSize: 14,
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
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProcessStep(
    String step,
    String description,
    Color color,
    bool isActive,
  ) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? color : AppColors.white,
              border: Border.all(
                color: isActive ? color : AppSemanticColors.borderHover,
                width: 2,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha:0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isActive ? AppColors.white : AppSemanticColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? color : AppSemanticColors.textSecondary,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProcessCard(
    String step,
    String role,
    String title,
    String description,
    IconData icon,
    String gradientColors,
  ) {
    final colors = _getGradientColors(gradientColors);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppSemanticColors.borderDefault),
        boxShadow: [
          BoxShadow(
            color: AppSemanticColors.borderDefault,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    step,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors[0].withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  role,
                  style: TextStyle(
                    color: colors[1],
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                description,
                style: TextStyle(
                  color: AppSemanticColors.textSecondary,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getGradientColors(String gradientString) {
    switch (gradientString) {
      case 'from-blue-400 to-indigo-500':
        return [AppSemanticColors.interactivePrimaryActive, AppSemanticColors.borderFocus];
      case 'from-indigo-400 to-purple-500':
        return [AppSemanticColors.interactivePrimaryDefault, AppSemanticColors.interactivePrimaryActive];
      case 'from-green-400 to-teal-500':
        return [AppSemanticColors.statusSuccessIcon, AppSemanticColors.statusSuccessIcon];
      case 'from-purple-400 to-pink-500':
        return [AppSemanticColors.interactivePrimaryActive, AppSemanticColors.statusErrorBackground];
      default:
        return [AppSemanticColors.interactivePrimaryActive, AppSemanticColors.statusInfoIcon];
    }
  }
}

// 주소 검색 화면
class _AddressSearchScreen extends StatefulWidget {
  @override
  State<_AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<_AddressSearchScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController();
    
    // 1단계: 기본 설정
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.white)
      ..enableZoom(false);
    
    // 2단계: JavaScript Channel 추가
    _controller.addJavaScriptChannel(
      'AddressChannel',
      onMessageReceived: (JavaScriptMessage message) {
        print('[AddressSearch] ============ 메시지 수신 ============');
        print('[AddressSearch] 수신된 메시지: "${message.message}"');
        print('[AddressSearch] 메시지 길이: ${message.message.length}');
        print('[AddressSearch] mounted 상태: $mounted');
        
        if (message.message == 'MANUAL_INPUT') {
          print('[AddressSearch] 수동 입력 요청 - WebView 닫기');
          Navigator.of(context).pop(); // WebView 닫기
        } else if (message.message.isNotEmpty) {
          print('[AddressSearch] 주소 선택 완료 - 결과와 함께 닫기');
          Navigator.of(context).pop(message.message);
        } else {
          print('[AddressSearch] 빈 메시지 - 결과 없이 닫기');
          Navigator.of(context).pop();
        }
      },
    );
    
    // 3단계: Navigation Delegate 설정
    _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (String url) {
          print('[AddressSearch] 페이지 로드 시작: $url');
        },
        onPageFinished: (String url) {
          print('[AddressSearch] 페이지 로드 완료: $url');
          
          // HTML 페이지가 로드된 후 JavaScript 채널 확인
          if (url.startsWith('data:text/html')) {
            print('[AddressSearch] HTML 페이지 로드 완료 - JavaScript 채널 테스트');
            _controller.runJavaScript('''
              console.log('JavaScript 실행 테스트');
              console.log('window.AddressChannel 존재:', !!window.AddressChannel);
              setTimeout(function() {
                console.log('1초 후 window.AddressChannel 존재:', !!window.AddressChannel);
              }, 1000);
            ''');
          }
        },
        onWebResourceError: (WebResourceError error) {
          print('[AddressSearch] 리소스 에러: ${error.description}');
        },
      ),
    );
    
    // 4단계: HTML 로드
    print('[AddressSearch] HTML 로드 시작');
    _controller.loadHtmlString(
      _getAddressSearchHtml(),
      baseUrl: 'https://postcode.map.daum.net/',
    );
  }

  String _getAddressSearchHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>주소 검색</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { width: 100%; height: 100vh; overflow: hidden; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
        #layer { width: 100%; height: 100%; }
        #loading { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); text-align: center; z-index: 1000; }
        .spinner { width: 40px; height: 40px; border: 3px solid #f3f3f3; border-top: 3px solid #3498db; border-radius: 50%; animation: spin 1s linear infinite; margin: 0 auto 16px; }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
        #error { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); text-align: center; padding: 20px; background: #f8f9fa; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); display: none; }
        .retry-btn { background: #3498db; color: white; border: none; padding: 12px 24px; border-radius: 6px; font-size: 16px; cursor: pointer; margin: 8px; }
    </style>
</head>
<body>
    <div id="loading">
        <div class="spinner"></div>
        <div>주소 검색을 불러오는 중...</div>
    </div>
    
    <div id="error">
        <div>⚠️</div>
        <div>주소 검색을 불러올 수 없습니다</div>
        <button class="retry-btn" onclick="retryLoad()">다시 시도</button>
        <button class="retry-btn" onclick="useManualInput()">직접 입력</button>
    </div>
    
    <div id="layer"></div>
    
    <script>
        console.log('=== 주소 검색 스크립트 시작 ===');
        console.log('window.AddressChannel 초기 상태:', !!window.AddressChannel);
        
        // AddressChannel 대기 함수
        function waitForAddressChannel() {
            return new Promise((resolve) => {
                if (window.AddressChannel) {
                    console.log('AddressChannel 즉시 사용 가능');
                    resolve();
                    return;
                }
                
                let attempts = 0;
                const maxAttempts = 50; // 5초간 대기
                
                const checkChannel = () => {
                    attempts++;
                    console.log('AddressChannel 확인 시도:', attempts, '/', maxAttempts);
                    
                    if (window.AddressChannel) {
                        console.log('AddressChannel 발견!');
                        resolve();
                    } else if (attempts < maxAttempts) {
                        setTimeout(checkChannel, 100);
                    } else {
                        console.error('AddressChannel을 찾을 수 없음');
                        resolve(); // 계속 진행
                    }
                };
                
                checkChannel();
            });
        }
        
        let retryCount = 0;
        const maxRetries = 3;
        
        function hideLoading() {
            const loading = document.getElementById('loading');
            if (loading) loading.style.display = 'none';
        }
        
        function showError() {
            hideLoading();
            const error = document.getElementById('error');
            if (error) error.style.display = 'block';
        }
        
        function sendMessage(message) {
            console.log('메시지 전송 시도:', message);
            try {
                if (window.AddressChannel && window.AddressChannel.postMessage) {
                    window.AddressChannel.postMessage(message);
                    console.log('메시지 전송 성공');
                } else {
                    console.error('AddressChannel 없음');
                }
            } catch (error) {
                console.error('메시지 전송 오류:', error);
            }
        }
        
        async function initPostcode() {
            try {
                console.log('다음 우편번호 API 초기화 시작');
                
                // AddressChannel이 준비될 때까지 대기
                await waitForAddressChannel();
                
                const postcode = new daum.Postcode({
                    oncomplete: function(data) {
                        console.log('=== 주소 선택 완료 ===');
                        console.log('선택된 데이터:', data);
                        
                        let addr = data.userSelectedType === 'R' ? data.roadAddress : data.jibunAddress;
                        
                        // 상세주소 추가
                        if (data.userSelectedType === 'R') {
                            let extraAddr = '';
                            if (data.bname && /[동|로|가]\$/g.test(data.bname)) {
                                extraAddr += data.bname;
                            }
                            if (data.buildingName && data.apartment === 'Y') {
                                extraAddr += (extraAddr ? ', ' + data.buildingName : data.buildingName);
                            }
                            if (extraAddr) {
                                addr += ' (' + extraAddr + ')';
                            }
                        }
                        
                        console.log('최종 주소:', addr);
                        sendMessage(addr);
                    },
                    onclose: function(state) {
                        console.log('주소 창 닫힘:', state);
                        if (state === 'FORCE_CLOSE') {
                            sendMessage('');
                        }
                    },
                    width: '100%',
                    height: '100%'
                });
                
                postcode.embed('layer');
                hideLoading();
                console.log('우편번호 서비스 초기화 완료');
                
            } catch (error) {
                console.error('초기화 오류:', error);
                showError();
            }
        }
        
        function loadScript(src) {
            return new Promise((resolve, reject) => {
                const script = document.createElement('script');
                script.onload = resolve;
                script.onerror = reject;
                script.src = src;
                document.head.appendChild(script);
            });
        }
        
        async function loadDaumAPI() {
            try {
                console.log('Daum API 로드 시도:', retryCount + 1);
                await loadScript('https://t1.daumcdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js');
                
                if (typeof daum !== 'undefined' && daum.Postcode) {
                    console.log('Daum API 로드 성공');
                    initPostcode();
                } else {
                    throw new Error('Daum API 로드 실패');
                }
            } catch (error) {
                console.error('API 로드 오류:', error);
                retryCount++;
                
                if (retryCount < maxRetries) {
                    console.log('재시도:', retryCount, '/', maxRetries);
                    setTimeout(loadDaumAPI, 1000);
                } else {
                    console.error('최대 재시도 초과');
                    showError();
                }
            }
        }
        
        function retryLoad() {
            retryCount = 0;
            document.getElementById('error').style.display = 'none';
            document.getElementById('loading').style.display = 'block';
            loadDaumAPI();
        }
        
        function useManualInput() {
            sendMessage('MANUAL_INPUT');
        }
        
        // 페이지 로드 완료 후 시작
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', loadDaumAPI);
        } else {
            loadDaumAPI();
        }
    </script>
</body>
</html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text(
          '주소 검색',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppSemanticColors.textInverse,
          ),
        ),
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        foregroundColor: AppSemanticColors.textInverse,
        iconTheme: IconThemeData(color: AppSemanticColors.textInverse),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
