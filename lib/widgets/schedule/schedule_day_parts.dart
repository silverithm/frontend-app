import 'package:flutter/material.dart';

import '../../models/schedule.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/member_avatar.dart';

/// 일정 분류 꼬리표 — 분류 색을 옅게 깐 바탕 + 같은 색을 어둡게 한 글자.
///
/// 예전엔 진한 분류색 바탕에 흰 글자(분홍 알약)라 제목보다 먼저 눈에 들어왔다. 분류는 보조 정보라
/// 한 단계 낮춘다. 글자색은 분류색의 밝기를 낮춰 옅은 바탕 위에서 4.5:1을 넘게 한다.
class ScheduleCategoryTag extends StatelessWidget {
  final String label;
  final Color color;

  const ScheduleCategoryTag({
    super.key,
    required this.label,
    required this.color,
  });

  static Color foregroundOf(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness * 0.55).clamp(0.18, 0.32))
        .withSaturation((hsl.saturation * 0.9).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: AppTypography.labelStrong.copyWith(color: foregroundOf(color)),
      ),
    );
  }
}

/// 참석자 — 사진을 조금씩 겹쳐 최대 넷, 그 뒤에 '참석 6명'.
class ScheduleParticipantStack extends StatelessWidget {
  final List<ScheduleParticipant> participants;
  final TextStyle nameStyle;
  final TextStyle roleStyle;

  const ScheduleParticipantStack({
    super.key,
    required this.participants,
    required this.nameStyle,
    required this.roleStyle,
  });

  static const double _size = 22;
  static const double _step = 15;
  static const int _maxFaces = 4;

  @override
  Widget build(BuildContext context) {
    final faces = participants.take(_maxFaces).toList();
    final names = participants.map((p) => p.memberName.trim()).join(', ');
    return Semantics(
      label: '참석 ${participants.length}명: $names',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _size + _step * (faces.length - 1),
            height: _size,
            child: Stack(
              children: [
                for (var i = 0; i < faces.length; i++)
                  Positioned(
                    left: _step * i,
                    child: Container(
                      // 겹친 사진 사이가 갈리도록 흰 테두리
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppSemanticColors.surfaceCard,
                      ),
                      padding: const EdgeInsets.all(1.5),
                      child: MemberAvatar(
                        name: faces[i].memberName,
                        memberId: faces[i].memberId,
                        size: _size - 3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '참석 ', style: roleStyle),
                TextSpan(text: '${participants.length}명', style: nameStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
