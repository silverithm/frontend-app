class Company {
  final String id; // Long을 String으로 처리
  final String name;
  final String addressName;
  final String? companyCode;
  final Location? companyAddress;
  final List<String> userEmails;

  Company({
    required this.id,
    required this.name,
    required this.addressName,
    this.companyCode,
    this.companyAddress,
    this.userEmails = const [],
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      addressName: json['addressName'] ?? '',
      companyCode: json['companyCode'],
      companyAddress: json['companyAddress'] != null
          ? Location.fromJson(json['companyAddress'])
          : null,
      userEmails: json['userEmails'] != null
          ? List<String>.from(json['userEmails'])
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'addressName': addressName,
      'companyCode': companyCode,
      'companyAddress': companyAddress?.toJson(),
      'userEmails': userEmails,
    };
  }

  @override
  String toString() => name;
}

class Location {
  final double? latitude;
  final double? longitude;

  Location({this.latitude, this.longitude});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'latitude': latitude, 'longitude': longitude};
  }
}
