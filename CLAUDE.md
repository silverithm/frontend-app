# Flutter Best Practices for Silverithm Project

## Code Organization Guidelines

### 1. 작은 단위로 작업 분할하기
- 하나의 파일에 너무 많은 코드를 넣지 마세요
- 각 위젯은 단일 책임 원칙(Single Responsibility Principle)을 따라야 합니다
- 복잡한 UI는 여러 개의 작은 위젯으로 분할하세요

### 2. 리팩토링 가능한 구조
- 중복 코드를 피하고 재사용 가능한 컴포넌트를 만드세요
- 공통 위젯은 `widgets/common` 폴더에 배치하세요
- 테마 관련 상수는 `theme/` 폴더에서 관리하세요

### 3. Flutter Best Practices

#### State Management
- Provider 패턴을 일관되게 사용하세요
- 상태 변경은 notifyListeners()를 통해 전파하세요
- Consumer 위젯을 사용하여 필요한 부분만 리빌드하세요

#### Widget Structure
```dart
// Good - 작은 위젯으로 분할
class AdminDashboardScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }
  
  Widget _buildBottomNavigation() {
    // 별도 메서드로 분리
  }
}
```

#### Navigation
- 관리자와 일반 사용자의 네비게이션을 명확히 분리
- MainScreen에서 역할에 따라 다른 화면 표시:
  - 관리자: AdminDashboardScreen (자체 BottomNavigationBar 포함)
  - 일반 사용자: 기존 구조 유지

#### Design System
- 모든 색상은 AppSemanticColors 사용
- 간격은 AppSpacing 상수 사용
- 타이포그래피는 AppTypography 사용

#### API Integration
- API 서비스는 싱글톤 패턴 사용
- 에러 처리를 위한 try-catch 블록 포함
- 의미 있는 에러 메시지 제공

### 4. 폴더 구조
```
lib/
├── models/          # 데이터 모델
├── providers/       # 상태 관리 (Provider)
├── screens/         # 화면 위젯
├── services/        # API 및 외부 서비스
├── theme/           # 디자인 시스템
├── utils/           # 유틸리티 함수
└── widgets/         # 재사용 가능한 위젯
    └── common/      # 공통 컴포넌트
```

### 5. 코드 컨벤션
- 클래스명: PascalCase (예: AdminDashboardScreen)
- 변수/함수명: camelCase (예: buildNavItem)
- 상수: camelCase 또는 SCREAMING_SNAKE_CASE
- Private 멤버: 언더스코어 prefix (예: _currentIndex)

### 6. 성능 최적화
- const 생성자 활용
- 불필요한 리빌드 방지
- IndexedStack으로 상태 유지
- AnimatedContainer로 부드러운 애니메이션

### 7. 접근성
- 모든 아이콘에 의미 있는 label 제공
- 적절한 색상 대비 유지
- 터치 영역 최소 48x48 픽셀 확보

## 프로젝트별 특별 지침

### AdminDashboardScreen 리팩토링
- AppBar의 TabBar를 제거하고 BottomNavigationBar 사용
- 각 탭의 내용은 별도 메서드로 분리 (_buildUserManagementTab 등)
- 관리자 대시보드는 독립적인 네비게이션 구조 유지

### API URL 구조
- baseUrl: 'https://silverithm.site/api'
- 엔드포인트는 Constants 클래스에서 관리
- URL 중복 문제 해결 완료

### 관리자 기능
- 승인 대기 사용자 관리
- 휴가 요청 승인/거부
- 회사 정보 관리
- 모든 기능에 적절한 권한 체크 포함

## 테스트 가이드라인
- 새로운 기능 추가 시 unit test 작성
- Provider 테스트 필수
- UI 테스트는 중요 플로우에 대해서만

## 커밋 메시지 컨벤션
- feat: 새로운 기능 추가
- fix: 버그 수정
- refactor: 코드 리팩토링
- style: 코드 포맷팅, 세미콜론 누락 등
- docs: 문서 수정
- test: 테스트 코드 추가/수정
- chore: 빌드 스크립트, 패키지 매니저 설정 등