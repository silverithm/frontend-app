import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/providers/schedule_provider.dart';

/// 홈 '오늘' 칸 → 일정 탭으로 "이 일정을 열어 달라"는 요청 규약.
/// 일정 탭은 요청을 한 번만 받아 처리해야 한다 — 남아 있으면 탭을 다시 열 때마다
/// 같은 날짜로 끌려간다.
void main() {
  test('요청하면 듣는 쪽에 알리고, 꺼내면 날짜만 남긴 채 한 번만 돌려준다', () {
    final provider = ScheduleProvider();
    var notified = 0;
    provider.addListener(() => notified++);

    provider.requestFocus(
      scheduleId: 42,
      date: DateTime(2026, 10, 4, 15, 30),
    );

    expect(notified, 1);
    final request = provider.takeFocusRequest();
    expect(request, isNotNull);
    expect(request!.scheduleId, 42);
    expect(request.date, DateTime(2026, 10, 4));
    expect(provider.takeFocusRequest(), isNull);
  });

  test('요청이 없으면 null', () {
    expect(ScheduleProvider().takeFocusRequest(), isNull);
  });
}
