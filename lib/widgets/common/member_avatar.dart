import 'package:flutter/material.dart';

import '../../services/member_directory.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
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

  /// 화면마다 다른 사람 번호 표기를 받는다 — 'admin_3'(채팅·업무·결재), ('ADMIN', '3'),
  /// ('MEMBER', '12'), 그냥 '12'. 종류를 모르는 숫자는 직원 번호로 보고 이름으로 확인한다.
  factory MemberAvatar.ref({
    Key? key,
    required String name,
    String? id,
    String? type,
    String? imageUrl,
    double size = 40,
  }) {
    final ref = PersonRef.parse(id, type: type);
    return MemberAvatar(
      key: key,
      name: name,
      memberId: ref.memberId,
      adminId: ref.adminId,
      imageUrl: imageUrl,
      size: size,
    );
  }

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

/// 사람 번호 하나 → (직원 번호, 시설장 번호). 둘 다 null이면 이름으로만 찾는다.
class PersonRef {
  final String? memberId;
  final String? adminId;
  const PersonRef({this.memberId, this.adminId});

  static PersonRef parse(String? id, {String? type}) {
    final raw = id?.trim() ?? '';
    if (raw.isEmpty) return const PersonRef();
    final kind = type?.trim().toUpperCase();
    if (raw.startsWith('admin_')) {
      return PersonRef(adminId: raw.substring('admin_'.length));
    }
    if (kind == 'ADMIN' || kind == 'FACILITY_ADMIN')
      return PersonRef(adminId: raw);
    // 외부 참석자 등 사람 번호가 아닌 것
    if (kind != null && kind.isNotEmpty && kind != 'MEMBER') {
      return const PersonRef();
    }
    return PersonRef(memberId: raw);
  }
}

/// 사람 한 명 — 사진 겹침 줄([MemberFaces])에 넘기는 값.
class MemberFace {
  final String name;
  final String? id;
  final String? type;
  final String? imageUrl;
  const MemberFace(this.name, {this.id, this.type, this.imageUrl});
}

/// 사진을 조금씩 겹쳐 [max]명까지, 넘치면 '+n' 원. 이름은 옆 글자로 따로 읽힌다고 보고 그림만 그린다.
class MemberFaces extends StatelessWidget {
  final List<MemberFace> people;
  final double size;
  final int max;

  /// 겹친 사진 사이 흰 테두리 색(놓인 바탕색)
  final Color ringColor;

  const MemberFaces({
    super.key,
    required this.people,
    this.size = 24,
    this.max = 3,
    this.ringColor = AppSemanticColors.surfaceCard,
  });

  @override
  Widget build(BuildContext context) {
    final shown = people.take(max).toList();
    final more = people.length - shown.length;
    final step = size * 0.68;
    final count = shown.length + (more > 0 ? 1 : 0);
    if (count == 0) return const SizedBox.shrink();
    Widget ring(Widget child) => Container(
      decoration: BoxDecoration(shape: BoxShape.circle, color: ringColor),
      padding: const EdgeInsets.all(1.5),
      child: child,
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: size + step * (count - 1),
        height: size,
        child: Stack(
          children: [
            for (var i = 0; i < shown.length; i++)
              Positioned(
                left: step * i,
                child: ring(
                  MemberAvatar.ref(
                    name: shown[i].name,
                    id: shown[i].id,
                    type: shown[i].type,
                    imageUrl: shown[i].imageUrl,
                    size: size - 3,
                  ),
                ),
              ),
            if (more > 0)
              Positioned(
                left: step * shown.length,
                child: ring(
                  Container(
                    width: size - 3,
                    height: size - 3,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppSemanticColors.fillDefault,
                    ),
                    child: Text(
                      '+$more',
                      style: TextStyle(
                        fontSize: (size * 0.38).clamp(9, 14).toDouble(),
                        fontWeight: AppTypography.fontWeightBold,
                        color: AppSemanticColors.textSecondary,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 사진 오른쪽 아래 작은 상태 표시(서명 완료 체크 등). [icon]이 없으면 사진만.
class BadgedAvatar extends StatelessWidget {
  final Widget avatar;
  final IconData? icon;
  final Color color;

  /// 표시가 없을 때 사진을 흐리게(아직 안 한 사람)
  final bool dim;

  const BadgedAvatar({
    super.key,
    required this.avatar,
    this.icon,
    this.color = AppSemanticColors.brandDefault,
    this.dim = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        dim ? Opacity(opacity: 0.45, child: avatar) : avatar,
        if (icon != null)
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                  color: AppSemanticColors.surfaceCard,
                  width: 2,
                ),
              ),
              child: Icon(icon, size: 11, color: AppSemanticColors.textInverse),
            ),
          ),
      ],
    );
  }
}
