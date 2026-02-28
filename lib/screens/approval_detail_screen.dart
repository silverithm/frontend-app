import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
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
import '../widgets/approval/approval_status_badge.dart';

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
  }

  Future<void> _deleteApproval() async {
    // ID가 유효하지 않으면 삭제 불가
    if (_approval.id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('결재 요청 정보가 올바르지 않습니다. 다시 시도해주세요.'),
          backgroundColor: AppSemanticColors.statusErrorIcon,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => shadcn.AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppSemanticColors.statusErrorBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.delete_outline,
                color: AppSemanticColors.statusErrorIcon,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '결재 요청 삭제',
              style: AppTypography.heading6.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppSemanticColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '이 결재 요청을 삭제하시겠습니까?\n삭제된 요청은 복구할 수 없습니다.',
                style: AppTypography.bodyLarge,
              ),
            ),
          ],
        ),
        actions: [
          shadcn.OutlineButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          shadcn.DestructiveButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('결재 요청이 삭제되었습니다'),
            backgroundColor: AppSemanticColors.statusSuccessIcon,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  bool _isDownloading = false;
  double _downloadProgress = 0;

  Future<void> _openAttachment() async {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppSemanticColors.statusErrorIcon,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
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
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: AppSemanticColors.textInverse,
          ),
          onPressed: () => Navigator.pop(context),
        ),
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
                ],
              ),
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
