import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/widgets/chat/chat_photo.dart';

/// 사진이 깨져 와도 앱이 스스로 다시 받게 하는 규칙.
///
/// 앱은 웹보다 나쁜 조건이다 — CachedNetworkImage는 깨진 응답도 **캐시에 저장**해
/// 다음에 열어도 계속 깨진 채로 나온다. 사람이 앱을 지웠다 깔아야 고쳐지는 건
/// 고쳐진 게 아니다. (제보: "종종 사진 깨짐")
///
/// 실제 재다운로드는 위젯 테스트로 증명할 수 없다 — 테스트 환경에는 캐시 매니저가
/// 쓰는 저장소 채널이 없어 이미지가 실패 상태까지 가지 않는다. 그래서 여기서는
/// **판단 규칙과 화면 배선**을 지키고, 사진 자리마다 ChatPhoto를 쓰는지는
/// verify/app-chat-photo.mjs가 따로 본다.
void main() {
  group('다시 받는 횟수', () {
    test('상한까지는 다시 받는다', () {
      for (var attempt = 0; attempt < ChatPhoto.maxAttempts; attempt++) {
        expect(ChatPhoto.shouldRetry(attempt), isTrue, reason: '$attempt번째');
      }
    });

    test('상한을 넘으면 멈춘다 — 무한 재시도로 서버를 두드리지 않는다', () {
      expect(ChatPhoto.shouldRetry(ChatPhoto.maxAttempts), isFalse);
      expect(ChatPhoto.shouldRetry(ChatPhoto.maxAttempts + 5), isFalse);
    });

    test('상한이 터무니없이 크거나 0이 아니다', () {
      expect(ChatPhoto.maxAttempts, greaterThan(1));
      expect(ChatPhoto.maxAttempts, lessThanOrEqualTo(5));
    });
  });

  group('다시 받을 때 위젯을 새로 만든다', () {
    test('시도마다 키가 달라진다 — 키가 같으면 깨진 그림이 그대로 남는다', () {
      const url = 'https://example.com/사진.jpg';
      final keys = List.generate(ChatPhoto.maxAttempts, (i) => ChatPhoto.cacheKeyFor(url, i));
      expect(keys.toSet().length, keys.length);
    });

    test('사진이 다르면 키도 다르다', () {
      expect(
        ChatPhoto.cacheKeyFor('https://a/1.jpg', 0),
        isNot(ChatPhoto.cacheKeyFor('https://a/2.jpg', 0)),
      );
    });
  });

  group('그릴 수 없는 사진', () {
    testWidgets('주소가 없으면 시도하지 않고 안내 그림을 둔다', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: ChatPhoto(imageUrl: null, width: 50, height: 50)),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    });

    testWidgets('빈 주소도 마찬가지다', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: ChatPhoto(imageUrl: '', width: 50, height: 50)),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    });

    testWidgets('부르는 쪽이 준 안내 그림이 있으면 그걸 쓴다 — 자리 크기가 튀지 않게', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ChatPhoto(imageUrl: null, brokenBuilder: (_) => const Text('사진 없음')),
        ),
      ));
      await tester.pump();

      expect(find.text('사진 없음'), findsOneWidget);
    });
  });
}
