import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../models/subscription.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'main_screen.dart';

class AdminPaymentScreen extends StatefulWidget {
  const AdminPaymentScreen({super.key});

  @override
  State<AdminPaymentScreen> createState() => _AdminPaymentScreenState();
}

class _AdminPaymentScreenState extends State<AdminPaymentScreen> {
  bool _isProcessing = false;
  SubscriptionPlan? _selectedPlan;
  bool _agreeToTerms = false;
  WebViewController? _webViewController;
  String? _paymentUrl;

  @override
  void initState() {
    super.initState();
    _loadAvailablePlans();
  }

  void _loadAvailablePlans() {
    final plans = SubscriptionPlan.getAvailablePlans();
    // 관리자는 기본적으로 Basic 플랜 선택
    _selectedPlan = plans.firstWhere(
      (plan) => plan.type == SubscriptionType.BASIC,
      orElse: () => plans.first,
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundSecondary,
      appBar: AppBar(
        title: Text(
          '구독 결제',
          style: AppTypography.heading6.copyWith(
            fontWeight: FontWeight.bold,
            color: AppSemanticColors.textInverse,
          ),
        ),
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        foregroundColor: AppSemanticColors.textInverse,
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer2<AuthProvider, SubscriptionProvider>(
        builder: (context, authProvider, subscriptionProvider, child) {
          if (_selectedPlan == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPlanSummary(),
                const SizedBox(height: 32),
                _buildCompanyInfo(authProvider),
                const SizedBox(height: 32),
                _buildPaymentInfo(),
                const SizedBox(height: 32),
                _buildTermsAgreement(),
                const SizedBox(height: 24),
                _buildPaymentButton(subscriptionProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlanSummary() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppSemanticColors.interactivePrimaryDefault,
            AppSemanticColors.interactivePrimaryDefault.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppSemanticColors.interactivePrimaryDefault.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppSemanticColors.textInverse.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.workspace_premium,
                  color: AppSemanticColors.textInverse,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedPlan!.name,
                      style: AppTypography.heading5.copyWith(
                        color: AppSemanticColors.textInverse,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedPlan!.description,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppSemanticColors.textInverse.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppSemanticColors.textInverse.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '월 구독료',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppSemanticColors.textInverse,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '₩${_formatPrice(_selectedPlan!.price)}',
                  style: AppTypography.heading4.copyWith(
                    color: AppSemanticColors.textInverse,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyInfo(AuthProvider authProvider) {
    final company = authProvider.currentUser?.company;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '결제 회사 정보',
            style: AppTypography.heading6.copyWith(
              color: AppSemanticColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('회사명', company?.name ?? ''),
          _buildInfoRow('관리자', authProvider.currentUser?.name ?? ''),
          _buildInfoRow('결제 일시', _getCurrentDateTime()),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '결제 정보',
            style: AppTypography.heading6.copyWith(
              color: AppSemanticColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('플랜', _selectedPlan!.name),
          _buildInfoRow('결제 주기', '매월 자동결제'),
          _buildInfoRow('다음 결제일', _getNextPaymentDate()),
          const Divider(height: 24),
          _buildInfoRow(
            '결제 금액', 
            '₩${_formatPrice(_selectedPlan!.price)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }




  Widget _buildTermsAgreement() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '서비스 이용약관',
            style: AppTypography.heading6.copyWith(
              color: AppSemanticColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 150,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppSemanticColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppSemanticColors.borderSubtle),
            ),
            child: SingleChildScrollView(
              child: Text(
                '''제1조 (목적)
본 약관은 실버리즘(이하 "회사")가 제공하는 서비스의 이용과 관련하여 일정 기간 서비스 이용을 보장하는 회사의 정기 구독 서비스(이하 "정기 구독 서비스")에 가입 및 결제한 회원(이하 "구독자") 사이의 권리, 의무 및 책임사항, 기타 필요한 사항을 규정하는 것을 목적으로 합니다.

제2조 (용어의 정의)
본 약관에서 사용하는 주요 용어의 정의는 실버리즘 서비스 이용약관을 따릅니다.

제3조 (정기 구독 서비스 가입과 결제방식)
회원은 정기 구독 서비스에 가입하기 위하여 사이트 내 버튼을 클릭하여 정기 구독 서비스 가입 화면인 "요금제 – 결제 페이지"(이하 "요금제 안내 화면")에서 가입할 수 있습니다.

제4조 (구독중 생성된 콘텐츠의 유효기간)
구독자가 구독 중 생성한 콘텐츠의 유효기간은 구독기간 내에 한하며, 사용자의 구독 콘텐츠 이용 시 이를 고지합니다.

제5조 (정기 구독 서비스 해지 방법)
구독자는 특별한 구독 해지 방법이 있지 아니하고, 구매한 구독기간 만큼 구독서비스를 제공받을 수 있습니다.

제6조 (구독 철회 및 환불)
구독자는 구독 시작일 이후 정기 구독 서비스를 1회라도 사용했거나 구독 시작일 이후 7일이 지난 경우 구독을 철회할 수 없습니다.

제7조 (구독제 변경 및 중단)
회사는 구독자의 구독 혜택을 유지하기 위해 합리적으로 운영을 지속할 의무가 있습니다.

제8조 (구독 요금)
"정기 구독 서비스"의 월 이용요금의 구체적인 내용은 (주)실버리즘 홈페이지 내 게재하며, 구독 요금은 회사의 요금정책에 따라 변경될 수 있습니다.''',
                style: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _agreeToTerms,
                  onChanged: (value) {
                    setState(() {
                      _agreeToTerms = value ?? false;
                    });
                  },
                  activeColor: AppSemanticColors.interactivePrimaryDefault,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '위 서비스 이용약관에 동의합니다.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButton(SubscriptionProvider subscriptionProvider) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: shadcn.PrimaryButton(
            onPressed: _isProcessing || subscriptionProvider.isLoading || !_agreeToTerms
                ? null
                : _processPayment,
            child: _isProcessing || subscriptionProvider.isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppSemanticColors.textInverse),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '결제 진행 중...',
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppSemanticColors.textInverse,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : Text(
                    _agreeToTerms
                      ? '₩${_formatPrice(_selectedPlan!.price)} 결제하기'
                      : '약관에 동의해주세요',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppSemanticColors.textInverse,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '결제 시 이용약관과 개인정보처리방침에 동의한 것으로 간주됩니다.',
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(
            color: AppSemanticColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppSemanticColors.statusSuccessBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppSemanticColors.statusSuccessBorder),
          ),
          child: Row(
            children: [
              Icon(
                Icons.security,
                color: AppSemanticColors.statusSuccessIcon,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Center(
                  child: Text(
                    '토스페이먼츠를 통한 안전한 결제',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppSemanticColors.statusSuccessText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: isTotal 
                ? AppSemanticColors.textPrimary 
                : AppSemanticColors.textSecondary,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textPrimary,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  String _getCurrentDateTime() {
    final now = DateTime.now();
    return '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _getNextPaymentDate() {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, now.day);
    return '${nextMonth.year}.${nextMonth.month.toString().padLeft(2, '0')}.${nextMonth.day.toString().padLeft(2, '0')}';
  }

  String _generateOrderId() {
    return 'order_${DateTime.now().millisecondsSinceEpoch}';
  }

  void _processPayment() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final orderId = _generateOrderId();
      final amount = _selectedPlan!.price;
      
      // 토스페이먼츠 결제 URL 생성
      final paymentUrl = await _createTossPayment(
        orderId: orderId,
        amount: amount,
        orderName: '${_selectedPlan!.name} 구독',
        customerName: authProvider.currentUser?.name ?? '관리자',
        customerEmail: StorageService().getSavedUserData()?['userEmail'] ?? '',
      );
      
      if (paymentUrl != null) {
        // WebView로 결제 진행
        await _showPaymentWebView(paymentUrl, orderId);
      } else {
        _showErrorDialog('결제 URL 생성에 실패했습니다.');
      }
      
    } catch (e) {
      print('[Payment] 결제 처리 중 오류: $e');
      _showErrorDialog('결제 처리 중 오류가 발생했습니다: ${e.toString()}');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }


  Future<String?> _createTossPayment({
    required String orderId,
    required int amount,
    required String orderName,
    required String customerName,
    required String customerEmail,
  }) async {
    try {
      final clientKey = dotenv.env['TOSS_PAYMENTS_CLIENT_KEY'];
      
      if (clientKey == null) {
        throw Exception('토스페이먼츠 CLIENT KEY가 설정되지 않았습니다.');
      }
      
      // 저장된 사용자 데이터에서 customerKey와 이메일 가져오기
      final userData = StorageService().getSavedUserData();
      final customerKey = userData?['customerKey'] ?? '';
      final userEmail = userData?['userEmail'] ?? '';
      
      print('[Payment] 사용할 customerKey: $customerKey');
      print('[Payment] 사용자 데이터: ${userData?['userName']} ($userEmail)');
      
      // 토스페이먼츠 v1 빌링 인증 페이지 HTML 생성 (frontend-admin과 동일)
      final billingAuthHtml = '''
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>결제</title>
    <script src="https://js.tosspayments.com/v1/payment"></script>
</head>
<body>
    <div style="padding: 20px; text-align: center;">
        <h2>결제 정보를 입력해주세요</h2>
        <p>안전한 결제를 위해 카드 정보를 등록합니다.</p>
        <div id="loading" style="margin: 20px;">
            <div style="border: 3px solid #f3f3f3; border-top: 3px solid #3498db; border-radius: 50%; width: 40px; height: 40px; animation: spin 2s linear infinite; margin: 0 auto;"></div>
            <p id="status">결제 모듈을 불러오는 중...</p>
        </div>
    </div>
    <style>
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
    </style>
    <script>
        // Console 로그를 Flutter로 전송하는 함수
        function logToFlutter(message) {
            if (window.Console && window.Console.postMessage) {
                window.Console.postMessage(message);
            }
            console.log(message);
        }
        
        async function loadPayment() {
            try {
                logToFlutter('결제 시작 - customerKey: $customerKey');
                document.getElementById('status').textContent = '토스페이먼츠 SDK 로딩 중...';
                
                // 토스페이먼츠 v1 SDK 로드 확인 (frontend-admin과 동일)
                if (!window.TossPayments) {
                    throw new Error('토스페이먼츠 v1 SDK가 로드되지 않았습니다.');
                }
                
                logToFlutter('토스페이먼츠 v1 SDK 로드 완료');
                document.getElementById('status').textContent = '결제 모듈 초기화 중...';
                
                const tossPayments = TossPayments('$clientKey');
                logToFlutter('토스페이먼츠 객체 생성 완료');
                
                document.getElementById('status').textContent = '빌링 인증 요청 중...';
                
                // v1 빌링 인증 요청 (frontend-admin과 동일한 방식)
                logToFlutter('빌링 인증 요청 시작');
                await tossPayments.requestBillingAuth('카드', {
                    customerKey: '$customerKey',
                    successUrl: 'https://silverithm.site/payment/success',
                    failUrl: 'https://silverithm.site/payment/fail',
                });
                
                logToFlutter('빌링 인증 요청 완료');
            } catch (error) {
                logToFlutter('결제 오류: ' + error.toString());
                document.getElementById('status').textContent = '결제 중 오류가 발생했습니다: ' + error.message;
                
                setTimeout(() => {
                    window.location.href = 'https://silverithm.site/payment/fail?error=' + encodeURIComponent(error.message);
                }, 2000);
            }
        }
        
        // 페이지 로드 후 결제 시작
        window.onload = function() {
            logToFlutter('페이지 로드 완료, 결제 시작');
            setTimeout(loadPayment, 500); // 0.5초 후 시작
        };
    </script>
</body>
</html>
      ''';
      
      return 'data:text/html;charset=utf-8,${Uri.encodeComponent(billingAuthHtml)}';
    } catch (e) {
      print('[Payment] 토스페이먼츠 빌링 인증 페이지 생성 오류: $e');
      return null;
    }
  }
  
  Future<void> _showPaymentWebView(String paymentUrl, String orderId) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>?>(
      MaterialPageRoute(
        builder: (context) => _PaymentWebViewScreen(
          paymentUrl: paymentUrl,
          orderId: orderId,
        ),
        fullscreenDialog: true,
      ),
    );
    
    if (result != null && result['status'] == 'success') {
      // 빌링 인증 성공 시 authKey를 받아서 처리
      final authKey = result['authKey'] ?? '';
      await _createSubscriptionAfterPayment(authKey, orderId);
    } else if (result != null && result['status'] == 'fail') {
      _showErrorDialog('결제가 실패했습니다.');
    }
  }
  
  Future<void> _createSubscriptionAfterPayment(String authKey, String orderId) async {
    try {
      // StorageService에서 토큰 가져오기
      final token = StorageService().getToken();
      if (token == null) {
        throw Exception('인증 토큰이 없습니다.');
      }
      
      final authProvider = context.read<AuthProvider>();
      
      // frontend-admin과 동일한 방식으로 구독 생성 요청
      final response = await http.post(
        Uri.parse('https://silverithm.site/api/v1/subscriptions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'planName': 'BASIC',
          'billingType': 'MONTHLY', 
          'amount': _selectedPlan!.price,
          'customerKey': StorageService().getSavedUserData()?['customerKey'] ?? '',
          'authKey': authKey,
          'orderName': '${_selectedPlan!.name} 구독',
          'customerEmail': StorageService().getSavedUserData()?['userEmail'] ?? '',
          'customerName': authProvider.currentUser?.name ?? '관리자',
          'taxFreeAmount': 0,
        }),
      );
      
      if (response.statusCode == 200) {
        // 결제 성공 후 구독 정보 새로고침
        final subscriptionProvider = context.read<SubscriptionProvider>();
        await subscriptionProvider.loadSubscription();
        _showSuccessDialog();
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error'] ?? errorData['message'] ?? '구독 생성에 실패했습니다.';
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      print('[Payment] 구독 생성 오류: $e');
      _showErrorDialog('구독 생성 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => shadcn.AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppSemanticColors.statusSuccessIcon, AppSemanticColors.statusSuccessIcon],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check, color: AppSemanticColors.textInverse, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              '결제 완료!',
              style: AppTypography.heading5.copyWith(
                color: AppSemanticColors.statusSuccessIcon,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${_selectedPlan!.name} 구독이 시작되었습니다.\n관리자 권한으로 모든 기능을 이용하세요!',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: shadcn.PrimaryButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MainScreen()),
                  (route) => false,
                );
              },
              child: const Text('완료'),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => shadcn.AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: AppSemanticColors.statusErrorIcon),
            const SizedBox(width: 8),
            const Text('결제 실패'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
          ],
        ),
        actions: [
          shadcn.OutlineButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}

class _PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String orderId;

  const _PaymentWebViewScreen({
    required this.paymentUrl,
    required this.orderId,
  });

  @override
  State<_PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<_PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    // WebView 초기화
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.white)
      ..enableZoom(false)
      ..addJavaScriptChannel(
        'Console',
        onMessageReceived: (JavaScriptMessage message) {
          print('[WebView Console] ${message.message}');
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('[WebView] Page started: $url');
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            print('[WebView] Page finished: $url');
            setState(() {
              _isLoading = false;
            });
            
            // 빌링 인증 완료 또는 실패 URL 체크
            if (url.contains('/payment/success')) {
              print('[WebView] Success URL 전체: $url');
              // URL에서 authKey와 customerKey 추출
              final uri = Uri.parse(url);
              final authKey = uri.queryParameters['authKey'] ?? '';
              final customerKey = uri.queryParameters['customerKey'] ?? '';
              print('[WebView] 추출된 authKey: $authKey');
              print('[WebView] 추출된 customerKey: $customerKey');
              Navigator.of(context).pop({
                'status': 'success',
                'authKey': authKey,
                'customerKey': customerKey,
              });
            } else if (url.contains('/payment/fail')) {
              print('[WebView] Fail URL: $url');
              Navigator.of(context).pop({'status': 'fail'});
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            print('[WebView] Navigation request: ${request.url}');
            
            // 앱 스킴 처리 (카드사, 은행 앱 등) - data: URL은 제외
            if (!request.url.startsWith('http') && 
                !request.url.startsWith('https') && 
                !request.url.startsWith('data:')) {
              print('[WebView] Handling app scheme: ${request.url}');
              _handleAppScheme(request.url);
              return NavigationDecision.prevent;
            }
            
            // 빌링 인증 완료/실패 페이지로 리다이렉트되는 경우 처리
            if (request.url.contains('/payment/success')) {
              print('[WebView] Navigation Success URL 전체: ${request.url}');
              // URL에서 authKey와 customerKey 추출
              final uri = Uri.parse(request.url);
              final authKey = uri.queryParameters['authKey'] ?? '';
              final customerKey = uri.queryParameters['customerKey'] ?? '';
              print('[WebView] Navigation 추출된 authKey: $authKey');
              print('[WebView] Navigation 추출된 customerKey: $customerKey');
              Navigator.of(context).pop({
                'status': 'success',
                'authKey': authKey,
                'customerKey': customerKey,
              });
              return NavigationDecision.prevent;
            } else if (request.url.contains('/payment/fail')) {
              print('[WebView] Navigation Fail URL: ${request.url}');
              Navigator.of(context).pop({'status': 'fail'});
              return NavigationDecision.prevent;
            }
            
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            print('[WebView] Error: ${error.description}');
          },
        ),
      );
    
    // URL 로드
    _controller.loadRequest(Uri.parse(widget.paymentUrl));
  }

  Future<void> _handleAppScheme(String url) async {
    try {
      print('[WebView] Handling app scheme: $url');
      
      // Android intent 스킴 처리
      if (url.startsWith('intent://')) {
        await _handleAndroidIntent(url);
        return;
      }
      
      // 일반 앱 스킴 처리 (iOS 스타일)
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        print('[WebView] Cannot launch URL: $url');
      }
    } catch (e) {
      print('[WebView] Failed to launch app scheme: $e');
    }
  }
  
  Future<void> _handleAndroidIntent(String intentUrl) async {
    try {
      // intent:// URL을 파싱하여 앱 실행
      final uri = Uri.parse(intentUrl);
      
      // Intent URL에서 패키지명 추출
      String? packageName;
      String? scheme;
      
      // URL 파라미터에서 패키지명과 스킴 추출
      final fragment = uri.fragment;
      if (fragment != null) {
        final params = Uri.splitQueryString(fragment);
        packageName = params['package'];
        scheme = params['scheme'];
      }
      
      // 패키지명이 있으면 해당 앱 실행 시도
      if (packageName != null) {
        final appUri = Uri.parse('$packageName://');
        if (await canLaunchUrl(appUri)) {
          await launchUrl(appUri, mode: LaunchMode.externalApplication);
          return;
        }
      }
      
      // 스킴이 있으면 스킴으로 실행 시도
      if (scheme != null) {
        final schemeUri = Uri.parse('$scheme://');
        if (await canLaunchUrl(schemeUri)) {
          await launchUrl(schemeUri, mode: LaunchMode.externalApplication);
          return;
        }
      }
      
      // 플레이스토어로 리다이렉트 (패키지명이 있는 경우)
      if (packageName != null) {
        final playStoreUri = Uri.parse('market://details?id=$packageName');
        if (await canLaunchUrl(playStoreUri)) {
          await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
        } else {
          final webPlayStoreUri = Uri.parse('https://play.google.com/store/apps/details?id=$packageName');
          await launchUrl(webPlayStoreUri, mode: LaunchMode.externalApplication);
        }
      }
      
      print('[WebView] Android intent handled: $intentUrl');
    } catch (e) {
      print('[WebView] Failed to handle Android intent: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.surfaceDefault,
      appBar: AppBar(
        title: Text(
          '토스페이먼츠 결제',
          style: AppTypography.heading6.copyWith(
            fontWeight: FontWeight.bold,
            color: AppSemanticColors.textInverse,
          ),
        ),
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        foregroundColor: AppSemanticColors.textInverse,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop({'status': 'cancel'}),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    '결제 페이지를 불러오는 중...',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : WebViewWidget(controller: _controller),
    );
  }
}