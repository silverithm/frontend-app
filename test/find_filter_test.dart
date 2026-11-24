import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/screens/meeting_minutes_list_screen.dart';
import 'package:frontend_app/widgets/common/app_search_bar.dart';

void main() {
  group('matchesKeyword', () {
    test('빈 검색어는 모두 통과', () {
      expect(matchesKeyword('', ['아무거나']), isTrue);
      expect(matchesKeyword('  ', [null]), isTrue);
    });
    test('여러 칸 중 하나라도 들어 있으면 통과', () {
      expect(matchesKeyword('낙상', ['제목', '낙상 예방 안내']), isTrue);
      expect(matchesKeyword('낙상', ['제목', null]), isFalse);
    });
    test('영문은 대소문자를 가리지 않는다', () {
      expect(matchesKeyword('pdf', ['Manual.PDF']), isTrue);
    });
  });

  group('meetingMonthLabel', () {
    test('날짜에서 년 월 머리글을 만든다', () {
      expect(meetingMonthLabel('2026-11-14T10:00:00'), '2026년 11월');
      expect(meetingMonthLabel('2026-09-01'), '2026년 9월');
    });
    test('읽을 수 없으면 빈 문자열', () {
      expect(meetingMonthLabel(''), '');
      expect(meetingMonthLabel('abcdefg'), '');
    });
  });
}
