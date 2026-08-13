import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../utils/document_open.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/admin_utils.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/seed/seed_button.dart';

/// 우리 기관 사람만 보는 자료실. 케어브이 커뮤니티 자료실과 달리
/// 기관 밖으로는 나가지 않아 서식·매뉴얼처럼 내부 문서를 둔다.
class CompanyLibraryScreen extends StatefulWidget {
  const CompanyLibraryScreen({super.key});

  @override
  State<CompanyLibraryScreen> createState() => _CompanyLibraryScreenState();
}

class _CompanyLibraryScreenState extends State<CompanyLibraryScreen> {
  static const List<String> _presetCategories = [
    '서식',
    '매뉴얼',
    '교육자료',
    '규정',
    '기타',
  ];
  static const String _uncategorized = '미분류';

  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _selectedCategory = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final companyId = context.read<AuthProvider>().currentUser?.company?.id;
    if (companyId == null) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final response = await ApiService().getCompanyLibrary(
        companyId: companyId,
      );
      final list =
          response['items'] as List<dynamic>? ??
          response['content'] as List<dynamic>? ??
          [];

      if (!mounted) return;
      setState(() {
        _items = list.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('기관 자료실 로드 실패: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  String _categoryOf(Map<String, dynamic> item) {
    final category = item['category']?.toString().trim() ?? '';
    return category.isEmpty ? _uncategorized : category;
  }

  List<String> get _categories {
    final used = _items.map(_categoryOf).toSet().toList()..sort();
    return used;
  }

  List<Map<String, dynamic>> get _visibleItems {
    if (_selectedCategory.isEmpty) return _items;
    return _items.where((i) => _categoryOf(i) == _selectedCategory).toList();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  // ===================== 열기 · 삭제 =====================

  /// 앱 안에서 볼 수 있는 문서는 뷰어로 열고, 나머지만 내려받아 기기 앱에 넘긴다
  Future<void> _openItem(Map<String, dynamic> item) async {
    final filePath = item['filePath']?.toString();
    final fileName = item['fileName']?.toString() ?? '파일';
    if (filePath == null || filePath.isEmpty) {
      AppSnackBar.showError(context, message: '파일 경로가 없습니다');
      return;
    }

    await openServerDocument(
      context,
      filePath: filePath,
      fileName: fileName,
      onDownloadFallback: () => _downloadItem(filePath, fileName),
    );
  }

  Future<void> _downloadItem(String filePath, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final savePath = '${directory.path}/$fileName';
      final token = StorageService().getToken();

      final dioClient = dio.Dio();
      await dioClient.download(
        ApiService().fileDownloadUrl(filePath, fileName),
        savePath,
        options: dio.Options(
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        ),
      );

      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done && mounted) {
        AppSnackBar.showInfo(context, message: '내려받았습니다: $fileName');
      }
    } catch (e) {
      debugPrint('기관 자료 열기 실패: $e');
      if (mounted) AppSnackBar.showError(context, message: '자료를 열지 못했습니다');
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final itemId = item['id'];
    if (itemId is! int) return;

    final confirmed = await AppDialog.showConfirm(
      context,
      title: '자료 삭제',
      message: '"${item['title']}" 자료를 삭제하시겠습니까?',
      confirmText: '삭제',
      cancelText: '취소',
      confirmVariant: SeedButtonVariant.critical,
    );
    if (confirmed != true) return;

    try {
      await ApiService().deleteCompanyLibraryItem(itemId: itemId);
      if (!mounted) return;
      AppSnackBar.showSuccess(context, message: '자료를 삭제했습니다');
      _load();
    } catch (e) {
      debugPrint('기관 자료 삭제 실패: $e');
      if (mounted) AppSnackBar.showError(context, message: '삭제에 실패했습니다');
    }
  }

  // ===================== 올리기 =====================

  Future<void> _showUploadSheet() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String category = _presetCategories.first;
    XFile? picked;
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppSemanticColors.surfaceDefault,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppBorderRadius.xl2),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              if (titleController.text.trim().isEmpty || picked == null) {
                AppSnackBar.showWarning(context, message: '제목과 파일을 모두 넣어주세요');
                return;
              }

              final auth = this.context.read<AuthProvider>();
              final companyId = auth.currentUser?.company?.id;
              if (companyId == null) return;

              setSheetState(() => isSaving = true);
              try {
                // 파일을 먼저 올리고, 돌려받은 경로로 자료를 등록한다
                final uploaded = await ApiService().uploadFileToServer(
                  filePath: picked!.path,
                );

                await ApiService().createCompanyLibraryItem(
                  companyId: companyId,
                  title: titleController.text.trim(),
                  description: descriptionController.text.trim(),
                  category: category,
                  fileName: uploaded['fileName']?.toString() ?? picked!.name,
                  fileSize:
                      (uploaded['fileSize'] as num?)?.toInt() ??
                      await File(picked!.path).length(),
                  filePath: uploaded['filePath']?.toString() ?? '',
                  uploaderId: auth.currentUser?.id ?? '',
                  uploaderName: auth.currentUser?.name ?? '',
                );

                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext);
                if (mounted) {
                  AppSnackBar.showSuccess(this.context, message: '자료를 올렸습니다');
                  _load();
                }
              } catch (e) {
                debugPrint('기관 자료 등록 실패: $e');
                setSheetState(() => isSaving = false);
                if (context.mounted) {
                  AppSnackBar.showError(context, message: '자료 등록에 실패했습니다');
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.space5,
                right: AppSpacing.space5,
                top: AppSpacing.space5,
                bottom:
                    AppSpacing.space5 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '자료 올리기',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: '제목',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  TextField(
                    controller: descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '설명 (선택)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(
                      labelText: '분류',
                      border: OutlineInputBorder(),
                    ),
                    items: _presetCategories
                        .map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setSheetState(() => category = value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final file = await openFile();
                      if (file != null) setSheetState(() => picked = file);
                    },
                    icon: const Icon(Icons.attach_file),
                    label: Text(picked?.name ?? '파일 선택'),
                  ),
                  const SizedBox(height: AppSpacing.space5),
                  SizedBox(
                    width: double.infinity,
                    child: SeedButton(
                      label: isSaving ? '올리는 중...' : '올리기',
                      onPressed: isSaving ? null : submit,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===================== 화면 =====================

  @override
  Widget build(BuildContext context) {
    final isAdmin = AdminUtils.canAccessAdminPages(
      context.watch<AuthProvider>().currentUser,
    );

    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundSecondary,
      appBar: AppBar(
        title: Text('기관 자료실', style: AppTypography.heading5),
        backgroundColor: AppSemanticColors.backgroundPrimary,
        elevation: 0,
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: _showUploadSheet,
              backgroundColor: AppSemanticColors.interactivePrimaryDefault,
              child: Icon(Icons.add, color: AppSemanticColors.textInverse),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
          ? _buildErrorState()
          : RefreshIndicator(onRefresh: _load, child: _buildList(isAdmin)),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: AppSpacing.space12,
            color: AppSemanticColors.statusErrorIcon,
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            '자료를 불러오지 못했습니다',
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          SeedButton(
            label: '다시 시도',
            variant: SeedButtonVariant.neutralWeak,
            size: SeedButtonSize.small,
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildList(bool isAdmin) {
    final items = _visibleItems;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.space16),
      children: [
        if (_categories.isNotEmpty) _buildCategoryChips(),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.space10),
            child: Center(
              child: Text(
                _items.isEmpty ? '아직 올라온 자료가 없습니다' : '이 분류에는 자료가 없습니다',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppSemanticColors.textTertiary,
                ),
              ),
            ),
          )
        else
          ...items.map((item) => _buildItemCard(item, isAdmin)),
      ],
    );
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      child: Row(
        children: [
          _buildChip('전체 (${_items.length})', _selectedCategory.isEmpty, () {
            setState(() => _selectedCategory = '');
          }),
          ..._categories.map((category) {
            final count = _items.where((i) => _categoryOf(i) == category).length;
            return Padding(
              padding: const EdgeInsets.only(left: AppSpacing.space2),
              child: _buildChip(
                '$category ($count)',
                _selectedCategory == category,
                () => setState(() => _selectedCategory = category),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space2,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppSemanticColors.interactivePrimaryDefault
              : AppSemanticColors.surfaceDefault,
          borderRadius: BorderRadius.circular(AppBorderRadius.full),
          border: Border.all(
            color: isSelected
                ? AppSemanticColors.interactivePrimaryDefault
                : AppSemanticColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: isSelected
                ? AppSemanticColors.textInverse
                : AppSemanticColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, bool isAdmin) {
    final fileSize = (item['fileSize'] as num?)?.toInt() ?? 0;
    final description = item['description']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        0,
        AppSpacing.space4,
        AppSpacing.space3,
      ),
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppSemanticColors.surfaceDefault,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppSemanticColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.description_outlined,
                color: AppSemanticColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.space2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title']?.toString() ?? '',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppSemanticColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppSemanticColors.backgroundTertiary,
                  borderRadius: BorderRadius.circular(AppBorderRadius.full),
                ),
                child: Text(
                  _categoryOf(item),
                  style: AppTypography.labelSmall.copyWith(
                    color: AppSemanticColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            '${item['fileName'] ?? ''} · ${_formatSize(fileSize)} · ${item['uploaderName'] ?? ''}',
            style: AppTypography.labelSmall.copyWith(
              color: AppSemanticColors.textTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.space3),
          Row(
            children: [
              SeedButton(
                label: '열기',
                size: SeedButtonSize.small,
                variant: SeedButtonVariant.neutralWeak,
                onPressed: () => _openItem(item),
              ),
              if (isAdmin) ...[
                const SizedBox(width: AppSpacing.space2),
                SeedButton(
                  label: '삭제',
                  size: SeedButtonSize.small,
                  variant: SeedButtonVariant.critical,
                  onPressed: () => _deleteItem(item),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
