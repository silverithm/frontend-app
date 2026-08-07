import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/approval/hwp_editor_view.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/seed/seed_button.dart';

/// HWP 편집 완료 시 반환되는 결과 (작성된 파일이 임시 디렉토리에 저장된다).
class HwpEditResult {
  HwpEditResult({required this.path, required this.name, required this.size});

  final String path;
  final String name;
  final int size;
}

/// 서버의 HWP/HWPX 문서를 셀프호스팅 웹 에디터로 열어 열람하거나,
/// [allowSave]가 true면 편집 후 "작성 완료"로 파일을 돌려받는 화면.
///
/// 전자결재 첨부문서 열람(approval_detail)과 템플릿 기반 기안 작성
/// (approval_form)에서 공용으로 사용한다.
class HwpEditorScreen extends StatefulWidget {
  const HwpEditorScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    this.allowSave = false,
    this.saveLabel = '작성 완료',
  });

  /// 서버 파일 경로. S3 전체 URL이 오면 carev/ 이후 상대 경로를 추출한다.
  final String filePath;
  final String fileName;
  final bool allowSave;
  final String saveLabel;

  @override
  State<HwpEditorScreen> createState() => _HwpEditorScreenState();
}

class _HwpEditorScreenState extends State<HwpEditorScreen> {
  late final HwpEditorController _editor;
  String? _loadingMessage = '문서를 불러오는 중...';
  String? _errorMessage;
  bool _documentLoaded = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _editor = HwpEditorController();
    _load();
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  /// S3 URL에서 상대 경로 추출 (웹 DocumentViewerModal의 extractRelativePath와 동일)
  static String _extractRelativePath(String url) {
    if (url.startsWith('https://') || url.startsWith('http://')) {
      final match = RegExp(r'/carev/(.+)$').firstMatch(url);
      if (match != null) return match.group(1)!;
    }
    return url;
  }

  Future<void> _load() async {
    try {
      final token = StorageService().getToken();
      if (token == null) {
        setState(() {
          _errorMessage = '인증 정보가 없습니다. 다시 로그인해주세요.';
          _loadingMessage = null;
        });
        return;
      }

      final downloadUri = Uri.https(
        'silverithm.site',
        '/api/v1/files/download',
        {
          'path': _extractRelativePath(widget.filePath),
          'fileName': widget.fileName,
        },
      );

      final response = await Dio().get<List<int>>(
        downloadUri.toString(),
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      final bytes = Uint8List.fromList(response.data ?? []);
      if (bytes.isEmpty) throw Exception('빈 파일입니다.');
      if (!mounted) return;

      setState(() => _loadingMessage = '한글 문서 에디터를 불러오는 중...');
      await _editor.waitReady();
      if (!mounted) return;

      await _editor.loadFile(bytes, widget.fileName);
      if (!mounted) return;

      setState(() {
        _loadingMessage = null;
        _documentLoaded = true;
      });
    } catch (e) {
      debugPrint('[HwpEditorScreen] 문서 로드 실패: $e');
      if (!mounted) return;
      setState(() {
        _loadingMessage = null;
        _errorMessage = e is HwpEditorException
            ? e.message
            : '문서를 불러오는 중 오류가 발생했습니다.\n네트워크 상태를 확인해주세요.';
      });
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final isHwpx = widget.fileName.toLowerCase().endsWith('.hwpx');
      Uint8List bytes;
      var outName = widget.fileName;

      if (isHwpx) {
        try {
          bytes = await _editor.exportHwpx();
        } catch (_) {
          // HWPX 직렬화가 안 되는 문서는 HWP로 변환 저장 (웹 구현과 동일)
          bytes = await _editor.exportHwp();
          outName = widget.fileName.replaceAll(RegExp(r'\.hwpx$', caseSensitive: false), '.hwp');
        }
      } else {
        bytes = await _editor.exportHwp();
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$outName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      Navigator.of(context).pop(
        HwpEditResult(path: file.path, name: outName, size: bytes.length),
      );
    } catch (e) {
      debugPrint('[HwpEditorScreen] 문서 저장 실패: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        AppSnackBar.showError(
          context,
          message: '작성한 문서를 저장하는 데 실패했습니다. 다시 시도해주세요.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundTertiary,
      appBar: AppBar(
        title: Text(
          widget.fileName,
          style: AppTypography.heading6.copyWith(
            fontWeight: AppTypography.fontWeightSemibold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (widget.allowSave && _documentLoaded)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.space2),
              child: SeedButton(
                label: _isSaving ? '저장 중...' : widget.saveLabel,
                prefixIcon: Icons.check,
                size: SeedButtonSize.small,
                isLoading: _isSaving,
                onPressed: _save,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (widget.allowSave && _documentLoaded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space4,
                vertical: AppSpacing.space2_5,
              ),
              color: AppSemanticColors.brandWeak,
              child: Text(
                '문서를 작성한 뒤 우측 상단 ${widget.saveLabel} 버튼을 누르면 자동으로 첨부됩니다.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.brandPressed,
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                // 에디터는 항상 렌더링 (WebView가 백그라운드에서 초기화되도록)
                HwpEditorView(controller: _editor),
                if (_loadingMessage != null)
                  Container(
                    color: AppSemanticColors.backgroundTertiary,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: AppSemanticColors.brandDefault,
                          ),
                          const SizedBox(height: AppSpacing.space4),
                          Text(
                            _loadingMessage!,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppSemanticColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_errorMessage != null)
                  Container(
                    color: AppSemanticColors.backgroundTertiary,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.space6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: AppSemanticColors.textTertiary,
                            ),
                            const SizedBox(height: AppSpacing.space4),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppSemanticColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.space4),
                            SeedButton(
                              label: '다시 시도',
                              variant: SeedButtonVariant.neutralOutline,
                              onPressed: () {
                                setState(() {
                                  _errorMessage = null;
                                  _loadingMessage = '문서를 불러오는 중...';
                                });
                                _load();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
