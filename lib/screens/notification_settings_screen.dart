import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/admin_utils.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? AppSemanticColors.statusErrorIcon
            : AppSemanticColors.statusSuccessIcon,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: Text(
          '알림 설정',
          style:
              AppTypography.heading6.copyWith(color: AppSemanticColors.textInverse),
        ),
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        foregroundColor: AppSemanticColors.textInverse,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.space4),
              children: [
                Card(
                  elevation: 0,
                  color: AppSemanticColors.backgroundSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    value: _enabled,
                    onChanged: _isSaving ? null : _toggle,
                    title: Text('푸시 알림 받기', style: AppTypography.bodyMedium),
                    subtitle: Text(
                      '휴무 승인, 결재 요청, 공지 등의 알림을 휴대폰으로 받습니다',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppSemanticColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  _enabled
                      ? '알림이 오지 않는다면 휴대폰 설정에서 케어브이 알림 권한이 켜져 있는지도 확인해주세요.'
                      : '알림을 꺼두면 휴무 승인이나 결재 요청도 알려드리지 못합니다.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textSecondary,
                  ),
                ),
              ],
            ),
    );
  }
}
