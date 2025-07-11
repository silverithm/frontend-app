class FCMTokenUpdateDTO {
  final String fcmToken;

  FCMTokenUpdateDTO({
    required this.fcmToken,
  });

  Map<String, dynamic> toJson() {
    return {
      'fcmToken': fcmToken,
    };
  }

  factory FCMTokenUpdateDTO.fromJson(Map<String, dynamic> json) {
    return FCMTokenUpdateDTO(
      fcmToken: json['fcmToken'] ?? '',
    );
  }
}