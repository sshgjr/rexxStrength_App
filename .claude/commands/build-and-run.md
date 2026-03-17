iOS 앱을 빌드하고 실제 iPhone(유선) 또는 시뮬레이터에서 실행합니다.

## 두 가지 빌드 모드

### A. 실제 iPhone (유선) — ML Kit 포함
```bash
cd rexx_app
flutter pub get && cd ios && pod install && cd ..
flutter devices                    # device ID 확인
flutter run --device-id <ID>
```

### B. 시뮬레이터 — ML Kit 제외 (스크립트 사용)
```bash
cd rexx_app
./scripts/run_simulator.sh "iPhone 17 Pro"
```
ML Kit을 빌드에서 제거하고 mock 데이터로 대체하여 시뮬레이터에서 실행합니다.

## 주의사항
- Railway 배포 서버 사용 시 로컬 백엔드 서버 불필요
- 시뮬레이터: UI, 로그인, API 통신, 규칙 평가 등 ML Kit 제외 전체 기능 테스트 가능
- 실제 iPhone: ML Kit 포즈 감지 포함 전체 기능 테스트 가능
- 첫 빌드 시 Xcode에서 Signing 설정 필요: `open rexx_app/ios/Runner.xcworkspace`
