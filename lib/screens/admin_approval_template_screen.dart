import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import '../providers/approval_provider.dart';
import '../providers/auth_provider.dart';
import '../models/approval.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/approval/template_card.dart';

/// 선택된 파일 정보를 담는 클래스
class _TemplateFileInfo {
  final String path;
  final String name;
  final int size;

  _TemplateFileInfo({required this.path, required this.name, required this.size});
}

class AdminApprovalTemplateScreen extends StatefulWidget {
  const AdminApprovalTemplateScreen({super.key});

  @override
  State<AdminApprovalTemplateScreen> createState() =>
      _AdminApprovalTemplateScreenState();
}

class _AdminApprovalTemplateScreenState
    extends State<AdminApprovalTemplateScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final approvalProvider = context.read<ApprovalProvider>();

      final companyId = authProvider.currentUser?.company?.id?.toString() ?? '';
      await approvalProvider.loadTemplates(companyId: companyId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터 로드 실패: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showCreateDialog() {
    _showTemplateDialog(null);
  }

  void _showEditDialog(ApprovalTemplate template) {
    _showTemplateDialog(template);
  }

  void _showTemplateDialog(ApprovalTemplate? template) {
    final nameController = TextEditingController(text: template?.name ?? '');
    final descriptionController =
        TextEditingController(text: template?.description ?? '');
    _TemplateFileInfo? selectedFile;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => shadcn.AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppSemanticColors.interactivePrimaryDefault
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  template == null ? Icons.add : Icons.edit,
                  color: AppSemanticColors.interactivePrimaryDefault,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                template == null ? '양식 추가' : '양식 수정',
                style: AppTypography.heading6.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '양식 이름 *',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppSemanticColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: '양식 이름을 입력하세요',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '설명',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppSemanticColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '양식에 대한 설명을 입력하세요 (선택)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '첨부파일 (양식 서식)',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppSemanticColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                if (selectedFile != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.statusInfoBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppSemanticColors.statusInfoBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.insert_drive_file,
                          color: AppSemanticColors.statusInfoIcon,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedFile!.name,
                                style: AppTypography.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _formatFileSize(selectedFile!.size),
                                style: AppTypography.caption.copyWith(
                                  color: AppSemanticColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setDialogState(() {
                              selectedFile = null;
                            });
                          },
                          icon: Icon(
                            Icons.close,
                            color: AppSemanticColors.statusErrorIcon,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (template?.fileName != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.insert_drive_file,
                          color: AppSemanticColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            template!.fileName!,
                            style: AppTypography.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        shadcn.GhostButton(
                          onPressed: () async {
                            const XTypeGroup typeGroup = XTypeGroup(
                              label: 'documents',
                              extensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
                            );
                            final XFile? result = await openFile(
                              acceptedTypeGroups: [typeGroup],
                            );
                            if (result != null) {
                              final file = File(result.path);
                              final size = await file.length();
                              setDialogState(() {
                                selectedFile = _TemplateFileInfo(
                                  path: result.path,
                                  name: result.name,
                                  size: size,
                                );
                              });
                            }
                          },
                          child: const Text('변경'),
                        ),
                      ],
                    ),
                  )
                else
                  InkWell(
                    onTap: () async {
                      const XTypeGroup typeGroup = XTypeGroup(
                        label: 'documents',
                        extensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
                      );
                      final XFile? result = await openFile(
                        acceptedTypeGroups: [typeGroup],
                      );
                      if (result != null) {
                        final file = File(result.path);
                        final size = await file.length();
                        setDialogState(() {
                          selectedFile = _TemplateFileInfo(
                            path: result.path,
                            name: result.name,
                            size: size,
                          );
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppSemanticColors.borderDefault,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            color: AppSemanticColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '파일 선택',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppSemanticColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            shadcn.OutlineButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            shadcn.PrimaryButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('양식 이름을 입력해주세요'),
                            backgroundColor:
                                AppSemanticColors.statusWarningIcon,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);

                      final authProvider = context.read<AuthProvider>();
                      final approvalProvider = context.read<ApprovalProvider>();
                      final companyId =
                          authProvider.currentUser?.company?.id ?? '1';

                      bool success;
                      if (template == null) {
                        success = await approvalProvider.createTemplate(
                          companyId: companyId,
                          name: name,
                          description: descriptionController.text.trim(),
                          fileName: selectedFile?.name,
                          fileSize: selectedFile?.size,
                        );
                      } else {
                        // 파일을 새로 선택하지 않으면 기존 파일 정보 사용
                        final fileName = selectedFile?.name ?? template.fileName;
                        final fileSize = selectedFile?.size ?? template.fileSize;

                        success = await approvalProvider.updateTemplate(
                          templateId: template.id,
                          companyId: companyId,
                          name: name,
                          description: descriptionController.text.trim(),
                          fileName: fileName,
                          fileSize: fileSize,
                        );
                      }

                      setDialogState(() => isSubmitting = false);

                      if (success && mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(template == null
                                ? '양식이 추가되었습니다'
                                : '양식이 수정되었습니다'),
                            backgroundColor:
                                AppSemanticColors.statusSuccessIcon,
                          ),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppSemanticColors.textInverse),
                      ),
                    )
                  : Text(template == null ? '추가' : '수정'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive(ApprovalTemplate template) async {
    final approvalProvider = context.read<ApprovalProvider>();
    final authProvider = context.read<AuthProvider>();
    final companyId = authProvider.currentUser?.company?.id?.toString() ?? '';
    final success = await approvalProvider.toggleTemplateActive(
      templateId: template.id,
      companyId: companyId,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              template.isActive ? '양식이 비활성화되었습니다' : '양식이 활성화되었습니다'),
          backgroundColor: AppSemanticColors.statusSuccessIcon,
        ),
      );
    }
  }

  Future<void> _deleteTemplate(ApprovalTemplate template) async {
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
              ),
            ),
            const SizedBox(width: 12),
            const Text('양식 삭제'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '"${template.name}" 양식을 삭제하시겠습니까?\n삭제된 양식은 복구할 수 없습니다.',
              style: AppTypography.bodyMedium,
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
      final approvalProvider = context.read<ApprovalProvider>();
      final authProvider = context.read<AuthProvider>();
      final companyId = authProvider.currentUser?.company?.id?.toString() ?? '';
      final success = await approvalProvider.deleteTemplate(
        templateId: template.id,
        companyId: companyId,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('양식이 삭제되었습니다'),
              backgroundColor: AppSemanticColors.statusSuccessIcon,
            ),
          );
        } else {
          // 에러 메시지 표시
          final errorMsg = approvalProvider.errorMessage;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg.isNotEmpty ? errorMsg : '양식 삭제에 실패했습니다'),
              backgroundColor: AppSemanticColors.statusErrorIcon,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin_approval_template_fab',
        onPressed: _showCreateDialog,
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        foregroundColor: AppSemanticColors.textInverse,
        icon: const Icon(Icons.add),
        label: const Text('양식 추가'),
      ),
    );
  }

  Widget _buildContent() {
    return Consumer<ApprovalProvider>(
      builder: (context, approvalProvider, child) {
        final templates = approvalProvider.templates;

        if (templates.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.description_outlined,
                    size: 64,
                    color: AppSemanticColors.textDisabled,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '결재 양식이 없습니다',
                  style: AppTypography.heading6.copyWith(
                    color: AppSemanticColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '아래 버튼을 눌러 양식을 추가해보세요',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppSemanticColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadData,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return TemplateCard(
                template: template,
                onEdit: () => _showEditDialog(template),
                onDelete: () => _deleteTemplate(template),
                onToggleActive: () => _toggleActive(template),
              );
            },
          ),
        );
      },
    );
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
