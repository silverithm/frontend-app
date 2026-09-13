import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/utils/chat_date_jump.dart';

void main() {
  group('formatChatDateQuery', () {
    test('YYYY-MM-DD로 0-패딩한다', () {
      expect(formatChatDateQuery(DateTime(2026, 9, 14)), '2026-09-14');
    });

    test('월/일이 한 자리여도 두 자리로 맞춘다', () {
      expect(formatChatDateQuery(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });

  group('shouldKeepLoadingForDateJump', () {
    test('이미 찾았으면 더 받지 않는다', () {
      expect(
        shouldKeepLoadingForDateJump(
          found: true,
          hasMore: true,
          triesSoFar: 0,
        ),
        isFalse,
      );
    });

    test('더 받을 옛 대화가 없으면 멈춘다', () {
      expect(
        shouldKeepLoadingForDateJump(
          found: false,
          hasMore: false,
          triesSoFar: 0,
        ),
        isFalse,
      );
    });

    test('상한에 닿으면 멈춘다', () {
      expect(
        shouldKeepLoadingForDateJump(
          found: false,
          hasMore: true,
          triesSoFar: chatDateJumpMaxLoadTries,
          maxTries: chatDateJumpMaxLoadTries,
        ),
        isFalse,
      );
    });

    test('상한 전이고 더 받을 게 있으면 계속 받는다', () {
      expect(
        shouldKeepLoadingForDateJump(
          found: false,
          hasMore: true,
          triesSoFar: chatDateJumpMaxLoadTries - 1,
          maxTries: chatDateJumpMaxLoadTries,
        ),
        isTrue,
      );
    });

    test('날짜 이동 상한은 답장 이동(5쪽)보다 넉넉하다', () {
      expect(chatDateJumpMaxLoadTries, greaterThan(5));
    });
  });
}
