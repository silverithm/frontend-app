import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../models/payment_failure.dart';
import '../models/subscription.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';
import '../widgets/common/index.dart';
import 'admin_payment_screen.dart';
import 'login_screen.dart';

class AdminCompanySettingsScreen extends StatefulWidget {
  const AdminCompanySettingsScreen({super.key});

  @override
  State<AdminCompanySettingsScreen> createState() => _AdminCompanySettingsScreenState();
}

class _AdminCompanySettingsScreenState extends State<AdminCompanySettingsScreen> {
  bool _isPaymentFailuresExpanded = false;
  @override
  void initState() {
    super.initState();
    // 화면 로드 시 최신 구독 정보 및 결제 실패 정보 가져오기
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final subscriptionProvider = context.read<SubscriptionProvider>();
      
      print('[AdminCompanySettings] 구독 정보 로드 시작');
      await subscriptionProvider.loadSubscription();
      print('[AdminCompanySettings] 구독 정보 로드 완료');
      
      print('[AdminCompanySettings] 결제 실패 정보 로드 시작');
      await subscriptionProvider.loadPaymentFailures();
      print('[AdminCompanySettings] 결제 실패 정보 로드 완료');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser;
        final company = user?.company;

        if (company == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('회사 정보'),
              backgroundColor: AppSemanticColors.interactivePrimaryDefault,
              foregroundColor: AppSemanticColors.textInverse,
            ),
            body: const Center(
              child: Text('회사 정보를 불러올 수 없습니다.'),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppSemanticColors.backgroundSecondary,
          appBar: AppBar(
            title: Text(
              '회사 정보',
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
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 회사 정보 카드
                Container(
                  width: double.infinity,
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
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppSemanticColors.textInverse.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.business,
                          color: AppSemanticColors.textInverse,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        company.name,
                        style: AppTypography.heading4.copyWith(
                          color: AppSemanticColors.textInverse,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '관리자 계정으로 로그인됨',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppSemanticColors.textInverse.withValues(alpha: 0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // 상세 정보 섹션
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.surfaceDefault,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '회사 상세 정보',
                        style: AppTypography.heading6.copyWith(
                          color: AppSemanticColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 회사명
                      _buildInfoRow(
                        icon: Icons.business,
                        iconColor: AppSemanticColors.textSecondary,
                        title: '회사명',
                        value: company.name,
                      ),

                      const SizedBox(height: 20),

                      // 회사 주소
                      _buildInfoRow(
                        icon: Icons.location_on,
                        iconColor: AppSemanticColors.statusErrorIcon,
                        title: '주소',
                        value: company.addressName.isNotEmpty
                            ? company.addressName
                            : '주소 정보 없음',
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 관리자 정보 섹션
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.surfaceDefault,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '관리자 정보',
                        style: AppTypography.heading6.copyWith(
                          color: AppSemanticColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 관리자명
                      _buildInfoRow(
                        icon: Icons.person,
                        iconColor: AppSemanticColors.statusInfoIcon,
                        title: '이름',
                        value: user!.name,
                      ),

                      const SizedBox(height: 20),

                      // 역할
                      _buildInfoRow(
                        icon: Icons.admin_panel_settings,
                        iconColor: AppSemanticColors.textSecondary,
                        title: '역할',
                        value: '관리자',
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 구독 정보 섹션 (관리자도 구독 정보 확인 가능)
                Consumer<SubscriptionProvider>(
                  builder: (context, subscriptionProvider, child) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.surfaceDefault,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '구독 정보',
                            style: AppTypography.heading6.copyWith(
                              color: AppSemanticColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildSubscriptionStatus(subscriptionProvider),
                        ],
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                
                // 로그아웃 버튼 (제일 하단)
                _buildLogoutSection(authProvider),

              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppSemanticColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppSemanticColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionStatus(SubscriptionProvider subscriptionProvider) {
    print('[AdminCompanySettings] _buildSubscriptionStatus 호출');
    print('[AdminCompanySettings] isLoading: ${subscriptionProvider.isLoading}');
    print('[AdminCompanySettings] subscription: ${subscriptionProvider.subscription}');
    print('[AdminCompanySettings] errorMessage: ${subscriptionProvider.errorMessage}');
    
    // 구독 정보 로딩 중
    if (subscriptionProvider.isLoading) {
      return Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppSemanticColors.interactivePrimaryDefault,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '구독 정보를 불러오는 중...',
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
        ],
      );
    }

    // 구독 정보가 없는 경우
    if (subscriptionProvider.subscription == null) {
      return Column(
        children: [
          _buildInfoRow(
            icon: Icons.info_outline,
            iconColor: AppSemanticColors.statusWarningIcon,
            title: '구독 상태',
            value: '구독 정보 없음',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppSemanticColors.statusWarningBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppSemanticColors.statusWarningBorder),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: AppSemanticColors.statusWarningIcon,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '관리자는 구독 상태와 관계없이 모든 기능을 사용할 수 있습니다.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppSemanticColors.statusWarningText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // 구독 정보가 있는 경우
    final subscription = subscriptionProvider.subscription!;
    final statusColor = subscription.isActive
        ? AppSemanticColors.statusSuccessIcon
        : subscription.isExpired
            ? AppSemanticColors.statusErrorIcon
            : AppSemanticColors.statusWarningIcon;

    return Column(
      children: [
        _buildInfoRow(
          icon: Icons.workspace_premium,
          iconColor: statusColor,
          title: '구독 플랜',
          value: subscription.planDisplayName,
        ),
        const SizedBox(height: 20),
        _buildInfoRow(
          icon: Icons.assignment_turned_in,
          iconColor: statusColor,
          title: '구독 상태',
          value: subscription.statusDisplayName,
        ),
        if (subscription.endDate != null) ...[
          const SizedBox(height: 20),
          _buildInfoRow(
            icon: Icons.schedule,
            iconColor: AppSemanticColors.statusSuccessIcon,
            title: '만료일',
            value: _formatDate(subscription.endDate!),
          ),
          if (subscription.isActive) ...[
            const SizedBox(height: 20),
            _buildInfoRow(
              icon: Icons.timer,
              iconColor: AppSemanticColors.statusInfoIcon,
              title: '남은 일수',
              value: '${subscription.daysRemaining}일',
            ),
          ],
        ],
        // 유료 플랜에 대한 구독 제어 버튼 (무료 플랜 제외)
        if (!subscription.isFree) ...[
          const SizedBox(height: 20),
          _buildSubscriptionControlButtons(subscription, subscriptionProvider),
        ],
        const SizedBox(height: 16),
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
                Icons.admin_panel_settings,
                color: AppSemanticColors.statusSuccessIcon,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '관리자 권한으로 구독 상태와 관계없이 모든 기능을 사용할 수 있습니다.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.statusSuccessText,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 결제 실패 정보 표시
        _buildPaymentFailuresSection(subscriptionProvider),
        const SizedBox(height: 16),
        // 결제 관리 버튼
        SizedBox(
          width: double.infinity,
          child: shadcn.PrimaryButton(
            onPressed: _navigateToPayment,
            leading: const Icon(Icons.payment),
            child: const Text('결제 및 구독 관리'),
          ),
        ),
      ],
    );
  }

  void _navigateToPayment() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AdminPaymentScreen(),
      ),
    );
  }

  Widget _buildLogoutSection(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '계정 관리',
            style: AppTypography.heading6.copyWith(
              color: AppSemanticColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // 관리자 회원탈퇴 버튼
          SizedBox(
            width: double.infinity,
            child: shadcn.DestructiveButton(
              onPressed: () => _showAdminWithdrawalDialog(authProvider),
              leading: const Icon(Icons.person_remove),
              child: const Text('회원탈퇴'),
            ),
          ),

          const SizedBox(height: 12),

          // 로그아웃 버튼
          SizedBox(
            width: double.infinity,
            child: shadcn.OutlineButton(
              onPressed: () => _showLogoutDialog(authProvider),
              leading: const Icon(Icons.logout),
              child: const Text('로그아웃'),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => shadcn.AlertDialog(
        title: Row(
          children: [
            Icon(Icons.logout, color: AppSemanticColors.statusWarningIcon),
            const SizedBox(width: 8),
            const Text('로그아웃'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('정말 로그아웃하시겠습니까?'),
          ],
        ),
        actions: [
          shadcn.OutlineButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          shadcn.GhostButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _performLogout(authProvider);
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout(AuthProvider authProvider) async {
    try {
      await authProvider.logout();
      if (mounted) {
        // 일반 로그인 화면으로 명시적으로 이동
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그아웃 중 오류가 발생했습니다: ${e.toString()}'),
            backgroundColor: AppSemanticColors.statusWarningIcon,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  Widget _buildPaymentFailuresSection(SubscriptionProvider subscriptionProvider) {
    // 결제 실패 정보 로딩 중
    if (subscriptionProvider.isLoadingFailures) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppSemanticColors.statusWarningBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppSemanticColors.statusWarningBorder),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppSemanticColors.statusWarningIcon),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '결제 실패 정보를 확인 중...',
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.statusWarningText,
              ),
            ),
          ],
        ),
      );
    }

    // 결제 실패가 없는 경우 - 표시하지 않음
    if (!subscriptionProvider.hasPaymentFailures) {
      return const SizedBox.shrink();
    }

    // 결제 실패가 있는 경우
    return Container(
      decoration: BoxDecoration(
        color: AppSemanticColors.statusErrorBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppSemanticColors.statusErrorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 (항상 표시되며 탭하면 펼치기/접기)
          InkWell(
            onTap: () {
              setState(() {
                _isPaymentFailuresExpanded = !_isPaymentFailuresExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppSemanticColors.statusErrorIcon,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '결제 실패 내역',
                      style: AppTypography.heading6.copyWith(
                        color: AppSemanticColors.statusErrorText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.statusErrorIcon,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${subscriptionProvider.paymentFailures.length}건',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppSemanticColors.textInverse,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isPaymentFailuresExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: AppSemanticColors.statusErrorIcon,
                  ),
                ],
              ),
            ),
          ),
          // 상세 내용 (펼쳐졌을 때만 표시)
          if (_isPaymentFailuresExpanded) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '결제 정보를 확인하고 다시 시도해 주세요.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppSemanticColors.statusErrorText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 결제 실패 정보 표시 (최대 5개)
                  ...subscriptionProvider.paymentFailures
                      .take(5)
                      .map((failure) => _buildPaymentFailureItem(failure))
                      .toList(),
                  if (subscriptionProvider.paymentFailures.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Center(
                        child: Text(
                          '외 ${subscriptionProvider.paymentFailures.length - 5}건 더...',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppSemanticColors.statusErrorIcon,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentFailureItem(PaymentFailure failure) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppSemanticColors.statusErrorBackground),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  failure.failureReasonKorean,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppSemanticColors.statusErrorText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${failure.formattedAmount} • ${failure.formattedFailedAt}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionControlButtons(Subscription subscription, SubscriptionProvider subscriptionProvider) {
    return Row(
      children: [
        // 구독 취소/활성화 버튼
        Expanded(
          child: subscription.isActive
              ? shadcn.OutlineButton(
                  onPressed: subscriptionProvider.isLoading
                      ? null
                      : () => _showCancelSubscriptionDialog(subscriptionProvider),
                  leading: subscriptionProvider.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.pause_circle_outline),
                  child: Text(subscriptionProvider.isLoading ? '처리 중...' : '구독 일시정지'),
                )
              : shadcn.PrimaryButton(
                  onPressed: subscriptionProvider.isLoading
                      ? null
                      : () => _showActivateSubscriptionDialog(subscriptionProvider),
                  leading: subscriptionProvider.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_circle_outline),
                  child: Text(subscriptionProvider.isLoading ? '처리 중...' : '구독 재개'),
                ),
        ),
      ],
    );
  }

  void _showCancelSubscriptionDialog(SubscriptionProvider subscriptionProvider) {
    showDialog(
      context: context,
      builder: (context) => shadcn.AlertDialog(
        title: Row(
          children: [
            Icon(Icons.pause_circle_outline, color: AppSemanticColors.statusErrorIcon),
            const SizedBox(width: 8),
            const Text('구독 일시정지'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('구독을 일시정지하시겠습니까?\n다음 결제일에 자동 결제가 중단됩니다.'),
          ],
        ),
        actions: [
          shadcn.OutlineButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          shadcn.GhostButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await subscriptionProvider.cancelSubscription();
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('구독이 일시정지되었습니다'),
                    backgroundColor: AppSemanticColors.statusWarningIcon,
                  ),
                );
              }
            },
            child: const Text('일시정지'),
          ),
        ],
      ),
    );
  }

  void _showActivateSubscriptionDialog(SubscriptionProvider subscriptionProvider) {
    showDialog(
      context: context,
      builder: (context) => shadcn.AlertDialog(
        title: Row(
          children: [
            Icon(Icons.play_circle_outline, color: AppSemanticColors.statusSuccessIcon),
            const SizedBox(width: 8),
            const Text('구독 재개'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('구독을 재개하시겠습니까?\n다음 결제일부터 자동 결제가 재개됩니다.'),
          ],
        ),
        actions: [
          shadcn.OutlineButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          shadcn.PrimaryButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await subscriptionProvider.activateSubscription();
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('구독이 재개되었습니다'),
                    backgroundColor: AppSemanticColors.statusSuccessIcon,
                  ),
                );
              }
            },
            child: const Text('재개'),
          ),
        ],
      ),
    );
  }

  void _showAdminWithdrawalDialog(AuthProvider authProvider) {
    bool isWithdrawing = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => shadcn.AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppSemanticColors.statusErrorBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person_remove, color: AppSemanticColors.statusErrorIcon, size: 24),
              ),
              const SizedBox(width: 12),
              Text('관리자 회원탈퇴', style: AppTypography.heading6.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppSemanticColors.statusErrorBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppSemanticColors.statusErrorBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ 주의사항',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppSemanticColors.statusErrorText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 관리자 계정이 영구적으로 삭제됩니다\n• 회사의 모든 데이터가 삭제됩니다\n• 직원들의 계정도 모두 삭제됩니다\n• 삭제된 데이터는 복구할 수 없습니다\n• 구독도 자동으로 취소됩니다',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppSemanticColors.statusErrorText,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '정말로 관리자 회원탈퇴를 진행하시겠습니까?',
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppSemanticColors.textPrimary,
                ),
              ),
            ],
          ),
          actions: [
            shadcn.OutlineButton(
              onPressed: isWithdrawing ? null : () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            shadcn.DestructiveButton(
              onPressed: isWithdrawing
                  ? null
                  : () async {
                      setState(() => isWithdrawing = true);

                      final success = await authProvider.deleteAdminAccount();

                      if (success && context.mounted) {
                        Navigator.pop(context);

                        await Future.delayed(const Duration(milliseconds: 100));

                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('관리자 회원탈퇴가 완료되었습니다. 그동안 이용해주셔서 감사했습니다.'),
                              backgroundColor: AppSemanticColors.statusSuccessIcon,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      } else if (context.mounted) {
                        setState(() => isWithdrawing = false);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              authProvider.errorMessage.isNotEmpty
                                  ? authProvider.errorMessage
                                  : '관리자 회원탈퇴에 실패했습니다',
                            ),
                            backgroundColor: AppSemanticColors.statusErrorIcon,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    },
              child: isWithdrawing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('탈퇴하기'),
            ),
          ],
        ),
      ),
    );
  }
}