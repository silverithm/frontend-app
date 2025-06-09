# 📱 앱 아이콘 등록 가이드

이 폴더에 앱 아이콘 관련 이미지 파일들을 저장하고 아래 단계를 따라 진행해주세요.

## 🎯 필요한 이미지 파일들

### 1. 메인 앱 아이콘 (필수)
- **파일명**: `app_icon.png`
- **크기**: 1024x1024 픽셀
- **형식**: PNG
- **설명**: 모든 플랫폼에서 사용될 메인 앱 아이콘

### 2. Android 적응형 아이콘 (권장)
- **배경 이미지**: `icon_background.png` (1024x1024 픽셀)
- **전경 이미지**: `icon_foreground.png` (1024x1024 픽셀)
- **설명**: Android 8.0 이상에서 다양한 모양으로 표시되는 적응형 아이콘

## 🚀 아이콘 생성 단계

### 1. 이미지 파일 준비
```bash
assets/images/
├── app_icon.png          # 1024x1024 메인 아이콘
├── icon_background.png   # 1024x1024 배경 (선택사항)
└── icon_foreground.png   # 1024x1024 전경 (선택사항)
```

### 2. 의존성 설치
```bash
flutter pub get
```

### 3. 아이콘 생성 실행
```bash
# 모든 플랫폼 아이콘 생성
flutter pub run flutter_launcher_icons:main

# 또는 다트 명령어 사용
dart run flutter_launcher_icons:main
```

### 4. 생성 확인
아이콘이 성공적으로 생성되면 다음 위치에 파일들이 생성됩니다:

**Android:**
- `android/app/src/main/res/mipmap-*/launcher_icon.png`
- `android/app/src/main/res/mipmap-*/ic_launcher_foreground.png` (적응형 아이콘 사용 시)
- `android/app/src/main/res/mipmap-*/ic_launcher_background.png` (적응형 아이콘 사용 시)

**iOS:**
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

**Web:**
- `web/icons/`

## ⚙️ 설정 커스터마이징

`pubspec.yaml`의 `flutter_icons` 섹션에서 설정을 수정할 수 있습니다:

```yaml
flutter_icons:
  android: "launcher_icon"              # Android 아이콘 이름
  ios: true                            # iOS 아이콘 생성 여부
  image_path: "assets/images/app_icon.png"  # 메인 아이콘 경로
  
  # 적응형 아이콘 설정 (Android)
  adaptive_icon_background: "assets/images/icon_background.png"
  adaptive_icon_foreground: "assets/images/icon_foreground.png"
  
  # iOS 설정
  remove_alpha_ios: true               # iOS에서 알파 채널 제거
  
  # 웹 설정
  web:
    generate: true
    image_path: "assets/images/app_icon.png"
    background_color: "#2196F3"        # 웹 앱 배경색
    theme_color: "#2196F3"             # 웹 앱 테마색
  
  # Windows 설정
  windows:
    generate: true
    image_path: "assets/images/app_icon.png"
    icon_size: 48                      # 48, 64, 128, 256 중 선택
  
  # macOS 설정
  macos:
    generate: true
    image_path: "assets/images/app_icon.png"
```

## 🎨 디자인 가이드라인

### Android 적응형 아이콘
- **전경**: 중앙 108x108dp 영역에 주요 요소 배치
- **배경**: 단색 또는 심플한 패턴 사용
- **안전 영역**: 중앙 66x66dp 영역은 항상 보이는 부분

### iOS 아이콘
- **모서리**: iOS가 자동으로 둥근 모서리 적용
- **배경**: 투명 배경 사용 안 함 (불투명한 배경 필요)
- **그림자**: 그림자 효과 사용 안 함 (iOS가 자동 적용)

### 일반 가이드라인
- **해상도**: 벡터 기반으로 제작하여 고해상도 유지
- **단순함**: 작은 크기에서도 인식 가능한 단순한 디자인
- **브랜딩**: 앱의 정체성을 나타내는 색상과 모양 사용

## 🔧 문제 해결

### 일반적인 오류들

1. **이미지 파일이 없음**
   ```
   Error: Image file not found: assets/images/app_icon.png
   ```
   **해결**: 이미지 파일이 정확한 경로에 있는지 확인

2. **권한 오류**
   ```
   Error: Permission denied
   ```
   **해결**: `sudo` 없이 실행하거나 프로젝트 폴더 권한 확인

3. **iOS 빌드 오류**
   - Xcode에서 `Product > Clean Build Folder` 실행
   - `ios/Runner.xcworkspace` 파일로 Xcode 열기

### 수동 확인 방법

1. **Android**: Android Studio의 AVD에서 앱 실행
2. **iOS**: Xcode Simulator에서 앱 실행
3. **실제 기기**: 디버그 모드로 설치하여 확인

## 📝 체크리스트

- [ ] `app_icon.png` 파일 준비 (1024x1024)
- [ ] `pubspec.yaml` 설정 확인
- [ ] `flutter pub get` 실행
- [ ] `flutter pub run flutter_launcher_icons:main` 실행
- [ ] Android에서 아이콘 확인
- [ ] iOS에서 아이콘 확인
- [ ] 필요시 적응형 아이콘 파일 추가

---

💡 **팁**: 아이콘 디자인이 어려우시면 Figma, Adobe Illustrator, 또는 온라인 아이콘 생성기를 사용해보세요! 