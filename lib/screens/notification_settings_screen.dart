import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/admin_utils.dart';
import '../utils/app_haptics.dart';
import '../widgets/common/app_skeleton.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/common/carev_app_bar.dart';
import '../widgets/seed/seed_list_cell.dart';

/// 알림 설정 화면.
///
/// 여기서 끄면 서버가 이 사람 앞으로 나가는 푸시를 아예 보내지 않는다.
/// 기기 알림 권한을 끄는 것과 달리, 껐다 켤 때 권한을 다시 받을 필요가 없다.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _enabled = true;
  bool _isLoading = true;
  bool _isSaving = false;

  String? _userId;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _userId = user.id;
    _isAdmin = AdminUtils.canAccessAdminPages(user);

    try {
      final response = await ApiService().getPushEnabled(
        userId: _userId!,
        isAdmin: _isAdmin,
      );
      if (!mounted) return;
      setState(() {
        // 설정을 못 읽으면 켜진 것으로 본다 — 알림이 조용히 꺼진 것처럼 보이면 안 된다
        _enabled = response['pushEnabled'] != false;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('알림 설정 조회 실패: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggle(bool next) async {
    if (_userId == null || _isSaving) return;

    // 먼저 화면을 바꾸고, 실패하면 되돌린다 (토글은 즉시 반응해야 자연스럽다)
    final previous = _enabled;
    setState(() {
      _enabled = next;
      _isSaving = true;
    });

    try {
      await ApiService().updatePushEnabled(
        userId: _userId!,
        isAdmin: _isAdmin,
        enabled: next,
      );
      if (!mounted) return;
      _showSnack(next ? '알림을 받도록 설정했습니다.' : '알림을 받지 않도록 설정했습니다.');
    } catch (e) {
      debugPrint('알림 설정 변경 실패: $e');
      if (!mounted) return;
      setState(() => _enabled = previous);
      _showSnack('설정을 저장하지 못했습니다. 잠시 후 다시 시도해주세요.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (isError) {
      AppSnackBar.showError(context, message: message);
    } else {
      AppSnackBar.showSuccess(context, message: message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // B안: 옅은 회색 바탕 위 흰 카드
      backgroundColor: AppSemanticColors.backgroundCanvas,
      appBar: const CareVAppBar(title: '알림 설정'),
      body: _isLoading
          // 첫 불러오기 — 스위치 줄 카드 두 장 모양 뼈대(같은 여백)
          ? const _NotificationSettingsSkeleton()
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.space4),
              children: [
                // B안: 테두리 있는 Card 대신 테두리 없는 흰 카드(SeedListSection) 한 줄
                SeedListSection(
                  children: [
                    _SettingSwitchTile(
                      value: _enabled,
                      onChanged: _isSaving ? null : _toggle,
                      title: '푸시 알림 받기',
                      subtitle: '휴무 승인, 결재 요청, 공지 등의 알림을 휴대폰으로 받습니다',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space3),
                Padding(
                  // 카드 안 글자 시작(20)에 맞춘다
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space1,
                  ),
                  child: Text(
                  _enabled
                      ? '알림이 오지 않는다면 휴대폰 설정에서 케어브이 알림 권한이 켜져 있는지도 확인해주세요.'
                      : '알림을 꺼두면 휴무 승인이나 결재 요청도 알려드리지 못합니다.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppSemanticColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.space6),
                const _HapticsSettingCard(),
              ],
            ),
    );
  }
}

/// 알림 설정 첫 불러오기 뼈대 — 흰 카드 안 스위치 줄(제목·설명 두 줄·스위치) 두 장.
/// 카드 사이 안내 글 자리(회색 바탕 위)는 비워 둔다.
class _NotificationSettingsSkeleton extends StatelessWidget {
  const _NotificationSettingsSkeleton();

  Widget _switchCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space2),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppBorderRadius.card),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space2_5,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeletonLine(widthFactor: 0.45, height: AppSpacing.space4),
                  SizedBox(height: AppSpacing.space2),
                  AppSkeletonLine(widthFactor: 0.9, height: AppSpacing.space3_5),
                  SizedBox(height: AppSpacing.space1_5),
                  AppSkeletonLine(widthFactor: 0.6, height: AppSpacing.space3_5),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.space4),
            AppSkeletonBox(
              width: AppSpacing.space12,
              height: AppSpacing.space8,
              radius: AppBorderRadius.full,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      // 흰 카드 안의 뼈는 한 단계 옅은 색
      baseColor: AppSemanticColors.skeletonBaseOnCard,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _switchCard(),
            const SizedBox(height: AppSpacing.space3 + AppSpacing.space10),
            const SizedBox(height: AppSpacing.space6),
            _switchCard(),
          ],
        ),
      ),
    );
  }
}

/// '진동 반응' — 누르거나 저장할 때 휴대폰이 짧게 떨리는 것(햅틱)을 켜고 끈다.
/// 이 기기에만 저장된다(서버에 보내지 않는다). 기본 켬.
class _HapticsSettingCard extends StatelessWidget {
  const _HapticsSettingCard();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppHaptics.enabled,
      builder: (context, enabled, _) {
        return SeedListSection(
          children: [
            _SettingSwitchTile(
              value: enabled,
              onChanged: (next) {
                // 켤 때는 켜진 뒤에 한 번 떨어 어떤 느낌인지 알려 준다.
                AppHaptics.setEnabled(next);
                if (next) AppHaptics.selection();
              },
              title: '진동 반응',
              subtitle: '버튼을 누르거나 저장할 때 휴대폰이 짧게 떨립니다',
            ),
          ],
        );
      },
    );
  }
}

/// 설정 스위치 한 줄 — B안 목록 줄(SeedListCell)과 같은 치수: 줄 높이 60 이상,
/// 제목 16/w600, 설명 14 회색, 누름 모서리 14. [SeedListSection] 카드 안(여백 8)에서
/// 좌우 12를 써 글자 시작이 카드 가장자리에서 20이 된다.
class _SettingSwitchTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String title;
  final String subtitle;

  const _SettingSwitchTile({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppSemanticColors.textInverse,
      activeTrackColor: AppSemanticColors.brandDefault,
      minTileHeight: AppSpacing.listRowMinHeight,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.control),
      ),
      title: Text(
        title,
        style: AppTypography.titleMedium.copyWith(
          color: AppSemanticColors.textPrimary,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.space0_5),
        child: Text(
          subtitle,
          style: AppTypography.bodySmall.copyWith(
            color: AppSemanticColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
