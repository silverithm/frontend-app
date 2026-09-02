import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/admin_utils.dart';
import '../utils/permissions.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/seed/seed_list_cell.dart';
import 'admin_company_settings_screen.dart';
import 'admin_voice_box_screen.dart';
import 'admin_notice_management_screen.dart';
import 'admin_user_management_screen.dart';
import 'admin_vacation_management_screen.dart';
import 'admin_approval_template_screen.dart';
import 'admin_vacation_limits_setting_screen.dart';
import 'ai_post_writer_screen.dart';
import 'company_library_screen.dart';
import 'dispatch_screen.dart';
import 'login_screen.dart';
import 'my_vacation_screen.dart';
import 'notice_list_screen.dart';
import 'notification_settings_screen.dart';
import 'plaza_screen.dart';
import 'profile_screen.dart';
import 'signature_manage_screen.dart';
import 'meeting_minutes_list_screen.dart';
import 'voice_box_screen.dart';

/// 전체 메뉴 탭 — 흩어져 있던 기능들을 역할별 그룹으로 모은 허브.
/// 상단 프로필 카드 + (내 업무 / 소통 / 기관 관리(관리자) / 계정) 그룹.
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _showLogoutDialog(BuildContext context) {
    AppDialog.showConfirm(
      context,
      title: '로그아웃',
      message: '정말 로그아웃하시겠습니까?',
      confirmText: '로그아웃',
    ).then((confirmed) async {
      if (confirmed != true) return;

      final authProvider = context.read<AuthProvider>();
      await authProvider.logout();

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isAdmin = AdminUtils.canAccessAdminPages(user);

    // 세부 권한 — 관리자는 모두 true라 기존 화면이 그대로 유지된다.
    final canManageNotice =
        PermissionUtils.has(user, AppPermission.noticeManage);
    final canViewMembers = PermissionUtils.hasAny(
      user,
      const [AppPermission.memberView, AppPermission.memberManage],
    );
    final canManageWork = PermissionUtils.has(user, AppPermission.workManage);
    final canManageTemplate =
        PermissionUtils.has(user, AppPermission.approvalTemplate);
    final canDispatch =
        PermissionUtils.has(user, AppPermission.scheduleDispatch);

    // '기관 관리' 그룹은 보여줄 항목이 하나라도 있을 때만 낸다.
    // 권한이 없으면 감춘다 — 웹도 권한 없는 탭은 아예 렌더하지 않는다.
    final adminItems = <_MenuItem>[
      if (canViewMembers)
        _MenuItem(
          icon: Icons.people_outline,
          label: '회원관리',
          description: '가입 승인 · 직원 목록',
          onTap: () => _push(context, const AdminUserManagementScreen()),
        ),
      // 전자결재 탭이 신청/관리 둘로 단순해지면서(2026-08 개편)
      // 예전 승인함의 휴무 승인·양식 관리는 여기로 옮겼다
      if (canManageWork)
        _MenuItem(
          icon: Icons.beach_access_outlined,
          label: '휴무 승인',
          description: '직원 휴무 신청 승인·반려',
          onTap: () => _push(context, const AdminVacationManagementScreen()),
        ),
      if (canManageTemplate)
        _MenuItem(
          icon: Icons.description_outlined,
          label: '결재 양식 관리',
          onTap: () => _push(context, const AdminApprovalTemplateScreen()),
        ),
      if (canManageWork)
        _MenuItem(
          icon: Icons.event_busy_outlined,
          label: '휴무 한도 설정',
          onTap: () =>
              _push(context, const AdminVacationLimitsSettingScreen()),
        ),
      if (canDispatch)
        _MenuItem(
          icon: Icons.directions_bus_outlined,
          label: '배차관리',
          description: '노선 · 운전자 · 어르신 탑승',
          onTap: () => _push(context, const DispatchScreen()),
        ),
      // 고충·건의함 처리 — AppPermission 9종에 대응하는 권한이 아직 없어서
      // 세부 권한으로 나누지 못하고 기관 관리자에게만 연다(웹도 관리자 전용이다).
      if (isAdmin)
        _MenuItem(
          icon: Icons.mark_email_read_outlined,
          label: '고충·건의함 관리',
          description: '접수 확인 · 상태 변경 · 답변',
          onTap: () => _push(context, const AdminVoiceBoxScreen()),
        ),
      // 회사 정보·구독(결제)은 세부 권한으로 위임하지 않는다 — 기관 계정 소유자만.
      if (isAdmin)
        _MenuItem(
          icon: Icons.business_outlined,
          label: '회사 정보 · 구독',
          onTap: () => _push(context, const AdminCompanySettingsScreen()),
        ),
    ];

    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundSecondary,
      appBar: AppBar(
        title: Text('전체', style: AppTypography.heading5),
        backgroundColor: AppSemanticColors.backgroundPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.space4),
        children: [
          // 프로필 카드
          _ProfileCard(
            name: user?.name ?? '',
            companyName: user?.company?.name ?? '',
            roleLabel: isAdmin ? '관리자' : '직원',
            onTap: () => _push(context, const ProfileScreen()),
          ),
          const SizedBox(height: AppSpacing.space5),

          _MenuGroup(
            title: '내 업무',
            items: [
              _MenuItem(
                icon: Icons.beach_access_outlined,
                label: '내 휴무',
                description: '휴무 신청 내역과 처리 상태',
                onTap: () => _push(context, const MyVacationScreen()),
              ),
              _MenuItem(
                icon: Icons.draw_outlined,
                label: '결재 서명 관리',
                description: '전자결재에 사용할 서명 등록',
                onTap: () => _push(context, const SignatureManageScreen()),
              ),
              _MenuItem(
                icon: Icons.groups_outlined,
                label: '회의록',
                description: '회의 내용 확인과 서명',
                onTap: () => _push(context, const MeetingMinutesListScreen()),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),

          _MenuGroup(
            title: '소통',
            items: [
              _MenuItem(
                icon: Icons.campaign_outlined,
                label: '공지사항',
                onTap: () => _push(
                  context,
                  canManageNotice
                      ? const AdminNoticeManagementScreen()
                      : const NoticeListScreen(),
                ),
              ),
              _MenuItem(
                icon: Icons.groups_outlined,
                label: '케어브이 커뮤니티',
                description: '요양 소식 · 게시판 · 자료실',
                onTap: () => _push(context, const PlazaScreen()),
              ),
              _MenuItem(
                icon: Icons.record_voice_over_outlined,
                label: '고충·신고 · 건의함',
                description: '익명으로 남기는 고충·신고와 건의',
                onTap: () => _push(context, const VoiceBoxScreen()),
              ),
              _MenuItem(
                icon: Icons.folder_shared_outlined,
                label: '기관 자료실',
                description: '우리 기관 사람만 보는 서식 · 매뉴얼',
                onTap: () => _push(context, const CompanyLibraryScreen()),
              ),
            ],
          ),

          // 웹의 '편의기능' 탭에 대응하는 자리. 본 업무 흐름에 속하지 않는 부가 도구를 모은다.
          // 배차관리·회의록은 앱에선 이미 다른 그룹에 있어서 여기엔 AI 글쓰기만 둔다.
          //
          // 관리자 전용이 아니다 — 사진을 찍는 사람이 선생님이라 직원이 못 쓰면 의미가 없다.
          // (carev.kr의 ai-post 라우트가 직원 토큰도 검증하도록 함께 고쳤다.)
          const SizedBox(height: AppSpacing.space4),
          _MenuGroup(
            title: '편의기능',
            items: [
              _MenuItem(
                icon: Icons.auto_awesome_outlined,
                label: 'AI 글쓰기',
                description: '사진으로 밴드 · 블로그 글 자동 작성',
                onTap: () => _push(context, const AiPostWriterScreen()),
              ),
            ],
          ),

          if (adminItems.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.space4),
            _MenuGroup(
              title: '기관 관리',
              items: adminItems,
            ),
          ],

          const SizedBox(height: AppSpacing.space4),
          _MenuGroup(
            title: '계정',
            items: [
              // 프로필 카드 탭과 동일하게 ProfileScreen으로 이동한다.
              // ProfileScreen이 유일한 설정 화면이라 역할이 겹치지만,
              // '계정' 그룹에서도 진입 지점을 남겨두기 위해 라벨을
              // 명확한 문구로 구분해 둔다(동작은 그대로 ProfileScreen).
              _MenuItem(
                icon: Icons.notifications_outlined,
                label: '알림 설정',
                description: '푸시 알림 받기 켜기·끄기',
                onTap: () =>
                    _push(context, const NotificationSettingsScreen()),
              ),
              _MenuItem(
                icon: Icons.settings_outlined,
                label: '계정 설정',
                description: '비밀번호 변경',
                onTap: () => _push(context, const ProfileScreen()),
              ),
              _MenuItem(
                icon: Icons.logout,
                label: '로그아웃',
                isDestructive: true,
                onTap: () => _showLogoutDialog(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space8),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String name;
  final String companyName;
  final String roleLabel;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.name,
    required this.companyName,
    required this.roleLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // SeedListSection(단일 셀) — 흰 표면 + 얇은 구분선 컨테이너로 통일
    return SeedListSection(
      children: [
        SeedListCell(
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: AppSemanticColors.brandWeak,
            child: Text(
              name.isNotEmpty ? name.characters.first : '?',
              style: AppTypography.heading5.copyWith(
                color: AppSemanticColors.brandPressed,
              ),
            ),
          ),
          title: name,
          description: companyName,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppSemanticColors.brandWeak,
                  borderRadius: BorderRadius.circular(AppBorderRadius.full),
                ),
                child: Text(
                  roleLabel,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppSemanticColors.brandPressed,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: AppSemanticColors.textTertiary,
              ),
            ],
          ),
          onTap: onTap,
        ),
      ],
    );
  }
}

class _MenuGroup extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;

  const _MenuGroup({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    // SeedListSection — 그룹 타이틀 + 흰 표면 카드(얇은 구분선)로 정돈
    return SeedListSection(title: title, children: items);
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? description;
  final bool isDestructive;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.description,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // SeedListCell — leading 아이콘 칩 + title/description + trailing chevron 구성으로 정돈
    return SeedListCell(
      leadingIcon: icon,
      title: label,
      description: description,
      isDestructive: isDestructive,
      onTap: onTap,
    );
  }
}
