# Wrist Curl (리스트컬) 운동 평가 설계

> BlazePose 랜드마크 기반 리스트컬 자세 평가 규칙 및 자동 분류 확장

## Context

기존 3대 운동(스쿼트, 벤치프레스, 데드리프트)에 리스트컬을 추가한다. 리스트컬은 전완(forearm) 격리 운동으로, 기존 복합 운동과 동작 패턴이 근본적으로 다르다. BlazePose의 손목(wrist), 검지(index) 랜드마크를 활용하여 손목 굴곡/신전 각도를 측정한다.

### 기하학적 모델 참고

`elbow→wrist→index` 3점 각도는 손목 관절의 굴곡/신전을 간접 측정한다:
- **중립/신전 (이완)**: 팔꿈치-손목-검지가 거의 일직선 → **~160-180°**
- **최대 굴곡 (수축)**: 검지가 전완 방향으로 접힘 → **~100-130°**
- **실제 ROM**: 약 30-60° 변화폭

> **주의**: BlazePose의 index finger 랜드마크(19, 20)는 덤벨 그립 시 가려질 수 있다. 각 프레임에서 `likelihood ≥ 0.5` 체크를 필수로 수행하며, 임계값 미만 프레임은 스킵한다. 임계값은 테스트 시 조정 가능.

## Decision Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| 손목 각도 측정 | 팔꿈치→손목→검지 3점 각도 | BlazePose에 index(19,20) 존재, 3D 각도 계산 가능. likelihood 체크로 품질 보장 |
| 각도 범위 | 중립 ~170°, 수축 ~110° | 기하학적으로 정확한 범위. 테스트 후 보정 예정 |
| 평가 기준 수 | 5개 (기존 패턴 동일) | 코드 일관성, UI 호환성 유지 |
| 가중치 총합 | 1.0 | 기존 패턴 준수 |
| 페이즈 감지 | 손목 각도 기반 | 최소 손목 각도 = peak contraction (bottom) |
| 자동 분류 | 손목 ROM 특징 추가 | 기존 3운동과 확실히 구분 가능 |
| apiName | `'wrist_curl'` | 기존 snake_case 네이밍 준수 |

## 1. PoseFrame 랜드마크 상수 추가

BlazePose 인덱스 19, 20을 `PoseFrame`에 추가:

```dart
static const int leftIndex = 19;   // 왼쪽 검지
static const int rightIndex = 20;  // 오른쪽 검지
```

## 2. WristCurlRules — 평가 기준 5개

모든 기준에서 index finger 랜드마크의 `likelihood ≥ 0.5` 체크 필수. 미달 프레임은 스킵.

### 2.1 손목 가동범위 (Wrist ROM) — 30%

손목 관절의 굴곡-신전 범위를 측정한다.

- **측정**: `AngleCalculator.calculateAngle(elbow, wrist, indexFinger)` 의 max - min
- **이상적 범위**: ROM 30~60° (충분한 가동범위)
- **스코어링**: `rangeScore(rom, idealMin: 30, idealMax: 60, tolerance: 20)`

### 2.2 팔꿈치 고정도 (Elbow Stability) — 25%

리스트컬 중 팔꿈치가 고정되어야 한다. 팔꿈치 좌표 이동이 적을수록 좋다.

- **측정**: 전 프레임에서 팔꿈치 (x, y) 좌표의 표준편차 계산
- **정규화**: 체고(shoulder-ankle 거리) 대비 정규화된 이동량
- **스코어링**: 정규화된 std ≤ 0.02 → 100점, ≥ 0.08 → 0점, 선형 보간
- **유틸리티**: `AngleCalculator`에 `positionStability(landmarks, bodyHeight)` 메서드 추가

### 2.3 동작 일관성 (Rep Consistency) — 20%

여러 반복 수행 시 각 반복의 ROM이 일정해야 한다.

- **측정**: 손목 각도 시계열에서 단순 피크/밸리 감지 (이전 프레임 대비 방향 전환점)
- **알고리즘**: 각도가 증가→감소로 바뀌는 지점 = 피크, 감소→증가 = 밸리. 인접 피크-밸리 차이 = 1회 반복 ROM
- **스코어링**: 반복 간 ROM 표준편차. std ≤ 5° → 100점, ≥ 20° → 0점, 선형 보간
- **엣지 케이스**: 단일 반복(피크 1개 이하) → 기본 70점 (평가 불가)

### 2.4 최대 수축 각도 (Peak Contraction) — 15%

손목 최대 굴곡 시 충분히 수축했는지 평가.

- **측정**: `AngleCalculator.calculateAngle(elbow, wrist, indexFinger)` 의 최소값
- **이상적 범위**: 100~140° (충분한 수축, 낮을수록 더 깊은 굴곡)
- **스코어링**: `rangeScore(minAngle, idealMin: 100, idealMax: 140, tolerance: 25)`

### 2.5 좌우 대칭 (Symmetry) — 10%

양쪽 손목 각도 차이를 비교한다.

- **측정**: 좌/우 손목 각도(`elbow→wrist→index`)의 프레임별 차이
- **스코어링**: `AngleCalculator.symmetryScore(leftAngle, rightAngle, threshold: 5.0)` 평균
- **엣지 케이스**: 한쪽 랜드마크 부재 시 기본 70점

## 3. PhaseDetector — 리스트컬 페이즈 감지

손목 각도(elbow→wrist→index) 기반. 기존 `PhaseDetector`는 현재 evaluate에서 직접 사용되지 않지만, 향후 확장을 위해 기존 패턴대로 추가.

