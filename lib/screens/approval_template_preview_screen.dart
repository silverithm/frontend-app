import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../models/approval.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/approval/document_form_fields.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_callout.dart';
import 'hwp_editor_screen.dart';

/// 결재 양식(템플릿) 미리보기 화면.
///
/// - 온라인 양식(form/hybrid): formSchema를 공문 표 레이아웃으로 빈 칸 미리보기.
/// - 첨부파일 양식(file, hwp/hwpx 등): 원본 문서를 볼 수 있게 안내한다
///   (HWP/HWPX는 웹 에디터로 바로 열람, 그 외 형식은 다운로드 후 외부 앱으로 연다).
/// 하단 "이 양식으로 작성" 버튼을 누르면 이 템플릿을 들고 호출한 화면으로 돌아간다.
class ApprovalTemplatePreviewScreen extends StatefulWidget {
  final ApprovalTemplate template;

  /// 양식 관리(관리자)에서 열람만 할 때는 작성 버튼을 숨긴다
  final bool showUseButton;

  const ApprovalTemplatePreviewScreen({
    super.key,
    required this.template,
    this.showUseButton = true,
  });

  @override
  State<ApprovalTemplatePreviewScreen> createState() =>
      _ApprovalTemplatePreviewScreenState();
}

class _ApprovalTemplatePreviewScreenState
    extends State<ApprovalTemplatePreviewScreen> {
  bool _isDownloading = false;
  double _downloadProgress = 0;

  bool get _isHwpFile {
    final t = widget.template;
    if (t.fileUrl == null) return false;
    final name = (t.fileName ?? t.fileUrl!).toLowerCase();
    return name.endsWith('.hwp') || name.endsWith('.hwpx');
  }

  void _openHwpPreview() {
    final t = widget.template;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HwpEditorScreen(
          filePath: t.fileUrl!,
          fileName: t.fileName ?? '${t.name}.hwp',
          allowSave: false,
        ),
      ),
    );
  }

  Future<void> _downloadAndOpen() async {
    final t = widget.template;
    if (t.fileUrl == null || _isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      final token = StorageService().getToken();
      if (token == null) {
        AppSnackBar.showError(context, message: '인증 정보가 없습니다. 다시 로그인해주세요.');
        setState(() => _isDownloading = false);
        return;
      }

      final queryParams = <String, String>{'path': t.fileUrl!};
      if (t.fileName != null) {
        queryParams['fileName'] = t.fileName!;
      }

      final downloadUri =
          Uri.https('silverithm.site', '/api/v1/files/download', queryParams);

      final dir = await getTemporaryDirectory();
      final fileName = t.fileName ?? '${t.name}.dat';
      final filePath = '${dir.path}/$fileName';

      final dio = Dio();
      await dio.download(
        downloadUri.toString(),
        filePath,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() => _downloadProgress = received / total);
          }
        },
      );

      if (!mounted) return;
      setState(() => _isDownloading = false);

      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done && mounted) {
        AppSnackBar.showError(context, message: '파일을 열 수 없습니다: ${result.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        AppSnackBar.showError(context, message: '문서를 불러오는 중 오류가 발생했습니다: $e');
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _fileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
      case 'hwp':
      case 'hwpx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    final approvalLine = t.defaultApprovalLineCandidates;
    final fields = t.formFields;
    final hasFields = fields.isNotEmpty;
    final hasFile = t.fileUrl != null;

    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: Text(
          t.name,
          style: AppTypography.heading6.copyWith(color: AppSemanticColors.textInverse),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        iconTheme: IconThemeData(color: AppSemanticColors.textInverse),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (t.description != null && t.description!.isNotEmpty) ...[
                      Text(
                        t.description!,
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppSemanticColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.space4),
                    ],

                    if (approvalLine.isNotEmpty) ...[
                      SeedCallout(
                        icon: Icons.route_outlined,
                        title: '결재선',
                        description: approvalLine
                            .asMap()
                            .entries
                            .map((e) =>
                                '${e.key + 1}. ${e.value.name}${e.value.position != null ? ' (${e.value.position})' : ''}')
                            .join(' → '),
                      ),
                      const SizedBox(height: AppSpacing.space4),
                    ],

                    if (hasFields) ...[
                      Text(
                        '양식 미리보기',
                        style: AppTypography.heading6
                            .copyWith(color: AppSemanticColors.textPrimary),
                      ),
                      const SizedBox(height: AppSpacing.space1),
                      Text(
                        '실제 문서의 항목 구성입니다. 값은 다음 화면에서 입력합니다.',
                        style: AppTypography.caption
                            .copyWith(color: AppSemanticColors.textTertiary),
                      ),
                      const SizedBox(height: AppSpacing.space3),
                      DocumentFormFields(
                        fields: fields,
                        values: const {},
                        readOnly: true,
                      ),
                      const SizedBox(height: AppSpacing.space4),
                    ],

                    if (hasFile) ...[
                      Text(
                        '첨부 원본',
                        style: AppTypography.heading6
                            .copyWith(color: AppSemanticColors.textPrimary),
                      ),
                      const SizedBox(height: AppSpacing.space3),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.space4),
                        decoration: BoxDecoration(
                          color: AppSemanticColors.surfaceDefault,
                          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                          border: Border.all(color: AppSemanticColors.borderDefault),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.space2),
                                  decoration: BoxDecoration(
                                    color: AppSemanticColors.statusInfoBackground,
                                    borderRadius:
                                        BorderRadius.circular(AppBorderRadius.lg),
                                  ),
                                  child: Icon(
                                    _fileIcon(t.fileName ?? t.fileUrl!),
                                    size: 24,
                                    color: AppSemanticColors.statusInfoIcon,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.space3),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.fileName ?? '첨부 파일',
                                        style: AppTypography.bodyMedium
                                            .copyWith(color: AppSemanticColors.textPrimary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (t.fileSize != null)
                                        Text(
                                          _formatFileSize(t.fileSize!),
                                          style: AppTypography.caption.copyWith(
                                              color: AppSemanticColors.textTertiary),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.space3),
                            if (_isDownloading)
                              LinearProgressIndicator(
                                value: _downloadProgress == 0 ? null : _downloadProgress,
                                backgroundColor: AppSemanticColors.borderDefault,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppSemanticColors.interactivePrimaryDefault),
                              )
                            else
                              SizedBox(
                                width: double.infinity,
                                child: SeedButton(
                                  label: _isHwpFile ? '문서 미리보기' : '다운로드하여 열기',
                                  variant: SeedButtonVariant.neutralOutline,
                                  prefixIcon: _isHwpFile
                                      ? Icons.visibility_outlined
                                      : Icons.download_outlined,
                                  onPressed:
                                      _isHwpFile ? _openHwpPreview : _downloadAndOpen,
                                ),
                              ),
                            if (!_isHwpFile) ...[
                              const SizedBox(height: AppSpacing.space2),
                              Text(
                                '이 형식은 앱에서 바로 미리보기를 지원하지 않아 다운로드 후 기기의 다른 앱으로 엽니다.',
                                style: AppTypography.caption
                                    .copyWith(color: AppSemanticColors.textTertiary),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space4),
                    ],

                    if (!hasFields && !hasFile)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.space6),
                        decoration: BoxDecoration(
                          color: AppSemanticColors.surfaceDefault,
                          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                          border: Border.all(color: AppSemanticColors.borderDefault),
                        ),
                        child: Center(
                          child: Text(
                            '이 양식은 미리 볼 항목이 없습니다',
                            style: AppTypography.bodyMedium
                                .copyWith(color: AppSemanticColors.textTertiary),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.showUseButton)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.space4),
                decoration: BoxDecoration(
                  color: AppSemanticColors.surfaceDefault,
                  border: Border(top: BorderSide(color: AppSemanticColors.borderDefault)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: SeedButton(
                    label: '이 양식으로 작성',
                    variant: SeedButtonVariant.brandSolid,
                    size: SeedButtonSize.large,
                    onPressed: () => Navigator.of(context).pop(t),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
