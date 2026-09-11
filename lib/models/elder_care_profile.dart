// 어르신 케어 정보 — 등급·건강·식사·목욕·투약·차량·자리 기준을 한 장에 모은다.
//
// 앱은 주민번호 전체를 절대 다루지 않는다. 응답의 residentNumberMasked만 보여주고,
// 수정 요청에는 residentNumber 키를 아예 싣지 않는다(계약상 null = 기존 값 유지).

/// 장기요양등급
enum CareGrade {
  grade1,
  grade2,
  grade3,
  grade4,
  grade5,
  cognitiveSupport,
  none,
}

/// 기저귀 사용 형태
enum DiaperType { none, panty, pad, both }

/// 인지 상태
enum CognitionLevel { normal, mild, moderate, severe }

/// 식사 형태
enum MealType { regular, chopped, porridge, mixed }

/// 서버 enum 문자열 <-> Dart enum 변환과 한글 라벨을 한곳에서 관리한다.
/// 화면마다 스위치문을 복사하면 라벨이 어긋나기 때문이다.
class ElderCareEnums {
  ElderCareEnums._();

  static const Map<CareGrade, String> careGradeWire = {
    CareGrade.grade1: 'GRADE_1',
    CareGrade.grade2: 'GRADE_2',
    CareGrade.grade3: 'GRADE_3',
    CareGrade.grade4: 'GRADE_4',
    CareGrade.grade5: 'GRADE_5',
    CareGrade.cognitiveSupport: 'COGNITIVE_SUPPORT',
    CareGrade.none: 'NONE',
  };

  static const Map<CareGrade, String> careGradeLabel = {
    CareGrade.grade1: '1등급',
    CareGrade.grade2: '2등급',
    CareGrade.grade3: '3등급',
    CareGrade.grade4: '4등급',
    CareGrade.grade5: '5등급',
    CareGrade.cognitiveSupport: '인지지원등급',
    CareGrade.none: '등급 없음',
  };

  static const Map<DiaperType, String> diaperTypeWire = {
    DiaperType.none: 'NONE',
    DiaperType.panty: 'PANTY',
    DiaperType.pad: 'PAD',
    DiaperType.both: 'BOTH',
  };

  static const Map<DiaperType, String> diaperTypeLabel = {
    DiaperType.none: '사용 안 함',
    DiaperType.panty: '팬티기저귀',
    DiaperType.pad: '패드',
    DiaperType.both: '팬티기저귀 + 패드',
  };

  static const Map<CognitionLevel, String> cognitionLevelWire = {
    CognitionLevel.normal: 'NORMAL',
    CognitionLevel.mild: 'MILD',
    CognitionLevel.moderate: 'MODERATE',
    CognitionLevel.severe: 'SEVERE',
  };

  static const Map<CognitionLevel, String> cognitionLevelLabel = {
    CognitionLevel.normal: '정상',
    CognitionLevel.mild: '경증',
    CognitionLevel.moderate: '중등도',
    CognitionLevel.severe: '중증',
  };

  static const Map<MealType, String> mealTypeWire = {
    MealType.regular: 'REGULAR',
    MealType.chopped: 'CHOPPED',
    MealType.porridge: 'PORRIDGE',
    MealType.mixed: 'MIXED',
  };

  static const Map<MealType, String> mealTypeLabel = {
    MealType.regular: '일반식',
    MealType.chopped: '다진식',
    MealType.porridge: '죽',
    MealType.mixed: '비빔식',
  };

  /// 서버 문자열 -> enum. 모르는 값이 오면 null(미지정)로 떨어뜨린다.
  static T? _parse<T>(Map<T, String> wire, dynamic value) {
    if (value == null) return null;
    final text = value.toString();
    for (final entry in wire.entries) {
      if (entry.value == text) return entry.key;
    }
    return null;
  }

  static CareGrade? parseCareGrade(dynamic v) => _parse(careGradeWire, v);
  static DiaperType? parseDiaperType(dynamic v) => _parse(diaperTypeWire, v);
  static CognitionLevel? parseCognitionLevel(dynamic v) =>
      _parse(cognitionLevelWire, v);
  static MealType? parseMealType(dynamic v) => _parse(mealTypeWire, v);
}

