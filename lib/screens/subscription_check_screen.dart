import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/auth_provider.dart';
import '../models/subscription.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';
import 'payment_screen.dart';
import 'main_screen.dart';

class SubscriptionCheckScreen extends StatefulWidget {
  final bool isAdmin;
  
  const SubscriptionCheckScreen({
    super.key,
    this.isAdmin = false,
  });

  @override
  State<SubscriptionCheckScreen> createState() => _SubscriptionCheckScreenState();
}

class _SubscriptionCheckScreenState extends State<SubscriptionCheckScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
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

    // 구독 정보 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().loadSubscription();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Consumer2<SubscriptionProvider, AuthProvider>(
        builder: (context, subscriptionProvider, authProvider, child) {
          if (subscriptionProvider.isLoading) {
            return _buildLoadingScreen();
          }

          return CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildWelcomeSection(authProvider),
                          const SizedBox(height: 32),
                          _buildSubscriptionPlans(subscriptionProvider),
                          const SizedBox(height: 24),
                          _buildFeatureComparison(),
                          const SizedBox(height: 32),
                          _buildFooter(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppSemanticColors.interactiveSecondaryDefault.withOpacity(0.1),
                  AppSemanticColors.interactiveSecondaryDefault.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AppSemanticColors.interactiveSecondaryDefault,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '구독 정보를 확인하고 있습니다...',
            style: AppTypography.bodyLarge.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppSemanticColors.interactiveSecondaryDefault,
              AppSemanticColors.interactiveSecondaryDefault.withOpacity(0.8),
            ],
          ),
        ),
        child: FlexibleSpaceBar(
          centerTitle: true,
          title: Text(
            '요금제 선택',
            style: AppTypography.heading5.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.blue.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppSemanticColors.interactiveSecondaryDefault,
                  AppSemanticColors.interactiveSecondaryDefault.withOpacity(0.7),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.business_center,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${authProvider.currentUser?.company?.name ?? ''}에\n오신 것을 환영합니다!',
            textAlign: TextAlign.center,
            style: AppTypography.heading4.copyWith(
              color: AppSemanticColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '서비스를 이용하시려면 요금제를 선택해주세요.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionPlans(SubscriptionProvider subscriptionProvider) {
    final plans = SubscriptionPlan.getAvailablePlans();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '요금제 선택',
          style: AppTypography.heading5.copyWith(
            color: AppSemanticColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...plans.map((plan) => _buildPlanCard(plan, subscriptionProvider)),
      ],
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan, SubscriptionProvider subscriptionProvider) {
    final canUseFree = plan.type == SubscriptionType.FREE 
        ? subscriptionProvider.canUseFreeSubscription 
        : true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: plan.isPopular ? 8 : 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: plan.isPopular
              ? BorderSide(
                  color: AppSemanticColors.interactiveSecondaryDefault,
                  width: 2,
                )
              : BorderSide.none,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: plan.isPopular
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      AppSemanticColors.interactiveSecondaryDefault.withOpacity(0.05),
                    ],
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                plan.name,
                                style: AppTypography.heading6.copyWith(
                                  color: AppSemanticColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (plan.isPopular) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppSemanticColors.interactiveSecondaryDefault,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '추천',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            plan.description,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppSemanticColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (plan.price == 0) ...[
                          Text(
                            '무료',
                            style: AppTypography.heading4.copyWith(
                              color: Colors.green.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ] else ...[
                          Text(
                            '₩${_formatPrice(plan.price)}',
                            style: AppTypography.heading4.copyWith(
                              color: AppSemanticColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '/월',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppSemanticColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: plan.features.map((feature) => Chip(
                    label: Text(
                      feature,
                      style: AppTypography.labelSmall.copyWith(fontSize: 11),
                    ),
                    backgroundColor: plan.isPopular
                        ? AppSemanticColors.interactiveSecondaryDefault.withOpacity(0.1)
                        : Colors.grey.shade100,
                    side: BorderSide.none,
                  )).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canUseFree ? () => _selectPlan(plan, subscriptionProvider) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: plan.isPopular
                          ? AppSemanticColors.interactiveSecondaryDefault
                          : AppSemanticColors.interactivePrimaryDefault,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      !canUseFree 
                          ? '이미 사용함'
                          : plan.type == SubscriptionType.FREE
                              ? '무료 체험 시작'
                              : '구독하기',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white,
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

  Widget _buildFeatureComparison() {
    return Container(
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
            '모든 플랜에 포함된 기능',
            style: AppTypography.heading6.copyWith(
              color: AppSemanticColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...[
            '직원 관리 및 승인',
            '휴가 신청 및 관리',
            '실시간 캘린더',
            '알림 시스템',
            '모바일 앱 지원',
          ].map((feature) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  feature,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textPrimary,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.security,
            color: AppSemanticColors.textSecondary,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            '안전한 결제',
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '토스페이먼츠를 통한 안전하고 편리한 결제',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.textSecondary,
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

  void _selectPlan(SubscriptionPlan plan, SubscriptionProvider subscriptionProvider) async {
    if (plan.type == SubscriptionType.FREE) {
      // 무료 플랜 선택
      _showLoadingDialog();
      
      final success = await subscriptionProvider.createFreeSubscription();
      
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      
      if (success) {
        _showSuccessDialog('무료 체험이 시작되었습니다!', () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainScreen()),
            (route) => false,
          );
        });
      } else {
        _showErrorDialog(subscriptionProvider.errorMessage);
      }
    } else {
      // 유료 플랜 선택 - 결제 화면으로 이동
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            plan: plan,
            isAdmin: widget.isAdmin,
          ),
        ),
      );
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AppSemanticColors.interactiveSecondaryDefault,
              ),
            ),
            const SizedBox(height: 16),
            const Text('처리 중...'),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              '성공!',
              style: AppTypography.heading6.copyWith(
                color: Colors.green.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('확인'),
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
            Icon(Icons.error, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('오류'),
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