import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import '../providers/approval_provider.dart';
import '../providers/auth_provider.dart';
import '../models/approval.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/approval/template_card.dart';
import 'approval_template_preview_screen.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_fab.dart';
import '../widgets/common/app_list_entrance.dart';
import '../widgets/common/app_refresh.dart';
import '../widgets/common/app_skeleton.dart';
import '../widgets/common/app_sheet_frame.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_text_field.dart';
import '../widgets/common/carev_app_bar.dart';

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

  /// 목록을 아래로 내리면 FAB 글자를 접는다(B안 알약 FAB).
  bool _fabCollapsed = false;

  @override
  void initState() {
    super.initState();
    // 첫 프레임이 그려지는 중에 프로바이더가 notifyListeners를 부르면
    // "setState() or markNeedsBuild() called during build"가 난다 — 한 프레임 뒤에 시작한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final approvalProvider = context.read<ApprovalProvider>();

      final companyId = authProvider.currentUser?.company?.id?.toString() ?? '';
      await approvalProvider.loadTemplates(companyId: companyId);
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: '데이터 로드 실패: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

    // B안: 가운데 대화상자 대신 아래 시트(입력칸이 있어 키보드만큼 올라간다). 저장 흐름은 그대로.
    showAppSheet<void>(
      context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickFile() async {
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
          }

          return AppSheetFrame(
            title: template == null ? '양식 추가' : '양식 수정',
            actions: AppSheetActions(
              cancel: SeedButton(
                label: '취소',
                size: SeedButtonSize.large,
                variant: SeedButtonVariant.neutralWeak,
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
              ),
              confirm: SeedButton(
                label: template == null ? '추가' : '수정',
                size: SeedButtonSize.large,
                variant: SeedButtonVariant.brandSolid,
                isLoading: isSubmitting,
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) {
                          AppSnackBar.showWarning(
                            context,
                            message: '양식 이름을 입력해주세요',
                          );
                          return;
                        }

                        setDialogState(() => isSubmitting = true);

                        final authProvider = context.read<AuthProvider>();
                        final approvalProvider =
                            context.read<ApprovalProvider>();
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
                          final fileName =
                              selectedFile?.name ?? template.fileName;
                          final fileSize =
                              selectedFile?.size ?? template.fileSize;

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
                          AppSnackBar.showSuccess(
                            context,
                            message: template == null
                                ? '양식이 추가되었습니다'
                                : '양식이 수정되었습니다',
                          );
                        }
                      },
              ),
            ),
            children: [
              const SizedBox(height: AppSpacing.space5),
              SeedTextField(
                label: '양식 이름 *',
                controller: nameController,
                placeholder: '양식 이름을 입력하세요',
                size: SeedTextFieldSize.large,
              ),
              const SizedBox(height: AppSpacing.space4),
              SeedTextField(
                label: '설명',
                controller: descriptionController,
                maxLines: 3,
                placeholder: '양식에 대한 설명을 입력하세요 (선택)',
                size: SeedTextFieldSize.large,
              ),
              const SizedBox(height: AppSpacing.space4),
              Text(
                '첨부파일 (양식 서식)',
                style: AppTypography.titleSmall.copyWith(
                  color: AppSemanticColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),
              if (selectedFile != null)
                // 고른 파일 — 테두리 없는 옅은 파랑 칸
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space4,
                    AppSpacing.space2,
                    AppSpacing.space1,
                    AppSpacing.space2,
                  ),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.statusInfoBackground,
                    borderRadius: BorderRadius.circular(AppBorderRadius.control),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.insert_drive_file,
                        color: AppSemanticColors.statusInfoIcon,
                      ),
                      const SizedBox(width: AppSpacing.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedFile!.name,
                              style: AppTypography.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _formatFileSize(selectedFile!.size),
                              style: AppTypography.bodySmall.copyWith(
                                color: AppSemanticColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '선택한 파일 제거',
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
                // 지금 붙은 파일 — 회색 칸 + 옅은 틸 '변경' 단추(회색 위 회색 단추는 묻힌다)
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space4,
                    AppSpacing.space2,
                    AppSpacing.space2,
                    AppSpacing.space2,
                  ),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.fillDefault,
                    borderRadius: BorderRadius.circular(AppBorderRadius.control),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.insert_drive_file,
                        color: AppSemanticColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.space3),
                      Expanded(
                        child: Text(
                          template!.fileName!,
                          style: AppTypography.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SeedButton(
                        label: '변경',
                        variant: SeedButtonVariant.brandWeak,
                        size: SeedButtonSize.small,
                        onPressed: pickFile,
                      ),
                    ],
                  ),
                )
              else
                // 파일 고르기 — 테두리 상자 대신 회색 채운 칸(높이 54 이상)
                Material(
                  color: AppSemanticColors.fillDefault,
                  borderRadius: BorderRadius.circular(AppBorderRadius.control),
                  child: InkWell(
                    onTap: pickFile,
                    borderRadius: BorderRadius.circular(AppBorderRadius.control),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppSpacing.buttonHeightLarge,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.space3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_upload_outlined,
                              color: AppSemanticColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.space2),
                            Flexible(
                              child: Text(
                                '파일 선택',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppSemanticColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
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
      if (template.isActive) {
        AppSnackBar.showWarning(context, message: '양식이 비활성화되었습니다');
      } else {
        AppSnackBar.showSuccess(context, message: '양식이 활성화되었습니다');
      }
    }
  }

  Future<void> _deleteTemplate(ApprovalTemplate template) async {
    final confirmed = await AppDialog.showConfirm(
      context,
      title: '양식 삭제',
      message: '"${template.name}" 양식을 삭제하시겠습니까?\n삭제된 양식은 복구할 수 없습니다.',
      confirmText: '삭제',
      cancelText: '취소',
      confirmVariant: SeedButtonVariant.critical,
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
          // 삭제는 되돌릴 수 없는 행위지만, 이 알림은 정상 완료 통보이지 오류가 아니다 — 빨강 금지
          AppSnackBar.showInfo(context, message: '양식이 삭제되었습니다');
        } else {
          // 에러 메시지 표시
          final errorMsg = approvalProvider.errorMessage;
          AppSnackBar.showError(
            context,
            message: errorMsg.isNotEmpty ? errorMsg : '양식 삭제에 실패했습니다',
            duration: const Duration(seconds: 4),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // B안: 옅은 회색 바탕, 알약 FAB(글자는 예전 그대로 '양식 추가', 목록을 내리면 접힘)
    // 처음 불러올 때(아직 보일 양식이 없을 때)만 뼈대 — 양식이 있는 채로 다시 불러올 때는 예전 스피너
    final hasNoTemplates = context.select<ApprovalProvider, bool>(
      (provider) => provider.templates.isEmpty,
    );
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundCanvas,
      appBar: const CareVAppBar(title: '결재 양식 관리'),
      // 카드 등장 연출은 처음 한 번만 — 다시 불러와도 다시 떠오르지 않게 바깥에 둔다
      body: AppListEntrance(
        child: _isLoading && hasNoTemplates
            ? const _TemplateListSkeleton()
            : _isLoading
            ? const Center(child: CircularProgressIndicator())
            : NotificationListener<UserScrollNotification>(
                onNotification: (notification) {
                  final direction = notification.direction;
                  if (direction != ScrollDirection.idle) {
                    final collapse = direction == ScrollDirection.reverse;
                    if (collapse != _fabCollapsed) {
                      setState(() => _fabCollapsed = collapse);
                    }
                  }
                  return false;
                },
                child: _buildContent(),
              ),
      ),
      floatingActionButton: AppFab(
        icon: Icons.add,
        label: '양식 추가',
        collapsed: _fabCollapsed,
        onPressed: _showCreateDialog,
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
                // AppEmptyState와 같은 옅은 틸 원(글자 크기는 그대로 두려고 직접 그린다)
                Container(
                  width: AppSpacing.space14,
                  height: AppSpacing.space14,
                  decoration: const BoxDecoration(
                    color: AppSemanticColors.brandWeak,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    size: 26,
                    color: AppSemanticColors.brandDefault,
                  ),
                ),
                const SizedBox(height: AppSpacing.space3_5),
                Text(
                  '결재 양식이 없습니다',
                  style: AppTypography.heading6.copyWith(
                    color: AppSemanticColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space2),
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

        return AppRefreshIndicator(
          onRefresh: _loadData,
          child: ListView.builder(
            // 떠 있는 FAB가 마지막 카드를 가리지 않게 아래 96
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.space3,
              AppSpacing.screenGutter,
              96,
            ),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return AppListEntranceItem(
                index: index,
                child: TemplateCard(
                  template: template,
                  // 카드를 누르면 양식을 바로 열람한다 (웹의 양식 미리보기와 같은 동작)
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ApprovalTemplatePreviewScreen(
                        template: template,
                        showUseButton: false,
                      ),
                    ),
                  ),
                  onEdit: () => _showEditDialog(template),
                  onDelete: () => _deleteTemplate(template),
                  onToggleActive: () => _toggleActive(template),
                ),
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

/// 결재 양식 첫 불러오기 뼈대 — 회색 바탕 위 흰 양식 카드(목록과 같은 여백·간격)
class _TemplateListSkeleton extends StatelessWidget {
  const _TemplateListSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      baseColor: AppSemanticColors.skeletonBaseOnCard,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          AppSpacing.space3,
          AppSpacing.screenGutter,
          96,
        ),
        children: List.generate(
          4,
          (_) => const AppSkeletonCard(
            standalone: false,
            margin: EdgeInsets.only(bottom: AppSpacing.cardGap),
          ),
        ),
      ),
    );
  }
}
