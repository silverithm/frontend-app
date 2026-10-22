import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/providers/chat_provider.dart';

/// 채팅 탭 목록은 늘 살아 있고, 알림을 눌러 연 목록이 그 위에 하나 더 뜬다.
/// 위의 목록이 닫힐 때 실시간 구독을 다 끊으면 탭 목록이 새 메시지를 못 받는다.
void main() {
  // ChatProvider는 만들 때 연결 상태(플랫폼 채널)를 듣는다
  TestWidgetsFlutterBinding.ensureInitialized();

  test('목록 화면이 둘 떠 있으면 하나가 닫혀도 실시간 구독은 남는다', () {
    final provider = ChatProvider();

    provider.subscribeToRoomList(); // 채팅 탭
    provider.subscribeToRoomList(); // 알림으로 연 목록
    provider.unsubscribeFromRoomList(); // 알림 목록 닫힘

    expect(provider.isWatchingRoomList, isTrue);

    provider.unsubscribeFromRoomList(); // 탭도 내려감(로그아웃 등)
    expect(provider.isWatchingRoomList, isFalse);
  });

  test('해제가 더 많이 와도 다음 구독은 정상으로 센다', () {
    final provider = ChatProvider();

    provider.unsubscribeFromRoomList();
    provider.subscribeToRoomList();

    expect(provider.isWatchingRoomList, isTrue);
  });

  test('초기화(로그아웃)하면 구독 수도 0', () {
    final provider = ChatProvider();
    provider.subscribeToRoomList();
    provider.subscribeToRoomList();

    provider.reset();

    expect(provider.isWatchingRoomList, isFalse);
  });
}
