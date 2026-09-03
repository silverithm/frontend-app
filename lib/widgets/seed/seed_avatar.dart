import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/constants.dart';

/// 당근 Seed 디자인 시스템 — 회원 프로필 아바타.
///
/// 사진 URL이 있으면 원형 네트워크 이미지, 없거나 로드 실패 시
/// 이름 첫 글자 이니셜 + 브랜드 톤 배경으로 대체 표시한다.
/// (cached_network_image 미사용 프로젝트이므로 Image.network + errorBuilder 사용)
enum SeedAvatarSize { small, medium, large }

class SeedAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final SeedAvatarSize size;

  const SeedAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = SeedAvatarSize.medium,
  });

  // 사이즈 프리셋 — small 32 / medium 40 / large 56
  double get _diameter {
    switch (size) {
      case SeedAvatarSize.small:
        return 32;
      case SeedAvatarSize.medium:
        return 40;
      case SeedAvatarSize.large:
        return 56;
    }
  }

  double get _fontSize {
    switch (size) {
      case SeedAvatarSize.small:
        return AppTypography.fontSizeSm;
      case SeedAvatarSize.medium:
        return AppTypography.fontSizeBase;
      case SeedAvatarSize.large:
        return AppTypography.fontSizeXl;
    }
  }

  String get _initial {
    final trimmed = name.trim();
    return trimmed.isNotEmpty ? trimmed.substring(0, 1) : '?';
  }

  /// 상대경로로 내려올 수 있는 이미지 URL을 절대 URL로 변환한다.
  /// (chat fileUrl/thumbnailUrl과 달리 profileImageUrl은 상대경로 가능성이 있어 방어적으로 처리)
  static String resolveImageUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final origin = Constants.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    return trimmed.startsWith('/') ? '$origin$trimmed' : '$origin/$trimmed';
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final diameter = _diameter;

    return Container(
      width: diameter,
      height: diameter,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppSemanticColors.brandWeak,
      ),
      alignment: Alignment.center,
      child: hasImage
          ? Image.network(
              resolveImageUrl(imageUrl!),
              width: diameter,
              height: diameter,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildInitial(),
            )
          : _buildInitial(),
    );
  }

  Widget _buildInitial() {
    return Text(
      _initial,
      style: TextStyle(
        fontSize: _fontSize,
        fontWeight: AppTypography.fontWeightSemibold,
        color: AppSemanticColors.brandPressed,
        height: 1,
      ),
    );
  }
}
