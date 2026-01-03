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

#### API 응답 처리 가이드라인
**⚠️ 중요: API 응답 파싱 패턴**

1. **`_makeAuthenticatedRequest` 사용 시**:
   ```dart
   // ✅ 정확한 방법: 이미 파싱된 Map이 반환됨
   final response = await _makeAuthenticatedRequest(() async {
     return await http.get(uri, headers: headers);
   });
   final userEmail = response['userEmail']?.toString() ?? '';
   
   // ❌ 잘못된 방법: 중복 파싱 시도
   final responseData = json.decode(response.body); // 에러 발생!
   ```

2. **baseUrl과 엔드포인트 조합**:
   ```dart
   // baseUrl = 'https://silverithm.site/api'
   
   // ✅ 정확한 방법
   final uri = Uri.parse('$_baseUrl/v1/users/info');
   // 결과: https://silverithm.site/api/v1/users/info
   
   // ❌ 잘못된 방법: api 중복
   final uri = Uri.parse('$_baseUrl/api/v1/users/info');
   // 결과: https://silverithm.site/api/api/v1/users/info (404 에러)
   ```

3. **API 응답 디버깅**:
   ```dart
   // getUserInfo API 같은 복잡한 응답의 경우 전체 구조 확인
   final userInfoResponse = await getUserInfo();
   print('[API] getUserInfo 전체 응답: $userInfoResponse');
   final userEmail = userInfoResponse['userEmail']?.toString() ?? '';
   ```

**공통 실수 방지:**
- `_makeAuthenticatedRequest`는 이미 `_handleResponse`를 거쳐 파싱된 데이터 반환
- baseUrl에 이미 '/api'가 포함되어 있으므로 엔드포인트에 추가하지 말 것
- API 응답 구조를 정확히 파악하기 위해 전체 응답을 먼저 로깅

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
- 휴무 요청 승인/거부
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

## 개발 워크플로우 규칙

### Flutter 앱 실행
- **중요**: Flutter 앱 실행(`flutter run`)은 사용자가 직접 수행합니다
- Claude는 `flutter run` 명령어를 사용하지 않습니다
- 코드 수정 후 사용자가 직접 앱을 실행하여 테스트합니다
- Claude는 코드 구현 및 수정에만 집중합니다

---

## 디자인 시스템 가이드라인

### 1. 타이포그래피 매핑

| 용도 | 크기 | AppTypography 매핑 | 설명 |
|------|------|-------------------|------|
| 화면 제목 | 20pt | `heading4` | 스크린 타이틀 |
| 섹션 제목 | 18pt | `heading5` | 섹션 헤더 |
| 소제목 | 16pt | `heading6` / `bodyLarge` | 카드 제목 등 |
| 본문 | 14pt | `bodyMedium` | 일반 텍스트 |
| 본문 (작은) | 12pt | `bodySmall` | 부가 설명 |
| 레이블 | 14pt | `labelLarge` | 버튼, 폼 레이블 |
| 레이블 (작은) | 12pt | `labelMedium` | 배지, 태그 |
| 캡션 | 11pt | `caption` / `labelSmall` | 작은 정보 |
| 오버라인 | 11pt | `overline` | 매우 작은 뱃지 |

**사용 예시:**
```dart
// 화면 제목
Text('프로필', style: AppTypography.heading4)

// 본문 텍스트 (색상 지정)
Text('설명', style: AppTypography.bodyMedium.copyWith(
  color: AppSemanticColors.textSecondary,
))
```

### 2. 간격 시스템 (8의 배수)

| 용도 | 값 | AppSpacing 상수 |
|------|-----|----------------|
| 최소 간격 | 4px | `space1` |
| 작은 간격 | 8px | `space2` |
| 기본 간격 | 12px | `space3` |
| 중간 간격 | 16px | `space4` |
| 큰 간격 | 20px | `space5` |
| 섹션 간격 | 24px | `space6` |
| 대형 간격 | 32px | `space8` |

**사용 예시:**
```dart
Padding(
  padding: EdgeInsets.all(AppSpacing.space4), // 16px
  child: ...
)

SizedBox(height: AppSpacing.space2) // 8px 간격
```

### 3. Border Radius

