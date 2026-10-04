import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 채팅 사진·파일을 카카오톡 등 다른 앱으로 바로 보낸다 (2026-09-30 버그제보방 요청).
///
/// 겹치지 않는 임시 폴더에 **원래 이름**으로 받아 시스템 공유 창을 연다 — 받는 쪽 앱에
/// 'share_1790…' 같은 임시 이름이 그대로 보이지 않게 한다. 받은 파일은 공유 창이 닫힌 뒤에도
/// 받는 앱이 읽을 수 있어야 해서 바로 지우지 않고, 운영체제가 임시 폴더를 정리하게 둔다.
///
/// 느린 연결에서 멈춰 있지 않게 저장과 같은 시간 제한(연결 20초·무응답 60초)을 둔다.
Future<void> shareRemoteFile({
  required String url,
  required String fileName,
  Rect? sharePositionOrigin,
}) async {
  final base = await getTemporaryDirectory();
  final dir = await Directory(
    '${base.path}/share_${DateTime.now().microsecondsSinceEpoch}',
  ).create(recursive: true);
  final safeName = safeShareFileName(fileName);
  final path = '${dir.path}/$safeName';

  await Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
    ),
  ).download(url, path);

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(path)],
      // 아이패드는 공유 창을 띄울 기준 위치가 없으면 열리지 않는다
      sharePositionOrigin: sharePositionOrigin,
    ),
  );
}

/// 파일 이름에 쓸 수 없는 글자를 '_'로 바꾸고, 비어 있으면 기본 이름을 쓴다.
String safeShareFileName(String fileName) {
  final cleaned = fileName.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  return cleaned.isEmpty ? 'image.jpg' : cleaned;
}
