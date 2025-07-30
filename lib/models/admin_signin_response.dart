import 'user.dart';
import 'company.dart';
import 'subscription.dart';

class AdminSigninResponse {
  final String userId;
  final String userName;
  final String userEmail;
  final String companyId;
  final String companyName;
  final Location? companyAddress;
  final String companyAddressName;
  final TokenInfo tokenInfo;
  final SubscriptionResponse? subscription;
  final String? customerKey;

  AdminSigninResponse({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.companyId,
    required this.companyName,
    this.companyAddress,
    required this.companyAddressName,
    required this.tokenInfo,
    this.subscription,
    this.customerKey,
  });

  factory AdminSigninResponse.fromJson(Map<String, dynamic> json) {
    return AdminSigninResponse(
      userId: json['userId']?.toString() ?? '',
      userName: json['userName'] ?? '',
      userEmail: json['userEmail'] ?? '',
      companyId: json['companyId']?.toString() ?? '',
      companyName: json['companyName'] ?? '',
      companyAddress: json['companyAddress'] != null
          ? Location.fromJson(json['companyAddress'])
          : null,
      companyAddressName: json['companyAddressName'] ?? '',
      tokenInfo: TokenInfo.fromJson(json['tokenInfo']),
      subscription: json['subscription'] != null
          ? SubscriptionResponse.fromJson(json['subscription'])
          : null,
      customerKey: json['customerKey'],
    );
  }

  /// AdminSigninResponse를 User 객체로 변환
  User toUser() {
    return User(
      id: userId,
      username: userName, // username을 userName 값으로 설정
      email: userEmail, // 관리자 이메일 설정
      name: userName,
      role: 'ADMIN', // 관리자로 명시적 설정
      status: 'active',
      isActive: true,
      createdAt: DateTime.now(),
      company: Company(
        id: companyId,
        name: companyName,
        addressName: companyAddressName,
        companyAddress: companyAddress,
        userEmails: [],
      ),
      tokenInfo: tokenInfo,
    );
  }

  /// 관리자 로그인 응답에서 구독 정보를 Subscription 객체로 변환
  Subscription? toSubscription() {
    if (subscription == null) return null;

    try {
      return Subscription(
        id: subscription!.id,
        companyId: companyId,
        planType: _mapPlanNameToType(subscription!.planName),
        status: _mapStatusToEnum(subscription!.status),
        startDate: DateTime.tryParse(subscription!.startDate),
        endDate: DateTime.tryParse(subscription!.endDate),
        hasUsedFreeSubscription: subscription!.hasUsedFreeSubscription ?? false,
        paymentType: _mapBillingTypeToPaymentType(subscription!.billingType),
        customerKey: customerKey,
      );
    } catch (e) {
      print('[AdminSigninResponse] 구독 정보 변환 실패: $e');
      return null;
    }
  }

  SubscriptionType _mapPlanNameToType(String planName) {
    switch (planName.toUpperCase()) {
      case 'FREE':
      case 'TRIAL':
      case '무료':
        return SubscriptionType.FREE;
      case 'BASIC':
      case '베이직':
        return SubscriptionType.BASIC;
      case 'ENTERPRISE':
      case '엔터프라이즈':
        return SubscriptionType.ENTERPRISE;
      default:
        return SubscriptionType.FREE;
    }
  }

  SubscriptionStatus _mapStatusToEnum(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case '활성':
        return SubscriptionStatus.ACTIVE;
      case 'CANCELLED':
      case '취소됨':
        return SubscriptionStatus.CANCELLED;
      case 'EXPIRED':
      case '만료됨':
        return SubscriptionStatus.EXPIRED;
      case 'INACTIVE':
      case '비활성':
        return SubscriptionStatus.INACTIVE;
      default:
        return SubscriptionStatus.INACTIVE;
    }
  }

  PaymentType _mapBillingTypeToPaymentType(String billingType) {
    switch (billingType.toUpperCase()) {
      case 'MONTHLY':
      case '월간':
        return PaymentType.MONTHLY;
      case 'YEARLY':
      case '연간':
        return PaymentType.YEARLY;
      default:
        return PaymentType.MONTHLY;
    }
  }
}

class SubscriptionResponse {
  final String id;
  final String planName;
  final String billingType;
  final String startDate;
  final String endDate;
  final String status;
  final int amount;
  final bool? hasUsedFreeSubscription;

  SubscriptionResponse({
    required this.id,
    required this.planName,
    required this.billingType,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.amount,
    this.hasUsedFreeSubscription,
  });

  factory SubscriptionResponse.fromJson(Map<String, dynamic> json) {
    return SubscriptionResponse(
      id: json['id']?.toString() ?? '',
      planName: json['planName'] ?? '',
      billingType: json['billingType'] ?? '',
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
      status: json['status'] ?? '',
      amount: json['amount'] ?? 0,
      hasUsedFreeSubscription: json['hasUsedFreeSubscription'],
    );
  }
}