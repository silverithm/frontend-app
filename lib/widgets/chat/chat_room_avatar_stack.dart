import 'package:flutter/material.dart';

import '../../models/chat_room.dart';
import '../../theme/app_colors.dart';
import '../seed/seed_avatar.dart';

/// 채팅방 목록 아이콘 — 참여자 얼굴을 모아 하나의 원으로 보여준다 (카카오톡과 같은 방식).
///
/// 사람 수에 따라 칸을 다르게 나눈다. 넷을 넘으면 앞의 넷만 보여준다 —
/// 더 넣으면 한 칸이 너무 작아져 누가 누군지 알아볼 수 없다.
///
/// ```
///   1명        2명          3명            4명 이상
///  ┌────┐    ┌──┬──┐    ┌────┬───┐     ┌──┬──┐
///  │ 얼 │    │얼│얼│    │ 얼 ├───┤     │얼│얼│
///  │ 굴 │    │  │  │    │    │얼 │     ├──┼──┤
///  └────┘    └──┴──┘    └────┴───┘     │얼│얼│
///                                       └──┴──┘
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
    this.size = 56,
  });

  /// 칸 사이 실선 — 얼굴끼리 맞붙으면 한 사람처럼 보인다
  static const double _gap = 1.5;

  @override
  Widget build(BuildContext context) {
    final people = avatars.take(4).toList();

    if (people.isEmpty) {
      return SeedAvatar(name: roomName, size: SeedAvatarSize.large);
    }
    if (people.length == 1) {
      return SeedAvatar(
        name: people.first.userName,
        imageUrl: people.first.profileImageUrl,
        size: SeedAvatarSize.large,
      );
    }

    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: AppSemanticColors.borderSubtle,
        child: _grid(people),
      ),
    );
  }

  Widget _grid(List<ChatRoomAvatar> people) {
    switch (people.length) {
      case 2:
        // 세로로 반씩 — 둘이 나란히 서 있는 모양
        return Row(
          children: [
            Expanded(child: _face(people[0])),
            const SizedBox(width: _gap),
            Expanded(child: _face(people[1])),
          ],
        );
      case 3:
        // 왼쪽 한 명이 크게, 오른쪽에 둘이 위아래로
        return Row(
          children: [
            Expanded(child: _face(people[0])),
            const SizedBox(width: _gap),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _face(people[1])),
                  const SizedBox(height: _gap),
                  Expanded(child: _face(people[2])),
                ],
              ),
            ),
          ],
        );
      default:
        // 넷은 2×2
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _face(people[0])),
                  const SizedBox(width: _gap),
                  Expanded(child: _face(people[1])),
                ],
              ),
            ),
            const SizedBox(height: _gap),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _face(people[2])),
                  const SizedBox(width: _gap),
                  Expanded(child: _face(people[3])),
                ],
              ),
            ),
          ],
        );
    }
  }

  /// 한 칸. 사진이 있으면 칸을 꽉 채우고, 없으면 이름 첫 글자를 브랜드 톤으로 그린다.
  Widget _face(ChatRoomAvatar person) {
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
              style: TextStyle(
                color: AppSemanticColors.brandPressed,
                fontWeight: FontWeight.w600,
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
      ),
    );
  }
}
