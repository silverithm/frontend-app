import 'subscription.dart';

class UserInfo {
  final int userId;
  final String userName;
  final String userEmail;
  final int companyId;
  final String companyName;
  final Location? companyAddress;
  final String companyAddressName;
  final Subscription? subscription;
  final String customerKey;

  UserInfo({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.companyId,
    required this.companyName,
    this.companyAddress,
    required this.companyAddressName,
    this.subscription,
    required this.customerKey,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    print('[UserInfo.fromJson] 파싱 시작 - 전체 JSON: $json');
    
    return UserInfo(
      userId: json['userId'] ?? 0,
      userName: json['userName']?.toString() ?? '',
      userEmail: json['userEmail']?.toString() ?? '',
      companyId: json['companyId'] ?? 0,
      companyName: json['companyName']?.toString() ?? '',
      companyAddress: json['companyAddress'] != null 
          ? Location.fromJson(json['companyAddress'] as Map<String, dynamic>)
          : null,
      companyAddressName: json['companyAddressName']?.toString() ?? '',
      subscription: json['subscription'] != null
          ? Subscription.fromJson(json['subscription'] as Map<String, dynamic>)
          : null,
      customerKey: json['customerKey']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'companyId': companyId,
      'companyName': companyName,
      'companyAddress': companyAddress?.toJson(),
      'companyAddressName': companyAddressName,
      'subscription': subscription?.toJson(),
      'customerKey': customerKey,
    };
  }

  // 기존 User 모델과의 호환성을 위한 변환 메서드
  Map<String, dynamic> toLegacyUserData() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'companyId': companyId,
      'companyName': companyName,
      'companyAddress': companyAddress?.toString() ?? '',
      'companyAddressName': companyAddressName,
      'customerKey': customerKey,
      'subscription': subscription?.toJson(),
    };
  }
}

class Location {
  final String? address;
  final double? latitude;
  final double? longitude;

  Location({
    this.address,
    this.latitude,
    this.longitude,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      address: json['address']?.toString(),
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  @override
  String toString() {
    return address ?? '';
  }
}