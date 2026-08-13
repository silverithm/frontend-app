import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../providers/approval_provider.dart';
import '../providers/auth_provider.dart';
import '../models/approval.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../services/api_service.dart';
import '../widgets/approval/approval_status_badge.dart';
import '../widgets/approval/official_document_view.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_snackbar.dart';
import '../utils/document_open.dart';
import '../widgets/seed/seed_button.dart';
import 'hwp_editor_screen.dart';

class ApprovalDetailScreen extends StatefulWidget {
  final ApprovalRequest approval;

  const ApprovalDetailScreen({
    super.key,
    required this.approval,
  });

  @override
  State<ApprovalDetailScreen> createState() => _ApprovalDetailScreenState();
}

class _ApprovalDetailScreenState extends State<ApprovalDetailScreen> {
  late ApprovalRequest _approval;
  ApprovalTemplate? _template; // 공문 본문 라벨 해석용
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _approval = widget.approval;
    // 빌드 완료 후 로드하여 setState during build 에러 방지
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDetail();
    });
  }

  Future<void> _loadDetail() async {
    final approvalProvider = context.read<ApprovalProvider>();
    final detail = await approvalProvider.loadApprovalDetail(approvalId: _approval.id);
    if (detail != null && mounted) {
      setState(() {
        _approval = detail;
      });
    }
    _loadTemplate();
  }

  Future<void> _loadTemplate() async {
    if (_approval.templateId <= 0) return;
    try {
      final response = await ApiService()
          .getApprovalTemplateDetail(templateId: _approval.templateId);
      final raw = response['template'] ?? response;
      if (raw is Map && mounted) {
        setState(() {
          _template = ApprovalTemplate.fromJson(Map<String, dynamic>.from(raw));
        });
      }
    } catch (e) {
      debugPrint('양식 정보 로드 실패(공문 라벨 없이 표시): $e');
    }
  }

  Future<void> _deleteApproval() async {
    // ID가 유효하지 않으면 삭제 불가
    if (_approval.id <= 0) {
      AppSnackBar.showError(
        context,
        message: '결재 요청 정보가 올바르지 않습니다. 다시 시도해주세요.',
      );
      return;
    }

    // 파괴적 액션(삭제) 확인 다이얼로그
    final confirmed = await AppDialog.showConfirm(
      context,
      title: '결재 요청 삭제',
      message: '이 결재 요청을 삭제하시겠습니까?\n삭제된 요청은 복구할 수 없습니다.',
      confirmText: '삭제',
      cancelText: '취소',
      confirmVariant: SeedButtonVariant.critical,
    );

    if (confirmed == true && mounted) {
      setState(() => _isDeleting = true);

      final approvalProvider = context.read<ApprovalProvider>();
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.company?.id?.toString() ?? '';
      final success = await approvalProvider.deleteApprovalRequest(
        approvalId: _approval.id,
        companyId: companyId,
      );

      setState(() => _isDeleting = false);

      if (success && mounted) {
        // 삭제는 되돌릴 수 없는 행위지만, 이 알림은 정상 완료 통보이지 오류가 아니다 — 빨강 금지
        AppSnackBar.showInfo(context, message: '결재 요청이 삭제되었습니다');
        Navigator.pop(context, true);
      }
    }
  }

  bool _isDownloading = false;
  double _downloadProgress = 0;

  /// 첨부파일이 웹 에디터로 열 수 있는 HWP/HWPX 문서인지
  bool get _isHwpAttachment {
    final name = _approval.attachmentFileName?.toLowerCase();
    if (name == null || _approval.attachmentUrl == null) return false;
    return name.endsWith('.hwp') || name.endsWith('.hwpx');
  }

  void _openHwpPreview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HwpEditorScreen(
          filePath: _approval.attachmentUrl!,
          fileName: _approval.attachmentFileName!,
        ),
      ),
    );
  }

  /// 첨부를 누르면 앱 안에서 바로 보여준다.
  /// 한글·워드·엑셀·슬라이드·글자 파일은 뷰어로 열고, 그 밖(pdf 등)만 기기 앱에 넘긴다.
  /// 예전에는 무조건 내려받아 기기 앱에 넘겨서, 한글 업무일지 같은 건 아무것도 열리지 않았다.
  Future<void> _openAttachment() async {
    if (_approval.attachmentUrl == null || _isDownloading) return;

    await openServerDocument(
      context,
      filePath: _approval.attachmentUrl,
      fileName: _approval.attachmentFileName ?? 'attachment',
      onDownloadFallback: _downloadAndOpenWithSystemApp,
    );
  }

  Future<void> _downloadAndOpenWithSystemApp() async {
    if (_approval.attachmentUrl == null || _isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      // 인증 토큰 가져오기
      final token = StorageService().getToken();

      if (token == null) {
        _showErrorSnackBar('인증 정보가 없습니다. 다시 로그인해주세요.');
        setState(() => _isDownloading = false);
        return;
      }

      // 다운로드 URL 구성 (Uri 클래스 사용)
      final queryParams = <String, String>{
        'path': _approval.attachmentUrl!,
      };
      if (_approval.attachmentFileName != null) {
        queryParams['fileName'] = _approval.attachmentFileName!;
      }

      final downloadUri = Uri.https(
        'silverithm.site',
        '/api/v1/files/download',
        queryParams,
      );

      print('[Approval] 첨부파일 다운로드 시작: $downloadUri');
      print('[Approval] path 파라미터: ${_approval.attachmentUrl}');

      // 임시 디렉토리에 저장
      final dir = await getTemporaryDirectory();
      final fileName = _approval.attachmentFileName ?? 'attachment';
      final filePath = '${dir.path}/$fileName';

      // Dio로 파일 다운로드 (Authorization 헤더 포함)
      final dio = Dio();
      await dio.download(
        downloadUri.toString(),
        filePath,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      print('[Approval] 다운로드 완료: $filePath');

      if (mounted) {
        setState(() {
          _isDownloading = false;
        });

        // 파일 열기
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          _showErrorSnackBar('파일을 열 수 없습니다: ${result.message}');
        }
      }
    } catch (e) {
      print('[Approval] 다운로드 에러: $e');
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });

        String errorMessage = '파일 다운로드 중 오류가 발생했습니다';
        if (e is DioException) {
          final statusCode = e.response?.statusCode;
          if (statusCode == 404) {
            errorMessage = '파일을 찾을 수 없습니다. 서버에 파일이 존재하지 않습니다.';
          } else if (statusCode == 403) {
            errorMessage = '파일 접근 권한이 없습니다. 다시 로그인해주세요.';
          } else if (statusCode == 401) {
            errorMessage = '인증이 만료되었습니다. 다시 로그인해주세요.';
          }
        }
        _showErrorSnackBar(errorMessage);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    AppSnackBar.showError(context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy년 MM월 dd일 HH:mm');

    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: Text(
          '결재 상세',
          style: AppTypography.heading6.copyWith(
            color: AppSemanticColors.textInverse,
          ),
        ),
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        iconTheme: IconThemeData(color: AppSemanticColors.textInverse),
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_approval.status == ApprovalStatus.pending)
            Container(
              margin: const EdgeInsets.only(right: AppSpacing.space2),
              child: IconButton(
                icon: _isDeleting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppSemanticColors.textInverse,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.delete_outline,
                        color: AppSemanticColors.textInverse,
                      ),
                onPressed: _isDeleting ? null : _deleteApproval,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상태 카드 - 깔끔한 화이트 디자인
            Container(
              padding: const EdgeInsets.all(AppSpacing.space4),
              decoration: BoxDecoration(
                color: AppSemanticColors.surfaceDefault,
                borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                border: Border.all(
                  color: AppSemanticColors.borderDefault,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _approval.title,
                          style: AppTypography.heading5.copyWith(
                            color: AppSemanticColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space2),
                      ApprovalStatusBadge(status: _approval.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  _buildInfoRow(
                    Icons.person_outline,
                    '요청자',
                    _approval.requesterName,
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  _buildInfoRow(
                    Icons.access_time,
                    '요청일시',
                    dateFormat.format(_approval.createdAt),
                  ),
                  if (_approval.approvalLine.isNotEmpty &&
                      _approval.status == ApprovalStatus.pending &&
                      _approval.currentStep != null) ...[
                    const SizedBox(height: AppSpacing.space2),
                    _buildInfoRow(
                      Icons.pending_actions,
                      '결재 차례',
                      '${_approval.currentStep!.approverName} (${_approval.approvalLine.where((s) => s.isApproved).length}/${_approval.approvalLine.length} 승인)',
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.space4),

            // 공문(표준 기안문) 뷰
            OfficialDocumentView(
              approval: _approval,
              template: _template,
              companyName: context.read<AuthProvider>().currentUser?.company?.name ?? '',
            ),

            const SizedBox(height: AppSpacing.space4),

            // 첨부파일 카드
            if (_approval.attachmentFileName != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.space4),
                decoration: BoxDecoration(
                  color: AppSemanticColors.surfaceDefault,
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  border: Border.all(
                    color: AppSemanticColors.borderDefault,
                  ),
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
                            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                          ),
                          child: Icon(
                            Icons.attach_file,
                            size: 20,
                            color: AppSemanticColors.statusInfoIcon,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.space3),
                        Text(
                          '첨부파일',
                          style: AppTypography.heading6.copyWith(
                            color: AppSemanticColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space3),
                    InkWell(
                      onTap: _isDownloading ? null : _openAttachment,
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.space3),
                        decoration: BoxDecoration(
                          color: AppSemanticColors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getFileIcon(_approval.attachmentFileName!),
                              size: 32,
                              color: AppSemanticColors.interactivePrimaryDefault,
                            ),
                            const SizedBox(width: AppSpacing.space3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _approval.attachmentFileName!,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppSemanticColors.textLink,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_isDownloading)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: LinearProgressIndicator(
                                        value: _downloadProgress,
                                        backgroundColor: AppSemanticColors.borderDefault,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          AppSemanticColors.interactivePrimaryDefault,
                                        ),
                                      ),
                                    )
                                  else if (_approval.attachmentFileSize != null)
                                    Text(
                                      _formatFileSize(_approval.attachmentFileSize!),
                                      style: AppTypography.caption.copyWith(
                                        color: AppSemanticColors.textTertiary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (_isDownloading)
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppSemanticColors.interactivePrimaryDefault,
                                  ),
                                ),
                              )
                            else
                              Icon(
                                Icons.download_outlined,
                                color: AppSemanticColors.interactivePrimaryDefault,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_isHwpAttachment) ...[
                      const SizedBox(height: AppSpacing.space3),
                      SizedBox(
                        width: double.infinity,
                        child: SeedButton(
                          label: '문서 미리보기',
                          variant: SeedButtonVariant.neutralOutline,
                          prefixIcon: Icons.visibility_outlined,
                          onPressed: _openHwpPreview,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
            ],

            // 처리 정보 카드 - 깔끔한 화이트 디자인
            if (_approval.processedAt != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.space4),
                decoration: BoxDecoration(
                  color: AppSemanticColors.surfaceDefault,
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  border: Border.all(
                    color: AppSemanticColors.borderDefault,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _approval.status == ApprovalStatus.approved
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                          size: 20,
                          color: _approval.status == ApprovalStatus.approved
                              ? AppSemanticColors.statusSuccessIcon
                              : AppSemanticColors.statusErrorIcon,
                        ),
                        const SizedBox(width: AppSpacing.space2),
                        Text(
                          '처리 정보',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppSemanticColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.space2),
                        // 상태 태그
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.space2,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _approval.status == ApprovalStatus.approved
                                ? AppSemanticColors.statusSuccessBackground
                                : AppSemanticColors.statusErrorBackground,
                            borderRadius: BorderRadius.circular(AppBorderRadius.base),
                          ),
                          child: Text(
                            _approval.status == ApprovalStatus.approved ? '승인' : '거절',
                            style: AppTypography.labelSmall.copyWith(
                              color: _approval.status == ApprovalStatus.approved
                                  ? AppSemanticColors.statusSuccessText
                                  : AppSemanticColors.statusErrorText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space3),
                    _buildInfoRow(
                      Icons.person_outline,
                      '처리자',
                      _approval.processedByName ?? '-',
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    _buildInfoRow(
                      Icons.access_time,
                      '처리일시',
                      dateFormat.format(_approval.processedAt!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
            ],

            // 거절 사유 - 깔끔한 디자인
            if (_approval.rejectReason != null &&
                _approval.status == ApprovalStatus.rejected) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.space4),
                decoration: BoxDecoration(
                  color: AppSemanticColors.surfaceDefault,
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  border: Border.all(
                    color: AppSemanticColors.borderDefault,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: AppSemanticColors.textTertiary,
                        ),
                        const SizedBox(width: AppSpacing.space2),
                        Text(
                          '거절 사유',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppSemanticColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space3),
                    Text(
                      _approval.rejectReason!,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppSemanticColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppSemanticColors.textTertiary,
        ),
        const SizedBox(width: AppSpacing.space2),
        Text(
          '$label: ',
          style: AppTypography.bodySmall.copyWith(
            color: AppSemanticColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
