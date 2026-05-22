# Rexx Strength — Flutter App

운동 영상을 업로드하면 포즈를 분석하여 점수와 AI 코칭 피드백을 제공하는 피트니스 앱입니다.

## 사전 요구사항

- **Flutter SDK** 3.11.1 이상
- **Xcode** 최신 버전 (iOS 빌드용)
- **CocoaPods** (`sudo gem install cocoapods`)
- Apple Developer 계정 (실기기 배포 시 필요)

## 빌드 및 실행 (터미널 전용 가이드)

> Xcode 서명·기기 신뢰·시뮬레이터 생성·앱 실행 등 GUI 작업은 본인이 처리한다는 전제. 본 가이드는 **터미널에서만 해야 하는 부분**에 한합니다.

### 0. 공통 준비 (한 번)

```bash
cd rexx_app
flutter pub get
```

CocoaPods가 없다면: `sudo gem install cocoapods`

> **시뮬레이터 준비**: Xcode → Window → Devices and Simulators (`⇧⌘2`) → Simulators 탭 → **+** 로 본 작업 전용 시뮬레이터 생성을 권장. 본 가이드는 그 이름을 `<simulator-name>`으로 표기 (예: `rexx_without_ml`). 본인이 부여한 이름으로 치환해 사용하세요.

ML Kit는 Apple Silicon Mac의 arm64 시뮬레이터를 지원하지 않으므로, 빌드 흐름이 두 갈래로 나뉩니다.

```
시뮬레이터(M1/M2/M3 Mac) → ML Kit 불가 → EXCLUDE_MLKIT=true + SIMULATOR_MODE=true → stub 사용
실기기 iPhone           → ML Kit 정상  → 환경변수 없음                          → 실제 BlazePose
```

---

### A. 시뮬레이터 빌드 (ML Kit 제외)

영상 업로드 시 stub 데이터(고정 시드의 가짜 스쿼트 모션)로 평가가 흐릅니다. UI/통신 흐름 검증 용도.

#### A-1. 권장: 자동 스크립트

```bash
cd rexx_app
./scripts/run_simulator.sh <simulator-name>
```

스크립트가 자동으로 처리:
1. 시뮬레이터 부팅
2. `EXCLUDE_MLKIT=true` 환경에서 `flutter pub get` + `pod install`
3. `flutter run --dart-define=SIMULATOR_MODE=true` 로 실행
4. **종료 시 자동 복원** — `flutter pub get` + `pod install`을 다시 돌려 ML Kit 포함 상태로 되돌림

#### A-2. 수동 명령

```bash
cd rexx_app
export EXCLUDE_MLKIT=true
flutter clean
flutter pub get
(cd ios && rm -rf Pods Podfile.lock && pod install)
flutter run --dart-define=SIMULATOR_MODE=true -d <simulator-name>
```

종료 후 다른 빌드(특히 실기기)로 넘어가기 전 **반드시 복원**:

```bash
unset EXCLUDE_MLKIT
flutter pub get
(cd ios && pod install)
```

#### 두 플래그 의미

| 플래그 | 층위 | 역할 |
|---|---|---|
| `EXCLUDE_MLKIT=true` (셸 환경변수) | iOS Pod 빌드 | `Podfile`이 이 변수를 읽고 ML Kit 의존성을 동적으로 제거. `pod install` 시점에만 영향 |
| `--dart-define=SIMULATOR_MODE=true` | Dart 컴파일 타임 | `pose_analyzer.dart`의 `isSimulatorMode` 상수가 `true`로 박힘 → `PoseDetectorStub` 선택, ML Kit 호출 분기는 데드 코드로 트리 셰이킹 |

**둘 다 필요합니다.** 한쪽만 쓰면:
- `EXCLUDE_MLKIT`만: Dart는 여전히 ML Kit 호출 시도 → 런타임 크래시
- `SIMULATOR_MODE`만: stub은 골랐지만 iOS arm64 빌드가 ML Kit 때문에 실패

---

### B. 실기기(iPhone) 빌드 (ML Kit 포함)

터미널에서는 **pod 설치까지만** 처리. 이후 서명·기기 선택·Run은 Xcode에서.

```bash
cd rexx_app

# (시뮬레이터 모드를 거쳤다면 반드시 먼저 복원)
unset EXCLUDE_MLKIT
flutter pub get
(cd ios && rm -rf Pods Podfile.lock && pod install)

# Xcode 워크스페이스 열기 (.xcodeproj가 아니라 .xcworkspace)
open ios/Runner.xcworkspace
```

이후 Xcode에서:
- Signing & Capabilities → Team 설정
- 상단 디바이스 선택 → ▶ Run (⌘R)

> CLI로 끝까지 가고 싶다면 (서명이 이미 잡혀 있는 전제):
> ```bash
> flutter devices            # 연결된 기기 ID 확인
> flutter run -d <device-id>
> ```

---

### C. 모드 전환 체크리스트

| 직전 상태 | 다음 작업 | 필수 명령 |
|---|---|---|
| 시뮬레이터(EXCLUDE_MLKIT) | 실기기 | `unset EXCLUDE_MLKIT && flutter pub get && (cd ios && rm -rf Pods Podfile.lock && pod install)` |
| 실기기 | 시뮬레이터 | A 섹션 절차 그대로 |

> `ios/Podfile.lock`, `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/GeneratedPluginRegistrant.m`이 변형돼도 **커밋 금지** — 모드별로 자동 변형되는 산출물입니다.

---

### D. 자주 겪는 터미널 오류

| 메시지 | 원인 / 해결 |
|---|---|
| `Undefined symbol: _OBJC_CLASS_$_GoogleMLKit...` | `EXCLUDE_MLKIT` 안 풀고 실기기 빌드. C의 복원 명령 실행 |
| `arm64` 관련 link error (시뮬레이터) | `EXCLUDE_MLKIT=true` 누락한 채 `pod install` 함 |
| `Generated.xcconfig must exist` | `flutter pub get`을 `rexx_app/`에서 안 돌림 |
| `pod install` 후에도 ML Kit 잔존 | 캐시 문제. `(cd ios && rm -rf Pods Podfile.lock && pod install)` 다시 |
| 시뮬레이터 영상 업로드 후 점수가 항상 비슷 | 정상. stub이 고정 시드(42)로 mock 스쿼트 데이터 반환 |

---

### E. 모드별 동작 검증

`pose_analyzer.dart`의 `isSimulatorMode` 상수가 분기 진입점:
```dart
const bool isSimulatorMode =
    bool.fromEnvironment('SIMULATOR_MODE', defaultValue: false);

PoseAnalyzer()
    : _detector =
          isSimulatorMode ? PoseDetectorStub() : MLKitPoseDetector();
```

- 시뮬레이터: `SIMULATOR_MODE=true` 컴파일 타임 주입 → `PoseDetectorStub`
- 실기기: 미주입(default false) → `MLKitPoseDetector`

ML Kit 사용은 `pose_detector_mlkit.dart` 한 파일에 격리되어 있어, 시뮬레이터 빌드에서는 호출 자체가 일어나지 않습니다.

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
