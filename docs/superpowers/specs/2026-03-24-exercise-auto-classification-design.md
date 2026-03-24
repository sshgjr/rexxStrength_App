# Exercise Auto-Classification Design

> ML Kit 포즈 랜드마크 기반 3대 운동(스쿼트, 벤치프레스, 데드리프트) 자동 분류 시스템

## Context

현재 사용자가 영상 분석 전에 운동 종류를 수동 선택해야 한다. 이를 ML Kit에서 추출된 33개 BlazePose 랜드마크의 각도 패턴으로 자동 판별하는 알고리즘을 추가한다.

## Decision Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Classification timing | 포즈 감지 후, 점수 산출 전 (approach A) | 전체 프레임 패턴을 보는 것이 정확도 최고 |
| Ambiguous case | 상위 2개 선택지 알림창 | 사용자 선택권 보장 |
| Classification failure | 지원 운동 확인 → 선택 or 입력 | 완전 차단 대신 유연한 처리 |
| Exercise select screen | 자동 분류 기본 + 수동 선택 병존 | 숙련 사용자 빠른 경로 보장 |

## 1. Classification Algorithm — `ExerciseClassifier`

### 1.1 Feature Extraction

전체 프레임의 포즈 데이터에서 3가지 특징 벡터를 추출한다:

**Feature 1: Joint ROM (Range of Motion)**
- Knee ROM: `AngleCalculator.calculateAngle(hip, knee, ankle)` — max와 min의 차이
- Elbow ROM: `AngleCalculator.calculateAngle(shoulder, elbow, wrist)` — max와 min의 차이
- Hip ROM: `AngleCalculator.calculateAngle(shoulder, hip, knee)` — max와 min의 차이
- 각 운동은 주요 관절의 ROM이 가장 크다 (스쿼트→무릎, 벤치→팔꿈치, 데드리프트→힙)

**Feature 2: Upper/Lower Body Motion Ratio**
- Shoulder vertical movement: shoulder landmark Y 좌표의 (max - min), 체고(shoulder-ankle Y 거리) 대비 정규화
- Hip vertical movement: hip landmark Y 좌표의 (max - min), 동일하게 정규화
- Upper body motion = Elbow ROM + normalized Shoulder vertical movement
- Lower body motion = Knee ROM + normalized Hip vertical movement
- Ratio = upper / (upper + lower)
- 벤치프레스: 상체 위주 (ratio > 0.6), 스쿼트: 하체 위주 (ratio < 0.4), 데드리프트: 혼합

**Feature 3: Torso Orientation**
- `AngleCalculator.calculateVerticalAngle(shoulder, hip)` 의 프레임 평균
- 이 함수는 **수직(Y축) 기준** 각도를 반환: 직립 ≈ 0°, 수평(누움) ≈ 90°
- 벤치프레스: 수평에 가까움 (**> 70°**), 스쿼트: 비교적 수직 (**10°~30°**), 데드리프트: 전방 경사 (**30°~55°**)
- 벤치프레스 판별의 가장 강력한 단일 특징

### 1.2 Scoring

각 운동에 대해 특징별 유사도 점수를 산출하고 가중합으로 확률을 계산한다:

```
exerciseScore(type) = w1 * romScore(type) + w2 * ratioScore(type) + w3 * orientationScore(type)
```

**Feature Weights:** `w1 = 0.35` (ROM), `w2 = 0.25` (상하체 비율), `w3 = 0.40` (torso orientation)
- w3이 가장 높은 이유: torso orientation은 벤치프레스(누움)를 스쿼트/데드리프트와 확실히 구분하는 가장 강력한 단일 특징
- w1이 w2보다 높은 이유: 주요 관절 ROM이 스쿼트 vs 데드리프트 구분에 핵심적

**Per-Exercise Scoring Functions:**

`romScore(type)` — 주요 관절 ROM이 해당 운동의 기대 패턴과 일치하는 정도:
```
romScore(squat)     = rangeScore(kneeROM, idealMin: 60, idealMax: 120, tolerance: 30)
romScore(benchPress)= rangeScore(elbowROM, idealMin: 50, idealMax: 110, tolerance: 30)
romScore(deadlift)  = rangeScore(hipROM, idealMin: 50, idealMax: 100, tolerance: 30)
```

