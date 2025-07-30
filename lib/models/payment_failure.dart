import 'subscription.dart';

class PaymentFailure {
  final int id;
  final int subscriptionId;
  final PaymentFailureReason failureReason;
  final String failureReasonDescription;
  final String failureMessage;
  final int attemptedAmount;
  final SubscriptionType subscriptionType;
  final SubscriptionBillingType billingType;
  final DateTime failedAt;

  PaymentFailure({
    required this.id,
    required this.subscriptionId,
    required this.failureReason,
    required this.failureReasonDescription,
    required this.failureMessage,
    required this.attemptedAmount,
    required this.subscriptionType,
    required this.billingType,
    required this.failedAt,
  });

  factory PaymentFailure.fromJson(Map<String, dynamic> json) {
    return PaymentFailure(
      id: json['id'] ?? 0,
      subscriptionId: json['subscriptionId'] ?? 0,
      failureReason: PaymentFailureReason.fromString(json['failureReason']?.toString() ?? 'OTHER'),
      failureReasonDescription: json['failureReasonDescription']?.toString() ?? '',
      failureMessage: json['failureMessage']?.toString() ?? '',
      attemptedAmount: json['attemptedAmount'] ?? 0,
      subscriptionType: SubscriptionType.fromString(json['subscriptionType']?.toString() ?? 'FREE'),
      billingType: SubscriptionBillingType.fromString(json['billingType']?.toString() ?? 'MONTHLY'),
      failedAt: json['failedAt'] != null ? DateTime.parse(json['failedAt']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subscriptionId': subscriptionId,
      'failureReason': failureReason.name,
      'failureReasonDescription': failureReasonDescription,
      'failureMessage': failureMessage,
      'attemptedAmount': attemptedAmount,
      'subscriptionType': subscriptionType.name,
      'billingType': billingType.name,
      'failedAt': failedAt.toIso8601String(),
    };
  }

  // 실패 사유 한국어 설명
  String get failureReasonKorean {
    switch (failureReason) {
      case PaymentFailureReason.cardExpired:
        return '카드 만료';
      case PaymentFailureReason.insufficientFunds:
        return '잔액 부족';
      case PaymentFailureReason.cardDeclined:
        return '카드 거절';
      case PaymentFailureReason.invalidCard:
        return '유효하지 않은 카드';
      case PaymentFailureReason.networkError:
        return '네트워크 오류';
      case PaymentFailureReason.systemError:
        return '시스템 오류';
      case PaymentFailureReason.other:
        return '기타 오류';
    }
  }

  // 금액을 원화 형식으로 변환
  String get formattedAmount {
    return '${attemptedAmount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}원';
  }

  // 실패 날짜를 한국어 형식으로 변환
  String get formattedFailedAt {
    return '${failedAt.year}년 ${failedAt.month}월 ${failedAt.day}일 ${failedAt.hour.toString().padLeft(2, '0')}:${failedAt.minute.toString().padLeft(2, '0')}';
  }
}

enum PaymentFailureReason {
  cardExpired,
  insufficientFunds,
  cardDeclined,
  invalidCard,
  networkError,
  systemError,
  other;

  static PaymentFailureReason fromString(String value) {
    switch (value.toUpperCase()) {
      case 'CARD_EXPIRED':
        return PaymentFailureReason.cardExpired;
      case 'INSUFFICIENT_FUNDS':
        return PaymentFailureReason.insufficientFunds;
      case 'CARD_DECLINED':
        return PaymentFailureReason.cardDeclined;
      case 'INVALID_CARD':
        return PaymentFailureReason.invalidCard;
      case 'NETWORK_ERROR':
        return PaymentFailureReason.networkError;
      case 'SYSTEM_ERROR':
        return PaymentFailureReason.systemError;
      case 'OTHER':
      default:
        return PaymentFailureReason.other;
    }
  }

