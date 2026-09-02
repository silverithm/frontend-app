import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/seed/seed_button.dart';
import '../widgets/seed/seed_callout.dart';
import '../widgets/seed/seed_chip.dart';
import '../widgets/seed/seed_text_field.dart';

/// AI 글쓰기 도우미 — 웹(frontend-admin의 AiPostWriter.tsx)과 같은 기능.
///
/// 사진은 폰으로 찍는데 기능은 웹에만 있어서 PC로 옮겨야 했던 것을 앱으로 가져온 화면이다.
/// 사진을 올리면 Gemini가 밴드·블로그 게시글(제목·본문·해시태그)을 써주고, 선생님은
/// 그 결과를 복사해서 밴드에 붙여넣는다. 그래서 '복사'가 이 화면의 핵심 동작이다.
///
/// API 키(GEMINI_API_KEY)는 웹 서버(Vercel)에만 있고 앱에는 들어오지 않는다.
/// ApiService.generateAiPost가 carev.kr의 Next 라우트를 호출한다 — 자세한 사정은 그쪽 주석 참고.
class AiPostWriterScreen extends StatefulWidget {
  const AiPostWriterScreen({super.key});

  @override
  State<AiPostWriterScreen> createState() => _AiPostWriterScreenState();
}

/// 어디에 올릴 글인지. 백엔드 라우트의 channel 값과 1:1.
enum _Channel {
  band,
  blog;

  String get apiValue => this == _Channel.band ? 'band' : 'blog';

  String get label => this == _Channel.band ? '밴드 글' : '블로그 글';

  String get resultLabel => this == _Channel.band ? '밴드용' : '블로그용';
}

class _AiPostResult {
  final String title;
  final String content;
  final List<String> hashtags;

  const _AiPostResult({
    required this.title,
    required this.content,
    required this.hashtags,
  });
}

class _AiPostWriterScreenState extends State<AiPostWriterScreen> {
  /// 웹과 같은 제한 — 라우트도 5장을 넘기면 400을 준다.
  static const int _maxImages = 5;

  /// 웹과 같은 축소 기준(긴 변 1024px). 요청 크기와 토큰 비용을 줄인다.
  static const int _resizeMaxSide = 1024;

  /// 라우트가 장당 base64 2MB를 넘기면 거절한다. 올리기 전에 앱에서 먼저 걸러 안내한다.
  static const int _maxBase64Length = 2 * 1024 * 1024;

  final TextEditingController _descriptionController = TextEditingController();

  final List<File> _images = [];
  _Channel _channel = _Channel.band;
  bool _isGenerating = false;
  String? _errorMessage;
  _AiPostResult? _result;

