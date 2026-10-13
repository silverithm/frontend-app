import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/utils/single_flight.dart';

/// 토큰 갱신이 동시에 여러 번 나가지 않는지 — 앱 복귀 때 401이 한꺼번에 와도 갱신은 한 번.
void main() {
  test('동시에 부르면 작업은 한 번만 돌고 모두 같은 결과를 받는다', () async {
    final flight = SingleFlight<int>();
    var calls = 0;
    final gate = Completer<int>();

    final results = Future.wait([
      for (var i = 0; i < 5; i++)
        flight.run(() {
          calls++;
          return gate.future;
        }),
    ]);

    expect(flight.isRunning, isTrue);
    gate.complete(42);
    expect(await results, [42, 42, 42, 42, 42]);
    expect(calls, 1);
    expect(flight.isRunning, isFalse);
  });

  test('끝난 뒤에 부르면 새로 돈다', () async {
    final flight = SingleFlight<int>();
    var calls = 0;
    expect(await flight.run(() async => ++calls), 1);
    expect(await flight.run(() async => ++calls), 2);
  });

  test('작업이 실패해도 다음 호출은 막히지 않는다', () async {
    final flight = SingleFlight<int>();
    await expectLater(flight.run(() async => throw StateError('네트워크')), throwsStateError);
    expect(flight.isRunning, isFalse);
    expect(await flight.run(() async => 7), 7);
  });
}
