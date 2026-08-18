import 'company.dart';

class User {
  final String id;
  final String email;
  final String name;
  final String role; // 'CAREGIVER', 'OFFICE', 'admin'

  /// 관리자 계정(app_user) 로그인인지.
  ///
  /// role만으로는 판별할 수 없다 — 직원(members) 중에도 role이 ADMIN인 사람이 있고,
  /// 그 사람의 id는 직원 id다. 채팅 식별자 규약(관리자만 admin_ 접두사)에 이 구분이 필요하다.
  final bool isAdminAccount;
  final String? profileImage;
  final String? profileImageUrl;
  final DateTime createdAt;
  final bool isActive;

  // 새로 추가된 필드들
  final String username;
  final String status;
  final String? department;
  final String? position;
  final Company? company;
  final DateTime? lastLoginAt;
  final TokenInfo? tokenInfo;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.profileImage,
    this.profileImageUrl,
    required this.createdAt,
    this.isActive = true,
    required this.username,
    this.status = 'active',
    this.department,
    this.position,
    this.company,
    this.lastLoginAt,
    this.tokenInfo,
    this.isAdminAccount = false,
  });

  /// 채팅에서 나를 가리키는 값.
  ///
  /// 관리자 계정과 직원은 다른 표라 id가 겹치므로, 서버·웹과 같은 규약으로 관리자 계정에만
  /// 'admin_' 접두사를 붙인다. 서버가 내려주는 senderId/userId와 이 값을 비교해야
  /// 내 메시지·내 참가자 행을 제대로 알아본다 — 원시 id로 비교하면 관리자의 메시지가
  /// 남의 것처럼 보인다(실제 사고).
  String get chatUserId => isAdminAccount ? 'admin_$id' : id;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'CAREGIVER',
      status: json['status'] ?? 'active',
      department: json['department'],
      position: json['position'],
      profileImage: json['profileImage'],
      profileImageUrl: json['profileImageUrl']?.toString(),
      company: json['company'] != null
          ? Company.fromJson(json['company'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.tryParse(json['lastLoginAt'])
          : null,
      isActive: json['isActive'] ?? (json['status'] == 'active'),
      tokenInfo: json['tokenInfo'] != null
          ? TokenInfo.fromJson(json['tokenInfo'])
          : null,
      isAdminAccount: json['isAdminAccount'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'name': name,
      'role': role,
      'status': status,
      'department': department,
      'position': position,
      'profileImage': profileImage,
      'profileImageUrl': profileImageUrl,
      'company': company?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'isActive': isActive,
      'tokenInfo': tokenInfo?.toJson(),
      'isAdminAccount': isAdminAccount,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? name,
    String? role,
    String? status,
    String? department,
    String? position,
    String? profileImage,
    String? profileImageUrl,
    Company? company,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
    TokenInfo? tokenInfo,
    bool? isAdminAccount,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      status: status ?? this.status,
      department: department ?? this.department,
      position: position ?? this.position,
      profileImage: profileImage ?? this.profileImage,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      company: company ?? this.company,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
      tokenInfo: tokenInfo ?? this.tokenInfo,
      isAdminAccount: isAdminAccount ?? this.isAdminAccount,
    );
  }
}

class TokenInfo {
  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  TokenInfo({required this.accessToken, this.refreshToken, this.expiresAt});

  factory TokenInfo.fromJson(Map<String, dynamic> json) {
    return TokenInfo(
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'],
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }
}
