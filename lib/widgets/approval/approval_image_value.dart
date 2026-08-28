import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 결재 양식의 '이미지' 필드 값을 문서 본문에 그린다 (첨부파일 목록이 아니라
/// 텍스트처럼 문서 안에 바로 박히는 이미지 — 웹 ApprovalImageValue.tsx와 짝).
///
/// formData에 저장되는 값은 `{fileUrl, fileName, fileSize?}`이고 fileUrl은
/// 비공개 저장 경로라 인증 없는 <img>/Image.network로는 못 받는다. 그래서
/// 인증 GET으로 바이트를 받아 메모리에 그린다(웹이 blob URL로 바꾸는 것과 같은 이유).
class ApprovalImageFieldValue extends StatefulWidget {
  final String? fileUrl;
  final String? fileName;
  final double maxWidth;
  final double maxHeight;

  const ApprovalImageFieldValue({
    super.key,
    required this.fileUrl,
    this.fileName,
    this.maxWidth = 240,
    this.maxHeight = 240,
  });

  @override
  State<ApprovalImageFieldValue> createState() =>
      _ApprovalImageFieldValueState();
}

class _ApprovalImageFieldValueState extends State<ApprovalImageFieldValue> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ApprovalImageFieldValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileUrl != widget.fileUrl) {
      _load();
    }
  }

  Future<void> _load() async {
    final url = widget.fileUrl;
    if (url == null || url.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _bytes = null;
          _error = false;
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final bytes = await ApiService().downloadFileBytes(url);
      if (!mounted) return;
      setState(() {
        _bytes = Uint8List.fromList(bytes);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  void _openFullscreen() {
    final bytes = _bytes;
    if (bytes == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ApprovalImageFullscreenViewer(
          bytes: bytes,
          fileName: widget.fileName ?? '첨부 이미지',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fileUrl == null || widget.fileUrl!.isEmpty) {
      return Text(
        '-',
        style: AppTypography.bodySmall
            .copyWith(color: AppSemanticColors.textTertiary),
      );
    }

    if (_error) {
      return Text(
        '이미지를 불러오지 못했습니다',
        style: AppTypography.bodySmall
            .copyWith(color: AppSemanticColors.textTertiary),
      );
    }

    if (_loading || _bytes == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.space2),
          Text(
            '이미지 불러오는 중...',
            style: AppTypography.bodySmall
                .copyWith(color: AppSemanticColors.textTertiary),
          ),
        ],
      );
    }

    return Semantics(
      button: true,
      label: '이미지 크게 보기',
      child: GestureDetector(
        onTap: _openFullscreen,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: widget.maxWidth,
              maxHeight: widget.maxHeight,
            ),
            child: Image.memory(_bytes!, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _ApprovalImageFullscreenViewer extends StatelessWidget {
  final Uint8List bytes;
  final String fileName;

  const _ApprovalImageFullscreenViewer({
    required this.bytes,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          fileName,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
