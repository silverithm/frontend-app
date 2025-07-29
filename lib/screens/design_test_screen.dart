import 'package:flutter/material.dart';
import '../widgets/common/index.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class DesignTestScreen extends StatelessWidget {
  const DesignTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('디자인 시스템 테스트'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Typography Test
            Text('Heading 1', style: AppTypography.heading1),
            const SizedBox(height: AppSpacing.space2),
            Text('Heading 2', style: AppTypography.heading2),
            const SizedBox(height: AppSpacing.space2),
            Text('Body Medium', style: AppTypography.bodyMedium),
            const SizedBox(height: AppSpacing.space4),

            // Button Test
            const AppButton(text: 'Primary Button'),
            const SizedBox(height: AppSpacing.space3),
            const AppButton(
              text: 'Secondary Button',
              variant: AppButtonVariant.secondary,
            ),
            const SizedBox(height: AppSpacing.space3),
            const AppButton(
              text: 'Outline Button',
              variant: AppButtonVariant.outline,
            ),
            const SizedBox(height: AppSpacing.space4),

            // Input Test
            const AppInput(
              label: '이메일',
              hintText: 'example@email.com',
            ),
            const SizedBox(height: AppSpacing.space3),
            const AppPasswordInput(
              label: '비밀번호',
              hintText: '비밀번호를 입력하세요',
            ),
            const SizedBox(height: AppSpacing.space4),

            // Card Test
            AppCard(
              child: Column(
                children: [
                  Text('기본 카드', style: AppTypography.heading6),
                  const SizedBox(height: AppSpacing.space2),
                  Text('카드 내용입니다.', style: AppTypography.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space3),

            // Status Card Test
            AppStatusCard(
              status: AppStatusType.success,
              child: Text('성공 메시지', style: AppTypography.bodyMedium),
            ),
            const SizedBox(height: AppSpacing.space2),
            AppStatusCard(
              status: AppStatusType.error,
              child: Text('에러 메시지', style: AppTypography.bodyMedium),
            ),
            const SizedBox(height: AppSpacing.space4),

            // Loading Test
            const AppLoading(message: '로딩 중...'),
            const SizedBox(height: AppSpacing.space4),

            // Snackbar Test Button
            AppButton(
              text: 'Snackbar 테스트',
              variant: AppButtonVariant.outline,
              onPressed: () {
                AppSnackBar.showSuccess(context, message: '성공 메시지입니다!');
              },
            ),
          ],
        ),
      ),
    );
  }
}