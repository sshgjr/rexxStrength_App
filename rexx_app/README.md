# Rexx Strength — Flutter App

운동 영상을 업로드하면 포즈를 분석하여 점수와 AI 코칭 피드백을 제공하는 피트니스 앱입니다.

## 사전 요구사항

- **Flutter SDK** 3.11.1 이상
- **Xcode** 최신 버전 (iOS 빌드용)
- **CocoaPods** (`sudo gem install cocoapods`)
- Apple Developer 계정 (실기기 배포 시 필요)

## 빌드 및 실행

### 1. 의존성 설치

```bash
cd rexx_app
flutter pub get
```

### 2. iOS Pod 설치

```bash
cd ios
pod install
cd ..
```

> `pod install`이 실패하면 `pod repo update` 후 재시도하세요.

### 3. Xcode 서명 설정

1. `ios/Runner.xcworkspace`를 Xcode로 열기
2. Runner 타겟 → **Signing & Capabilities** 탭
3. **Team**을 본인의 Apple Developer 계정으로 변경
4. **Bundle Identifier**가 충돌하면 고유한 값으로 수정 (예: `com.yourname.rexxApp`)

### 4. 앱 실행

```bash
# 연결된 기기/시뮬레이터에서 실행 (디버그 모드)
flutter run

# 디버그 모드 + 특정 기기 지정
flutter devices                  # 연결된 기기 목록 확인
flutter run -d <device_id>

# 디버그 모드 (Hot Reload/Restart, DevTools, 디버그 배너 등 개발 도구 활성화)
# flutter run은 기본이 --debug 이므로 동일합니다
flutter run --debug

# 프로파일 모드 (성능 측정용, DevTools 사용 가능하나 디버그 오버헤드 없음)
flutter run --profile

# 릴리즈 모드 (최종 배포용, 모든 디버그 기능 비활성화)
flutter run --release
```

> **참고:** ML Kit 포즈 감지는 **실제 기기(iPhone)**에서만 정상 동작합니다. 시뮬레이터에서는 카메라/ML Kit 기능이 제한됩니다.

### 5. Xcode에서 직접 실행하기

Flutter 명령어 대신 Xcode에서 직접 빌드·실행할 수도 있습니다:

1. `flutter pub get` 및 `pod install`이 완료된 상태에서
2. `ios/Runner.xcworkspace`를 Xcode로 열기 (**`.xcodeproj`가 아닌 `.xcworkspace`를 열어야 합니다**)
3. 상단에서 실행 대상 기기 선택
4. **▶ Run** (⌘R) 버튼으로 빌드 및 실행

## 기타 명령어

```bash
flutter analyze    # 정적 분석 (린트)
flutter test       # 유닛 테스트 실행
flutter clean      # 빌드 캐시 초기화 (빌드 오류 시)
```

## 서버 연동

앱이 AI 피드백을 받으려면 백엔드 서버가 필요합니다. `rexx_server/` 디렉토리의 README를 참고하세요.

- iOS 시뮬레이터: `http://127.0.0.1:8000` (기본값)
- Android 에뮬레이터: `http://10.0.2.2:8000`으로 변경 필요 (`lib/config/api_config.dart`)