`ratioScore(type)` — 상하체 동작 비율이 기대치와 일치하는 정도:
```
ratioScore(squat)     = rangeScore(ratio, idealMin: 0.15, idealMax: 0.40, tolerance: 0.20)
ratioScore(benchPress)= rangeScore(ratio, idealMin: 0.60, idealMax: 0.90, tolerance: 0.20)
ratioScore(deadlift)  = rangeScore(ratio, idealMin: 0.35, idealMax: 0.60, tolerance: 0.20)
```

`orientationScore(type)` — 평균 torso 각도가 기대치와 일치하는 정도 (수직 기준):
```
orientationScore(squat)     = rangeScore(avgAngle, idealMin: 10, idealMax: 30, tolerance: 20)
orientationScore(benchPress)= rangeScore(avgAngle, idealMin: 70, idealMax: 90, tolerance: 20)
orientationScore(deadlift)  = rangeScore(avgAngle, idealMin: 30, idealMax: 55, tolerance: 20)
```

3개 운동의 점수를 단순 정규화로 확률(0~1, 합=1.0)로 변환한다:
```
probability(type) = exerciseScore(type) / sum(allScores)
```

### 1.3 Confidence Thresholds

| Condition | Confidence Level | Action |
|-----------|-----------------|--------|
| bestProb ≥ 0.60 | `high` | 자동 확정, 바로 평가 진행 |
| 0.40 ≤ bestProb < 0.60 AND bestProb - secondProb ≥ 0.10 | `moderate` | 자동 확정 + "_{운동명}_(으)로 분석합니다" 토스트 표시 |
| 0.40 ≤ bestProb < 0.60 AND bestProb - secondProb < 0.10 | `ambiguous` | 상위 2개 선택지 알림창 |
| bestProb < 0.40 | `failed` | 분류 실패 플로우 |

**평가 우선순위:** 위에서부터 순서대로 평가하며, 첫 번째로 만족하는 조건을 적용한다.

## 2. Pipeline Change

```
기존:  운동 선택 → 영상 업로드 → 프레임 추출 → 포즈 감지 → 규칙 평가 → 결과

변경:  영상 업로드 → 프레임 추출 → 포즈 감지 → [자동 분류] → 규칙 평가 → 결과
                                                 ↓ (ambiguous)
                                           상위 2개 선택 알림
                                                 ↓ (failed)
                                           분류 실패 플로우
```

### PoseAnalyzer 변경

`PoseAnalyzer.analyze()` 메서드에 분류 단계 삽입:

```dart
// 기존: ExerciseType을 매개변수로 받음
Future<EvaluationResult> analyze(File video, ExerciseType type, ...)

// 변경: ExerciseType이 null이면 자동 분류
Future<EvaluationResult> analyze(File video, {ExerciseType? type, ...})
```

- `type`이 제공되면 기존처럼 해당 규칙으로 바로 평가 (수동 선택 경로)
- `type`이 null이면 `ExerciseClassifier.classify(frames)`를 호출하여 분류
- `analyzeWithDebug()` 메서드에도 동일한 optional type + 콜백 패턴 적용

**UI 통신 메커니즘:** `analyze()`가 `ClassificationResult`를 직접 반환하지 않고, 콜백 기반으로 UI에 분류 결과를 전달한다:

```dart
Future<EvaluationResult> analyze(
  File video, {
  ExerciseType? type,
  Future<ExerciseType> Function(ClassificationResult)? onClassificationNeeded,
  void Function(String)? onProgress,
})
```

- `confidence == high || moderate`: 자동 확정, 콜백 호출 없이 진행
- `confidence == ambiguous || failed`: `onClassificationNeeded` 콜백을 await하여 사용자 선택을 받음
- 콜백이 null이면 (테스트 등) bestMatch로 자동 확정

## 3. Data Models

### ClassificationResult

```dart
enum ClassificationConfidence { high, moderate, ambiguous, failed }

class ClassificationResult {
  final Map<ExerciseType, double> probabilities;
  final ExerciseType bestMatch;
  final ExerciseType? secondMatch;
  final ClassificationConfidence confidence;
}
```

## 4. UI Changes

### 4.1 ExerciseSelectScreen Redesign

**레이아웃:**
- 상단 영역: **"영상으로 자동 분석"** 큰 버튼 (primary color 강조)
  - 탭하면 VideoUploadScreen으로 이동 (`type: null`). 기존과 동일하게 갤러리 선택 → 영상 미리보기 → 분석 시작 플로우 유지. 단, 분석 시 자동 분류가 먼저 수행됨.
- 구분선 + 안내 문구: "더 빠른 분석을 원하시면 직접 선택하세요"
- 하단 영역: 기존 3개 운동 카드 (축소된 형태)
  - 탭하면 기존처럼 해당 운동으로 바로 VideoUploadScreen 진입