| Phase | 조건 |
|-------|------|
| setup | bottomIndex * 0.3 이전 프레임 |
| descent | setup 이후 ~ bottomIndex 이전 (손목 굴곡 진행) |
| bottom | 최소 손목 각도 프레임 (최대 수축) |
| ascent | bottom 이후 ~ 90% 이전 (손목 신전) |
| lockout | 마지막 10% (완전 이완) |

## 4. ExerciseClassifier — 자동 분류 확장

### 4.1 새 특징: 손목 ROM

기존 `_extractROMs`에 wrist ROM 추가:

```dart
// 추가 랜드마크 (likelihood 체크 포함)
final indexIdx = useLeft ? PoseFrame.leftIndex : PoseFrame.rightIndex;

// Wrist ROM: AngleCalculator.calculateAngle(elbow, wrist, indexFinger)
'wrist': wristMax > wristMin ? wristMax - wristMin : 0,
```

`chooseSide()`에도 index finger 랜드마크 추가하여 가시성 판단에 반영.

### 4.2 분류 프로필

| Feature | 리스트컬 이상 범위 |
|---------|-------------------|
| ROM | wrist ROM 20~60° (주 동작 관절) |
| Motion Ratio | 0.70~0.95 (거의 전부 상체/전완) |
| Torso Orientation | 10~40° (앉아서 또는 서서 수행, 대체로 직립) |

### 4.3 스코어링 함수 변경

`_romScore()`, `_ratioScore()`, `_orientationScore()` 3개 메서드에 모두 `case ExerciseType.wristCurl:` 추가:

```dart
// _romScore
case ExerciseType.wristCurl:
  return AngleCalculator.rangeScore(roms['wrist']!, idealMin: 20, idealMax: 60, tolerance: 20);

// _ratioScore
case ExerciseType.wristCurl:
  return AngleCalculator.rangeScore(ratio, idealMin: 0.70, idealMax: 0.95, tolerance: 0.20);

// _orientationScore
case ExerciseType.wristCurl:
  return AngleCalculator.rangeScore(avgAngle, idealMin: 10, idealMax: 40, tolerance: 20);
```

### 4.4 정규화 업데이트

2곳의 균등 확률 fallback을 `1.0 / 4`로 업데이트:
- `classify()` 내 프레임 부족 시 early return (line ~19)
- `classify()` 내 totalScore ≤ 0 fallback (line ~49)

메인 정규화 경로는 `ExerciseType.values` 순회이므로 자동 반영.

### 4.5 motionRatio 안정화

wrist ROM을 upper motion 계산에 반영하여 리스트컬의 ratio가 안정적으로 상체 우세로 나오도록 함:

```dart
final upperMotion = roms['elbow']! + roms['wrist']! + normalizedShoulderMove;
```

## 5. 변경 파일 목록

모든 경로는 `rexx_app/lib/features/pose_evaluation/` 기준.

| 파일 | 변경 내용 |
|------|----------|
| `models/pose_frame.dart` | `leftIndex(19)`, `rightIndex(20)` 상수 추가 |
| `models/exercise_phase.dart` | `ExerciseType.wristCurl` 추가 + `displayName: '리스트컬'`, `apiName: 'wrist_curl'` |
| `engine/rules/wrist_curl_rules.dart` | **신규** — 5개 평가 기준 구현 |
| `engine/angle_calculator.dart` | `positionStability()` 유틸리티 메서드 추가 |
| `engine/pose_analyzer.dart` | `_getRule()` switch에 `wristCurl` case 추가 |
| `engine/phase_detector.dart` | `detectWristCurlPhases()` 메서드 추가 |
| `engine/classifier/exercise_classifier.dart` | wrist ROM 추출, `chooseSide` 업데이트, 3개 스코어링 메서드에 wristCurl case, fallback 1/4, motionRatio에 wrist ROM 반영 |
| `screens/exercise_select_screen.dart` | 리스트컬 카드 추가 |
| `widgets/classification_dialogs.dart` | 지원 운동 텍스트에 '리스트컬' 추가 |

### 참고: Dart 컴파일러 안전망

`ExerciseType` enum에 `wristCurl`을 추가하면 모든 exhaustive switch 문에서 컴파일 에러가 발생한다. 위 목록 외에도 다른 switch 문이 있다면 컴파일러가 잡아준다.

### 참고: 서버 사이드

`rexx_server/schemas/pose_schemas.py`의 `exercise_type`은 `str` 타입이므로 `'wrist_curl'`이 자동으로 수용된다. Claude Haiku 프롬프트 템플릿에서 리스트컬 맥락을 이해할 수 있도록 서버의 프롬프트 템플릿 검토가 필요할 수 있으나, 이는 별도 태스크로 분리.

## 6. 테스트 전략

기존 테스트 패턴을 따르며, 각 구성요소별 단위 테스트:

- `WristCurlRules` — 5개 기준 각각에 대한 스코어 검증 (likelihood 필터링 포함)
- `AngleCalculator.positionStability` — 좌표 안정성 계산 검증
- `PhaseDetector.detectWristCurlPhases` — 페이즈 할당 검증
- `ExerciseClassifier` — 리스트컬 특징 입력 시 wristCurl 최고 확률 확인
- 기존 3운동 분류 회귀 테스트 — 리스트컬 추가 후 기존 분류 정확도 유지 확인

## 7. 임계값 보정 계획

모든 각도 임계값은 초기 추정치이다. 다음 단계에서 보정:

1. 리스트컬 영상 2-3개를 BlazePose로 처리하여 실제 `elbow→wrist→index` 각도 범위 로깅
2. 로깅 데이터 기반으로 섹션 2.1, 2.4, 4.2의 임계값 조정
3. 자동 분류기 회귀 테스트 통과 확인
