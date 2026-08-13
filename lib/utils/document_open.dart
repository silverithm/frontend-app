/// 서버에 있는 문서를 여는 한 가지 방법.
///
/// 형식마다 열 수 있는 곳이 달라서, 화면마다 제각각 처리하다 보면 어떤 화면에서는
/// 한글 파일이 그냥 "열 수 없습니다"로 끝난다(전자결재 첨부가 그랬다).
/// 여기 한곳에 모아두고 결재·채팅·자료실이 같이 쓴다.
///
/// - 한글(hwp/hwpx): 앱에 들어 있는 한글 뷰어
/// - 워드·엑셀·슬라이드·글자 파일: 관리자 웹과 같은 뷰어를 WebView로
/// - 이미지: 같은 뷰어가 그려준다
/// - 그 밖(pdf·옛 오피스·압축 등): 기기 기본 앱에 맡긴다 —
///   특히 pdf는 기기 뷰어가 WebView보다 잘 보여준다
library;

import 'package:flutter/material.dart';

import '../screens/document_viewer_screen.dart';
import '../screens/hwp_editor_screen.dart';

const Set<String> _hwpExtensions = {'hwp', 'hwpx'};

const Set<String> _inAppViewableExtensions = {
  'docx',
  'xlsx', 'xlsm',
  'pptx',
  'txt', 'csv', 'md', 'json', 'log', 'xml', 'yaml', 'yml',
  'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp',
};

String documentExtension(String fileName) {
  final idx = fileName.lastIndexOf('.');
  return idx >= 0 ? fileName.substring(idx + 1).toLowerCase() : '';
}

/// 앱 안에서 바로 열 수 있는 형식인지 (버튼 문구를 정할 때 쓴다)
bool canOpenInApp(String fileName) {
  final ext = documentExtension(fileName);
  return _hwpExtensions.contains(ext) || _inAppViewableExtensions.contains(ext);
}

/// [filePath]는 S3 전체 URL이어도 되고 서버 상대 경로여도 된다.
/// 앱 안에서 못 여는 형식이면 [onDownloadFallback]으로 넘긴다.
Future<void> openServerDocument(
  BuildContext context, {
  required String? filePath,
  required String fileName,
  required Future<void> Function() onDownloadFallback,
}) async {
  if (filePath == null || filePath.isEmpty) {
    await onDownloadFallback();
    return;
  }

  final ext = documentExtension(fileName);

  if (_hwpExtensions.contains(ext)) {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HwpEditorScreen(filePath: filePath, fileName: fileName),
      ),
    );
    return;
  }

  if (_inAppViewableExtensions.contains(ext)) {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          filePath: filePath,
          fileName: fileName,
          onDownload: onDownloadFallback,
        ),
      ),
    );
    return;
  }

  await onDownloadFallback();
}
