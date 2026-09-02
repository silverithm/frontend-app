import 'user.dart';
import 'company.dart';
import '../utils/permissions.dart';

class MemberSigninResponse {
  final String memberId;
  final String username;
  final String name;
  final String email;
  final String role;
  final String status;
  final String? department;
  final String? position;
  final String? profileImageUrl;
  final CompanyListDTO company;
  final String? lastLoginAt;
  final TokenInfo tokenInfo;

  /// 서버(MemberSigninResponseDTO.permissions)가 로그인 응답에 실어주는 세부 권한.
  /// 구버전 응답이나 권한 미설정 계정에서는 비어 있을 수 있다.
  final List<String> permissions;

  MemberSigninResponse({
    required this.memberId,
    required this.username,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.department,
    this.position,
    this.profileImageUrl,
    required this.company,
    this.lastLoginAt,
    required this.tokenInfo,
    this.permissions = const [],
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
      profileImageUrl: json['profileImageUrl']?.toString(),
      company: CompanyListDTO.fromJson(json['company']),
      lastLoginAt: json['lastLoginAt'],
      tokenInfo: TokenInfo.fromJson(json['tokenInfo']),
      permissions: PermissionUtils.sanitize(json['permissions']),
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
      profileImageUrl: profileImageUrl,
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
      permissions: permissions,
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