/// 휴무 종류.
///
/// 웹 관리자(frontend-admin `src/types/vacation.ts`의 VACATION_KIND_OPTIONS)와 같은 목록이다.
/// 서버는 `type`(regular/mandatory/substitute)과 `duration`(UNUSED/FULL_DAY/HALF_DAY_*)을
/// 따로 받지만, 고르는 사람 입장에서는 "일반휴무 / 연차 / 오전반차"처럼 한 줄로 보는 게 자연스러워
/// 웹과 똑같이 둘을 합친 6가지로 묶어 보여준다.
///
/// 여기를 고치면 웹의 VACATION_KIND_OPTIONS도 함께 맞춰야 두 화면의 표기가 어긋나지 않는다.
enum VacationKind { regular, mandatory, substitute, annual, halfAm, halfPm }

extension VacationKindX on VacationKind {
  String get label {
    switch (this) {
      case VacationKind.regular:
        return '일반휴무';
      case VacationKind.mandatory:
        return '필수휴무';
      case VacationKind.substitute:
        return '대체휴무';
      case VacationKind.annual:
        return '연차';
      case VacationKind.halfAm:
        return '오전반차';
      case VacationKind.halfPm:
        return '오후반차';
    }
  }

  String get description {
    switch (this) {
      case VacationKind.regular:
        return '하루 쉼 · 연차로 기록하지 않음';
      case VacationKind.mandatory:
        return '하루 쉼 · 사유를 반드시 남김';
      case VacationKind.substitute:
        return '근무한 날을 대신 쉼';
      case VacationKind.annual:
        return '하루 종일 · 연차로 기록';
      case VacationKind.halfAm:
        return '오전만 쉼';
      case VacationKind.halfPm:
        return '오후만 쉼';
    }
  }

  /// 서버 type 컬럼 값
  String get serverType {
    switch (this) {
      case VacationKind.mandatory:
        return 'mandatory';
      case VacationKind.substitute:
        return 'substitute';
      case VacationKind.regular:
      case VacationKind.annual:
      case VacationKind.halfAm:
      case VacationKind.halfPm:
        return 'regular';
    }
  }

  /// 서버 duration 컬럼 값
  String get serverDuration {
    switch (this) {
      case VacationKind.annual:
        return 'FULL_DAY';
      case VacationKind.halfAm:
        return 'HALF_DAY_AM';
      case VacationKind.halfPm:
        return 'HALF_DAY_PM';
      case VacationKind.regular:
      case VacationKind.mandatory:
      case VacationKind.substitute:
        return 'UNUSED';
    }
  }

  /// 연차로 차감할지. false면 서버가 duration을 UNUSED로 고정한다.
  bool get useAnnualLeave => serverDuration != 'UNUSED';

  /// 사유를 반드시 받아야 하는 종류 (웹과 같은 규칙)
  bool get reasonRequired => this == VacationKind.mandatory;
}
