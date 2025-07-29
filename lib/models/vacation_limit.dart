class VacationLimit {
  final String? id;
  final String date; // yyyy-MM-dd 형식
  final int maxPeople;
  final String role; // 'CAREGIVER', 'OFFICE'
  final String? createdAt;

  VacationLimit({
    this.id,
    required this.date,
    required this.maxPeople,
    required this.role,
    this.createdAt,
  });

  // JSON으로부터 객체 생성
  factory VacationLimit.fromJson(Map<String, dynamic> json) {
    return VacationLimit(
      id: json['id']?.toString(),
      date: json['date'] ?? '',
      maxPeople: json['maxPeople'] ?? 0,
      role: json['role'] ?? 'CAREGIVER',
      createdAt: json['createdAt'],
    );
  }

  // JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'maxPeople': maxPeople,
      'role': role,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }

  // 복사본 생성
  VacationLimit copyWith({
    String? id,
    String? date,
    int? maxPeople,
    String? role,
    String? createdAt,
  }) {
    return VacationLimit(
      id: id ?? this.id,
      date: date ?? this.date,
      maxPeople: maxPeople ?? this.maxPeople,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'VacationLimit(id: $id, date: $date, maxPeople: $maxPeople, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VacationLimit &&
        other.id == id &&
        other.date == date &&
        other.maxPeople == maxPeople &&
        other.role == role;
  }

  @override
  int get hashCode {
    return id.hashCode ^ date.hashCode ^ maxPeople.hashCode ^ role.hashCode;
  }
}