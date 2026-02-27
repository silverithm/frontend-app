import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../providers/auth_provider.dart';
import '../providers/vacation_provider.dart';
import '../providers/approval_provider.dart';
import '../providers/notice_provider.dart';
import '../providers/admin_provider.dart';
import '../utils/admin_utils.dart';
import '../providers/notification_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'my_vacation_screen.dart';
import 'approval_list_screen.dart';
import 'notice_list_screen.dart';
import 'admin_unified_approval_screen.dart';
import 'admin_notice_management_screen.dart';
import 'admin_user_management_screen.dart';
import '../widgets/common/notification_bell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    final isAdmin = AdminUtils.canAccessAdminPages(user);
    final companyId = user.company?.id ?? '';

    try {
      if (isAdmin) {
        await Future.wait([
          context.read<ApprovalProvider>().loadApprovalRequests(
                companyId: companyId,
                refresh: true,
              ),
          context.read<NoticeProvider>().loadNotices(
                companyId: companyId,
                refresh: true,
              ),
          context.read<AdminProvider>().loadPendingUsers(companyId),
          context.read<AdminProvider>().loadCompanyMembers(companyId),
        ]);
      } else {
        await Future.wait([
          context.read<VacationProvider>().loadMyVacationRequests(
                user.id.toString(),
                companyId: companyId,
                userName: user.name,
              ),
          context.read<ApprovalProvider>().loadMyApprovalRequests(
                requesterId: user.id.toString(),
                refresh: true,
              ),
          context.read<NoticeProvider>().loadPublishedNotices(
                companyId: companyId,
                refresh: true,
              ),
        ]);
      }
      // 알림 로드
      context.read<NotificationProvider>().loadNotifications(user.id.toString());
    } catch (e) {
      print('[HomeScreen] 대시보드 데이터 로드 에러: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final isAdmin = AdminUtils.canAccessAdminPages(user);

    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: AppSemanticColors.interactivePrimaryDefault,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 헤더: "홈" 가운데 정렬 + 알림 벨
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space5,
                    AppSpacing.space4,
                    AppSpacing.space5,
                    AppSpacing.space2,
                  ),
                  child: SizedBox(
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // 중앙 타이틀
                        Text(
                          '홈',
                          style: AppTypography.heading5.copyWith(
                            color: AppSemanticColors.textPrimary,
                            fontWeight: AppTypography.fontWeightBold,
                          ),
                        ),
                        // 오른쪽 알림 벨
                        Positioned(
                          right: 0,
                          child: const NotificationBell(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 인사말
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space5,
                  AppSpacing.space2,
                  AppSpacing.space5,
                  AppSpacing.space4,
                ),
                child: Text(
                  '안녕하세요, ${user?.name ?? '사용자'}님',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
              ),
            ),

            // 로딩 또는 콘텐츠
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space5,
                  0,
                  AppSpacing.space5,
                  AppSpacing.space8,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    isAdmin
                        ? _buildAdminCards()
                        : _buildEmployeeCards(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===================== 직원 카드 목록 =====================

  List<Widget> _buildEmployeeCards() {
    return [
      Consumer<VacationProvider>(
        builder: (context, provider, _) {
          final total = provider.vacationRequests.length;
          return _HomeTile(
            icon: Icons.calendar_today_rounded,
            title: '내 휴무',
            subtitle: '휴무 신청 및 현황 확인',
            badgeCount: total,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyVacationScreen()),
            ),
          );
        },
      ),
      const SizedBox(height: AppSpacing.space3),
      Consumer<ApprovalProvider>(
        builder: (context, provider, _) {
          final total = provider.myApprovalRequests.length;
          return _HomeTile(
            icon: Icons.description_outlined,
            title: '결재',
            subtitle: '결재 요청 및 승인 현황',
            badgeCount: total,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ApprovalListScreen()),
            ),
          );
        },
      ),
      const SizedBox(height: AppSpacing.space3),
      Consumer<NoticeProvider>(
        builder: (context, provider, _) {
          final total = provider.publishedNotices.length;
          return _HomeTile(
            icon: Icons.campaign_outlined,
            title: '공지사항',
            subtitle: '회사 공지 확인',
            badgeCount: total,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NoticeListScreen()),
            ),
          );
        },
      ),
    ];
  }

  // ===================== 관리자 카드 목록 =====================

  List<Widget> _buildAdminCards() {
    return [
      Consumer<ApprovalProvider>(
        builder: (context, provider, _) {
          final total = provider.approvalRequests.length;
          return _HomeTile(
            icon: Icons.fact_check_outlined,
            title: '결재관리',
            subtitle: '결재 요청 승인 및 관리',
            badgeCount: total,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const AdminUnifiedApprovalScreen()),
            ),
          );
        },
      ),
      const SizedBox(height: AppSpacing.space3),
      Consumer<NoticeProvider>(
        builder: (context, provider, _) {
          final total = provider.notices.length;
          return _HomeTile(
            icon: Icons.campaign_outlined,
            title: '공지관리',
            subtitle: '공지사항 작성 및 관리',
            badgeCount: total,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const AdminNoticeManagementScreen()),
            ),
          );
        },
      ),
      const SizedBox(height: AppSpacing.space3),
      Consumer<AdminProvider>(
        builder: (context, provider, _) {
          final pendingCount = provider.pendingUsers.length;
          return _HomeTile(
            icon: Icons.people_outline_rounded,
            title: '회원관리',
            subtitle: '회원 승인 및 관리',
            badgeCount: pendingCount,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const AdminUserManagementScreen()),
            ),
          );
        },
      ),
    ];
  }
}

// ===================== 홈 타일 컴포넌트 =====================

class _HomeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int badgeCount;
  final VoidCallback onTap;

  const _HomeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      borderRadius: BorderRadius.circular(AppBorderRadius.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        splashColor: AppSemanticColors.interactivePrimaryDefault.withValues(alpha: 0.06),
        highlightColor: AppSemanticColors.interactivePrimaryDefault.withValues(alpha: 0.04),
        child: shadcn.Card(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space5,
            vertical: AppSpacing.space4,
          ),
          child: Row(
            children: [
              // 아이콘
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppSemanticColors.backgroundTertiary,
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: AppSemanticColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.space4),
              // 제목 + 설명
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppSemanticColors.textPrimary,
                        fontWeight: AppTypography.fontWeightSemibold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space0_5),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppSemanticColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // 뱃지 카운트
              if (badgeCount > 0) ...[
                const SizedBox(width: AppSpacing.space2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space2_5,
                    vertical: AppSpacing.space1,
                  ),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.statusErrorIcon,
                    borderRadius: BorderRadius.circular(AppBorderRadius.full),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppSemanticColors.textInverse,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.space2),
              // 화살표
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppSemanticColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
