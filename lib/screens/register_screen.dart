import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/company_provider.dart';
import '../models/company.dart';
import '../utils/constants.dart';
import '../widgets/common/index.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

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
  Company? _selectedCompany; // 선택된 회사
  String? _companyErrorMessage;

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

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    // 회사 선택 필수 검사
    if (_selectedCompany == null) {
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
    final success = await authProvider.register(
      _emailController.text.trim(),
      _passwordController.text,
      _nameController.text.trim(),
      _selectedRole,
      companyId: _selectedCompany!.id, // 필수로 전달
    );

    if (success && mounted) {
      // 회원가입 요청 성공 - 승인 대기 안내
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.green.shade50],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 성공 아이콘
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.shade300.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 제목
                  Text(
                    '회원가입 요청 완료!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // 승인 대기 설명
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200, width: 1),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.admin_panel_settings,
                              color: Colors.blue.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '관리자 승인 대기 중',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '회원가입 요청이 관리자에게 전달되었습니다.\n승인 완료 후 로그인이 가능합니다.',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 13,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 알림 방법 안내
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.shade200,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              color: Colors.orange.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '승인 결과 알림',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '승인 결과는 등록하신 이메일로\n안내해 드리겠습니다.',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 13,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 확인 버튼
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade300.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // 다이얼로그 닫기
                        Navigator.of(context).pop(); // 회원가입 화면 닫기 (로그인 화면으로 이동)
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '로그인 화면으로 이동',
                        style: TextStyle(
                          color: Colors.white,
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
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Constants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 제목
              Icon(Icons.person_add, size: 60, color: Colors.blue.shade600),
              const SizedBox(height: Constants.defaultPadding),

              Text(
                '회원가입',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              const SizedBox(height: Constants.smallPadding),

              Text(
                '새 계정을 만들어 시작하세요',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
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
                          colors: [Colors.white, Colors.blue.shade50],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade100.withOpacity(0.5),
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
                              color: Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // 프로세스 그리드
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            children: [
                              _buildProcessCard(
                                '1',
                                '[관리자]',
                                '웹사이트 가입',
                                '근무표 관리자가 먼저 carev.kr에서 회사 정보를 등록하며 가입을 완료합니다.',
                                Icons.computer,
                                'from-blue-400 to-indigo-500',
                              ),
                              _buildProcessCard(
                                '2',
                                '[직원]',
                                '앱 가입 요청',
                                '직원은 앱에서 가입 시, 등록된 소속 회사를 선택하고 가입을 요청합니다.',
                                Icons.phone_android,
                                'from-indigo-400 to-purple-500',
                              ),
                              _buildProcessCard(
                                '3',
                                '[관리자]',
                                '가입 승인',
                                '관리자는 carev.kr에서(회원 관리) 직원의 가입 요청을 확인하고 승인합니다.',
                                Icons.check_circle,
                                'from-green-400 to-teal-500',
                              ),
                              _buildProcessCard(
                                '4',
                                '[직원]',
                                '앱 로그인',
                                '관리자의 승인이 완료되면, 직원은 앱에 정상적으로 로그인할 수 있습니다.',
                                Icons.login,
                                'from-purple-400 to-pink-500',
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
                          colors: [Colors.orange.shade400, Colors.orange.shade600],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.shade300.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextButton.icon(
                        onPressed: () => _launchURL('https://youtu.be/x2cJedS6vaU'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(
                          Icons.play_circle_filled,
                          color: Colors.white,
                          size: 24,
                        ),
                        label: const Text(
                          '사용방법 보러가기',
                          style: TextStyle(
                            color: Colors.white,
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
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.blue.shade500,
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
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.blue.shade500,
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

                        // 역할 선택
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
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.blue.shade500,
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

                        // 회사 선택
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
                                        ? Colors.red.shade300
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _companyErrorMessage != null
                                        ? Colors.red.shade500
                                        : Colors.blue.shade500,
                                  ),
                                ),
                              ),
                              hint: const Text('회사를 선택해주세요'),
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
                                                color: Colors.grey.shade600,
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
                                    color: Colors.red.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: Constants.defaultPadding),

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
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.blue.shade500,
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
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.blue.shade500,
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
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _agreementErrorMessage != null
                                  ? Colors.red.shade300
                                  : Colors.grey.shade200,
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
                                    color: Colors.blue.shade600,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '약관 동의',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '(필수)',
                                    style: TextStyle(
                                      color: Colors.red.shade600,
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
                                                ? Colors.blue.shade600
                                                : Colors.grey.shade400,
                                            width: 2,
                                          ),
                                          color: _agreeToPrivacyPolicy
                                              ? Colors.blue.shade600
                                              : Colors.transparent,
                                        ),
                                        child: _agreeToPrivacyPolicy
                                            ? const Icon(
                                                Icons.check,
                                                color: Colors.white,
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
                                                  color: Colors.grey.shade700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              TextSpan(
                                                text: '에 동의합니다',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
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
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: Colors.blue.shade200,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            '보기',
                                            style: TextStyle(
                                              color: Colors.blue.shade700,
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
                                                ? Colors.blue.shade600
                                                : Colors.grey.shade400,
                                            width: 2,
                                          ),
                                          color: _agreeToTermsOfService
                                              ? Colors.blue.shade600
                                              : Colors.transparent,
                                        ),
                                        child: _agreeToTermsOfService
                                            ? const Icon(
                                                Icons.check,
                                                color: Colors.white,
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
                                                  color: Colors.grey.shade700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              TextSpan(
                                                text: '에 동의합니다',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
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
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: Colors.blue.shade200,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            '보기',
                                            style: TextStyle(
                                              color: Colors.blue.shade700,
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
                              Container(height: 1, color: Colors.grey.shade300),
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
                                                ? Colors.green.shade600
                                                : Colors.grey.shade400,
                                            width: 2,
                                          ),
                                          color:
                                              (_agreeToPrivacyPolicy &&
                                                  _agreeToTermsOfService)
                                              ? Colors.green.shade600
                                              : Colors.transparent,
                                        ),
                                        child:
                                            (_agreeToPrivacyPolicy &&
                                                _agreeToTermsOfService)
                                            ? const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 14,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '위 약관에 모두 동의합니다',
                                        style: TextStyle(
                                          color: Colors.grey.shade800,
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
                                      color: Colors.red.shade600,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _agreementErrorMessage!,
                                        style: TextStyle(
                                          color: Colors.red.shade600,
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

                            return ElevatedButton(
                              onPressed:
                                  (authProvider.isLoading || !isFormValid)
                                  ? null
                                  : _handleRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFormValid
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade400,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: isFormValid ? 2 : 0,
                              ),
                              child: authProvider.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
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
                                    color: Colors.red.shade50,
                                    border: Border.all(
                                      color: Colors.red.shade200,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: Colors.red.shade600,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          authProvider.errorMessage,
                                          style: TextStyle(
                                            color: Colors.red.shade700,
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
              color: isActive ? color : Colors.white,
              border: Border.all(
                color: isActive ? color : Colors.grey.shade300,
                width: 2,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.3),
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
                  color: isActive ? Colors.white : Colors.grey.shade600,
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
              color: isActive ? color : Colors.grey.shade600,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
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
                      color: Colors.white,
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
                  color: colors[0].withOpacity(0.1),
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
          Icon(
            icon,
            size: 32,
            color: colors[0],
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
                  color: Colors.grey.shade600,
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
        return [Colors.blue.shade400, Colors.indigo.shade500];
      case 'from-indigo-400 to-purple-500':
        return [AppSemanticColors.interactivePrimaryDefault, AppSemanticColors.interactiveSecondaryDefault];
      case 'from-green-400 to-teal-500':
        return [Colors.green.shade400, Colors.teal.shade500];
      case 'from-purple-400 to-pink-500':
        return [AppSemanticColors.interactiveSecondaryDefault, AppSemanticColors.statusErrorBackground];
      default:
        return [Colors.blue.shade400, Colors.blue.shade600];
    }
  }
}
