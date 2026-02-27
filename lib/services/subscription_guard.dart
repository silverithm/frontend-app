import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/subscription_provider.dart';
import '../providers/auth_provider.dart';
import '../screens/subscription_check_screen.dart';
import '../utils/admin_utils.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

class SubscriptionGuard {
  static const String _tag = '[SubscriptionGuard]';

  /// 구독 상태를 확인하고 필요시 SubscriptionCheckScreen으로 리다이렉트
  /// 관리자에게만 적용 - 일반 사용자는 구독 체크 건너뛰기
  static Future<bool> checkSubscriptionAndRedirect(BuildContext context) async {
    try {
      print('$_tag 구독 상태 확인 시작');
      
      final authProvider = context.read<AuthProvider>();
      final subscriptionProvider = context.read<SubscriptionProvider>();

      // 사용자 정보가 없으면 구독 체크 건너뛰기
      if (authProvider.currentUser == null) {
        print('$_tag 사용자 정보 없음 - 구독 체크 건너뛰기');
        return true;
      }

      final isAdmin = AdminUtils.canAccessAdminPages(authProvider.currentUser);
      
      // 일반 사용자는 구독 체크 건너뛰기 (보류)
      if (!isAdmin) {
        print('$_tag 일반 사용자 - 구독 체크 건너뛰기 (보류)');
        return true;
      }
      
      print('$_tag 관리자 사용자 - 구독 상태 확인 진행');

      // 구독 정보 로드
      final hasSubscription = await subscriptionProvider.loadSubscription();
      
      // 구독이 있고 활성 상태인 경우
      if (hasSubscription && subscriptionProvider.hasActiveSubscription) {
        print('$_tag 활성 구독 있음 - 메인 화면 진행');
        return true;
      } 
      // 관리자에게 구독이 없거나 비활성 상태인 경우 구독 화면으로 이동
      else {
        print('$_tag 관리자 - 활성 구독 없음 - 구독 선택 화면으로 이동');
        print('$_tag hasSubscription: $hasSubscription, hasActiveSubscription: ${subscriptionProvider.hasActiveSubscription}');
        _navigateToSubscriptionCheck(context, true);
        return false;
      }
    } catch (e) {
      print('$_tag 구독 체크 중 오류: $e');
      final authProvider = context.read<AuthProvider>();
      final isAdmin = AdminUtils.canAccessAdminPages(authProvider.currentUser);
      
      // 관리자의 경우 404 오류 (구독 없음)시 구독 화면으로 이동
      if (isAdmin && (e.toString().contains('404') || e.toString().contains('No subscription found'))) {
        print('$_tag 관리자 404 오류 - 구독 없음으로 판단하여 구독 화면으로 이동');
        _navigateToSubscriptionCheck(context, true);
        return false;
      }
      
      // 일반 사용자이거나 기타 오류 발생 시 메인 화면으로 진행
      print('$_tag 일반 사용자이거나 기타 오류 - 메인 화면 진행');
      return true;
    }
  }

  /// 구독 선택 화면으로 이동
  static void _navigateToSubscriptionCheck(BuildContext context, [bool isAdmin = false]) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => SubscriptionCheckScreen(isAdmin: isAdmin),
      ),
      (route) => false, // 이전 화면 스택 모두 제거
    );
  }

  /// 현재 사용자가 특정 기능에 접근할 수 있는지 확인
  static bool canAccessFeature(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final subscriptionProvider = context.read<SubscriptionProvider>();

    // 관리자는 모든 기능 접근 가능
    if (AdminUtils.canAccessAdminPages(authProvider.currentUser)) {
      return true;
    }

    // 일반 사용자는 활성 구독이 있어야 접근 가능
    return subscriptionProvider.hasActiveSubscription;
  }

  /// 구독이 필요한 기능 접근 시 안내 다이얼로그 표시
  static void showSubscriptionRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => shadcn.AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.workspace_premium,
              color: AppSemanticColors.statusWarningIcon,
            ),
            const SizedBox(width: 8),
            const Text('구독 필요'),
          ],
        ),
        content: const Text(
          '이 기능을 사용하려면 구독이 필요합니다.\n구독 화면으로 이동하시겠습니까?',
        ),
        actions: [
          shadcn.GhostButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          shadcn.PrimaryButton(
            onPressed: () {
              Navigator.of(context).pop();
              final isAdmin = AdminUtils.canAccessAdminPages(context.read<AuthProvider>().currentUser);
              _navigateToSubscriptionCheck(context, isAdmin);
            },
            child: const Text('구독하기'),
          ),
        ],
      ),
    );
  }

  /// 구독 만료 경고 다이얼로그 표시
  static void showSubscriptionExpiryWarning(BuildContext context) {
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final daysRemaining = subscriptionProvider.getDaysRemaining();
    
    if (daysRemaining <= 7 && daysRemaining > 0) {
      showDialog(
        context: context,
        builder: (context) => shadcn.AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.warning,
                color: AppSemanticColors.statusWarningIcon,
              ),
              const SizedBox(width: 8),
              const Text('구독 만료 예정'),
            ],
          ),
          content: Text(
            '구독이 ${daysRemaining}일 후에 만료됩니다.\n계속 서비스를 이용하려면 구독을 연장해주세요.',
          ),
          actions: [
            shadcn.GhostButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('나중에'),
            ),
            shadcn.PrimaryButton(
              onPressed: () {
                Navigator.of(context).pop();
                final isAdmin = AdminUtils.canAccessAdminPages(context.read<AuthProvider>().currentUser);
                _navigateToSubscriptionCheck(context, isAdmin);
              },
              child: const Text('구독 연장'),
            ),
          ],
        ),
      );
    }
  }

  /// 앱 시작시 구독 상태를 확인하고 필요한 액션 수행
  static Future<void> performStartupSubscriptionCheck(BuildContext context) async {
    try {
      print('$_tag 앱 시작 구독 체크 수행');
      
      // 구독 상태 확인 및 리다이렉트
      final canProceed = await checkSubscriptionAndRedirect(context);
      
      if (canProceed) {
        // 구독 만료 경고 표시 (필요시)
        showSubscriptionExpiryWarning(context);
      }
    } catch (e) {
      print('$_tag 시작 시 구독 체크 오류: $e');
    }
  }
}