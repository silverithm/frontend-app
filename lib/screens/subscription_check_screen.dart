import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/auth_provider.dart';
import '../models/subscription.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_loading.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_chip.dart';
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
      backgroundColor: AppSemanticColors.backgroundPrimary,
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
                      padding: const EdgeInsets.all(AppSpacing.space6),
                      child: Column(
                        children: [
                          _buildWelcomeSection(authProvider),
                          const SizedBox(height: AppSpacing.space8),
                          _buildSubscriptionPlans(subscriptionProvider),
                          const SizedBox(height: AppSpacing.space6),
                          _buildFeatureComparison(),
                          const SizedBox(height: AppSpacing.space8),
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
            padding: const EdgeInsets.all(AppSpacing.space6),
            decoration: BoxDecoration(
              color: AppSemanticColors.brandWeak,
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
          const SizedBox(height: AppSpacing.space6),
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
      backgroundColor: AppColors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          color: AppSemanticColors.interactivePrimaryDefault,
        ),
        child: FlexibleSpaceBar(
          centerTitle: true,
          title: Text(
            '요금제 선택',
            style: AppTypography.heading5.copyWith(
              color: AppSemanticColors.textInverse,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space6),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
        border: Border.all(
          color: AppSemanticColors.borderDefault,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppSemanticColors.interactivePrimaryDefault,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.business_center,
              color: AppSemanticColors.textInverse,
              size: 40,
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            '${authProvider.currentUser?.company?.name ?? ''}에\n오신 것을 환영합니다!',
            textAlign: TextAlign.center,
            style: AppTypography.heading4.copyWith(
              color: AppSemanticColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
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
        const SizedBox(height: AppSpacing.space4),
        ...plans.map((plan) => _buildPlanCard(plan, subscriptionProvider)),
      ],
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan, SubscriptionProvider subscriptionProvider) {
    final canUseFree = plan.type == SubscriptionType.FREE
        ? subscriptionProvider.canUseFreeSubscription
        : true;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space4),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
          side: plan.isPopular
              ? BorderSide(
                  color: AppSemanticColors.interactivePrimaryDefault,
                  width: 2,
                )
              : BorderSide(
                  color: AppSemanticColors.borderDefault,
                  width: 1,
                ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
            color: plan.isPopular ? AppSemanticColors.brandWeak : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space6),
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
                                const SizedBox(width: AppSpacing.space2),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.space2,
                                    vertical: AppSpacing.space1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppSemanticColors.interactivePrimaryDefault,
                                    borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                                  ),
                                  child: Text(
                                    '추천',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppSemanticColors.textInverse,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppSpacing.space1),
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
                              color: AppSemanticColors.statusSuccessIcon,
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
                const SizedBox(height: AppSpacing.space4),
                Wrap(
                  spacing: AppSpacing.space2,
                  runSpacing: AppSpacing.space1,
                  children: plan.features
                      .map((feature) => SeedChip(
                            label: feature,
                            selected: plan.isPopular,
                            size: SeedChipSize.small,
                          ))
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.space5),
                SizedBox(
                  width: double.infinity,
                  child: SeedButton(
                    label: !canUseFree
                        ? '이미 사용함'
                        : plan.type == SubscriptionType.FREE
                            ? '무료 체험 시작'
                            : '구독하기',
                    size: SeedButtonSize.large,
                    isDisabled: !canUseFree,
                    onPressed: canUseFree
                        ? () => _selectPlan(plan, subscriptionProvider)
                        : null,
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
      padding: const EdgeInsets.all(AppSpacing.space6),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
        border: Border.all(
          color: AppSemanticColors.borderDefault,
          width: 1,
        ),
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
          const SizedBox(height: AppSpacing.space4),
          ...[
            '직원 관리 및 승인',
            '휴무 신청 및 관리',
            '실시간 캘린더',
            '알림 시스템',
            '모바일 앱 지원',
          ].map((feature) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space2),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppSemanticColors.statusSuccessIcon,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.space3),
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
      padding: const EdgeInsets.all(AppSpacing.space5),
      decoration: BoxDecoration(
        color: AppSemanticColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
      ),
      child: Column(
        children: [
          Icon(
            Icons.security,
            color: AppSemanticColors.textSecondary,
            size: 32,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            '안전한 결제',
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.space1),
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
    AppDialog.showCustom<void>(
      context,
      barrierDismissible: false,
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.space6),
        child: AppLoading(message: '처리 중...'),
      ),
    );
  }

  void _showSuccessDialog(String message, VoidCallback onConfirm) {
    AppDialog.showCustom<void>(
      context,
      barrierDismissible: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: AppSemanticColors.statusSuccessIcon,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: AppSemanticColors.textInverse, size: 30),
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(
              '성공!',
              style: AppTypography.heading6.copyWith(
                color: AppSemanticColors.statusSuccessIcon,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.space6),
            SizedBox(
              width: double.infinity,
              child: SeedButton(
                label: '확인',
                onPressed: onConfirm,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    AppDialog.showAlert(
      context,
      title: '오류',
      message: message,
    );
  }
}
