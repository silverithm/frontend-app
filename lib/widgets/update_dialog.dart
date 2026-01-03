import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import '../theme/app_colors.dart';

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
    return WillPopScope(
      onWillPop: () async => !forceUpdate,
      child: AlertDialog(
        backgroundColor: AppSemanticColors.surfaceDefault,
        title: const Text('업데이트 알림'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(updateMessage),
            const SizedBox(height: 16),
            Text(
              '현재 버전: $currentVersion',
              style: const TextStyle(fontSize: 14, color: AppSemanticColors.textSecondary),
            ),
            Text(
              '최신 버전: $latestVersion',
              style: const TextStyle(fontSize: 14, color: AppSemanticColors.textSecondary),
            ),
          ],
        ),
        actions: [
          if (!forceUpdate)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('나중에'),
            ),
          ElevatedButton(
            onPressed: _launchStore,
            child: const Text('업데이트'),
          ),
        ],
      ),
    );
  }
}