class ElderCareProfile {
  // 기본
  final String? residentNumberMasked; // 응답 전용. 예: 410203-2******
  final String? birthDate; // yyyy-MM-dd
  final String? gender; // MALE / FEMALE
  final int? age; // 응답 전용(만 나이)
  final CareGrade? careGrade;

  // 건강
  final bool fallRisk;
  final String? fallNote;
  final bool pressureSore;
  final String? pressureSoreNote;
  final DiaperType? diaperType;
  final bool diaperIntermittent;
  final CognitionLevel? cognitionLevel;
  final String? cognitionNote;

  // 식사
  final MealType? mealType;
  final bool morningSnack;
  final bool afternoonSnack;
  final bool dinner;
  final String? mealNote;

  // 목욕
  final String? bathTime;
  final String? bathNote;

  // 투약
  final bool medMorning;
  final String? medMorningTime;
  final bool medLunch;
  final String? medLunchTime;
  final bool medEvening;
  final String? medEveningTime;
  final String? medNote;

  // 차량 · 자리 · 메모
  final String? vehicleNote;
  final int? floor;
  final String? seatNote;
  final String? careNote;

  final String? updatedAt; // 응답 전용

  const ElderCareProfile({
    this.residentNumberMasked,
    this.birthDate,
    this.gender,
    this.age,
    this.careGrade,
    this.fallRisk = false,
    this.fallNote,
    this.pressureSore = false,
    this.pressureSoreNote,
    this.diaperType,
    this.diaperIntermittent = false,
    this.cognitionLevel,
    this.cognitionNote,
    this.mealType,
    this.morningSnack = true,
    this.afternoonSnack = true,
    this.dinner = true,
    this.mealNote,
    this.bathTime,
    this.bathNote,
    this.medMorning = false,
    this.medMorningTime,
    this.medLunch = false,
    this.medLunchTime,
    this.medEvening = false,
    this.medEveningTime,
    this.medNote,
    this.vehicleNote,
    this.floor,
    this.seatNote,
    this.careNote,
    this.updatedAt,
  });

