import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/admin_signin_response.dart';

/// 관리자 프로필 사진이 앱까지 오는가.
///
/// 앱은 로그인 응답만 보고 사람을 그리는데 그 응답에 사진 칸이 아예 없어서,
/// 웹에서 사진을 올려도 앱에서는 관리자만 늘 이니셜이었다
/// ("프로필 사진 업데이트가 반영 안 되네, 관리자 프로필이 뜨게 웹앱모두").
void main() {
  Map<String, dynamic> signinJson({String? profileImageUrl}) => {
        'userId': 3,
        'userName': '김도형',
        'userEmail': 'test@carev.kr',
        'companyId': 4,
        'companyName': '숲속어르신학교',
        'companyAddressName': '서울시',
        'companyCode': 'ABCD',
        'tokenInfo': {'accessToken': 'a', 'refreshToken': 'r'},
        if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      };

  const photoUrl =
      'https://dearglobe.s3.ap-northeast-2.amazonaws.com/carev/profiles/cae15feb.jpg';

  test('로그인 응답의 프로필 사진이 사용자에게까지 실린다', () {
    final user = AdminSigninResponse.fromJson(signinJson(profileImageUrl: photoUrl)).toUser();

    expect(user.profileImageUrl, photoUrl);
  });

  test('사진을 올리지 않은 관리자는 null이다 — 화면은 이니셜로 그린다', () {
    final user = AdminSigninResponse.fromJson(signinJson()).toUser();

    expect(user.profileImageUrl, isNull);
  });

  test('관리자 계정 표식은 그대로 유지된다 — 채팅 식별자가 여기에 걸려 있다', () {
    final user = AdminSigninResponse.fromJson(signinJson(profileImageUrl: photoUrl)).toUser();

    expect(user.isAdminAccount, isTrue);
    expect(user.id, '3');
  });
}
