# 휴무 관리 시스템 (Flutter App)

Flutter로 개발된 휴무 관리 모바일 애플리케이션입니다.

## 🚀 시작하기

### 필요 요건
- Flutter SDK (3.33.0 이상)
- Dart SDK
- Android Studio / Xcode (모바일 개발용)
- Spring Boot 백엔드 서버

### 설치 및 실행

1. 의존성 설치
```bash
flutter pub get
```

2. **API 서버 설정** (중요!)
   `lib/utils/constants.dart` 파일에서 Spring Boot 서버 URL을 설정하세요:
   ```dart
   static const String baseUrl = 'http://localhost:8080/api'; // 개발 환경
   // 또는
   static const String baseUrl = 'https://your-domain.com/api'; // 프로덕션 환경
   ```

3. 애플리케이션 실행
```bash
flutter run
```

## 🔗 API 연결 상태

### ✅ 연결된 API
- **회원가입 요청**: `POST /members/join-request`
  - DTO: `MemberJoinRequestDTO` (username, email, name, role, password)
- **휴가 캘린더 조회**: `GET /vacations/calendar`
  - DTO: `VacationCalendarResponseDTO` with `Map<String, VacationDateInfo>`
- **특정 날짜 휴가 조회**: `GET /vacations/date/{date}`
  - DTO: `VacationDateResponseDTO`
- **휴가 신청 생성**: `POST /vacations/submit`
  - DTO: `VacationCreateRequestDTO` (userName, date, reason, role, password, type, userId)
- **휴가 제한 조회**: `GET /vacations/limits`
  - DTO: `VacationLimitDTO` (id, date, maxPeople, role)

### ⏳ 연결 대기 중인 API
- **로그인**: `POST /auth/login` (JWT 토큰 응답 필요)
- **토큰 검증**: API 엔드포인트 필요
- **사용자별 휴가 목록**: API 엔드포인트 필요
- **휴가 신청 취소**: API 엔드포인트 필요

## 📁 프로젝트 구조

```
lib/
├── models/          # 데이터 모델 (User, VacationRequest)
├── providers/       # 상태 관리 (AuthProvider, VacationProvider)
├── screens/         # 화면 위젯 (로그인, 회원가입, 캘린더, 휴가목록, 프로필)
├── services/        # API 서비스, 저장소 등
├── utils/           # 유틸리티 함수 및 상수
├── widgets/         # 재사용 가능한 위젯 (캘린더, 다이얼로그 등)
└── main.dart        # 애플리케이션 진입점
```

## 📦 주요 패키지

- **provider**: 상태 관리
- **http**: HTTP 통신
- **shared_preferences**: 로컬 저장소
- **json_annotation**: JSON 직렬화
- **intl**: 다국어 지원

## ✨ 주요 기능

### 🔐 인증 시스템
- ✅ 로그인 (이메일/비밀번호)
- ✅ 회원가입 요청 (관리자 승인 방식)
- ✅ 로그아웃
- ✅ 토큰 기반 인증

### 📅 휴무 캘린더
- ✅ 월별 캘린더 조회
- ✅ 역할별 필터링 (전체/돌봄직원/사무직원)
- ✅ 날짜별 휴무자 확인
- ✅ 휴무 유형 표시 (필수/개인)

### 📝 휴무 신청
- ✅ 새 휴무 신청
- ✅ 신청 상태 확인 (대기/승인/거절)
- ✅ 개인 휴무 목록 조회
- ✅ 신청 취소 (로컬, API 연결 필요)

### 👤 사용자 프로필
- ✅ 사용자 정보 표시
- ✅ 앱 설정 (테마, 알림 등)
- ✅ 도움말 및 정보

## 🛠 개발 가이드

### API 응답 형식
Spring Boot API는 다음 형식으로 응답해야 합니다:

**성공 응답:**
```json
{
  "success": true,
  "message": "성공 메시지",
  "data": { /* 실제 데이터 */ }
}
```

**에러 응답:**
```json
{
  "error": "에러 메시지",
  "success": false
}
```

### 새로운 API 연결
1. `lib/services/api_service.dart`에 새 메서드 추가
2. 해당 Provider에서 API 호출
3. 모델 클래스에 JSON 직렬화 메서드 확인

### 상태 관리
Provider 패턴을 사용하여 상태를 관리합니다:
- `AuthProvider`: 인증 상태 관리
- `VacationProvider`: 휴무 데이터 관리
- `AppProvider`: 앱 전역 설정 관리

## 🐛 디버깅

### 일반적인 문제들

1. **API 연결 오류**
   - `lib/utils/constants.dart`에서 baseUrl 확인
   - 네트워크 권한 확인 (Android: `android/app/src/main/AndroidManifest.xml`)

2. **CORS 오류 (웹)**
   - Spring Boot에서 CORS 설정 확인
   - 개발 중에는 `flutter run -d chrome --web-renderer html`

3. **토큰 인증 오류**
   - 토큰 만료 시간 확인
   - 헤더 형식: `Authorization: Bearer <token>`

## 📱 지원 플랫폼

- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ macOS
- ✅ Windows
- ✅ Linux

### 🧪 API 연결 테스트

1. **서버 확인**
   ```bash
   # Spring Boot 서버가 실행 중인지 확인
   curl http://localhost:8080/api/vacations/calendar?startDate=2024-01-01&endDate=2024-01-31&roleFilter=all
   ```

2. **Flutter 앱에서 확인**
   - 회원가입 시 승인 대기 메시지 표시 확인
   - 캘린더에서 데이터 로딩 확인
   - 휴가 신청 시 비밀번호 입력 확인

3. **주요 API 응답 형식**
   ```json
   // 캘린더 응답
   {
     "dates": {
       "2024-01-15": {
         "date": "2024-01-15",
         "vacations": [...],
         "totalVacationers": 2,
         "maxPeople": 5
       }
     }
   }
   
   // 휴가 신청 응답
   {
     "success": true,
     "data": {
       "id": 123,
       "userName": "김직원",
       "date": "2024-01-15",
       "status": "pending",
       "role": "caregiver",
       "type": "personal"
     }
   }
   ```
