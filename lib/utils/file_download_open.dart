/// 서버 파일을 내려받아 기기 기본 앱(플레이어·뷰어)으로 연다.
/// 채팅방 화면과 채팅방 정보(미디어 탭)가 같은 방식으로 동영상·파일을 열도록 한 곳에 둔다.
library;

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_snackbar.dart';

Future<void> downloadAndOpenFile(
  BuildContext context,
  String? url,
  String fileName,
) async {
  if (url == null || url.isEmpty) {
    AppSnackBar.showError(context, message: '파일 URL이 없습니다');
    return;
  }

  // 다운로드 진행 표시
  AppDialog.showCustom<void>(
    context,
    barrierDismissible: false,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.space6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.space4),
          Text('다운로드 중...', style: AppTypography.bodyMedium),
          const SizedBox(height: AppSpacing.space2),
          Text(
            fileName,
            style: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );

  try {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';

    await dio.Dio().download(
      url,
      filePath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          debugPrint('[Download] ${(received / total * 100).toStringAsFixed(0)}%');
        }
      },
    );

    // 다이얼로그 닫기
    if (context.mounted) Navigator.pop(context);

    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done && context.mounted) {
      AppSnackBar.showError(context, message: '파일을 열 수 없습니다: ${result.message}');
    }
  } catch (e) {
    if (context.mounted) Navigator.pop(context);
    debugPrint('[Download] 에러: $e');
    if (context.mounted) {
      AppSnackBar.showError(context, message: '다운로드 실패: $e');
    }
  }
}
