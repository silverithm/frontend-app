import 'user.dart';
import 'company.dart';

class AdminSigninResponse {
  final String userId;
  final String userName;
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
      email: '', // 관리자 응답에는 email이 없으므로 빈 값
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