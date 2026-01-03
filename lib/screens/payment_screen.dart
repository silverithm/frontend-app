import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/subscription_provider.dart';
import '../providers/auth_provider.dart';
import '../models/subscription.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';
import 'main_screen.dart';
import 'admin_dashboard_screen.dart';

class PaymentScreen extends StatefulWidget {
  final SubscriptionPlan plan;
  final bool isAdmin;
  
  const PaymentScreen({
    super.key,
    required this.plan,
    this.isAdmin = false,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _isProcessing = false;
  String _authKey = '';

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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundSecondary,
      appBar: AppBar(
        title: Text(
          '결제',
          style: AppTypography.heading5.copyWith(
            color: AppSemanticColors.textInverse,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppSemanticColors.interactiveSecondaryDefault,
        foregroundColor: AppSemanticColors.textInverse,
        elevation: 0,
      ),
      body: Consumer2<SubscriptionProvider, AuthProvider>(
        builder: (context, subscriptionProvider, authProvider, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPlanSummary(),
                    const SizedBox(height: 32),
                    _buildPaymentInfo(),
                    const SizedBox(height: 32),
                    _buildPaymentMethods(),
                    const SizedBox(height: 32),
                    _buildSecurityInfo(),
                    const SizedBox(height: 40),
                    _buildPaymentButton(subscriptionProvider),
                  ],
                ),
              ),
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
            AppSemanticColors.interactiveSecondaryDefault,
            AppSemanticColors.interactiveSecondaryDefault.withValues(alpha:0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppSemanticColors.interactiveSecondaryDefault.withValues(alpha:0.3),
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
                      widget.plan.name,
                      style: AppTypography.heading5.copyWith(
                        color: AppSemanticColors.textInverse,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.plan.description,
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
                  '₩${_formatPrice(widget.plan.price)}',
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
          _buildInfoRow('플랜', widget.plan.name),
          _buildInfoRow('결제 주기', '매월'),
          _buildInfoRow('첫 결제일', _getFirstPaymentDate()),
          _buildInfoRow('다음 결제일', _getNextPaymentDate()),
          const Divider(height: 24),
          _buildInfoRow(
            '총 결제 금액', 
            '₩${_formatPrice(widget.plan.price)}',
            isTotal: true,
          ),
        ],
      ),
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

  Widget _buildPaymentMethods() {
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
            '결제 수단',
            style: AppTypography.heading6.copyWith(
              color: AppSemanticColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppSemanticColors.statusInfoBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppSemanticColors.interactiveSecondaryDefault,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppSemanticColors.interactiveSecondaryDefault,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.credit_card,
                    color: AppSemanticColors.textInverse,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '토스페이먼츠',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppSemanticColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '신용카드, 계좌이체, 간편결제',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppSemanticColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppSemanticColors.statusSuccessBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppSemanticColors.statusSuccessBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.security,
            color: AppSemanticColors.statusSuccessIcon,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '안전한 결제',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.statusSuccessText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '결제 정보는 암호화되어 안전하게 보호됩니다.\n언제든지 구독을 취소할 수 있습니다.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.statusSuccessText,
                  ),
                ),
              ],
            ),
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
          child: ElevatedButton(
            onPressed: _isProcessing || subscriptionProvider.isLoading
                ? null
                : _startPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppSemanticColors.interactiveSecondaryDefault,
              foregroundColor: AppSemanticColors.textInverse,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
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
                    '₩${_formatPrice(widget.plan.price)} 결제하기',
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
      ],
    );
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  String _getFirstPaymentDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _getNextPaymentDate() {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, now.day);
    return '${nextMonth.year}-${nextMonth.month.toString().padLeft(2, '0')}-${nextMonth.day.toString().padLeft(2, '0')}';
  }

  void _startPayment() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final orderId = _generateOrderId();
      final amount = widget.plan.price;
      
      // 토스페이먼츠 결제 URL 생성
      final paymentUrl = await _createTossPayment(
        orderId: orderId,
        amount: amount,
        orderName: '${widget.plan.name} 구독',
        customerName: authProvider.currentUser?.name ?? '사용자',
        customerEmail: '', // userInfo에서 받아올 예정
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

  String _generateOrderId() {
    return 'order_${DateTime.now().millisecondsSinceEpoch}';
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
      
      // userInfo API에서 customerKey와 이메일 가져오기
      final userInfoResponse = await ApiService().getUserInfo();
      final customerKey = userInfoResponse['customerKey']?.toString() ?? '';
      final userEmail = userInfoResponse['userEmail']?.toString() ?? '';
      
      print('[Payment] 사용할 customerKey: $customerKey');
      print('[Payment] 사용자 데이터: ${userInfoResponse['userName']} ($userEmail)');
      
      // 토스페이먼츠 v1 빌링 인증 페이지 HTML 생성
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
                
                if (!window.TossPayments) {
                    throw new Error('토스페이먼츠 v1 SDK가 로드되지 않았습니다.');
                }
                
                logToFlutter('토스페이먼츠 v1 SDK 로드 완료');
                document.getElementById('status').textContent = '결제 모듈 초기화 중...';
                
                const tossPayments = TossPayments('$clientKey');
                logToFlutter('토스페이먼츠 객체 생성 완료');
                
                document.getElementById('status').textContent = '빌링 인증 요청 중...';
                
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
        
        window.onload = function() {
            logToFlutter('페이지 로드 완료, 결제 시작');
            setTimeout(loadPayment, 500);
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
      final subscriptionProvider = context.read<SubscriptionProvider>();
      
      final success = await subscriptionProvider.createPaidSubscription(
        planType: widget.plan.type,
        paymentType: PaymentType.MONTHLY,
        authKey: authKey, // WebView에서 받은 실제 authKey 사용
        amount: widget.plan.price,
        planName: widget.plan.name,
      );

      if (success) {
        _showSuccessDialog();
      } else {
        _showErrorDialog(subscriptionProvider.errorMessage);
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.green400, AppColors.green600],
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
              '${widget.plan.name} 구독이 시작되었습니다.\n모든 기능을 자유롭게 이용하세요!',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MainScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppSemanticColors.statusSuccessIcon,
                foregroundColor: AppSemanticColors.textInverse,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('시작하기'),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error, color: AppSemanticColors.statusErrorIcon),
            const SizedBox(width: 8),
            const Text('결제 실패'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
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
            
            if (url.contains('/payment/success')) {
              print('[WebView] Success URL 전체: $url');
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
            
            if (!request.url.startsWith('http') && 
                !request.url.startsWith('https') && 
                !request.url.startsWith('data:')) {
              print('[WebView] Handling app scheme: ${request.url}');
              _handleAppScheme(request.url);
              return NavigationDecision.prevent;
            }
            
            if (request.url.contains('/payment/success')) {
              print('[WebView] Navigation Success URL 전체: ${request.url}');
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
    
    _controller.loadRequest(Uri.parse(widget.paymentUrl));
  }

  Future<void> _handleAppScheme(String url) async {
    try {
      print('[WebView] Handling app scheme: $url');
      
      if (url.startsWith('intent://')) {
        await _handleAndroidIntent(url);
        return;
      }
      
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
      final uri = Uri.parse(intentUrl);
      
      String? packageName;
      String? scheme;
      
      final fragment = uri.fragment;
      if (fragment != null) {
        final params = Uri.splitQueryString(fragment);
        packageName = params['package'];
        scheme = params['scheme'];
      }
      
      if (packageName != null) {
        final appUri = Uri.parse('$packageName://');
        if (await canLaunchUrl(appUri)) {
          await launchUrl(appUri, mode: LaunchMode.externalApplication);
          return;
        }
      }
      
      if (scheme != null) {
        final schemeUri = Uri.parse('$scheme://');
        if (await canLaunchUrl(schemeUri)) {
          await launchUrl(schemeUri, mode: LaunchMode.externalApplication);
          return;
        }
      }
      
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
        backgroundColor: AppSemanticColors.interactiveSecondaryDefault,
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