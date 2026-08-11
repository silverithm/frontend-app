import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// 워드·엑셀·슬라이드·텍스트 문서를 앱 안에서 바로 보는 화면.
///
/// 이런 형식을 그릴 수 있는 네이티브 위젯이 없어, 관리자 웹이 쓰는 것과 같은
/// 뷰어(carev.kr/doc-view)를 WebView로 띄운다. 문서가 외부 미리보기 서비스로
/// 나가지 않고 우리 서버·기기 안에서만 처리된다.
///
/// 한글(hwp/hwpx)은 [HwpEditorScreen], 사진은 ChatImageViewer가 맡는다.
class DocumentViewerScreen extends StatefulWidget {
  const DocumentViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    this.onDownload,
  });

  /// 서버 파일 경로. S3 전체 URL이 오면 carev/ 이후 상대 경로를 추출한다.
  final String filePath;
  final String fileName;

  /// 눌렀을 때 기기로 내려받기 (뷰어가 못 여는 경우의 탈출구)
  final VoidCallback? onDownload;

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  /// 관리자 웹과 같은 곳에서 서빙되는 뷰어 페이지 (rhwp-studio와 동일 호스트)
  static const String _viewerOrigin = 'https://carev.kr';

  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  /// S3 URL에서 상대 경로 추출 (웹 DocumentViewerModal의 extractRelativePath와 동일)
  static String _extractRelativePath(String url) {
    if (url.startsWith('https://') || url.startsWith('http://')) {
      final match = RegExp(r'/carev/(.+)$').firstMatch(url);
      if (match != null) return match.group(1)!;
    }
    return url;
  }

  @override
  void initState() {
    super.initState();

    final uri = Uri.parse('$_viewerOrigin/doc-view').replace(
      queryParameters: {
        'path': _extractRelativePath(widget.filePath),
        'name': widget.fileName,
      },
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppSemanticColors.backgroundTertiary)
      // 뷰어의 닫기 버튼을 앱의 '뒤로'와 같게 만든다
      ..addJavaScriptChannel(
        'CarevViewerBridge',
        onMessageReceived: (message) {
          if (message.message == 'close' && mounted) Navigator.of(context).pop();
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _injectToken(),
          onWebResourceError: (error) {
            debugPrint('[DocumentViewer] 로드 실패: ${error.description}');
            if (!mounted || !error.isForMainFrame!) return;
            setState(() {
              _isLoading = false;
              _errorMessage = '문서 뷰어를 불러오지 못했습니다.\n네트워크 상태를 확인해주세요.';
            });
          },
        ),
      )
      ..loadRequest(uri);
  }

  /// 토큰은 주소에 담지 않고, 페이지가 뜬 뒤 넣어준다.
  Future<void> _injectToken() async {
    final token = StorageService().getToken();
    if (!mounted) return;

    if (token == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = '인증 정보가 없습니다. 다시 로그인해주세요.';
      });
      return;
    }

    // 따옴표·역슬래시가 섞여도 스크립트가 깨지지 않게 JSON 문자열로 넘긴다
    final escaped = token.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    await _controller.runJavaScript("window.carevSetAuthToken && window.carevSetAuthToken('$escaped')");
    if (mounted) setState(() => _isLoading = false);
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
          if (widget.onDownload != null)
            IconButton(
              onPressed: widget.onDownload,
              icon: const Icon(Icons.download_outlined),
              tooltip: '기기에 내려받기',
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_errorMessage == null) WebViewWidget(controller: _controller),
          if (_errorMessage != null)
            Center(
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
                        color: AppSemanticColors.textSecondary,
                      ),
                    ),
                    if (widget.onDownload != null) ...[
                      const SizedBox(height: AppSpacing.space4),
                      TextButton.icon(
                        onPressed: widget.onDownload,
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('기기에 내려받기'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (_isLoading && _errorMessage == null)
            Container(
              color: AppSemanticColors.backgroundTertiary,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
