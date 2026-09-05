import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_app/models/subscription.dart';

// 결제도 되어 있고 기간도 남았는데 앱을 켜면 결제 화면이 뜨던 문제를 막는 테스트.
// 접근 판정은 isActive(ACTIVE만 인정)가 아니라 isUsable을 쓴다.
Subscription _sub(SubscriptionStatus status, DateTime endDate) => Subscription(
      companyId: '1',
      planType: SubscriptionType.BASIC,
      status: status,
      endDate: endDate,
    );

void main() {
  final future = DateTime.now().add(const Duration(days: 200));
  final past = DateTime.now().subtract(const Duration(days: 1));

  group('구독 사용 가능 판정', () {
    test('결제된 구독은 기간이 남아 있으면 쓸 수 있다', () {
      expect(_sub(SubscriptionStatus.ACTIVE, future).isUsable, isTrue);
    });

    test('해지를 눌렀어도 남은 기간에는 쓸 수 있다', () {
      // 서버는 해지 시 status만 CANCELLED로 바꾸고 endDate는 그대로 둔다.
      expect(_sub(SubscriptionStatus.CANCELLED, future).isUsable, isTrue);
    });

    test('기간이 지난 구독은 쓸 수 없다', () {
      expect(_sub(SubscriptionStatus.ACTIVE, past).isUsable, isFalse);
      expect(_sub(SubscriptionStatus.CANCELLED, past).isUsable, isFalse);
    });

    test('만료·비활성 구독은 기간과 무관하게 쓸 수 없다', () {
      expect(_sub(SubscriptionStatus.EXPIRED, future).isUsable, isFalse);
      expect(_sub(SubscriptionStatus.INACTIVE, future).isUsable, isFalse);
    });
  });
}
