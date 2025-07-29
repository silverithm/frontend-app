import 'company.dart';

class User {
  final String id;
  final String email;
  final String name;
  final String role; // 'CAREGIVER', 'OFFICE', 'admin'
  final String? profileImage;
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
    required this.createdAt,
    this.isActive = true,
    required this.username,
    this.status = 'active',
    this.department,
    this.position,
    this.company,
    this.lastLoginAt,
    this.tokenInfo,
  });

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
      'company': company?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'isActive': isActive,
      'tokenInfo': tokenInfo?.toJson(),
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
    Company? company,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
    TokenInfo? tokenInfo,
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
      company: company ?? this.company,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
      tokenInfo: tokenInfo ?? this.tokenInfo,
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
