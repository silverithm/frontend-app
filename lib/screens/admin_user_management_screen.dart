import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../utils/admin_utils.dart';
import '../utils/permissions.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/seed/seed_button.dart';

class AdminUserManagementScreen extends StatefulWidget {
  final bool showBackButton;

  const AdminUserManagementScreen({super.key, this.showBackButton = true});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  // 개별 사용자 작업 상태 추적
  final Set<String> _processingStatusUsers = {};
  final Set<String> _processingDeleteUsers = {};

  @override
  void initState() {
    super.initState();

    // 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final authProvider = context.read<AuthProvider>();
    final adminProvider = context.read<AdminProvider>();
    final companyId = authProvider.currentUser?.company?.id ?? '';

    if (companyId.isNotEmpty) {
      adminProvider.loadPendingUsers(companyId);
      adminProvider.loadCompanyMembers(companyId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // 회원 조회/관리 권한 — 관리자는 언제나 통과한다
        if (!PermissionUtils.hasAny(authProvider.currentUser, const [
          AppPermission.memberView,
          AppPermission.memberManage,
        ])) {
          return _buildNoPermissionView();
        }

        // 슬림 상단: 타이틀 1개(AppBar) + 탭바만. 배지·서브텍스트로
        // 제목을 반복하지 않는다 (Seed 레이아웃 원칙 — 중복 레이어 금지).
        // 회원 '조회'만 위임받은 직원에게는 가입 승인 탭과 상태변경·삭제 버튼을 감춘다.
        final canManageMembers = PermissionUtils.has(
          authProvider.currentUser,
          AppPermission.memberManage,
        );

        return DefaultTabController(
          length: canManageMembers ? 2 : 1,
          child: Scaffold(
            backgroundColor: AppSemanticColors.backgroundPrimary,
            appBar: AppBar(
              title: Text('회원 관리', style: AppTypography.heading5),
              backgroundColor: AppSemanticColors.backgroundPrimary,
              elevation: 0,
              automaticallyImplyLeading: widget.showBackButton,
              leading: widget.showBackButton
                  ? IconButton(
                      tooltip: '뒤로 가기',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : null,
              actions: [
                IconButton(
                  tooltip: '새로고침',
                  icon: Icon(
                    Icons.refresh,
                    color: AppSemanticColors.textPrimary,
                  ),
                  onPressed: _loadData,
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppSemanticColors.borderDefault,
                        width: 1,
                      ),
                    ),
                  ),
                  child: TabBar(
                    labelColor: AppSemanticColors.interactivePrimaryDefault,
                    unselectedLabelColor: AppSemanticColors.textTertiary,
                    indicatorColor: AppSemanticColors.interactivePrimaryDefault,
                    indicatorWeight: 2,
                    labelStyle: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: AppTypography.labelMedium,
                    dividerColor: AppColors.transparent,
                    tabs: [
                      if (canManageMembers)
                        const Tab(
                          icon: Icon(Icons.pending_actions, size: 20),
                          text: '승인 대기',
                        ),
                      const Tab(
                        icon: Icon(Icons.people, size: 20),
                        text: '전체 회원',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            body: TabBarView(
              children: [
                if (canManageMembers) const AdminPendingUsersTab(),
                _buildAllMembersTab(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoPermissionView() {
    return Scaffold(
      appBar: AppBar(
        title: Text('회원 관리', style: AppTypography.heading5),
        backgroundColor: AppSemanticColors.backgroundPrimary,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppSemanticColors.statusErrorIcon,
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(
              '관리자 권한이 필요합니다',
              style: AppTypography.heading6.copyWith(
                fontWeight: FontWeight.bold,
                color: AppSemanticColors.statusErrorIcon,
              ),
            ),
            const SizedBox(height: AppSpacing.space2),
            Text(
              '회원 관리 기능을 사용하려면 관리자 권한이 필요합니다.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllMembersTab() {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        if (adminProvider.isLoading) {
          return Center(
            child: CircularProgressIndicator(
              color: AppSemanticColors.interactivePrimaryDefault,
            ),
          );
        }

        if (adminProvider.errorMessage.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppSemanticColors.statusErrorIcon,
                ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  '오류 발생',
                  style: AppTypography.heading6.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppSemanticColors.statusErrorIcon,
                  ),
                ),
                const SizedBox(height: AppSpacing.space2),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space8,
                  ),
                  child: Text(
                    adminProvider.errorMessage,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.space4),
                SeedButton(
                  label: '다시 시도',
                  onPressed: _loadData,
                  variant: SeedButtonVariant.neutralWeak,
                ),
              ],
            ),
          );
        }

        if (adminProvider.companyMembers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: AppSemanticColors.textTertiary,
                ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  '등록된 회원이 없습니다',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppSemanticColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _loadData(),
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.space4),
            itemCount: adminProvider.companyMembers.length,
            itemBuilder: (context, index) {
              final user = adminProvider.companyMembers[index];
              return _buildMemberCard(user);
            },
          ),
        );
      },
    );
  }

  Widget _buildMemberCard(User user) {
    final isActive = user.status == 'active';
    final isStatusProcessing = _processingStatusUsers.contains(
      user.id.toString(),
    );
    final isDeleteProcessing = _processingDeleteUsers.contains(
      user.id.toString(),
    );

    // 정적 리스트 카드 — 그림자 대신 보더만 (Seed 레이아웃 원칙)
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.space2),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(color: AppSemanticColors.borderSubtle, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
      onTap: () => _showMemberDetail(user),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isActive
                      ? AppSemanticColors.statusSuccessBackground
                      : AppSemanticColors.backgroundSecondary,
                  child: Icon(
                    Icons.person,
                    size: 18,
                    color: isActive
                        ? AppSemanticColors.statusSuccessIcon
                        : AppSemanticColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.space2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        user.email,
                        style: AppTypography.caption.copyWith(
                          color: AppSemanticColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space1_5,
                    vertical: AppSpacing.space0_5,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppSemanticColors.statusSuccessBackground
                        : AppSemanticColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                  ),
                  child: Text(
                    AdminUtils.getStatusDisplayName(user.status),
                    style: AppTypography.caption.copyWith(
                      color: isActive
                          ? AppSemanticColors.statusSuccessText
                          : AppSemanticColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space1),
            Row(
              children: [
                const SizedBox(width: 44), // avatar + gap 정렬
                Icon(
                  Icons.work_outline,
                  size: 14,
                  color: AppSemanticColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.space1),
                Text(
                  AdminUtils.getRoleDisplayName(user.role),
                  style: AppTypography.caption.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space3),
            // 상태 변경·삭제는 '회원 관리' 권한자만 (조회 권한자는 목록만 본다)
            if (PermissionUtils.has(
              context.read<AuthProvider>().currentUser,
              AppPermission.memberManage,
            ))
            Row(
              children: [
                Expanded(
                  child: SeedButton(
                    label: isStatusProcessing
                        ? '처리중...'
                        : (isActive ? '비활성화' : '활성화'),
                    onPressed: isStatusProcessing
                        ? null
                        : () => _toggleMemberStatus(user),
                    variant: SeedButtonVariant.brandSolid,
                    size: SeedButtonSize.small,
                    isLoading: isStatusProcessing,
                    prefixIcon: isActive ? Icons.pause : Icons.play_arrow,
                  ),
                ),
                const SizedBox(width: AppSpacing.space2),
                Expanded(
                  child: SeedButton(
                    label: isDeleteProcessing ? '처리중...' : '삭제',
                    onPressed: isDeleteProcessing
                        ? null
                        : () => _showDeleteDialog(user),
                    variant: SeedButtonVariant.critical,
                    size: SeedButtonSize.small,
                    isLoading: isDeleteProcessing,
                    prefixIcon: Icons.delete,
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

  /// 활성 회원 상세 — 카드에 없는 아이디·부서·직책·최근 로그인까지 한 시트로.
  void _showMemberDetail(User user) {
    String formatDate(DateTime? d) => d == null
        ? '-'
        : '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.space2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  label,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppSemanticColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value.isEmpty ? '-' : value,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        );

    final bool isActive = user.status == 'active';
    AppBottomSheet.show(
      context,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      user.name,
                      style: AppTypography.heading5.copyWith(
                        color: AppSemanticColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space2,
                      vertical: AppSpacing.space1,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppSemanticColors.statusSuccessBackground
                          : AppSemanticColors.backgroundTertiary,
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    ),
                    child: Text(
                      isActive ? '활성' : '비활성',
                      style: AppTypography.labelSmall.copyWith(
                        color: isActive
                            ? AppSemanticColors.statusSuccessText
                            : AppSemanticColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space4),
              row('역할', AdminUtils.getRoleDisplayName(user.role)),
              row('이메일', user.email),
              row('아이디', user.username),
              row('부서', user.department ?? ''),
              row('직책', user.position ?? ''),
              row('가입일', formatDate(user.createdAt)),
              row('최근 로그인', formatDate(user.lastLoginAt)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleMemberStatus(User user) async {
    final newStatus = user.status == 'active' ? 'inactive' : 'active';
    final actionText = newStatus == 'active' ? '활성화' : '비활성화';

    final confirmed = await AppDialog.showConfirm(
      context,
      title: '회원 $actionText',
      message: '${user.name}님을 $actionText하시겠습니까?',
      confirmText: actionText,
      cancelText: '취소',
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _processingStatusUsers.add(user.id.toString());
    });
    try {
      final adminProvider = context.read<AdminProvider>();
      final success = await adminProvider.updateMemberStatus(
        user.id,
        newStatus,
      );
      if (success && mounted) {
        // 활성화=긍정 결과, 비활성화=주의가 필요한 정상 처리 결과 — 둘 다 실패가 아니므로 빨강은 쓰지 않는다
        if (newStatus == 'active') {
          AppSnackBar.showSuccess(
            context,
            message: '${user.name}님을 $actionText했습니다.',
          );
        } else {
          AppSnackBar.showWarning(
            context,
            message: '${user.name}님을 $actionText했습니다.',
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingStatusUsers.remove(user.id.toString());
        });
      }
    }
  }

  Future<void> _showDeleteDialog(User user) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: '회원 삭제',
      message: '${user.name}님을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
      confirmText: '삭제',
      cancelText: '취소',
      confirmVariant: SeedButtonVariant.critical,
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _processingDeleteUsers.add(user.id.toString());
    });
    try {
      final adminProvider = context.read<AdminProvider>();
      final success = await adminProvider.deleteMember(user.id);
      if (success && mounted) {
        // 삭제는 되돌릴 수 없는 행위지만, 이 알림은 "정상적으로 완료됐다"는 결과 통보이지 오류가 아니다 — 빨강 금지
        AppSnackBar.showInfo(context, message: '${user.name}님을 삭제했습니다.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingDeleteUsers.remove(user.id.toString());
        });
      }
    }
  }
}

/// 승인 대기 사용자 목록 + 승인/거부 액션.
/// AdminUserManagementScreen(회원 관리 > 승인 대기 탭)과
/// AdminUnifiedApprovalScreen(승인함 > 가입 승인 탭)에서 공유한다.
/// (admin_user_management_screen.dart에서 추출 — 로직 변경 없음)
class AdminPendingUsersTab extends StatefulWidget {
  const AdminPendingUsersTab({super.key});

  @override
  State<AdminPendingUsersTab> createState() => _AdminPendingUsersTabState();
}

class _AdminPendingUsersTabState extends State<AdminPendingUsersTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final authProvider = context.read<AuthProvider>();
    final adminProvider = context.read<AdminProvider>();
    final companyId = authProvider.currentUser?.company?.id ?? '';

    if (companyId.isNotEmpty) {
      adminProvider.loadPendingUsers(companyId);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        if (adminProvider.isLoading) {
          return Center(
            child: CircularProgressIndicator(
              color: AppSemanticColors.interactivePrimaryDefault,
            ),
          );
        }

        if (adminProvider.errorMessage.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppSemanticColors.statusErrorIcon,
                ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  '오류 발생',
                  style: AppTypography.heading6.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppSemanticColors.statusErrorIcon,
                  ),
                ),
                const SizedBox(height: AppSpacing.space2),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space8,
                  ),
                  child: Text(
                    adminProvider.errorMessage,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.space4),
                SeedButton(
                  label: '다시 시도',
                  onPressed: _loadData,
                  variant: SeedButtonVariant.neutralWeak,
                ),
              ],
            ),
          );
        }

        if (adminProvider.pendingUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: AppSemanticColors.statusSuccessIcon,
                ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  '승인 대기 중인 사용자가 없습니다',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppSemanticColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _loadData(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space4,
              vertical: AppSpacing.space2,
            ),
            itemCount: adminProvider.pendingUsers.length,
            itemBuilder: (context, index) {
              final user = adminProvider.pendingUsers[index];
              return _buildPendingUserCard(user);
            },
          ),
        );
      },
    );
  }

  Widget _buildPendingUserCard(User user) {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        final isProcessing = adminProvider.isLoading;

        // 정적 리스트 카드 — 그림자 대신 보더만 (Seed 레이아웃 원칙)
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.space3),
          decoration: BoxDecoration(
            color: AppSemanticColors.surfaceDefault,
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            border: Border.all(color: AppSemanticColors.borderSubtle, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _showPendingUserDetail(user),
            child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          AppSemanticColors.statusWarningBackground,
                      child: Icon(
                        Icons.person,
                        color: AppSemanticColors.statusWarningIcon,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user.email,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppSemanticColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space2,
                        vertical: AppSpacing.space1,
                      ),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.statusWarningBackground,
                        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                      ),
                      child: Text(
                        AdminUtils.getRoleDisplayName(user.role),
                        style: AppTypography.labelSmall.copyWith(
                          color: AppSemanticColors.statusWarningText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space4),
                Row(
                  children: [
                    Expanded(
                      child: SeedButton(
                        label: isProcessing ? '처리중...' : '승인',
                        onPressed: isProcessing
                            ? null
                            : () => _showApprovalDialog(user),
                        variant: SeedButtonVariant.brandSolid,
                        isLoading: isProcessing,
                        prefixIcon: Icons.check,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space3),
                    Expanded(
                      child: SeedButton(
                        label: isProcessing ? '처리중...' : '거부',
                        onPressed: isProcessing
                            ? null
                            : () => _showRejectDialog(user),
                        variant: SeedButtonVariant.neutralOutline,
                        isLoading: isProcessing,
                        prefixIcon: Icons.close,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  /// 가입 신청 상세 — 카드에 없는 아이디·부서·직책·신청일까지 한 시트로.
  void _showPendingUserDetail(User user) {
    String formatDate(DateTime d) =>
        '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.space2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  label,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppSemanticColors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value.isEmpty ? '-' : value,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        );

    AppBottomSheet.show(
      context,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      user.name,
                      style: AppTypography.heading5.copyWith(
                        color: AppSemanticColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space2,
                      vertical: AppSpacing.space1,
                    ),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.statusWarningBackground,
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    ),
                    child: Text(
                      AdminUtils.getRoleDisplayName(user.role),
                      style: AppTypography.labelSmall.copyWith(
                        color: AppSemanticColors.statusWarningText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space4),
              row('이메일', user.email),
              row('아이디', user.username),
              row('부서', user.department ?? ''),
              row('직책', user.position ?? ''),
              row('신청일', formatDate(user.createdAt)),
              const SizedBox(height: AppSpacing.space5),
              Row(
                children: [
                  Expanded(
                    child: SeedButton(
                      label: '거부',
                      variant: SeedButtonVariant.neutralOutline,
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showRejectDialog(user);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  Expanded(
                    child: SeedButton(
                      label: '승인',
                      variant: SeedButtonVariant.brandSolid,
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showApprovalDialog(user);
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

  Future<void> _showApprovalDialog(User user) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: '가입 승인',
      message: '${user.name}님의 가입을 승인하시겠습니까?',
      confirmText: '승인',
      cancelText: '취소',
    );

    if (confirmed != true || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    final adminProvider = context.read<AdminProvider>();
    final success = await adminProvider.approveJoinRequest(
      user.id,
      authProvider.currentUser?.id ?? '',
    );
    if (mounted && success) {
      AppSnackBar.showSuccess(context, message: '${user.name}님의 가입을 승인했습니다.');
    }
  }

  Future<void> _showRejectDialog(User user) async {
    final reason = await AppDialog.showInput(
      context,
      title: '가입 거부',
      message: '${user.name}님의 가입을 거부하시겠습니까?',
      hintText: '거부 사유를 입력해주세요',
      maxLines: 3,
      confirmText: '거부',
      cancelText: '취소',
      validator: (value) =>
          (value == null || value.trim().isEmpty) ? '거부 사유를 입력해주세요' : null,
    );

    if (reason == null || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    final adminProvider = context.read<AdminProvider>();
    final success = await adminProvider.rejectJoinRequest(
      user.id,
      authProvider.currentUser?.id ?? '',
      reason.trim(),
    );
    if (mounted && success) {
      // 거부는 실패가 아니라 정상 처리 결과다 — 비활성화 완료와 같은 톤(warning)으로 통일
      AppSnackBar.showWarning(context, message: '${user.name}님의 가입을 거부했습니다.');
    }
  }
}
