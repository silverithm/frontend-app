import 'package:flutter/material.dart';

import '../../models/chat_room.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../seed/seed_avatar.dart';

/// 채팅방 목록 아이콘 — 참여자 얼굴을 모아 하나의 원으로 보여준다 (웹과 같은 규칙).
///
/// D3: 3명 이상은 얼굴 3~4개를 한 원에 욱여넣지 않는다 — 칸이 너무 작아져 이니셜이
/// 안 읽혔다. 대신 첫 사람 얼굴 하나 + 나머지 인원수로 보여준다(최대 2칸이라 항상 읽힌다).
///
/// ```
///   1명        2명          3명 이상
///  ┌────┐    ┌──┬──┐    ┌────┬───┐
///  │ 얼 │    │얼│얼│    │ 얼 │+2 │
///  │ 굴 │    │  │  │    │ 굴 │   │
///  └────┘    └──┴──┘    └────┴───┘
/// ```
/// 참여자를 못 받았으면(옛 서버 응답 등) 방 이름 첫 글자로 그린다 — 빈 원을 두지 않는다.
class ChatRoomAvatarStack extends StatelessWidget {
  final String roomName;
  final List<ChatRoomAvatar> avatars;
  final double size;

  const ChatRoomAvatarStack({
    super.key,
    required this.roomName,
    required this.avatars,
    this.size = 48,
  });

  /// 칸 사이 실선 — 얼굴끼리 맞붙으면 한 사람처럼 보인다
  static const double _gap = 1.5;

  @override
  Widget build(BuildContext context) {
    final people = avatars;

    // 한 명·빈 방도 둘 이상인 방과 같은 지름 — SeedAvatar.large(56)를 쓰면 줄마다 크기가 달랐다
    if (people.isEmpty || people.length == 1) {
      final person = people.isEmpty
          ? ChatRoomAvatar(userId: '', userName: roomName)
          : people.first;
      return ClipOval(
        child: SizedBox(width: size, height: size, child: _face(person, single: true)),
      );
    }

    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: AppSemanticColors.borderSubtle,
        child: Row(
          children: [
            Expanded(child: _face(people[0])),
            const SizedBox(width: _gap),
            Expanded(
              child: people.length == 2
                  ? _face(people[1])
                  : _countBadge(people.length - 1),
            ),
          ],
        ),
      ),
    );
  }

  /// 오른쪽 칸 — 첫 사람 외 나머지 인원수("+N")
  Widget _countBadge(int count) {
    return Container(
      color: AppSemanticColors.brandWeak,
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Text(
            '+$count',
            style: AppTypography.labelMedium.copyWith(
              color: AppSemanticColors.textLink,
              fontWeight: AppTypography.fontWeightSemibold,
            ),
          ),
        ),
      ),
    );
  }

  /// 한 칸. 사진이 있으면 칸을 꽉 채우고, 없으면 이름 첫 글자를 브랜드 톤으로 그린다.
  Widget _face(ChatRoomAvatar person, {bool single = false}) {
    final url = (person.profileImageUrl ?? '').trim();
    if (url.isEmpty) {
      return Container(
        color: AppSemanticColors.brandWeak,
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Text(
              person.userName.trim().isNotEmpty
                  ? person.userName.trim().substring(0, 1)
                  : '?',
              // 칸 하나가 원 전체인 한 명 방은 이니셜을 크게, 둘로 나뉜 칸은 작게
              style: (single ? AppTypography.titleMedium : AppTypography.labelMedium).copyWith(
                color: AppSemanticColors.brandPressed,
                fontWeight: AppTypography.fontWeightSemibold,
              ),
            ),
          ),
        ),
      );
    }
    return Image.network(
      SeedAvatar.resolveImageUrl(url),
      fit: BoxFit.cover,
      // 사진이 안 열려도 칸이 비어 보이지 않게 첫 글자로 되돌린다
      errorBuilder: (context, error, stack) => _face(
        ChatRoomAvatar(userId: person.userId, userName: person.userName),
        single: single,
      ),
    );
  }
}
