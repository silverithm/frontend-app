class PositionOption {
  final String id;
  final String name;
  final String? description;
  final String? memberRole;
  final int? sortOrder;

  const PositionOption({
    required this.id,
    required this.name,
    this.description,
    this.memberRole,
    this.sortOrder,
  });

  factory PositionOption.fromJson(Map<String, dynamic> json) {
    return PositionOption(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      memberRole: json['memberRole']?.toString(),
      sortOrder: json['sortOrder'] is num
          ? (json['sortOrder'] as num).toInt()
          : int.tryParse(json['sortOrder']?.toString() ?? ''),
    );
  }
}
