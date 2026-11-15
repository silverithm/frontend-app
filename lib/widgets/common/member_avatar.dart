import 'package:flutter/material.dart';

import '../../services/member_directory.dart';
import '../seed/seed_avatar.dart';

/// 직원 이름 옆 프로필 사진 — 사람 번호로 회사 구성원 사진첩([MemberDirectory])에서 사진을 찾는다.
///
/// 사진이 없거나 못 찾으면 이름 첫 글자 원(SeedAvatar와 같다). 사진 주소를 이미 알면 [imageUrl]을
/// 넘긴다(채팅·내 정보처럼 응답에 사진이 오는 곳). 화면 읽기에는 이름이 옆 글자로 이미 읽히므로
/// 사진은 읽지 않는다.
class MemberAvatar extends StatelessWidget {
  final String name;
  final String? memberId;
  final String? adminId;
  final String? email;
  final String? imageUrl;
  final double size;

  const MemberAvatar({
    super.key,
    required this.name,
    this.memberId,
    this.adminId,
    this.email,
    this.imageUrl,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final known = imageUrl?.trim();
    if (known != null && known.isNotEmpty) return _avatar(known);
    final directory = MemberDirectory.instance;
    return ListenableBuilder(
      listenable: directory,
      builder: (context, _) => _avatar(
        directory.photoFor(
          memberId: memberId,
          adminId: adminId,
          email: email,
          name: name,
        ),
      ),
    );
  }

  Widget _avatar(String? url) => ExcludeSemantics(
    child: SeedAvatar(name: name, imageUrl: url, diameter: size),
  );
}

/// 사진 + 이름 한 덩어리 — 목록 안 '담당 김민지'처럼 사람을 가리키는 짧은 줄.
class MemberNameChip extends StatelessWidget {
  final String name;
  final String? memberId;
  final String? adminId;
  final String? email;

  /// 이름 뒤에 붙는 역할 글자('담당'·'등록' 등) — 이름보다 옅게
  final String? suffix;
  final TextStyle? style;
  final TextStyle? suffixStyle;
  final double avatarSize;

  const MemberNameChip({
    super.key,
    required this.name,
    this.memberId,
    this.adminId,
    this.email,
    this.suffix,
    this.style,
    this.suffixStyle,
    this.avatarSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MemberAvatar(
          name: name,
          memberId: memberId,
          adminId: adminId,
          email: email,
          size: avatarSize,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: name, style: style),
                if (suffix != null)
                  TextSpan(text: ' $suffix', style: suffixStyle ?? style),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
