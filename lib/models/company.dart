class Company {
  final String id; // Long을 String으로 처리
  final String name;
  final String addressName;
  final Location? companyAddress;

  Company({
    required this.id,
    required this.name,
    required this.addressName,
    this.companyAddress,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      addressName: json['addressName'] ?? '',
      companyAddress: json['companyAddress'] != null
          ? Location.fromJson(json['companyAddress'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'addressName': addressName,
      'companyAddress': companyAddress?.toJson(),
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
