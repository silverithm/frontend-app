import 'package:flutter/material.dart';

import '../../models/chat_room.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../seed/seed_avatar.dart';

/// 채팅방 목록 아이콘 — 참여자 얼굴을 한 원에 나눠 담는다 (카카오톡과 같은 방식, 웹과 같은 규칙).
///
/// 한동안 '첫 사람 얼굴 + 나머지 인원수'로 줄였는데, 단체방이 다 비슷해 보여 어느 방인지
/// 얼굴로 찾을 수 없었다. 사용자 요청(2026-11-03 "카톡처럼 4명 잘라서")으로 되돌린다.
/// 넷을 넘으면 앞의 넷만 — 더 넣으면 한 칸이 너무 작아져 누가 누군지 알아볼 수 없다.
///
/// ```
///   1명        2명          3명            4명 이상
///  ┌────┐    ┌──┬──┐    ┌────┬───┐     ┌──┬──┐
///  │ 얼 │    │얼│얼│    │ 얼 ├───┤     │얼│얼│
///  │ 굴 │    │  │  │    │    │얼 │     ├──┼──┤
///  └────┘    └──┴──┘    └────┴───┘     │얼│얼│
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

  /// 칸 사이 흰 선 — 얼굴끼리 맞붙으면 한 사람처럼 보인다
  static const double _gap = 1.5;

  @override
  Widget build(BuildContext context) {
    final people = avatars.take(4).toList();

    // 한 명·빈 방도 둘 이상인 방과 같은 지름 — SeedAvatar.large(56)를 쓰면 줄마다 크기가 달랐다
    if (people.length <= 1) {
      final person = people.isEmpty
          ? ChatRoomAvatar(userId: '', userName: roomName)
          : people.first;
      return ClipOval(
        child: SizedBox(width: size, height: size, child: _cell(person, 0, _CellSize.whole)),
      );
    }

    final Widget body;
    if (people.length == 2) {
      body = Row(children: [
        Expanded(child: _cell(people[0], 0, _CellSize.half)),
        const SizedBox(width: _gap),
        Expanded(child: _cell(people[1], 1, _CellSize.half)),
      ]);
    } else if (people.length == 3) {
      body = Row(children: [
        Expanded(child: _cell(people[0], 0, _CellSize.half)),
        const SizedBox(width: _gap),
        Expanded(
          child: Column(children: [
            Expanded(child: _cell(people[1], 1, _CellSize.quarter)),
            const SizedBox(height: _gap),
            Expanded(child: _cell(people[2], 2, _CellSize.quarter)),
          ]),
        ),
      ]);
    } else {
      Widget pair(int a, int b) => Expanded(
            child: Row(children: [
              Expanded(child: _cell(people[a], a, _CellSize.quarter)),
              const SizedBox(width: _gap),
              Expanded(child: _cell(people[b], b, _CellSize.quarter)),
            ]),
          );
      body = Column(children: [pair(0, 1), const SizedBox(height: _gap), pair(2, 3)]);
    }

    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: AppSemanticColors.surfaceDefault,
        child: body,
      ),
    );
  }

  /// 한 칸. 사진이 있으면 칸을 꽉 채우고, 없으면 이름 첫 글자를 브랜드 톤으로 그린다.
  Widget _cell(ChatRoomAvatar person, int index, _CellSize cellSize) {
    final url = (person.profileImageUrl ?? '').trim();
    final key = ValueKey('chat-room-avatar-cell-$index');
    if (url.isEmpty) return _initial(person, cellSize, key);
    return SizedBox.expand(
      key: key,
      child: Image.network(
        SeedAvatar.resolveImageUrl(url),
        fit: BoxFit.cover,
        // 사진이 안 열려도 칸이 비어 보이지 않게 첫 글자로 되돌린다
        errorBuilder: (context, error, stack) => _initial(person, cellSize, null),
      ),
    );
  }

  Widget _initial(ChatRoomAvatar person, _CellSize cellSize, Key? key) {
    final name = person.userName.trim();
    // 칸이 작을수록 글자도 한 단계씩 작게 — 원 전체인 한 명 방은 크게
    final style = switch (cellSize) {
      _CellSize.whole => AppTypography.titleMedium,
      _CellSize.half => AppTypography.labelMedium,
      _CellSize.quarter => AppTypography.labelSmall,
    };
    return Container(
      key: key,
      color: AppSemanticColors.brandWeak,
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: Text(
            name.isNotEmpty ? name.substring(0, 1) : '?',
            style: style.copyWith(
              color: AppSemanticColors.brandPressed,
              fontWeight: AppTypography.fontWeightSemibold,
            ),
          ),
        ),
      ),
    );
  }
}

enum _CellSize { whole, half, quarter }
