import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'seed/seed_button.dart';

class UpdateDialog extends StatelessWidget {
  final String currentVersion;
  final String latestVersion;
  final String updateMessage;
  final bool forceUpdate;

  const UpdateDialog({
    Key? key,
    required this.currentVersion,
    required this.latestVersion,
    required this.updateMessage,
    required this.forceUpdate,
  }) : super(key: key);

  Future<void> _launchStore() async {
    final String url;
    
    if (Platform.isIOS) {
      // iOS App Store URL
      url = 'https://apps.apple.com/kr/app/%EC%BC%80%EC%96%B4%EB%B8%8C%EC%9D%B4/id6747028185';
    } else if (Platform.isAndroid) {
      // Android Play Store URL
      url = 'https://play.google.com/store/apps/details?id=com.silverithm.carev.app&hl=ko';
    } else {
      return;
    }

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !forceUpdate,
      child: shadcn.AlertDialog(
        title: Text('업데이트 알림', style: AppTypography.heading5),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(updateMessage, style: AppTypography.bodyMedium),
            const SizedBox(height: AppSpacing.space4),
            Text(
              '현재 버전: $currentVersion',
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textSecondary,
              ),
            ),
            Text(
              '최신 버전: $latestVersion',
              style: AppTypography.bodyMedium.copyWith(
                color: AppSemanticColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          if (!forceUpdate)
            SeedButton(
              label: '나중에',
              variant: SeedButtonVariant.neutralWeak,
              onPressed: () => Navigator.of(context).pop(),
            ),
          SeedButton(
            label: '업데이트',
            variant: SeedButtonVariant.brandSolid,
            onPressed: _launchStore,
          ),
        ],
      ),
    );
  }
}