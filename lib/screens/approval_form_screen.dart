import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';
import '../providers/approval_provider.dart';
import '../providers/auth_provider.dart';
import '../models/approval.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/approval/dynamic_form_fields.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/seed/seed_text_field.dart';
import 'hwp_editor_screen.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

class ApprovalFormScreen extends StatefulWidget {
  const ApprovalFormScreen({super.key});

  @override
  State<ApprovalFormScreen> createState() => _ApprovalFormScreenState();
}

/// 선택된 파일 정보를 담는 클래스
class _SelectedFileInfo {
  final String path;
  final String name;
  final int size;

  _SelectedFileInfo({required this.path, required this.name, required this.size});
}

class _ApprovalFormScreenState extends State<ApprovalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  _SelectedFileInfo? _selectedFile;
  bool _isSubmitting = false;
  bool _isLoadingTemplates = true;
  ApprovalTemplate? _selectedTemplate;
  // 결재선 (순서=결재 순서, 마지막=최종 결재자)
  final List<ApproverCandidate> _approvalLine = [];
  // 온라인 양식 입력값
  final Map<String, dynamic> _formValues = {};

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final authProvider = context.read<AuthProvider>();
    final approvalProvider = context.read<ApprovalProvider>();
    final companyId = authProvider.currentUser?.company?.id?.toString() ?? '';

    if (companyId.isNotEmpty) {
      await approvalProvider.loadActiveTemplates(companyId: companyId);
    }

    if (mounted) {
      setState(() {
        _isLoadingTemplates = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _showFilePickOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppSemanticColors.surfaceDefault,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppBorderRadius.xl2)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.space4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.space2),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.interactivePrimaryDefault.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    ),
                    child: Icon(
                      Icons.photo_library,
                      color: AppSemanticColors.interactivePrimaryDefault,
                    ),
                  ),
                  title: Text(
                    '이미지 첨부',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppSemanticColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'JPG, PNG 이미지 선택',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppSemanticColors.textTertiary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.space2),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.statusWarningIcon.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    ),
                    child: Icon(
                      Icons.insert_drive_file,
                      color: AppSemanticColors.statusWarningIcon,
                    ),
                  ),
                  title: Text(
                    '문서 첨부',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppSemanticColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'PDF, DOC, XLS 문서 선택',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppSemanticColors.textTertiary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickDocument();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        final file = File(image.path);
        final size = await file.length();

        setState(() {
          _selectedFile = _SelectedFileInfo(
            path: image.path,
            name: image.name,
            size: size,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: '이미지 선택에 실패했습니다: $e');
      }
    }
  }

  Future<void> _pickDocument() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'documents',
        extensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'hwp', 'hwpx'],
      );
      final XFile? result = await openFile(acceptedTypeGroups: [typeGroup]);

      if (result != null) {
        final file = File(result.path);
        final size = await file.length();

        setState(() {
          _selectedFile = _SelectedFileInfo(
            path: result.path,
            name: result.name,
            size: size,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: '문서 선택에 실패했습니다: $e');
      }
    }
  }

  /// 선택된 템플릿이 웹 에디터로 작성 가능한 HWP/HWPX 양식인지
  bool get _canWriteTemplateOnWeb {
    final t = _selectedTemplate;
    if (t == null || t.fileUrl == null) return false;
    final name = (t.fileName ?? t.fileUrl!).toLowerCase();
    return name.endsWith('.hwp') || name.endsWith('.hwpx');
  }

  /// 템플릿 HWP 양식을 웹 에디터로 열어 작성하고, 완료 시 첨부파일로 설정한다.
  Future<void> _writeTemplateOnWeb() async {
    final template = _selectedTemplate;
    if (template?.fileUrl == null) return;

    final result = await Navigator.of(context).push<HwpEditResult>(
      MaterialPageRoute(
        builder: (_) => HwpEditorScreen(
          filePath: template!.fileUrl!,
          fileName: template.fileName ?? '${template.name}.hwp',
          allowSave: true,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedFile = _SelectedFileInfo(
          path: result.path,
          name: result.name,
          size: result.size,
        );
      });
      AppSnackBar.showSuccess(context, message: '작성한 문서가 첨부되었습니다');
    }
  }

  void _removeFile() {
    setState(() {
      _selectedFile = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // 양식 선택 확인
    if (_selectedTemplate == null) {
      AppSnackBar.showError(context, message: '결재 양식을 선택해주세요');
      return;
    }

    final templateType = _selectedTemplate!.templateType;

    // 파일 첨부 확인 (온라인 폼 전용 양식은 첨부 선택사항)
    if (templateType != 'form' && _selectedFile == null) {
      AppSnackBar.showError(context, message: '첨부파일을 선택해주세요');
      return;
    }

    // 온라인 양식 필수 필드 확인
    if (templateType != 'file' && _selectedTemplate!.formFields.isNotEmpty) {
      final missingLabel = DynamicFormFields.validateRequired(
          _selectedTemplate!.formFields, _formValues);
      if (missingLabel != null) {
        AppSnackBar.showError(context, message: '\'$missingLabel\' 항목을 입력해주세요');
        return;
      }
    }

    // 결재선은 양식의 기본 결재선을 그대로 따른다. 비어 있으면 관리자 단일 승인(legacy).
    setState(() => _isSubmitting = true);

    final authProvider = context.read<AuthProvider>();
    final approvalProvider = context.read<ApprovalProvider>();
    final currentUser = authProvider.currentUser!;
    final companyId = currentUser.company?.id ?? '1';
    final requesterId = currentUser.id;
    final requesterName = currentUser.name;

    String? attachmentUrl;

    // 파일 업로드
    if (_selectedFile != null) {
      try {
        final uploadResponse = await ApiService().uploadApprovalFile(
          file: File(_selectedFile!.path),
        );

        if (uploadResponse['success'] == true) {
          attachmentUrl = uploadResponse['fileUrl'];
          print('[ApprovalForm] 파일 업로드 성공: $attachmentUrl');
        } else {
          throw Exception(uploadResponse['error'] ?? '파일 업로드 실패');
        }
      } catch (e) {
        print('[ApprovalForm] 파일 업로드 에러: $e');
        setState(() => _isSubmitting = false);
        if (mounted) {
          AppSnackBar.showError(context, message: '파일 업로드에 실패했습니다: $e');
        }
        return;
      }
    }

    // 결재 요청 생성
    final success = await approvalProvider.createApprovalRequest(
      companyId: companyId,
      requesterId: requesterId,
      requesterName: requesterName,
      templateId: _selectedTemplate!.id,
      title: _titleController.text.trim(),
      attachmentUrl: attachmentUrl,
      attachmentFileName: _selectedFile?.name,
      attachmentFileSize: _selectedFile?.size,
      formData: templateType != 'file' && _formValues.isNotEmpty
          ? Map<String, dynamic>.from(_formValues)
          : null,
      approvalLine: _approvalLine
          .map((c) => {
                'approverType': c.approverType,
                'approverId': c.approverId,
              })
          .toList(),
    );

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      AppSnackBar.showSuccess(context, message: '결재 요청이 제출되었습니다');
      Navigator.pop(context, true);
    } else if (mounted) {
      AppSnackBar.showError(
        context,
        message: approvalProvider.errorMessage.isNotEmpty
            ? approvalProvider.errorMessage
            : '결재 요청에 실패했습니다',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: Text(
          '결재 요청',
          style: AppTypography.heading6.copyWith(
            color: AppSemanticColors.textInverse,
          ),
        ),
        backgroundColor: AppSemanticColors.interactivePrimaryDefault,
        iconTheme: IconThemeData(color: AppSemanticColors.textInverse),
        elevation: 0,
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 결재 양식 선택 섹션
              _buildSectionHeader(
                '결재 양식',
                Icons.description_outlined,
                isRequired: true,
              ),
              const SizedBox(height: AppSpacing.space3),
              Consumer<ApprovalProvider>(
                builder: (context, approvalProvider, child) {
                  if (_isLoadingTemplates) {
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.space4),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.surfaceDefault,
                        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                        border: Border.all(
                          color: AppSemanticColors.borderDefault,
                        ),
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppSemanticColors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  final templates = approvalProvider.activeTemplates;

                  if (templates.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.space4),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.surfaceDefault,
                        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                        border: Border.all(
                          color: AppSemanticColors.borderDefault,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '사용 가능한 결재 양식이 없습니다',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppSemanticColors.textTertiary,
                          ),
                        ),
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: AppSemanticColors.surfaceDefault,
                      borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                      border: Border.all(
                        color: AppSemanticColors.borderDefault,
                      ),
                    ),
                    child: DropdownButtonFormField<ApprovalTemplate>(
                      value: _selectedTemplate,
                      decoration: InputDecoration(
                        hintText: '결재 양식을 선택하세요',
                        hintStyle: AppTypography.bodyMedium.copyWith(
                          color: AppSemanticColors.textTertiary,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.space4,
                          vertical: AppSpacing.space3,
                        ),
                      ),
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppSemanticColors.textPrimary,
                      ),
                      dropdownColor: AppSemanticColors.surfaceDefault,
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        color: AppSemanticColors.textSecondary,
                      ),
                      itemHeight: 56,
                      selectedItemBuilder: (context) {
                        return templates.map((template) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              template.name,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppSemanticColors.textPrimary,
                              ),
                            ),
                          );
                        }).toList();
                      },
                      items: templates.map((template) {
                        return DropdownMenuItem<ApprovalTemplate>(
                          value: template,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                template.name,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppSemanticColors.textPrimary,
                                ),
                              ),
                              if (template.description != null &&
                                  template.description!.isNotEmpty)
                                Text(
                                  template.description!,
                                  style: AppTypography.caption.copyWith(
                                    color: AppSemanticColors.textTertiary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedTemplate = value;
                          _formValues.clear(); // 양식 변경 시 입력값 초기화
                          // 결재선은 양식에 정의된 기본 결재선을 그대로 따른다 (기안자가 고르지 않음).
                          // 양식에 없으면 빈 결재선(관리자 단일 승인) — 이전 양식 선택이 남지 않게 리셋.
                          _approvalLine
                            ..clear()
                            ..addAll(value?.defaultApprovalLineCandidates ?? []);
                        });
                      },
                    ),
                  );
                },
              ),

              if (_canWriteTemplateOnWeb) ...[
                const SizedBox(height: AppSpacing.space3),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _writeTemplateOnWeb,
                    icon: const Icon(Icons.edit_document, size: 18),
                    label: const Text('양식 문서 바로 작성하기'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          AppSemanticColors.interactivePrimaryDefault,
                      side: BorderSide(
                        color: AppSemanticColors.interactivePrimaryDefault,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.space6),

              // 제목 입력 섹션
              _buildSectionHeader(
                '결재 제목',
                Icons.title,
                isRequired: true,
              ),
              const SizedBox(height: AppSpacing.space3),
              SeedTextField(
                label: '결재 제목',
                showLabel: false,
                controller: _titleController,
                placeholder: '결재 제목을 입력하세요',
                size: SeedTextFieldSize.large,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '결재 제목을 입력해주세요';
                  }
                  return null;
                },
              ),

              // 결재선 — 양식에 정의된 기본 결재선을 따른다 (기안자가 임의 지정하지 않음)
              if (_approvalLine.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space6),
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
                      Text(
                        '결재선 (양식에 지정됨)',
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppSemanticColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space2),
                      Text(
                        _approvalLine
                            .asMap()
                            .entries
                            .map((e) =>
                                '${e.key + 1}. ${e.value.name}${e.value.position != null ? ' (${e.value.position})' : ''}')
                            .join(' → '),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppSemanticColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 온라인 양식 (form/hybrid 타입)
              if (_selectedTemplate != null &&
                  _selectedTemplate!.templateType != 'file' &&
                  _selectedTemplate!.formFields.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space6),
                _buildSectionHeader(
                  '온라인 양식 작성',
                  Icons.edit_note,
                  isRequired: true,
                ),
                const SizedBox(height: AppSpacing.space3),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space4),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.surfaceDefault,
                    borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                    border: Border.all(color: AppSemanticColors.borderDefault),
                  ),
                  child: DynamicFormFields(
                    fields: _selectedTemplate!.formFields,
                    values: _formValues,
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.space6),

              // 첨부파일 섹션 (온라인 폼 전용 양식은 선택사항)
              _buildSectionHeader(
                '첨부파일',
                Icons.attach_file,
                isRequired: _selectedTemplate?.templateType != 'form',
              ),
              const SizedBox(height: AppSpacing.space3),
              if (_selectedFile != null)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space4),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.surfaceDefault,
                    borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                    border: Border.all(
                      color: AppSemanticColors.statusInfoBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.space2),
                        decoration: BoxDecoration(
                          color: AppSemanticColors.statusInfoBackground,
                          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                        ),
                        child: Icon(
                          _getFileIcon(_selectedFile!.name),
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
                              _selectedFile!.name,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppSemanticColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _formatFileSize(_selectedFile!.size),
                              style: AppTypography.caption.copyWith(
                                color: AppSemanticColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _removeFile,
                        icon: Icon(
                          Icons.close,
                          color: AppSemanticColors.statusErrorIcon,
                        ),
                      ),
                    ],
                  ),
                )
              else
                InkWell(
                  onTap: _showFilePickOptions,
                  borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.space6),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.surfaceDefault,
                      borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                      border: Border.all(
                        color: AppSemanticColors.borderDefault,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.space3),
                          decoration: BoxDecoration(
                            color: AppSemanticColors.backgroundTertiary,
                            borderRadius: BorderRadius.circular(AppBorderRadius.full),
                          ),
                          child: Icon(
                            Icons.cloud_upload_outlined,
                            size: 32,
                            color: AppSemanticColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space3),
                        Text(
                          '파일을 선택하세요',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppSemanticColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space1),
                        Text(
                          'PDF, DOC, XLS, JPG, PNG (최대 10MB)',
                          style: AppTypography.caption.copyWith(
                            color: AppSemanticColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: AppSpacing.space8),

              // 제출 버튼
              SizedBox(
                width: double.infinity,
                child: shadcn.PrimaryButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppSemanticColors.textInverse,
                            ),
                          ),
                        )
                      : Text(
                          '결재 요청',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppSemanticColors.textInverse,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: AppSpacing.space6),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {required bool isRequired}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.space2),
          decoration: BoxDecoration(
            color: AppSemanticColors.interactivePrimaryDefault.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          ),
          child: Icon(
            icon,
            size: 20,
            color: AppSemanticColors.interactivePrimaryDefault,
          ),
        ),
        const SizedBox(width: AppSpacing.space3),
        Text(
          title,
          style: AppTypography.heading6.copyWith(
            color: AppSemanticColors.textPrimary,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: AppSpacing.space1),
          Text(
            '*',
            style: AppTypography.heading6.copyWith(
              color: AppSemanticColors.statusErrorIcon,
            ),
          ),
        ],
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
