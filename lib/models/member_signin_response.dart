import 'user.dart';
import 'company.dart';

class MemberSigninResponse {
  final String memberId;
  final String username;
  final String name;
  final String email;
  final String role;
  final String status;
  final String? department;
  final String? position;
  final CompanyListDTO company;
  final String? lastLoginAt;
  final TokenInfo tokenInfo;

  MemberSigninResponse({
    required this.memberId,
    required this.username,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.department,
    this.position,
    required this.company,
    this.lastLoginAt,
    required this.tokenInfo,
  });

  factory MemberSigninResponse.fromJson(Map<String, dynamic> json) {
    return MemberSigninResponse(
      memberId: json['memberId']?.toString() ?? '',
      username: json['username'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'CAREGIVER',
      status: json['status'] ?? 'active',
      department: json['department'],
      position: json['position'],
      company: CompanyListDTO.fromJson(json['company']),
      lastLoginAt: json['lastLoginAt'],
      tokenInfo: TokenInfo.fromJson(json['tokenInfo']),
    );
  }

  /// MemberSigninResponse를 User 객체로 변환
  User toUser() {
    return User(
      id: memberId,
      username: username,
      email: email,
      name: name,
      role: role,
      status: status,
      isActive: status == 'active',
      createdAt: DateTime.now(),
      department: department,
      position: position,
      company: Company(
        id: company.id,
        name: company.name,
        addressName: company.addressName ?? '',
        companyAddress: company.companyAddress,
        userEmails: [],
      ),
      lastLoginAt: lastLoginAt != null 
          ? DateTime.tryParse(lastLoginAt!)
          : null,
      tokenInfo: tokenInfo,
    );
  }
}

class CompanyListDTO {
  final String id;
  final String name;
  final String? addressName;
  final Location? companyAddress;

  CompanyListDTO({
    required this.id,
    required this.name,
    this.addressName,
    this.companyAddress,
  });

  factory CompanyListDTO.fromJson(Map<String, dynamic> json) {
    return CompanyListDTO(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      addressName: json['addressName'],
      companyAddress: json['companyAddress'] != null
          ? Location.fromJson(json['companyAddress'])
          : null,
    );
  }
}