import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/widgets/chat/chat_image_viewer.dart';

/// 크게 보기에서 긴 세로 이미지를 폭에 맞춰 훑어보게 할지 정하는 규칙.
///
/// 공문을 한 장짜리 긴 JPG로 공유하게 되면서, 화면에 통째로 맞추면 1214×13817 공문이
/// 폭 49px 막대가 되어 읽을 수 없었다.
void main() {
  test('공문 전체를 한 장으로 올린 긴 이미지는 훑어보기 모드', () {
    expect(isTallChatImage(1214, 13817), isTrue);
    expect(isTallChatImage(1588, 6800), isTrue); // 3쪽 분량
  });

  test('휴대폰 화면 캡처나 일반 사진은 지금처럼 화면에 맞춘다', () {
    expect(isTallChatImage(1080, 2340), isFalse); // 19.5:9 캡처
    expect(isTallChatImage(1080, 2400), isFalse); // 20:9 캡처
    expect(isTallChatImage(3024, 4032), isFalse); // 세로 사진
    expect(isTallChatImage(4032, 3024), isFalse); // 가로 사진
  });

  test('크기를 모르면 일반 사진으로 본다', () {
    expect(isTallChatImage(0, 0), isFalse);
    expect(isTallChatImage(0, 1000), isFalse);
  });
}
