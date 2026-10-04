import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/utils/share_file.dart';

/// 사진 공유 시 받는 앱에 보일 파일 이름 — 원래 이름을 살리되 파일 이름에 못 쓰는 글자만 바꾼다.
void main() {
  test('원래 이름은 그대로 둔다', () {
    expect(safeShareFileName('프로그램 사진.jpg'), '프로그램 사진.jpg');
  });

  test('경로·특수 글자는 밑줄로 바꾼다', () {
    expect(safeShareFileName('a/b:c*d?.png'), 'a_b_c_d_.png');
  });

  test('이름이 비어 있으면 기본 이름을 쓴다', () {
    expect(safeShareFileName('   '), 'image.jpg');
  });
}
