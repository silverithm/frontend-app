import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/services/push_navigation_gate.dart';

/// 꺼진 앱을 알림으로 켜면 탭 신호가 로그인 복원보다 먼저 온다. 그때 바로 화면을 띄우면
/// 사용자 정보가 없어 채팅방을 못 찾고 목록에서 멈춘다(2026-10-22). 문지기가 메인 화면이
/// 뜰 때까지 이동을 붙잡아 두는지 못박는다.
void main() {
  late List<Map<String, dynamic>> opened;
  late DateTime now;
  late PushNavigationGate gate;

  setUp(() {
    opened = [];
    now = DateTime(2026, 10, 22, 9);
    gate = PushNavigationGate(opened.add, now: () => now);
  });

  test('메인 화면이 뜨기 전에 누른 알림은 붙잡아 둔다', () {
    gate.handle({'type': 'chat', 'roomId': '191'});

    expect(opened, isEmpty);
    expect(gate.pending, {'type': 'chat', 'roomId': '191'});
  });

  test('메인 화면이 뜨면 붙잡아 둔 이동을 한 번만 한다', () {
    gate.handle({'type': 'chat', 'roomId': '191'});
    gate.open();

    expect(opened, [
      {'type': 'chat', 'roomId': '191'},
    ]);
    expect(gate.pending, isNull);

    // 다시 열려도 같은 이동을 또 하지 않는다
    gate.close();
    gate.open();
    expect(opened, hasLength(1));
  });

  test('열린 뒤 누른 알림은 바로 간다(앱이 떠 있을 때)', () {
    gate.open();
    gate.handle({'type': 'approval', 'requestId': '990'});

    expect(opened, [
      {'type': 'approval', 'requestId': '990'},
    ]);
    expect(gate.pending, isNull);
  });

  test('열리기 전에 여러 번 눌렀으면 마지막 알림 하나로만 간다', () {
    gate.handle({'type': 'chat', 'roomId': '1'});
    gate.handle({'type': 'notice', 'noticeId': '7'});
    gate.open();

    expect(opened, [
      {'type': 'notice', 'noticeId': '7'},
    ]);
  });

  test('로그아웃(닫힘) 뒤 누른 알림은 다시 로그인될 때까지 기다린다', () {
    gate.open();
    gate.close();
    gate.handle({'type': 'work_task', 'taskId': '41'});

    expect(opened, isEmpty);
    gate.open();
    expect(opened, [
      {'type': 'work_task', 'taskId': '41'},
    ]);
  });

  test('메인 화면이 겹쳐 뜨는 순간 — 새 화면이 먼저 열고 옛 화면이 나중에 닫아도 열린 채다', () {
    gate.open(); // 옛 메인 화면
    gate.open(); // 다시 로그인한 새 메인 화면
    gate.close(); // 옛 화면이 내려감

    expect(gate.isOpen, isTrue);
    gate.handle({'type': 'chat', 'roomId': '5'});
    expect(opened, hasLength(1));
  });

  test('닫힘이 열림보다 많이 와도 음수로 내려가지 않는다', () {
    gate.close();
    gate.close();
    gate.open();

    expect(gate.isOpen, isTrue);
  });

  test('너무 오래 붙잡혀 있던 이동은 버린다 — 한참 뒤 로그인했는데 옛 방이 열리지 않게', () {
    gate.handle({'type': 'chat', 'roomId': '191'});
    now = now.add(const Duration(minutes: 11));
    gate.open();

    expect(opened, isEmpty);
    expect(gate.pending, isNull);
  });

  test('기한 안이면 간다', () {
    gate.handle({'type': 'chat', 'roomId': '191'});
    now = now.add(const Duration(minutes: 9));
    gate.open();

    expect(opened, hasLength(1));
  });

  test('붙잡아 둔 data는 복사본이다 — 원본이 바뀌어도 누른 그대로 간다', () {
    final data = <String, dynamic>{'type': 'chat', 'roomId': '191'};
    gate.handle(data);
    data['roomId'] = '999';
    gate.open();

    expect(opened.single['roomId'], '191');
  });
}