  /// 결과를 만들어낸 채널 — 생성 뒤 사용자가 채널 칩을 바꿔도 결과 배지가 따라 바뀌면 안 된다.
  _Channel? _resultChannel;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_isGenerating) return;

    final remaining = _maxImages - _images.length;
    if (remaining <= 0) {
      AppSnackBar.showError(context, message: '사진은 최대 $_maxImages장까지 올릴 수 있어요');
      return;
    }

    try {
      // 웹은 canvas로 축소하고 HEIC은 폴백 분기를 뒀지만, 앱은 picker가
      // 축소·회전 보정까지 네이티브로 해주고 아이폰 HEIC도 JPEG으로 내려준다.
      final picked = await ImagePicker().pickMultiImage(
        maxWidth: _resizeMaxSide.toDouble(),
        maxHeight: _resizeMaxSide.toDouble(),
        imageQuality: 80,
      );
      if (picked.isEmpty) return;

      if (!mounted) return;
      setState(() {
        _images.addAll(picked.take(remaining).map((x) => File(x.path)));
        _errorMessage = null;
      });

      if (picked.length > remaining) {
        AppSnackBar.showInfo(
          context,
          message: '사진은 최대 $_maxImages장까지라 앞의 $remaining장만 담았어요',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, message: '사진을 불러오지 못했습니다: $e');
    }
  }

  void _removeImageAt(int index) {
    if (_isGenerating) return;
    setState(() {
      _images.removeAt(index);
      _errorMessage = null;
    });
  }

  /// 사진 한 장을 JPEG base64로 만든다. picker가 이미 축소했지만,
  /// PNG 등으로 들어온 경우까지 JPEG으로 맞추려고 한 번 더 압축한다.
  Future<Map<String, String>> _toJpegBase64(File file) async {
    Uint8List? bytes;
    try {
      bytes = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: _resizeMaxSide,
        minHeight: _resizeMaxSide,
        quality: 80,
        format: CompressFormat.jpeg,
      );
    } catch (_) {
      // 압축 실패는 치명적이지 않다 — 원본 바이트로 넘어간다.
      bytes = null;
    }
    bytes ??= await file.readAsBytes();

    final data = base64Encode(bytes);
    if (data.length > _maxBase64Length) {
      throw Exception('사진 용량이 너무 큽니다. 더 작은 사진으로 다시 시도해주세요');
    }
    return {'mimeType': 'image/jpeg', 'data': data};
  }

  Future<void> _generate() async {
    if (_images.isEmpty) {
      setState(() => _errorMessage = '사진을 1장 이상 올려주세요.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    final channel = _channel;
    // await 이전에 읽는다 — 비동기 뒤에 context를 다시 만지지 않기 위해서.
    final companyName = context.read<AuthProvider>().currentUser?.company?.name;
    try {
      final images = <Map<String, String>>[];
      for (final file in _images) {
        images.add(await _toJpegBase64(file));
      }

      final now = DateTime.now();
      final response = await ApiService().generateAiPost(
        channel: channel.apiValue,
        images: images,
        description: _descriptionController.text.trim(),
        companyName: companyName,
        date: '${now.year}년 ${now.month}월 ${now.day}일',
      );

      final hashtagsRaw = response['hashtags'];
      final hashtags = hashtagsRaw is List
          ? hashtagsRaw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList()
          : <String>[];

      if (!mounted) return;
      setState(() {
        _result = _AiPostResult(
          title: response['title']?.toString() ?? '',
          content: response['content']?.toString() ?? '',
          hashtags: hashtags,
        );
        _resultChannel = channel;
      });
      AppSnackBar.showSuccess(
        context,
        message: '글이 완성됐어요. 확인하고 복사해서 올려주세요',
      );
    } catch (e) {
      final message = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('ApiException: ', '');
      if (!mounted) return;
      setState(() {
        _errorMessage = message.isNotEmpty ? message : '글 생성에 실패했습니다';
      });
      AppSnackBar.showError(
        context,
        message: message.isNotEmpty ? message : '글 생성에 실패했습니다',
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  String _buildFullText({required bool withTitle}) {
    final result = _result;
    if (result == null) return '';
    final parts = <String>[];
    if (withTitle && result.title.isNotEmpty) parts.add(result.title);
    if (result.content.isNotEmpty) parts.add(result.content);
    if (result.hashtags.isNotEmpty) parts.add(result.hashtags.join(' '));
    return parts.join('\n\n');
  }

  Future<void> _copy(String text, String label) async {
    if (text.isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      AppSnackBar.showSuccess(context, message: '$label을(를) 복사했어요. 밴드·블로그에 붙여넣으세요');
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.showError(context, message: '복사에 실패했습니다. 글을 길게 눌러 직접 복사해주세요');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.backgroundPrimary,
      appBar: AppBar(
        title: Text('AI 글쓰기 도우미', style: AppTypography.heading5),
        backgroundColor: AppSemanticColors.backgroundPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SeedCallout(
                variant: SeedCalloutVariant.info,
                title: '사진만 올리면 글을 써드려요',
                description:
                    '오늘 찍은 식사·프로그램 사진을 올리면 밴드/블로그 게시글을 자동으로 작성해요. 완성된 글을 복사해서 붙여넣기만 하면 됩니다.',
              ),
              const SizedBox(height: AppSpacing.space5),

              Text(
                '오늘의 사진 (${_images.length}/$_maxImages)',
                style: AppTypography.labelLarge.copyWith(
                  color: AppSemanticColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),
              Text(
                '식사, 프로그램, 만들기 활동 사진 등을 최대 $_maxImages장까지 올릴 수 있어요.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.space3),

              if (_images.isNotEmpty) ...[
                _buildThumbnailStrip(),
                const SizedBox(height: AppSpacing.space3),
              ],

              SizedBox(
                width: double.infinity,
                child: SeedButton(
                  label: _images.isEmpty ? '사진 선택하기' : '사진 더 담기',
                  variant: SeedButtonVariant.neutralOutline,
                  prefixIcon: Icons.add_photo_alternate_outlined,
                  isDisabled: _isGenerating || _images.length >= _maxImages,
                  onPressed: _pickImages,
                ),
              ),
              const SizedBox(height: AppSpacing.space5),

              Text(
                '어디에 올릴 글인가요?',
                style: AppTypography.labelLarge.copyWith(
                  color: AppSemanticColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.space2),
              Row(
                children: [
                  for (final channel in _Channel.values) ...[
                    SeedChip(
                      label: channel.label,
                      selected: _channel == channel,
                      isDisabled: _isGenerating,
                      onTap: () => setState(() => _channel = channel),
                    ),
                    if (channel != _Channel.values.last)
                      const SizedBox(width: AppSpacing.space2),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.space5),

              SeedTextField(
                label: '상황 설명 (선택)',
                placeholder:
                    '예: 오늘 오전엔 원예 프로그램으로 다육이 화분을 만들었고, 점심은 잡채와 미역국이었어요.',
                helperText: '적어주시면 글이 훨씬 정확해져요. 비워두면 사진만 보고 작성합니다.',
                controller: _descriptionController,
                maxLines: 3,
                isDisabled: _isGenerating,
              ),
              const SizedBox(height: AppSpacing.space4),

              if (_errorMessage != null) ...[
                SeedCallout(
                  variant: SeedCalloutVariant.danger,
                  title: _errorMessage!,
                ),
                const SizedBox(height: AppSpacing.space4),
              ],

              SizedBox(
                width: double.infinity,
                child: SeedButton(
                  label: _isGenerating ? '글을 쓰고 있어요...' : '버튼 하나로 글 완성하기',
                  size: SeedButtonSize.large,
                  prefixIcon: Icons.auto_awesome_outlined,
                  isLoading: _isGenerating,
                  isDisabled: _isGenerating || _images.isEmpty,
                  onPressed: _generate,
                ),
              ),

              if (_isGenerating) ...[
                const SizedBox(height: AppSpacing.space3),
                Text(
                  '사진을 살펴보고 글을 쓰는 중이에요. 사진 장수에 따라 10~40초쯤 걸립니다.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
              ],

              if (_result != null) ...[
                const SizedBox(height: AppSpacing.space6),
                _buildResult(_result!),
              ],

              const SizedBox(height: AppSpacing.space8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailStrip() {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.space2),
        itemBuilder: (context, index) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                child: Image.file(
                  _images[index],
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  // 파일을 못 읽어도 화면이 깨지지 않게 자리를 지킨다.
                  errorBuilder: (context, error, stack) => Container(
                    width: 96,
                    height: 96,
                    color: AppSemanticColors.backgroundTertiary,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppSemanticColors.textTertiary,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: Semantics(
                  button: true,
                  label: '${index + 1}번째 사진 빼기',
                  child: GestureDetector(
                    onTap: () => _removeImageAt(index),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.space1),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.backgroundPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppSemanticColors.borderDefault,
                        ),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: AppSemanticColors.statusErrorIcon,
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

  Widget _buildResult(_AiPostResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: AppSemanticColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(color: AppSemanticColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.title.isNotEmpty ? result.title : '완성된 글',
                  style: AppTypography.heading6.copyWith(
                    color: AppSemanticColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space2,
                  vertical: AppSpacing.space0_5,
                ),
                decoration: BoxDecoration(
                  color: AppSemanticColors.brandWeak,
                  borderRadius: BorderRadius.circular(AppBorderRadius.full),
                ),
                child: Text(
                  (_resultChannel ?? _channel).resultLabel,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppSemanticColors.brandDefault,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),

          // 길게 눌러 직접 선택·복사할 수도 있게 둔다 (복사 버튼이 막혔을 때의 대비).
          SelectableText(
            result.content,
            style: AppTypography.bodyMedium.copyWith(
              color: AppSemanticColors.textSecondary,
            ),
          ),

          if (result.hashtags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.space3),
            Wrap(
              spacing: AppSpacing.space1_5,
              runSpacing: AppSpacing.space1_5,
              children: [
                for (final tag in result.hashtags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space2,
                      vertical: AppSpacing.space0_5,
                    ),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.backgroundTertiary,
                      borderRadius:
                          BorderRadius.circular(AppBorderRadius.full),
                    ),
                    child: Text(
                      tag,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppSemanticColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.space4),
          SizedBox(
            width: double.infinity,
            child: SeedButton(
              label: '전체 복사',
              prefixIcon: Icons.copy_outlined,
              isDisabled: _isGenerating,
              onPressed: () =>
                  _copy(_buildFullText(withTitle: true), '제목·본문·해시태그'),
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          Row(
            children: [
              Expanded(
                child: SeedButton(
                  label: '본문만 복사',
                  variant: SeedButtonVariant.neutralOutline,
                  prefixIcon: Icons.copy_outlined,
                  isDisabled: _isGenerating,
                  onPressed: () =>
                      _copy(_buildFullText(withTitle: false), '본문'),
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              Expanded(
                child: SeedButton(
                  label: '다시 쓰기',
                  variant: SeedButtonVariant.neutralWeak,
                  prefixIcon: Icons.refresh,
                  isLoading: _isGenerating,
                  isDisabled: _isGenerating,
                  onPressed: _generate,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          Text(
            '올리기 전에 내용을 한 번 확인해주세요. 어르신 개인정보가 드러나는 표현이 없는지 살펴보는 것이 좋아요.',
            style: AppTypography.bodySmall.copyWith(
              color: AppSemanticColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