### 4.2 Ambiguous Classification Dialog

1위와 2위 확률 차이가 10% 미만일 때 표시:
- 제목: "운동 종류를 확인해 주세요"
- 상위 2개 운동을 버튼으로 제시 (확률 높은 순)
- 선택하면 해당 운동으로 평가 진행

### 4.3 Classification Failed Flow

**Step 1 — 확인 다이얼로그:**
- 제목: "운동을 판별하지 못했어요"
- 본문: "분석 가능한 운동 영상이 맞나요?"
- 하단에 지원 운동 목록 작게 표시: `현재 지원: 스쿼트 · 벤치프레스 · 데드리프트`
- 버튼: "예" / "아니오"

**Step 2a — "예" 선택:**
- 3개 운동을 확률 높은 순으로 정렬하여 선택지 제시
- 선택하면 해당 운동으로 평가 진행

**Step 2b — "아니오" 선택:**
- 운동 종류 텍스트 입력 필드 표시
- 제출 시 감사 메시지 표시 (다크 그린 테마에 맞는 톤)
  - 예: "소중한 의견 감사합니다! 더 다양한 운동을 지원할 수 있도록 참고하겠습니다 💪"
- 이후 선택지 제시:
  - "다른 영상 분석하기" → ExerciseSelectScreen으로 이동
  - "메인으로 돌아가기" → HomeScreen으로 이동

## 5. File Structure

### New Files

```
engine/classifier/
└── exercise_classifier.dart     — ExerciseClassifier 클래스 (분류 알고리즘)

models/
└── classification_result.dart   — ClassificationResult, ClassificationConfidence

widgets/
├── ambiguous_dialog.dart        — 상위 2개 선택 다이얼로그
└── classification_failed_dialog.dart — 분류 실패 플로우 다이얼로그
```

### Modified Files

```
engine/pose_analyzer.dart        — analyze() 시그니처 변경, 분류 단계 삽입
screens/exercise_select_screen.dart — 자동분석 버튼 추가, 레이아웃 재설계
screens/video_upload_screen.dart — 분류 결과 처리 로직 (콜백 기반)
```

## 6. Landmark Side Selection

분류 시 좌측/우측 랜드마크 중 likelihood가 높은 쪽을 사용한다:
```dart
// 프레임별로 좌/우 landmark likelihood 평균 비교
// 높은 쪽의 관절 좌표로 각도 계산
final leftConf = avg(leftShoulder.likelihood, leftHip.likelihood, leftKnee.likelihood, ...);
final rightConf = avg(rightShoulder.likelihood, rightHip.likelihood, rightKnee.likelihood, ...);
// 전체 프레임 중 과반수 기준으로 한쪽 선택 (프레임마다 바뀌지 않음)
```

이는 사용자가 어느 방향에서 촬영하더라도 분류 정확도를 유지하기 위함이다.

## 7. Unsupported Exercise Feedback Storage

분류 실패 후 사용자가 입력한 운동 종류는 SharedPreferences에 로컬 저장한다:
```dart
// key: 'unsupported_exercise_requests'
// value: JSON array of {exercise: String, timestamp: String}
```
추후 분석 시 어떤 운동 지원 요청이 많은지 확인할 수 있도록 한다. 네트워크 연결 시 서버에 동기화하는 것은 이 설계 범위 밖이다.

## 8. Error Handling

- ML Kit 포즈 감지 실패 (landmarks가 부족한 프레임): 해당 프레임 무시, 유효 프레임만으로 분류
- 전체 프레임에서 유효 포즈가 너무 적은 경우 (< 5프레임): "영상에서 포즈를 충분히 감지하지 못했습니다" 에러
- 분류와 평가 모두 기존 오프라인 동작 유지 (네트워크 불필요)

## 9. Testing Strategy

- `ExerciseClassifier` 유닛 테스트: 각 운동의 대표적 랜드마크 패턴을 mock 데이터로 생성하여 분류 정확도 검증
- Confidence threshold 경계값 테스트: 60%, 40%, 차이 10% 경계에서의 동작 확인
- 위젯 테스트: 각 다이얼로그의 버튼 동작 및 네비게이션 검증
- 통합 테스트: `PoseAnalyzer.analyze(video, type: null)`에서 분류→평가 전체 파이프라인 동작 확인, `type` 제공 시 분류 단계 건너뛰기 확인