  String get name {
    switch (this) {
      case PaymentFailureReason.cardExpired:
        return 'CARD_EXPIRED';
      case PaymentFailureReason.insufficientFunds:
        return 'INSUFFICIENT_FUNDS';
      case PaymentFailureReason.cardDeclined:
        return 'CARD_DECLINED';
      case PaymentFailureReason.invalidCard:
        return 'INVALID_CARD';
      case PaymentFailureReason.networkError:
        return 'NETWORK_ERROR';
      case PaymentFailureReason.systemError:
        return 'SYSTEM_ERROR';
      case PaymentFailureReason.other:
        return 'OTHER';
    }
  }
}

enum SubscriptionBillingType {
  monthly,
  yearly;

  static SubscriptionBillingType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'MONTHLY':
        return SubscriptionBillingType.monthly;
      case 'YEARLY':
        return SubscriptionBillingType.yearly;
      default:
        return SubscriptionBillingType.monthly;
    }
  }

  String get name {
    switch (this) {
      case SubscriptionBillingType.monthly:
        return 'MONTHLY';
      case SubscriptionBillingType.yearly:
        return 'YEARLY';
    }
  }

  String get displayName {
    switch (this) {
      case SubscriptionBillingType.monthly:
        return '월간';
      case SubscriptionBillingType.yearly:
        return '연간';
    }
  }
}

class PaymentFailurePage {
  final List<PaymentFailure> content;
  final Pageable pageable;
  final bool last;
  final int totalPages;
  final int totalElements;
  final int size;
  final int number;
  final Sort sort;
  final bool first;
  final int numberOfElements;
  final bool empty;

  PaymentFailurePage({
    required this.content,
    required this.pageable,
    required this.last,
    required this.totalPages,
    required this.totalElements,
    required this.size,
    required this.number,
    required this.sort,
    required this.first,
    required this.numberOfElements,
    required this.empty,
  });

  factory PaymentFailurePage.fromJson(Map<String, dynamic> json) {
    return PaymentFailurePage(
      content: (json['content'] as List<dynamic>? ?? [])
          .map((item) => PaymentFailure.fromJson(item as Map<String, dynamic>))
          .toList(),
      pageable: Pageable.fromJson(json['pageable'] as Map<String, dynamic>? ?? {}),
      last: json['last'] ?? true,
      totalPages: json['totalPages'] ?? 0,
      totalElements: json['totalElements'] ?? 0,
      size: json['size'] ?? 0,
      number: json['number'] ?? 0,
      sort: Sort.fromJson(json['sort'] as Map<String, dynamic>? ?? {}),
      first: json['first'] ?? true,
      numberOfElements: json['numberOfElements'] ?? 0,
      empty: json['empty'] ?? true,
    );
  }
}

class Pageable {
  final int pageNumber;
  final int pageSize;
  final Sort sort;
  final int offset;
  final bool paged;
  final bool unpaged;

  Pageable({
    required this.pageNumber,
    required this.pageSize,
    required this.sort,
    required this.offset,
    required this.paged,
    required this.unpaged,
  });

  factory Pageable.fromJson(Map<String, dynamic> json) {
    return Pageable(
      pageNumber: json['pageNumber'] ?? 0,
      pageSize: json['pageSize'] ?? 10,
      sort: Sort.fromJson(json['sort'] as Map<String, dynamic>? ?? {}),
      offset: json['offset'] ?? 0,
      paged: json['paged'] ?? true,
      unpaged: json['unpaged'] ?? false,
    );
  }
}

class Sort {
  final bool empty;
  final bool sorted;
  final bool unsorted;

  Sort({
    required this.empty,
    required this.sorted,
    required this.unsorted,
  });

  factory Sort.fromJson(Map<String, dynamic> json) {
    return Sort(
      empty: json['empty'] ?? true,
      sorted: json['sorted'] ?? false,
      unsorted: json['unsorted'] ?? true,
    );
  }
}