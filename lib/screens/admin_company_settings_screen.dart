import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../models/payment_failure.dart';
import '../models/subscription.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/index.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/seed/seed_button.dart';
import 'admin_payment_screen.dart';
import 'login_screen.dart';

class AdminCompanySettingsScreen extends StatefulWidget {
  const AdminCompanySettingsScreen({super.key});

  @override
  State<AdminCompanySettingsScreen> createState() =>
      _AdminCompanySettingsScreenState();
}

class _AdminCompanySettingsScreenState
    extends State<AdminCompanySettingsScreen> {
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
            body: const Center(child: Text('회사 정보를 불러올 수 없습니다.')),
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
            padding: const EdgeInsets.all(AppSpacing.space6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 회사 정보 카드
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.space6),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.interactivePrimaryDefault,
                    borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
                    border: Border.all(
                      color: AppSemanticColors.borderDefault,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: AppSpacing.space20,
                        height: AppSpacing.space20,
                        decoration: BoxDecoration(
                          color: AppSemanticColors.textInverse.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppBorderRadius.xl2,
                          ),
                        ),
                        child: Icon(
                          Icons.business,
                          color: AppSemanticColors.textInverse,
                          size: AppSpacing.space10,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space4),
                      Text(
                        company.name,
                        style: AppTypography.heading4.copyWith(
                          color: AppSemanticColors.textInverse,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.space2),
                      Text(
                        '관리자 계정으로 로그인됨',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppSemanticColors.textInverse.withValues(
                            alpha: 0.9,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.space8),

                // 상세 정보 섹션
                Container(
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
                        '회사 상세 정보',
                        style: AppTypography.heading6.copyWith(
                          color: AppSemanticColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space5),

                      // 회사명
                      _buildInfoRow(
                        icon: Icons.business,
                        iconColor: AppSemanticColors.textSecondary,
                        title: '회사명',
                        value: company.name,
                      ),

                      const SizedBox(height: AppSpacing.space5),

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

                const SizedBox(height: AppSpacing.space6),

                // 관리자 정보 섹션
                Container(
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
                        '관리자 정보',
                        style: AppTypography.heading6.copyWith(
                          color: AppSemanticColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space5),

                      // 관리자명
                      _buildInfoRow(
                        icon: Icons.person,
                        iconColor: AppSemanticColors.statusInfoIcon,
                        title: '이름',
                        value: user!.name,
                      ),

                      const SizedBox(height: AppSpacing.space5),

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

                const SizedBox(height: AppSpacing.space6),

                // 구독 정보 섹션 (관리자도 구독 정보 확인 가능)
                Consumer<SubscriptionProvider>(
                  builder: (context, subscriptionProvider, child) {
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.space6),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.surfaceDefault,
                        borderRadius: BorderRadius.circular(
                          AppBorderRadius.xl2,
                        ),
                        border: Border.all(
                          color: AppSemanticColors.borderDefault,
                          width: 1,
                        ),
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
                          const SizedBox(height: AppSpacing.space5),
                          _buildSubscriptionStatus(subscriptionProvider),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: AppSpacing.space6),

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
          width: AppSpacing.space10,
          height: AppSpacing.space10,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: AppSpacing.space4),
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
              const SizedBox(height: AppSpacing.space0_5),
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
    print(
      '[AdminCompanySettings] isLoading: ${subscriptionProvider.isLoading}',
    );
    print(
      '[AdminCompanySettings] subscription: ${subscriptionProvider.subscription}',
    );
    print(
      '[AdminCompanySettings] errorMessage: ${subscriptionProvider.errorMessage}',
    );

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
          const SizedBox(width: AppSpacing.space3),
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
          const SizedBox(height: AppSpacing.space4),
          Container(
            padding: const EdgeInsets.all(AppSpacing.space4),
            decoration: BoxDecoration(
              color: AppSemanticColors.statusWarningBackground,
              borderRadius: BorderRadius.circular(AppBorderRadius.xl),
              border: Border.all(color: AppSemanticColors.statusWarningBorder),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: AppSemanticColors.statusWarningIcon,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.space3),
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
        const SizedBox(height: AppSpacing.space5),
        _buildInfoRow(
          icon: Icons.assignment_turned_in,
          iconColor: statusColor,
          title: '구독 상태',
          value: subscription.statusDisplayName,
        ),
        if (subscription.endDate != null) ...[
          const SizedBox(height: AppSpacing.space5),
          _buildInfoRow(
            icon: Icons.schedule,
            iconColor: AppSemanticColors.statusSuccessIcon,
            title: '만료일',
            value: _formatDate(subscription.endDate!),
          ),
          if (subscription.isActive) ...[
            const SizedBox(height: AppSpacing.space5),
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
          const SizedBox(height: AppSpacing.space5),
          _buildSubscriptionControlButtons(subscription, subscriptionProvider),
        ],
        const SizedBox(height: AppSpacing.space4),
        Container(
          padding: const EdgeInsets.all(AppSpacing.space4),
          decoration: BoxDecoration(
            color: AppSemanticColors.statusSuccessBackground,
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            border: Border.all(color: AppSemanticColors.statusSuccessBorder),
          ),
          child: Row(
            children: [
              Icon(
                Icons.admin_panel_settings,
                color: AppSemanticColors.statusSuccessIcon,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.space3),
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
        const SizedBox(height: AppSpacing.space4),
        // 결제 실패 정보 표시
        _buildPaymentFailuresSection(subscriptionProvider),
        const SizedBox(height: AppSpacing.space4),
        // 결제 관리 버튼
        SizedBox(
          width: double.infinity,
          child: SeedButton(
            label: '결제 및 구독 관리',
            prefixIcon: Icons.payment,
            onPressed: _navigateToPayment,
          ),
        ),
      ],
    );
  }

  void _navigateToPayment() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AdminPaymentScreen()));
  }

  Widget _buildLogoutSection(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space6),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl2),
        border: Border.all(color: AppSemanticColors.borderDefault, width: 1),
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
          const SizedBox(height: AppSpacing.space4),

          // 관리자 회원탈퇴 버튼
          SizedBox(
            width: double.infinity,
            child: SeedButton(
              label: '회원탈퇴',
              variant: SeedButtonVariant.critical,
              prefixIcon: Icons.person_remove,
              onPressed: () => _showAdminWithdrawalDialog(authProvider),
            ),
          ),

          const SizedBox(height: AppSpacing.space3),

          // 로그아웃 버튼
          SizedBox(
            width: double.infinity,
            child: SeedButton(
              label: '로그아웃',
              variant: SeedButtonVariant.neutralOutline,
              prefixIcon: Icons.logout,
              onPressed: () => _showLogoutDialog(authProvider),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutDialog(AuthProvider authProvider) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: '로그아웃',
      message: '정말 로그아웃하시겠습니까?',
      confirmText: '로그아웃',
    );
    if (confirmed == true) {
      await _performLogout(authProvider);
    }
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
        // 실제 오류 상황이므로 Warning이 아니라 Error 톤이 맞다 (기존은 시맨틱 오용)
        AppSnackBar.showError(
          context,
          message: '로그아웃 중 오류가 발생했습니다: ${e.toString()}',
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  Widget _buildPaymentFailuresSection(
    SubscriptionProvider subscriptionProvider,
  ) {
    // 결제 실패 정보 로딩 중
    if (subscriptionProvider.isLoadingFailures) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.space4),
        decoration: BoxDecoration(
          color: AppSemanticColors.statusWarningBackground,
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          border: Border.all(color: AppSemanticColors.statusWarningBorder),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppSemanticColors.statusWarningIcon,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.space3),
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
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
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
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.space4),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppSemanticColors.statusErrorIcon,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.space2),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space2,
                      vertical: AppSpacing.space1,
                    ),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.statusErrorIcon,
                      borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                    ),
                    child: Text(
                      '${subscriptionProvider.paymentFailures.length}건',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppSemanticColors.textInverse,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
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
              padding: const EdgeInsets.only(
                left: AppSpacing.space4,
                right: AppSpacing.space4,
                bottom: AppSpacing.space4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '결제 정보를 확인하고 다시 시도해 주세요.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppSemanticColors.statusErrorText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  // 결제 실패 정보 표시 (최대 5개)
                  ...subscriptionProvider.paymentFailures
                      .take(5)
                      .map((failure) => _buildPaymentFailureItem(failure))
                      .toList(),
                  if (subscriptionProvider.paymentFailures.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.space2),
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
      margin: const EdgeInsets.only(bottom: AppSpacing.space2),
      padding: const EdgeInsets.all(AppSpacing.space3),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppSemanticColors.statusErrorBorder),
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
                const SizedBox(height: AppSpacing.space1),
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

  Widget _buildSubscriptionControlButtons(
    Subscription subscription,
    SubscriptionProvider subscriptionProvider,
  ) {
    return Row(
      children: [
        // 구독 취소/활성화 버튼
        Expanded(
          child: subscription.isActive
              ? SeedButton(
                  label: '구독 일시정지',
                  variant: SeedButtonVariant.neutralOutline,
                  prefixIcon: Icons.pause_circle_outline,
                  isLoading: subscriptionProvider.isLoading,
                  onPressed: subscriptionProvider.isLoading
                      ? null
                      : () =>
                            _showCancelSubscriptionDialog(subscriptionProvider),
                )
              : SeedButton(
                  label: '구독 재개',
                  prefixIcon: Icons.play_circle_outline,
                  isLoading: subscriptionProvider.isLoading,
                  onPressed: subscriptionProvider.isLoading
                      ? null
                      : () => _showActivateSubscriptionDialog(
                          subscriptionProvider,
                        ),
                ),
        ),
      ],
    );
  }

  Future<void> _showCancelSubscriptionDialog(
    SubscriptionProvider subscriptionProvider,
  ) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: '구독 일시정지',
      message: '구독을 일시정지하시겠습니까?\n다음 결제일에 자동 결제가 중단됩니다.',
      confirmText: '일시정지',
    );
    if (confirmed == true) {
      final success = await subscriptionProvider.cancelSubscription();
      if (success && mounted) {
        AppSnackBar.showWarning(context, message: '구독이 일시정지되었습니다');
      }
    }
  }

  Future<void> _showActivateSubscriptionDialog(
    SubscriptionProvider subscriptionProvider,
  ) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: '구독 재개',
      message: '구독을 재개하시겠습니까?\n다음 결제일부터 자동 결제가 재개됩니다.',
      confirmText: '재개',
    );
    if (confirmed == true) {
      final success = await subscriptionProvider.activateSubscription();
      if (success && mounted) {
        AppSnackBar.showSuccess(context, message: '구독이 재개되었습니다');
      }
    }
  }

  void _showAdminWithdrawalDialog(AuthProvider authProvider) {
    bool isWithdrawing = false;

    AppDialog.showCustom<void>(
      context,
      child: StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(AppSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.space2),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.statusErrorBackground,
                      borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                    ),
                    child: Icon(
                      Icons.person_remove,
                      color: AppSemanticColors.statusErrorIcon,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: Text(
                      '관리자 회원탈퇴',
                      style: AppTypography.heading6.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space4),
              Container(
                padding: const EdgeInsets.all(AppSpacing.space4),
                decoration: BoxDecoration(
                  color: AppSemanticColors.statusErrorBackground,
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  border: Border.all(
                    color: AppSemanticColors.statusErrorBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: AppSemanticColors.statusErrorIcon,
                        ),
                        const SizedBox(width: AppSpacing.space1_5),
                        Text(
                          '주의사항',
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppSemanticColors.statusErrorText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space2),
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
              const SizedBox(height: AppSpacing.space4),
              Text(
                '정말로 관리자 회원탈퇴를 진행하시겠습니까?',
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppSemanticColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.space6),
              Row(
                children: [
                  Expanded(
                    child: SeedButton(
                      label: '취소',
                      variant: SeedButtonVariant.neutralOutline,
                      isDisabled: isWithdrawing,
                      onPressed: isWithdrawing
                          ? null
                          : () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: SeedButton(
                      label: '탈퇴하기',
                      variant: SeedButtonVariant.critical,
                      isLoading: isWithdrawing,
                      onPressed: isWithdrawing
                          ? null
                          : () async {
                              setState(() => isWithdrawing = true);

                              final success = await authProvider
                                  .deleteAdminAccount();

                              if (success && context.mounted) {
                                Navigator.pop(context);

                                await Future.delayed(
                                  const Duration(milliseconds: 100),
                                );

                                if (context.mounted) {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                    (route) => false,
                                  );

                                  AppSnackBar.showSuccess(
                                    context,
                                    message:
                                        '관리자 회원탈퇴가 완료되었습니다. 그동안 이용해주셔서 감사했습니다.',
                                  );
                                }
                              } else if (context.mounted) {
                                setState(() => isWithdrawing = false);

                                AppSnackBar.showError(
                                  context,
                                  message: authProvider.errorMessage.isNotEmpty
                                      ? authProvider.errorMessage
                                      : '관리자 회원탈퇴에 실패했습니다',
                                );
                              }
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
