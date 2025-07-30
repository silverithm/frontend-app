class Subscription {
  final String? id;
  final String companyId;
  final SubscriptionType planType;
  final SubscriptionStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool hasUsedFreeSubscription;
  final PaymentType? paymentType;
  final String? billingKey;
  final String? customerKey;

  Subscription({
    this.id,
    required this.companyId,
    required this.planType,
    required this.status,
    this.startDate,
    this.endDate,
    this.createdAt,
    this.updatedAt,
    this.hasUsedFreeSubscription = false,
    this.paymentType,
    this.billingKey,
    this.customerKey,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    print('[Subscription.fromJson] 파싱 시작 - 전체 JSON: $json');
    
    // planType 또는 planName 필드 확인
    String? planValue = json['planType']?.toString() ?? json['planName']?.toString();
    print('[Subscription.fromJson] planValue: $planValue');
    
    final planType = planValue != null 
        ? SubscriptionType.fromString(planValue)
        : SubscriptionType.FREE;
    print('[Subscription.fromJson] 최종 planType: ${planType.name}');
    
    // status 필드 확인
    String? statusValue = json['status']?.toString();
    print('[Subscription.fromJson] statusValue: $statusValue');
    
    final status = statusValue != null
        ? SubscriptionStatus.values.firstWhere(
            (e) => e.name.toUpperCase() == statusValue.toUpperCase(),
            orElse: () => SubscriptionStatus.INACTIVE,
          )
        : SubscriptionStatus.INACTIVE;
    print('[Subscription.fromJson] 최종 status: ${status.name}');
    
    return Subscription(
      id: json['id']?.toString(),
      companyId: json['companyId']?.toString() ?? '',
      planType: planType,
      status: status,
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      hasUsedFreeSubscription: json['hasUsedFreeSubscription'] ?? false,
      paymentType: json['paymentType'] != null 
        ? PaymentType.values.firstWhere(
            (e) => e.name.toUpperCase() == json['paymentType'].toString().toUpperCase(),
            orElse: () => PaymentType.MONTHLY,
          )
        : null,
      billingKey: json['billingKey'],
      customerKey: json['customerKey'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'companyId': companyId,
      'planType': planType.name,
      'status': status.name,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'hasUsedFreeSubscription': hasUsedFreeSubscription,
      'paymentType': paymentType?.name,
      'billingKey': billingKey,
      'customerKey': customerKey,
    };
  }

  // 유틸리티 메서드들
  bool get isActive => status == SubscriptionStatus.ACTIVE && 
                      (endDate == null || endDate!.isAfter(DateTime.now()));

  bool get isExpired => endDate != null && endDate!.isBefore(DateTime.now());

  bool get isCancelled => status == SubscriptionStatus.CANCELLED;

  bool get isFree => planType == SubscriptionType.FREE;

  bool get needsPayment => !isActive || isExpired;

  int get daysRemaining {
    if (endDate == null) return 0;
    final now = DateTime.now();
    if (endDate!.isBefore(now)) return 0;
    return endDate!.difference(now).inDays;
  }

  String get planDisplayName {
    switch (planType) {
      case SubscriptionType.FREE:
        return '무료 체험';
      case SubscriptionType.BASIC:
        return 'Basic 플랜';
      case SubscriptionType.ENTERPRISE:
        return 'Enterprise 플랜';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case SubscriptionStatus.ACTIVE:
        return '활성';
      case SubscriptionStatus.CANCELLED:
        return '취소됨';
      case SubscriptionStatus.EXPIRED:
        return '만료됨';
      case SubscriptionStatus.INACTIVE:
        return '비활성';
    }
  }
}

enum SubscriptionType {
  FREE,
  BASIC,
  ENTERPRISE;

  static SubscriptionType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'FREE':
        return SubscriptionType.FREE;
      case 'BASIC':
        return SubscriptionType.BASIC;
      case 'ENTERPRISE':
        return SubscriptionType.ENTERPRISE;
      default:
        return SubscriptionType.FREE;
    }
  }
}

enum SubscriptionStatus {
  ACTIVE,
  CANCELLED,
  EXPIRED,
  INACTIVE,
}

enum PaymentType {
  MONTHLY,
  YEARLY,
}

// 구독 플랜 정보
class SubscriptionPlan {
  final SubscriptionType type;
  final String name;
  final String description;
  final int price;
  final PaymentType paymentType;
  final List<String> features;
  final bool isPopular;

  SubscriptionPlan({
    required this.type,
    required this.name,
    required this.description,
    required this.price,
    required this.paymentType,
    required this.features,
    this.isPopular = false,
  });

  static List<SubscriptionPlan> getAvailablePlans() {
    return [
      SubscriptionPlan(
        type: SubscriptionType.FREE,
        name: '30일 무료 체험',
        description: '모든 기능을 30일간 무료로 사용해보세요',
        price: 0,
        paymentType: PaymentType.MONTHLY,
        features: [
          '모든 기본 기능',
          '직원 관리',
          '휴가 관리',
          '달력 기능',
          '30일 제한',
        ],
      ),
      SubscriptionPlan(
        type: SubscriptionType.BASIC,
        name: 'Basic 플랜',
        description: '소규모 팀을 위한 완벽한 솔루션',
        price: 9900,
        paymentType: PaymentType.MONTHLY,
        features: [
          '무제한 직원 관리',
          '고급 휴가 관리',
          '실시간 알림',
          '데이터 백업',
          '24/7 고객 지원',
        ],
        isPopular: true,
      ),
    ];
  }
}