  static bool _bool(dynamic v, {bool fallback = false}) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v.toLowerCase() == 'true';
    return fallback;
  }

  static String? _text(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  factory ElderCareProfile.fromJson(Map<String, dynamic> json) {
    return ElderCareProfile(
      residentNumberMasked: _text(json['residentNumberMasked']),
      birthDate: _text(json['birthDate']),
      gender: _text(json['gender']),
      age: _int(json['age']),
      careGrade: ElderCareEnums.parseCareGrade(json['careGrade']),
      fallRisk: _bool(json['fallRisk']),
      fallNote: _text(json['fallNote']),
      pressureSore: _bool(json['pressureSore']),
      pressureSoreNote: _text(json['pressureSoreNote']),
      diaperType: ElderCareEnums.parseDiaperType(json['diaperType']),
      diaperIntermittent: _bool(json['diaperIntermittent']),
      cognitionLevel: ElderCareEnums.parseCognitionLevel(
        json['cognitionLevel'],
      ),
      cognitionNote: _text(json['cognitionNote']),
      mealType: ElderCareEnums.parseMealType(json['mealType']),
      // 간식·저녁은 서버 기본값이 true다. 키가 없으면 true로 둬야 화면이 뒤집히지 않는다.
      morningSnack: _bool(json['morningSnack'], fallback: true),
      afternoonSnack: _bool(json['afternoonSnack'], fallback: true),
      dinner: _bool(json['dinner'], fallback: true),
      mealNote: _text(json['mealNote']),
      bathTime: _text(json['bathTime']),
      bathNote: _text(json['bathNote']),
      medMorning: _bool(json['medMorning']),
      medMorningTime: _text(json['medMorningTime']),
      medLunch: _bool(json['medLunch']),
      medLunchTime: _text(json['medLunchTime']),
      medEvening: _bool(json['medEvening']),
      medEveningTime: _text(json['medEveningTime']),
      medNote: _text(json['medNote']),
      vehicleNote: _text(json['vehicleNote']),
      floor: _int(json['floor']),
      seatNote: _text(json['seatNote']),
      careNote: _text(json['careNote']),
      updatedAt: _text(json['updatedAt']),
    );
  }

  /// 수정 요청 본문. 응답 전용 필드(residentNumberMasked·age·updatedAt)는 싣지 않고,
  /// residentNumber도 넣지 않는다 — 앱은 전체 주민번호를 다루지 않으며
  /// 키가 없으면 서버가 기존 값을 그대로 유지한다.
  Map<String, dynamic> toJson() {
    return {
      'birthDate': birthDate,
      'gender': gender,
      'careGrade': careGrade == null
          ? null
          : ElderCareEnums.careGradeWire[careGrade],
      'fallRisk': fallRisk,
      'fallNote': fallNote,
      'pressureSore': pressureSore,
      'pressureSoreNote': pressureSoreNote,
      'diaperType': diaperType == null
          ? null
          : ElderCareEnums.diaperTypeWire[diaperType],
      'diaperIntermittent': diaperIntermittent,
      'cognitionLevel': cognitionLevel == null
          ? null
          : ElderCareEnums.cognitionLevelWire[cognitionLevel],
      'cognitionNote': cognitionNote,
      'mealType': mealType == null
          ? null
          : ElderCareEnums.mealTypeWire[mealType],
      'morningSnack': morningSnack,
      'afternoonSnack': afternoonSnack,
      'dinner': dinner,
      'mealNote': mealNote,
      'bathTime': bathTime,
      'bathNote': bathNote,
      'medMorning': medMorning,
      'medMorningTime': medMorningTime,
      'medLunch': medLunch,
      'medLunchTime': medLunchTime,
      'medEvening': medEvening,
      'medEveningTime': medEveningTime,
      'medNote': medNote,
      'vehicleNote': vehicleNote,
      'floor': floor,
      'seatNote': seatNote,
      'careNote': careNote,
    };
  }

  ElderCareProfile copyWith({
    String? residentNumberMasked,
    String? birthDate,
    String? gender,
    int? age,
    CareGrade? careGrade,
    bool? fallRisk,
    String? fallNote,
    bool? pressureSore,
    String? pressureSoreNote,
    DiaperType? diaperType,
    bool? diaperIntermittent,
    CognitionLevel? cognitionLevel,
    String? cognitionNote,
    MealType? mealType,
    bool? morningSnack,
    bool? afternoonSnack,
    bool? dinner,
    String? mealNote,
    String? bathTime,
    String? bathNote,
    bool? medMorning,
    String? medMorningTime,
    bool? medLunch,
    String? medLunchTime,
    bool? medEvening,
    String? medEveningTime,
    String? medNote,
    String? vehicleNote,
    int? floor,
    String? seatNote,
    String? careNote,
    String? updatedAt,
  }) {
    return ElderCareProfile(
      residentNumberMasked: residentNumberMasked ?? this.residentNumberMasked,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      careGrade: careGrade ?? this.careGrade,
      fallRisk: fallRisk ?? this.fallRisk,
      fallNote: fallNote ?? this.fallNote,
      pressureSore: pressureSore ?? this.pressureSore,
      pressureSoreNote: pressureSoreNote ?? this.pressureSoreNote,
      diaperType: diaperType ?? this.diaperType,
      diaperIntermittent: diaperIntermittent ?? this.diaperIntermittent,
      cognitionLevel: cognitionLevel ?? this.cognitionLevel,
      cognitionNote: cognitionNote ?? this.cognitionNote,
      mealType: mealType ?? this.mealType,
      morningSnack: morningSnack ?? this.morningSnack,
      afternoonSnack: afternoonSnack ?? this.afternoonSnack,
      dinner: dinner ?? this.dinner,
      mealNote: mealNote ?? this.mealNote,
      bathTime: bathTime ?? this.bathTime,
      bathNote: bathNote ?? this.bathNote,
      medMorning: medMorning ?? this.medMorning,
      medMorningTime: medMorningTime ?? this.medMorningTime,
      medLunch: medLunch ?? this.medLunch,
      medLunchTime: medLunchTime ?? this.medLunchTime,
      medEvening: medEvening ?? this.medEvening,
      medEveningTime: medEveningTime ?? this.medEveningTime,
      medNote: medNote ?? this.medNote,
      vehicleNote: vehicleNote ?? this.vehicleNote,
      floor: floor ?? this.floor,
      seatNote: seatNote ?? this.seatNote,
      careNote: careNote ?? this.careNote,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ===== 표시용 요약 =====

  String get careGradeLabel =>
      careGrade == null ? '등급 미등록' : ElderCareEnums.careGradeLabel[careGrade]!;

  String get genderLabel {
    switch (gender) {
      case 'MALE':
        return '남';
      case 'FEMALE':
        return '여';
      default:
        return '';
    }
  }

  /// "85세 · 여" — 나이나 성별 한쪽만 있으면 있는 쪽만 낸다.
  String get ageGenderSummary {
    final parts = <String>[
      if (age != null) '$age세',
      if (genderLabel.isNotEmpty) genderLabel,
    ];
    return parts.join(' · ');
  }

  /// "아침(10시)·점심" — 켜진 끼니만, 시간이 있으면 괄호로 덧붙인다.
  String get medicationSummary {
    final parts = <String>[
      if (medMorning) _medPart('아침', medMorningTime),
      if (medLunch) _medPart('점심', medLunchTime),
      if (medEvening) _medPart('저녁', medEveningTime),
    ];
    return parts.isEmpty ? '투약 없음' : parts.join('·');
  }

  String _medPart(String label, String? time) =>
      (time == null || time.isEmpty) ? label : '$label($time)';

  /// "오전간식 X·오후간식 O·저녁 O" — 세 항목을 항상 같은 순서로 낸다.
  String get mealServingSummary =>
      '오전간식 ${_ox(morningSnack)}·오후간식 ${_ox(afternoonSnack)}·저녁 ${_ox(dinner)}';

  String _ox(bool on) => on ? 'O' : 'X';

  String get mealTypeLabel =>
      mealType == null ? '미지정' : ElderCareEnums.mealTypeLabel[mealType]!;

  String get diaperLabel {
    if (diaperType == null) return '미지정';
    final base = ElderCareEnums.diaperTypeLabel[diaperType]!;
    // 간헐적 사용은 형태와 별개 축이라 뒤에 붙여 준다.
    if (diaperType == DiaperType.none || !diaperIntermittent) return base;
    return '$base (간헐적)';
  }

  String get cognitionLabel => cognitionLevel == null
      ? '미지정'
      : ElderCareEnums.cognitionLevelLabel[cognitionLevel]!;

  /// "1층 · TV 앞"
  String get seatSummary {
    final parts = <String>[
      if (floor != null) '$floor층',
      if (seatNote != null && seatNote!.isNotEmpty) seatNote!,
    ];
    return parts.isEmpty ? '자리 미지정' : parts.join(' · ');
  }

  /// 목록 행에 다는 작은 태그들 — 눈에 띄어야 하는 것만 고른다.
  List<String> get riskTags => <String>[
    if (fallRisk) '낙상',
    if (pressureSore) '욕창',
    if (diaperType != null && diaperType != DiaperType.none) '기저귀',
    if (medMorning || medLunch || medEvening) '투약',
  ];
}

/// 목록 한 줄에 필요한 어르신 정보 + 케어 프로필.
/// 배차 쪽 ElderlyDTO(5필드)는 그대로 두고, 케어 화면만 이 모델을 쓴다.
class ElderInfo {
  final int id;
  final String name;
  final String? homeAddressName;
  final ElderCareProfile? careProfile;

  const ElderInfo({
    required this.id,
    required this.name,
    this.homeAddressName,
    this.careProfile,
  });

  factory ElderInfo.fromJson(Map<String, dynamic> json) {
    final rawProfile = json['careProfile'];
    return ElderInfo(
      id: ElderCareProfile._int(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      homeAddressName: ElderCareProfile._text(json['homeAddressName']),
      careProfile: rawProfile is Map<String, dynamic>
          ? ElderCareProfile.fromJson(rawProfile)
          : null,
    );
  }

  ElderInfo copyWith({ElderCareProfile? careProfile}) => ElderInfo(
    id: id,
    name: name,
    homeAddressName: homeAddressName,
    careProfile: careProfile ?? this.careProfile,
  );
}
