import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../providers/admin_provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../utils/admin_utils.dart';
import '../utils/constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() => _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  // 개별 사용자 작업 상태 추적
  Set<String> _processingStatusUsers = {};
  Set<String> _processingDeleteUsers = {};

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
        if (!AdminUtils.canManageUsers(authProvider.currentUser)) {
          return _buildNoPermissionView();
        }

        return Scaffold(
          backgroundColor: AppSemanticColors.backgroundPrimary,
          appBar: AppBar(
            title: Text('회원 관리', style: AppTypography.heading6.copyWith(color: AppSemanticColors.textInverse)),
            backgroundColor: AppSemanticColors.interactivePrimaryDefault,
            foregroundColor: AppSemanticColors.textInverse,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh, color: AppSemanticColors.textInverse),
                onPressed: _loadData,
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(80),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.textInverse.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.pending_actions,
                        color: AppSemanticColors.textInverse,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '승인 대기 회원 관리',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppSemanticColors.textInverse.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.textInverse.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'ADMIN',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppSemanticColors.textInverse.withValues(alpha: 0.9),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: _buildPendingUsersTab(),
        );
      },
    );
  }

  Widget _buildNoPermissionView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원 관리'),
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        foregroundColor: AppSemanticColors.textInverse,
        iconTheme: IconThemeData(color: AppSemanticColors.textInverse),
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
            const SizedBox(height: 16),
            Text(
              '관리자 권한이 필요합니다',
              style: AppTypography.heading6.copyWith(
                fontWeight: FontWeight.bold,
                color: AppSemanticColors.statusErrorIcon,
              ),
            ),
            const SizedBox(height: 8),
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

  Widget _buildPendingUsersTab() {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        if (adminProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
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
                const SizedBox(height: 16),
                Text(
                  '오류 발생',
                  style: AppTypography.heading6.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppSemanticColors.statusErrorIcon,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    adminProvider.errorMessage,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                shadcn.PrimaryButton(
                  onPressed: _loadData,
                  child: const Text('다시 시도'),
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
                const SizedBox(height: 16),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _buildAllMembersTab() {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        if (adminProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
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
                const SizedBox(height: 16),
                Text(
                  '오류 발생',
                  style: AppTypography.heading6.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppSemanticColors.statusErrorIcon,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    adminProvider.errorMessage,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                shadcn.PrimaryButton(
                  onPressed: _loadData,
                  child: const Text('다시 시도'),
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
                const SizedBox(height: 16),
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
            padding: const EdgeInsets.all(Constants.defaultPadding),
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

  Widget _buildPendingUserCard(User user) {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        final isProcessing = adminProvider.isLoading;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppSemanticColors.statusWarningBackground,
                      child: Icon(
                        Icons.person,
                        color: AppSemanticColors.statusWarningIcon,
                      ),
                    ),
                    const SizedBox(width: 12),
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
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.statusWarningBackground,
                        borderRadius: BorderRadius.circular(12),
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: shadcn.PrimaryButton(
                        onPressed: isProcessing ? null : () => _showApprovalDialog(user),
                        leading: isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check, size: 18),
                        child: Text(isProcessing ? '처리중...' : '승인'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: shadcn.OutlineButton(
                        onPressed: isProcessing ? null : () => _showRejectDialog(user),
                        leading: isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.close, size: 18),
                        child: Text(isProcessing ? '처리중...' : '거부'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMemberCard(User user) {
    final isActive = user.status == 'active';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isActive
                      ? AppSemanticColors.statusSuccessBackground
                      : AppSemanticColors.backgroundSecondary,
                  child: Icon(
                    Icons.person,
                    color: isActive
                        ? AppSemanticColors.statusSuccessIcon
                        : AppSemanticColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
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
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppSemanticColors.statusSuccessBackground
                        : AppSemanticColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AdminUtils.getStatusDisplayName(user.status),
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
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.work_outline,
                  size: 16,
                  color: AppSemanticColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  AdminUtils.getRoleDisplayName(user.role),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: shadcn.PrimaryButton(
                    onPressed: _processingStatusUsers.contains(user.id.toString())
                        ? null
                        : () => _toggleMemberStatus(user),
                    leading: _processingStatusUsers.contains(user.id.toString())
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            isActive ? Icons.pause : Icons.play_arrow,
                            size: 18,
                          ),
                    child: Text(
                      _processingStatusUsers.contains(user.id.toString())
                          ? '처리중...'
                          : (isActive ? '비활성화' : '활성화'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: shadcn.DestructiveButton(
                    onPressed: _processingDeleteUsers.contains(user.id.toString())
                        ? null
                        : () => _showDeleteDialog(user),
                    leading: _processingDeleteUsers.contains(user.id.toString())
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete, size: 18),
                    child: Text(
                      _processingDeleteUsers.contains(user.id.toString())
                          ? '처리중...'
                          : '삭제',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showApprovalDialog(User user) {
    showDialog(
      context: context,
      builder: (dialogContext) => shadcn.AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppSemanticColors.statusSuccessIcon),
            const SizedBox(width: 8),
            const Text('가입 승인'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${user.name}님의 가입을 승인하시겠습니까?'),
          ],
        ),
        actions: [
          shadcn.OutlineButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          shadcn.PrimaryButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final authProvider = context.read<AuthProvider>();
              final adminProvider = context.read<AdminProvider>();
              final success = await adminProvider.approveJoinRequest(
                user.id,
                authProvider.currentUser?.id ?? '',
              );
              if (mounted && success) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('${user.name}님의 가입을 승인했습니다.'),
                    backgroundColor: AppSemanticColors.statusSuccessIcon,
                  ),
                );
              }
            },
            child: const Text('승인'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(User user) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => shadcn.AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cancel, color: AppSemanticColors.statusErrorIcon),
            const SizedBox(width: 8),
            const Text('가입 거부'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${user.name}님의 가입을 거부하시겠습니까?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: '거부 사유',
                hintText: '거부 사유를 입력해주세요',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          shadcn.OutlineButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          shadcn.DestructiveButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: const Text('거부 사유를 입력해주세요.'),
                    backgroundColor: AppSemanticColors.statusErrorIcon,
                  ),
                );
                return;
              }
              Navigator.of(dialogContext).pop();
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final authProvider = context.read<AuthProvider>();
              final adminProvider = context.read<AdminProvider>();
              final success = await adminProvider.rejectJoinRequest(
                user.id,
                authProvider.currentUser?.id ?? '',
                reasonController.text.trim(),
              );
              if (mounted && success) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('${user.name}님의 가입을 거부했습니다.'),
                    backgroundColor: AppSemanticColors.statusErrorIcon,
                  ),
                );
              }
            },
            child: const Text('거부'),
          ),
        ],
      ),
    );
  }

  void _toggleMemberStatus(User user) {
    final newStatus = user.status == 'active' ? 'inactive' : 'active';
    final actionText = newStatus == 'active' ? '활성화' : '비활성화';
    
    showDialog(
      context: context,
      builder: (context) => shadcn.AlertDialog(
        title: Row(
          children: [
            Icon(
              newStatus == 'active' ? Icons.play_arrow : Icons.pause,
              color: newStatus == 'active' ? AppSemanticColors.statusSuccessIcon : AppSemanticColors.statusWarningIcon,
            ),
            const SizedBox(width: 8),
            Text('회원 $actionText'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${user.name}님을 ${actionText}하시겠습니까?'),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${user.name}님을 ${actionText}했습니다.'),
                      backgroundColor: newStatus == 'active' ? AppSemanticColors.statusSuccessIcon : AppSemanticColors.statusWarningIcon,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _processingStatusUsers.remove(user.id.toString());
                  });
                }
              }
            },
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => shadcn.AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: AppSemanticColors.statusErrorIcon),
            const SizedBox(width: 8),
            const Text('회원 삭제'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${user.name}님을 삭제하시겠습니까?'),
            const SizedBox(height: 8),
            Text(
              '이 작업은 되돌릴 수 없습니다.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.statusErrorIcon,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          shadcn.OutlineButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          shadcn.DestructiveButton(
            onPressed: () async {
              Navigator.of(context).pop();
              setState(() {
                _processingDeleteUsers.add(user.id.toString());
              });
              try {
                final adminProvider = context.read<AdminProvider>();
                final success = await adminProvider.deleteMember(user.id);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${user.name}님을 삭제했습니다.'),
                      backgroundColor: AppSemanticColors.statusErrorIcon,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _processingDeleteUsers.remove(user.id.toString());
                  });
                }
              }
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}