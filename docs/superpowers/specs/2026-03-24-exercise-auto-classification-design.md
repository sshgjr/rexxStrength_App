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
- Upper body motion: Elbow ROM + Shoulder vertical movement
- Lower body motion: Knee ROM + Hip vertical movement
- Ratio = upper / (upper + lower)
- 벤치프레스: 상체 위주 (ratio > 0.6), 스쿼트: 하체 위주 (ratio < 0.4), 데드리프트: 혼합

**Feature 3: Torso Orientation**
- `AngleCalculator.calculateVerticalAngle(shoulder, hip)` 의 프레임 평균
- 벤치프레스: 수평에 가까움 (< 30°), 스쿼트/데드리프트: 수직~전방 경사 (50°~80°)
- 벤치프레스 판별의 가장 강력한 단일 특징

### 1.2 Scoring

각 운동에 대해 특징별 유사도 점수를 산출하고 가중합으로 확률을 계산한다:

```
exerciseScore(type) = w1 * romScore(type) + w2 * ratioScore(type) + w3 * orientationScore(type)
```

3개 운동의 점수를 softmax 또는 단순 정규화로 확률(0~1, 합=1.0)로 변환한다.

### 1.3 Confidence Thresholds

| Condition | Confidence Level | Action |
|-----------|-----------------|--------|
| bestProb ≥ 0.60 | `high` | 자동 확정, 바로 평가 진행 |
| bestProb - secondProb < 0.10 | `ambiguous` | 상위 2개 선택지 알림창 |
| bestProb < 0.40 | `failed` | 분류 실패 플로우 |

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
- 분류 결과의 confidence에 따라 콜백으로 UI에 알림

## 3. Data Models

### ClassificationResult

```dart
enum ClassificationConfidence { high, ambiguous, failed }

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
  - 탭하면 바로 갤러리에서 영상 선택 → 자동 분류 파이프라인
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

## 6. Error Handling

- ML Kit 포즈 감지 실패 (landmarks가 부족한 프레임): 해당 프레임 무시, 유효 프레임만으로 분류
- 전체 프레임에서 유효 포즈가 너무 적은 경우 (< 5프레임): "영상에서 포즈를 충분히 감지하지 못했습니다" 에러
- 분류와 평가 모두 기존 오프라인 동작 유지 (네트워크 불필요)

## 7. Testing Strategy

- `ExerciseClassifier` 유닛 테스트: 각 운동의 대표적 랜드마크 패턴을 mock 데이터로 생성하여 분류 정확도 검증
- Confidence threshold 경계값 테스트: 60%, 40%, 차이 10% 경계에서의 동작 확인
- 위젯 테스트: 각 다이얼로그의 버튼 동작 및 네비게이션 검증
