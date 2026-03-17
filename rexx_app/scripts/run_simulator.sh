#!/bin/bash
# 시뮬레이터용 빌드 스크립트
# EXCLUDE_MLKIT 환경변수를 통해 Podfile이 자동으로 ML Kit을 제외합니다.
# 사용법: ./scripts/run_simulator.sh [simulator-name]
#   예: ./scripts/run_simulator.sh "iPhone 17 Pro"

set -e

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SIMULATOR_NAME="${1:-iPhone 17 Pro}"

cd "$APP_DIR"

echo "=== 시뮬레이터 빌드 (ML Kit 제외) ==="

# 종료 시 원래 상태 복원
cleanup() {
    echo ""
    echo "=== 원래 상태 복원 ==="
    cd "$APP_DIR"
    flutter pub get --suppress-analytics 2>/dev/null
    cd ios && pod install --silent 2>/dev/null || true
    echo "복원 완료!"
}
trap cleanup EXIT

# 1. 시뮬레이터 부팅
echo "[1/3] 시뮬레이터 부팅: $SIMULATOR_NAME..."
xcrun simctl boot "$SIMULATOR_NAME" 2>/dev/null || true
open -a Simulator

# 2. EXCLUDE_MLKIT=true로 빌드 준비 (Podfile이 ML Kit 자동 제거)
echo "[2/3] 빌드 준비 (ML Kit 제외)..."
export EXCLUDE_MLKIT=true
flutter clean --suppress-analytics 2>/dev/null
flutter pub get --suppress-analytics 2>/dev/null
cd ios && rm -rf Pods Podfile.lock && pod install 2>&1 | tail -1 && cd ..

# 3. Flutter 빌드 및 실행
echo "[3/3] Flutter 빌드 및 실행..."
echo ""
flutter run \
  --dart-define=SIMULATOR_MODE=true \
  -d "$SIMULATOR_NAME"
