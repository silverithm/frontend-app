# Frontend App

Flutter로 개발된 모바일 애플리케이션입니다.

## 🚀 시작하기

### 필요 요건
- Flutter SDK (3.33.0 이상)
- Dart SDK
- Android Studio / Xcode (모바일 개발용)

### 설치 및 실행

1. 의존성 설치
```bash
flutter pub get
```

2. 애플리케이션 실행
```bash
flutter run
```

## 📁 프로젝트 구조

```
lib/
├── models/          # 데이터 모델
├── providers/       # 상태 관리 (Provider)
├── screens/         # 화면 위젯
├── services/        # API 서비스, 저장소 등
├── utils/           # 유틸리티 함수 및 상수
├── widgets/         # 재사용 가능한 위젯
└── main.dart        # 애플리케이션 진입점
```

## 📦 주요 패키지

- **provider**: 상태 관리
- **http**: HTTP 통신
- **shared_preferences**: 로컬 저장소
- **go_router**: 라우팅
- **json_annotation & json_serializable**: JSON 직렬화

## ✨ 포함된 기능

- ✅ 기본 프로젝트 구조
- ✅ 상태 관리 (Provider)
- ✅ HTTP 서비스
- ✅ 로컬 저장소 서비스
- ✅ 다크/라이트 테마
- ✅ 상수 관리
- ✅ 기본 UI 컴포넌트

## 🛠 개발 가이드

### 새로운 화면 추가
1. `lib/screens/` 디렉토리에 새 파일 생성
2. 필요시 라우팅 설정

### 상태 관리
Provider 패턴을 사용하여 상태를 관리합니다. 새로운 Provider가 필요한 경우:
1. `lib/providers/` 디렉토리에 새 파일 생성
2. `main.dart`의 MultiProvider에 추가

### API 통신
`lib/services/api_service.dart`를 활용하여 HTTP 통신을 수행합니다.

## 📱 지원 플랫폼

- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ macOS
- ✅ Windows
- ✅ Linux