| 용도 | 값 | AppBorderRadius 상수 |
|------|-----|---------------------|
| 작은 요소 | 4px | `base` |
| 기본 요소 | 6px | `md` |
| 버튼 | 8px | `lg` |
| 카드 | 12px | `xl` |
| 큰 카드 | 16px | `xl2` |
| 원형 | 9999px | `full` |

**사용 예시:**
```dart
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(AppBorderRadius.xl), // 12px
  ),
)
```

### 4. 애니메이션 시간

| 용도 | 시간 | AppTransitions 상수 |
|------|------|-------------------|
| 매우 빠름 | 75ms | `fastest` |
| 빠름 | 150ms | `fast` |
| 보통 | 200ms | `normal` |
| 느림 | 300ms | `slow` |
| 매우 느림 | 500ms | `slowest` |

**사용 예시:**
```dart
AnimatedContainer(
  duration: AppTransitions.normal, // 200ms
  child: ...
)
```

### 5. 색상 사용 규칙

#### 색상 매핑 테이블
```dart
// Before                          → After
Colors.white                       → AppSemanticColors.surfaceDefault
Colors.grey.shade50                → AppSemanticColors.backgroundSecondary
Colors.grey.shade100               → AppSemanticColors.backgroundTertiary
Colors.grey.shade200               → AppSemanticColors.borderDefault
Colors.grey.shade500               → AppSemanticColors.textTertiary
Colors.grey.shade600               → AppSemanticColors.textSecondary
Colors.grey.shade900               → AppSemanticColors.textPrimary
Colors.blue.shade600               → AppSemanticColors.interactivePrimaryDefault
Colors.red.shade600                → AppSemanticColors.statusErrorIcon
Colors.green.shade600              → AppSemanticColors.statusSuccessIcon
Colors.yellow.shade600             → AppSemanticColors.statusWarningIcon
```

#### withOpacity() 대체 규칙
**⚠️ 중요: `withOpacity()` 사용 금지 (deprecated)**

```dart
// ❌ 잘못된 방법
color.withOpacity(0.5)

// ✅ 올바른 방법
color.withValues(alpha: 0.5)
```

### 6. forui 컴포넌트 가이드

프로젝트에서 forui 라이브러리를 사용합니다.

**Import:**
```dart
import 'package:forui/forui.dart';
```

#### 컴포넌트 매핑 테이블
| Flutter 기본 | forui 대체 | 용도 |
|-------------|-----------|------|
| `TextField` | `FTextField` | 일반 텍스트 입력 |
| `TextFormField` | `FTextFormField` | 폼 텍스트 입력 |
| `Switch` | `FSwitch` | 토글 스위치 |
| `Checkbox` | `FCheckbox` | 체크박스 |
| `AlertDialog` | `FDialog` | 다이얼로그 |
| `CircularProgressIndicator` | `FProgress` | 로딩 인디케이터 |

#### FTextField 사용 예시
```dart
FTextField(
  controller: _controller,
  label: const Text('이메일'),
  hint: 'example@email.com',
)
```

#### FSwitch 사용 예시
```dart
FSwitch(
  value: _isEnabled,
  onChange: (value) => setState(() => _isEnabled = value),
)
```

#### FDialog 사용 예시
```dart
showAdaptiveDialog(
  context: context,
  builder: (context) => FDialog(
    direction: Axis.horizontal,
    title: const Text('확인'),
    body: const Text('정말 삭제하시겠습니까?'),
    actions: [
      FButton(
        label: const Text('취소'),
        onPress: () => Navigator.pop(context),
        style: FButtonStyle.outline,
      ),
      FButton(
        label: const Text('삭제'),
        onPress: () => _delete(),
        style: FButtonStyle.destructive,
      ),
    ],
  ),
);
```

### 7. 코드 스타일 체크리스트

코드 작성 시 반드시 확인:
- [ ] `withOpacity()` 대신 `withValues(alpha:)` 사용
- [ ] 인라인 `TextStyle()` 대신 `AppTypography` 사용
- [ ] 직접 `Colors` 대신 `AppSemanticColors` 사용
- [ ] 하드코딩된 간격 대신 `AppSpacing` 상수 사용
- [ ] 하드코딩된 radius 대신 `AppBorderRadius` 상수 사용
- [ ] 하드코딩된 duration 대신 `AppTransitions` 상수 사용
- [ ] 터치 영역 최소 32x32px 확보