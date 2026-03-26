# Wrist Curl (리스트컬) 운동 추가 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 리스트컬 운동의 자세 평가 규칙, 페이즈 감지, 자동 분류를 기존 시스템에 추가한다.

**Architecture:** 기존 `ExerciseRule` 인터페이스를 구현하는 `WristCurlRules` 클래스를 추가하고, `ExerciseType` enum에 `wristCurl`을 등록한다. BlazePose의 elbow→wrist→index 3점 각도로 손목 굴곡/신전을 측정하며, 자동 분류기에 손목 ROM 특징을 추가하여 기존 3운동과 구분한다.

**Tech Stack:** Dart/Flutter, BlazePose (ML Kit), flutter_test

**Spec:** `docs/superpowers/specs/2026-03-26-wrist-curl-exercise-design.md`

---

### Task 1: PoseFrame 랜드마크 상수 추가

**Files:**
- Modify: `rexx_app/lib/features/pose_evaluation/models/pose_frame.dart:56-69`
- Test: `rexx_app/test/features/pose_evaluation/models/pose_frame_test.dart`

- [ ] **Step 1: 테스트 작성 — 새 랜드마크 상수 검증**

`pose_frame_test.dart`의 '랜드마크 상수 값 확인' 그룹에 추가:

```dart
test('검지 랜드마크 상수 값', () {
  expect(PoseFrame.leftIndex, 19);
  expect(PoseFrame.rightIndex, 20);
});
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

Run: `cd rexx_app && flutter test test/features/pose_evaluation/models/pose_frame_test.dart -v`
Expected: FAIL — `leftIndex`, `rightIndex` 미정의

- [ ] **Step 3: 구현 — PoseFrame에 상수 추가**

`pose_frame.dart` 의 기존 상수 블록 (line 69 `rightFootIndex` 다음)에 추가:

```dart
static const int leftIndex = 19;   // 왼쪽 검지
static const int rightIndex = 20;  // 오른쪽 검지
```

- [ ] **Step 4: 테스트 실행 — 통과 확인**

Run: `cd rexx_app && flutter test test/features/pose_evaluation/models/pose_frame_test.dart -v`
Expected: ALL PASS

- [ ] **Step 5: 커밋**

```bash
cd rexx_app && git add lib/features/pose_evaluation/models/pose_frame.dart test/features/pose_evaluation/models/pose_frame_test.dart && git commit -m "feat: PoseFrame에 검지 랜드마크 상수 추가 (leftIndex, rightIndex)"
```

---

### Task 2: ExerciseType enum에 wristCurl 추가

**Files:**
- Modify: `rexx_app/lib/features/pose_evaluation/models/exercise_phase.dart`
- Test: `rexx_app/test/features/pose_evaluation/models/evaluation_result_test.dart`

- [ ] **Step 1: 테스트 작성 — wristCurl displayName / apiName**

`evaluation_result_test.dart`의 `ExerciseType` 그룹에 추가:

```dart
test('wristCurl displayName은 리스트컬', () {
  expect(ExerciseType.wristCurl.displayName, '리스트컬');
});

test('wristCurl apiName은 wrist_curl', () {
  expect(ExerciseType.wristCurl.apiName, 'wrist_curl');
});
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

Run: `cd rexx_app && flutter test test/features/pose_evaluation/models/evaluation_result_test.dart -v`
Expected: FAIL — `wristCurl` 미정의

- [ ] **Step 3: 구현 — ExerciseType에 wristCurl 추가**

`exercise_phase.dart` 수정:

```dart
enum ExerciseType {
  squat,
  benchPress,
  deadlift,
  wristCurl;

  String get displayName {
    switch (this) {
      case ExerciseType.squat: return '스쿼트';
      case ExerciseType.benchPress: return '벤치프레스';
      case ExerciseType.deadlift: return '데드리프트';
      case ExerciseType.wristCurl: return '리스트컬';
    }
  }

  String get apiName {
    switch (this) {
      case ExerciseType.squat: return 'squat';
      case ExerciseType.benchPress: return 'bench_press';
      case ExerciseType.deadlift: return 'deadlift';
      case ExerciseType.wristCurl: return 'wrist_curl';
    }
  }
}
```

> **주의:** enum 추가 시 모든 exhaustive switch에서 컴파일 에러가 발생하므로, 이 Task에서 모든 switch를 함께 수정한다.

- [ ] **Step 4: 모든 exhaustive switch 업데이트**

**4a. `pose_analyzer.dart`** — import 추가 및 `_getRule` 확장:

상단 import에 추가:
```dart
import 'rules/wrist_curl_rules.dart';
```

`_getRule` 메서드에 case 추가:
```dart
case ExerciseType.wristCurl:
  return WristCurlRules();
```

> 참고: `WristCurlRules` 클래스는 Task 4에서 생성. 이 시점에서는 빈 구현으로 파일만 먼저 생성한다 (Step 4b).

**4b. 빈 `wrist_curl_rules.dart` 생성** (Task 4에서 전체 구현):

```dart
import '../../models/pose_frame.dart';
import '../../models/evaluation_result.dart';
import 'exercise_rule.dart';

/// 리스트컬 평가 규칙 (구현은 Task 4에서 완성)
class WristCurlRules implements ExerciseRule {
  @override
  String get name => '리스트컬';

  @override
  List<CriterionResult> evaluate(List<PoseFrame> frames) {
    return [];
  }
}
```

**4c. `exercise_classifier.dart`** — 3개 스코어링 메서드에 wristCurl case 추가:

```dart
// _romScore — 임시로 0 반환 (Task 7에서 완전 구현)
case ExerciseType.wristCurl:
  return AngleCalculator.rangeScore(roms['wrist'] ?? 0, idealMin: 20, idealMax: 60, tolerance: 20);

// _ratioScore
case ExerciseType.wristCurl:
  return AngleCalculator.rangeScore(ratio, idealMin: 0.70, idealMax: 0.95, tolerance: 0.20);

// _orientationScore
case ExerciseType.wristCurl:
  return AngleCalculator.rangeScore(avgAngle, idealMin: 10, idealMax: 40, tolerance: 20);
```

또한 `classify()`의 균등 확률 fallback 2곳을 동적으로 변경:
```dart
final count = ExerciseType.values.length;
// 기존 하드코딩된 1/3을 1/count로 교체
```

- [ ] **Step 5: flutter analyze 전체 확인**

Run: `cd rexx_app && flutter analyze`
Expected: No issues found (모든 exhaustive switch 해소)

- [ ] **Step 6: 테스트 실행 — 통과 확인**

Run: `cd rexx_app && flutter test test/features/pose_evaluation/models/evaluation_result_test.dart -v`
Expected: ALL PASS

- [ ] **Step 7: 커밋**

```bash
cd rexx_app && git add lib/features/pose_evaluation/models/exercise_phase.dart lib/features/pose_evaluation/engine/pose_analyzer.dart lib/features/pose_evaluation/engine/rules/wrist_curl_rules.dart lib/features/pose_evaluation/engine/classifier/exercise_classifier.dart test/features/pose_evaluation/models/evaluation_result_test.dart && git commit -m "feat: ExerciseType.wristCurl 추가 및 모든 exhaustive switch 해소"
```

---

### Task 3: AngleCalculator에 positionStability 유틸리티 추가

**Files:**
- Modify: `rexx_app/lib/features/pose_evaluation/engine/angle_calculator.dart`
- Test: `rexx_app/test/features/pose_evaluation/engine/angle_calculator_test.dart`

- [ ] **Step 1: 테스트 작성 — positionStability**

`angle_calculator_test.dart`에 그룹 추가:

```dart
group('AngleCalculator.positionStability', () {
  test('좌표가 고정이면 100점', () {
    final positions = [
      _lm(0.5, 0.5),
      _lm(0.5, 0.5),
      _lm(0.5, 0.5),
    ];
    expect(AngleCalculator.positionStability(positions, 0.6), 100.0);
  });

  test('좌표 이동이 크면 0점', () {
    final positions = [
      _lm(0.1, 0.1),
      _lm(0.5, 0.5),
      _lm(0.9, 0.9),
    ];
    final score = AngleCalculator.positionStability(positions, 0.6);
    expect(score, 0.0);
  });

  test('중간 이동이면 중간 점수', () {
    final positions = [
      _lm(0.5, 0.5),
      _lm(0.52, 0.51),
      _lm(0.49, 0.50),
    ];
    final score = AngleCalculator.positionStability(positions, 0.6);
    expect(score, greaterThan(0));
    expect(score, lessThan(100));
  });
});
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

Run: `cd rexx_app && flutter test test/features/pose_evaluation/engine/angle_calculator_test.dart -v`
Expected: FAIL — `positionStability` 미정의

- [ ] **Step 3: 구현**

`angle_calculator.dart` 끝에 추가:

```dart
/// 좌표 안정성 점수 (0-100)
/// 랜드마크 리스트의 (x, y) 좌표 표준편차를 체고 대비 정규화하여 평가
/// stableThreshold (0.02) 이하면 100점, unstableThreshold (0.08) 이상이면 0점
static double positionStability(
  List<PoseLandmark> positions,
  double bodyHeight, {
  double stableThreshold = 0.02,
  double unstableThreshold = 0.08,
}) {
  if (positions.isEmpty || bodyHeight <= 0) return 50.0;

  double sumX = 0, sumY = 0;
  for (final p in positions) {
    sumX += p.x;
    sumY += p.y;
  }
  final meanX = sumX / positions.length;
  final meanY = sumY / positions.length;

  double sumSqDist = 0;
  for (final p in positions) {
    sumSqDist += (p.x - meanX) * (p.x - meanX) + (p.y - meanY) * (p.y - meanY);
  }
  final std = sqrt(sumSqDist / positions.length);
  final normalizedStd = std / bodyHeight;

  if (normalizedStd <= stableThreshold) return 100.0;
  if (normalizedStd >= unstableThreshold) return 0.0;

  return 100.0 * (1 - (normalizedStd - stableThreshold) / (unstableThreshold - stableThreshold));
}
```

- [ ] **Step 4: 테스트 실행 — 통과 확인**

Run: `cd rexx_app && flutter test test/features/pose_evaluation/engine/angle_calculator_test.dart -v`
Expected: ALL PASS

- [ ] **Step 5: 커밋**

```bash
cd rexx_app && git add lib/features/pose_evaluation/engine/angle_calculator.dart test/features/pose_evaluation/engine/angle_calculator_test.dart && git commit -m "feat: AngleCalculator에 positionStability 유틸리티 추가"
```

---

### Task 4: WristCurlRules 전체 구현

Task 2에서 빈 `WristCurlRules`를 생성했으므로, 이 Task에서 전체 구현으로 교체한다.

**Files:**
- Modify: `rexx_app/lib/features/pose_evaluation/engine/rules/wrist_curl_rules.dart`
- Create: `rexx_app/test/features/pose_evaluation/engine/rules/wrist_curl_rules_test.dart`

- [ ] **Step 1: 테스트 작성**

`wrist_curl_rules_test.dart` 생성:

```dart
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:rexx_app/features/pose_evaluation/models/pose_frame.dart';
import 'package:rexx_app/features/pose_evaluation/models/evaluation_result.dart';
import 'package:rexx_app/features/pose_evaluation/engine/rules/wrist_curl_rules.dart';

PoseLandmark _lm(int index, double x, double y, {double z = 0, double likelihood = 0.9}) {
  return PoseLandmark(index: index, x: x, y: y, z: z, likelihood: likelihood);
}

/// 좋은 리스트컬 시뮬레이션:
/// - 손목 각도가 170° → 120° → 170° (ROM ~50°)
/// - 팔꿈치 고정
/// - 일관된 반복
///
/// 기하학: 팔꿈치(0.5, 0.4)→손목(0.5, 0.55) 벡터는 (0, 0.15) 방향.
/// 검지는 손목에서 반경 0.1, elbow→wrist 방향 기준 targetAngle만큼 회전.
List<PoseFrame> _goodWristCurlFrames() {
  final frames = <PoseFrame>[];
  final wristAngles = [170.0, 155.0, 135.0, 120.0, 135.0, 155.0, 170.0, 155.0, 135.0, 120.0, 135.0, 155.0, 170.0];

  // elbow→wrist 방향각 (아래쪽: pi/2 = 90도)
  final elbowX = 0.5;
  final elbowY = 0.4;
  final wristX = 0.5;
  final wristY = 0.55;
  // elbow→wrist 방향: (0, 0.15), 방향각 = pi/2 (Y+ 방향)
  final baseAngle = atan2(wristY - elbowY, wristX - elbowX); // pi/2

  for (int i = 0; i < wristAngles.length; i++) {
    // 목표 각도를 라디안으로. calculateAngle은 0-180 반환.
    // index 위치를 wrist 기준으로 baseAngle + (pi - targetAngle) 방향에 배치
    final targetRad = wristAngles[i] * pi / 180;
    final indexAngle = baseAngle + (pi - targetRad);
    final radius = 0.1;
    final indexX = wristX + radius * cos(indexAngle);
    final indexY = wristY + radius * sin(indexAngle);

    frames.add(PoseFrame(
      frameIndex: i,
      timestamp: i / 5.0,
      landmarks: [
        _lm(PoseFrame.leftShoulder, 0.5, 0.25),
        _lm(PoseFrame.rightShoulder, 0.5, 0.25, likelihood: 0.5),
        _lm(PoseFrame.leftElbow, elbowX, elbowY),
        _lm(PoseFrame.rightElbow, elbowX, elbowY, likelihood: 0.5),
        _lm(PoseFrame.leftWrist, wristX, wristY),
        _lm(PoseFrame.rightWrist, wristX, wristY, likelihood: 0.5),
        _lm(PoseFrame.leftIndex, indexX, indexY),
        _lm(PoseFrame.rightIndex, indexX, indexY, likelihood: 0.5),
        _lm(PoseFrame.leftHip, 0.5, 0.6),
        _lm(PoseFrame.rightHip, 0.5, 0.6, likelihood: 0.5),
        _lm(PoseFrame.leftKnee, 0.5, 0.75),
        _lm(PoseFrame.rightKnee, 0.5, 0.75, likelihood: 0.5),
        _lm(PoseFrame.leftAnkle, 0.5, 0.9),
        _lm(PoseFrame.rightAnkle, 0.5, 0.9, likelihood: 0.5),
      ],
    ));
  }
  return frames;
}

void main() {
  group('WristCurlRules', () {
    late WristCurlRules rules;

    setUp(() {
      rules = WristCurlRules();
    });

    test('name은 리스트컬이다', () {
      expect(rules.name, '리스트컬');
    });

    test('evaluate는 5개 기준을 반환한다', () {
      final results = rules.evaluate(_goodWristCurlFrames());
      expect(results.length, 5);
    });

    test('가중치 합은 1.0이다', () {
      final results = rules.evaluate(_goodWristCurlFrames());
      final weightSum = results.fold(0.0, (sum, c) => sum + c.weight);
      expect(weightSum, closeTo(1.0, 0.01));
    });

    test('좋은 자세면 총점이 50 이상이다', () {
      final results = rules.evaluate(_goodWristCurlFrames());
      final totalScore = results.fold(0.0, (sum, c) => sum + c.score * c.weight);
      expect(totalScore, greaterThan(50));
    });

    test('likelihood 낮은 프레임은 무시된다', () {
      // 모든 index finger의 likelihood를 0.1로 설정
      final frames = _goodWristCurlFrames().map((f) {
        final landmarks = f.landmarks.map((lm) {
          if (lm.index == PoseFrame.leftIndex || lm.index == PoseFrame.rightIndex) {
            return PoseLandmark(index: lm.index, x: lm.x, y: lm.y, z: lm.z, likelihood: 0.1);
          }
          return lm;
        }).toList();
        return PoseFrame(frameIndex: f.frameIndex, timestamp: f.timestamp, landmarks: landmarks);
      }).toList();

      final results = rules.evaluate(frames);
      // 결과가 반환되되 (크래시 없이), 기본값 사용
      expect(results.length, 5);
    });
  });
}
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

Run: `cd rexx_app && flutter test test/features/pose_evaluation/engine/rules/wrist_curl_rules_test.dart -v`
Expected: FAIL — `WristCurlRules` 미정의

- [ ] **Step 3: 구현 — WristCurlRules**

`wrist_curl_rules.dart` 생성:

```dart
import 'dart:math';
import '../../models/pose_frame.dart';
import '../../models/evaluation_result.dart';
import '../angle_calculator.dart';
import 'exercise_rule.dart';

/// 리스트컬 평가 규칙
class WristCurlRules implements ExerciseRule {
  /// likelihood 임계값 — 이 값 미만의 index finger 랜드마크는 무시
  static const double _likelihoodThreshold = 0.5;

  @override
  String get name => '리스트컬';

  @override
  List<CriterionResult> evaluate(List<PoseFrame> frames) {
    return [
      _evaluateWristROM(frames),
      _evaluateElbowStability(frames),
      _evaluateRepConsistency(frames),
      _evaluatePeakContraction(frames),
      _evaluateSymmetry(frames),
    ];
  }

  /// 손목 각도(elbow→wrist→index) 계산, likelihood 필터링
  double? _wristAngle(PoseFrame frame, {bool left = true}) {
    final elbowIdx = left ? PoseFrame.leftElbow : PoseFrame.rightElbow;
    final wristIdx = left ? PoseFrame.leftWrist : PoseFrame.rightWrist;
    final indexIdx = left ? PoseFrame.leftIndex : PoseFrame.rightIndex;

    final elbow = frame.getLandmark(elbowIdx);
    final wrist = frame.getLandmark(wristIdx);
    final index = frame.getLandmark(indexIdx);

    if (elbow == null || wrist == null || index == null) return null;
    if (index.likelihood < _likelihoodThreshold) return null;

    return AngleCalculator.calculateAngle(elbow, wrist, index);
  }

  /// 1. 손목 가동범위 (Wrist ROM) — 30%
  CriterionResult _evaluateWristROM(List<PoseFrame> frames) {
    double minAngle = 180, maxAngle = 0;

    for (final frame in frames) {
      final angle = _wristAngle(frame);
      if (angle == null) continue;
      minAngle = min(minAngle, angle);
      maxAngle = max(maxAngle, angle);
    }

    final rom = maxAngle > minAngle ? maxAngle - minAngle : 0.0;
    final score = AngleCalculator.rangeScore(rom, idealMin: 30, idealMax: 60, tolerance: 20);

    return CriterionResult(
      name: '손목 가동범위',
      description: '손목 가동범위 (ROM)',
      score: score,
      weight: 0.30,
      grade: CriterionGrade.fromScore(score),
    );
  }

  /// 2. 팔꿈치 고정도 (Elbow Stability) — 25%
  CriterionResult _evaluateElbowStability(List<PoseFrame> frames) {
    final elbowPositions = <PoseLandmark>[];
    double bodyHeight = 0.6; // 기본값

    for (final frame in frames) {
      final elbow = frame.getLandmark(PoseFrame.leftElbow);
      final shoulder = frame.getLandmark(PoseFrame.leftShoulder);
      final ankle = frame.getLandmark(PoseFrame.leftAnkle);

      if (elbow != null) elbowPositions.add(elbow);
      if (shoulder != null && ankle != null) {
        final h = (shoulder.y - ankle.y).abs();
        if (h > bodyHeight) bodyHeight = h;
      }
    }

    final score = AngleCalculator.positionStability(elbowPositions, bodyHeight);

    return CriterionResult(
      name: '팔꿈치 고정도',
      description: '팔꿈치 고정도',
      score: score,
      weight: 0.25,
      grade: CriterionGrade.fromScore(score),
    );
  }

  /// 3. 동작 일관성 (Rep Consistency) — 20%
  CriterionResult _evaluateRepConsistency(List<PoseFrame> frames) {
    // 손목 각도 시계열 추출
    final angles = <double>[];
    for (final frame in frames) {
      final angle = _wristAngle(frame);
      if (angle != null) angles.add(angle);
    }

    if (angles.length < 3) {
      return CriterionResult(
        name: '동작 일관성',
        description: '동작 일관성',
        score: 70.0,
        weight: 0.20,
        grade: CriterionGrade.fromScore(70.0),
      );
    }

    // 피크/밸리 감지 → 반복별 ROM
    final reps = <double>[];
    double? lastPeak;
    double? lastValley;
    bool? wasIncreasing;

    for (int i = 1; i < angles.length; i++) {
      final increasing = angles[i] > angles[i - 1];

      if (wasIncreasing == true && !increasing) {
        // 피크
        lastPeak = angles[i - 1];
        if (lastValley != null) {
          reps.add((lastPeak - lastValley).abs());
        }
      } else if (wasIncreasing == false && increasing) {
        // 밸리
        lastValley = angles[i - 1];
        if (lastPeak != null) {
          reps.add((lastPeak - lastValley).abs());
        }
      }

      if (angles[i] != angles[i - 1]) {
        wasIncreasing = increasing;
      }
    }

    if (reps.length < 2) {
      return CriterionResult(
        name: '동작 일관성',
        description: '동작 일관성',
        score: 70.0,
        weight: 0.20,
        grade: CriterionGrade.fromScore(70.0),
      );
    }

    // ROM 표준편차 계산
    final mean = reps.reduce((a, b) => a + b) / reps.length;
    final variance = reps.fold(0.0, (sum, r) => sum + (r - mean) * (r - mean)) / reps.length;
    final std = sqrt(variance);

    // std ≤ 5 → 100, ≥ 20 → 0
    double score;
    if (std <= 5) {
      score = 100.0;
    } else if (std >= 20) {
      score = 0.0;
    } else {
      score = 100.0 * (1 - (std - 5) / 15);
    }

    return CriterionResult(
      name: '동작 일관성',
      description: '동작 일관성',
      score: score.clamp(0.0, 100.0),
      weight: 0.20,
      grade: CriterionGrade.fromScore(score),
    );
  }

  /// 4. 최대 수축 각도 (Peak Contraction) — 15%
  CriterionResult _evaluatePeakContraction(List<PoseFrame> frames) {
    double minAngle = 180;

    for (final frame in frames) {
      final angle = _wristAngle(frame);
      if (angle == null) continue;
      if (angle < minAngle) minAngle = angle;
    }

    final score = minAngle < 180
        ? AngleCalculator.rangeScore(minAngle, idealMin: 100, idealMax: 140, tolerance: 25)
        : 50.0;

    return CriterionResult(
      name: '최대 수축',
      description: '최대 수축 각도',
      score: score,
      weight: 0.15,
      grade: CriterionGrade.fromScore(score),
    );
  }

  /// 5. 좌우 대칭 (Symmetry) — 10%
  CriterionResult _evaluateSymmetry(List<PoseFrame> frames) {
    final scores = <double>[];

    for (final frame in frames) {
      final leftAngle = _wristAngle(frame, left: true);
      final rightAngle = _wristAngle(frame, left: false);

      if (leftAngle == null || rightAngle == null) continue;
      scores.add(AngleCalculator.symmetryScore(leftAngle, rightAngle));
    }

    final avgScore = scores.isEmpty ? 70.0 : scores.reduce((a, b) => a + b) / scores.length;

    return CriterionResult(
      name: '좌우 대칭',
      description: '좌우 대칭',
      score: avgScore,
      weight: 0.10,
      grade: CriterionGrade.fromScore(avgScore),
    );
  }
}
```

- [ ] **Step 4: 테스트 실행 — 통과 확인**

Run: `cd rexx_app && flutter test test/features/pose_evaluation/engine/rules/wrist_curl_rules_test.dart -v`
Expected: ALL PASS

- [ ] **Step 5: 커밋**

```bash
cd rexx_app && git add lib/features/pose_evaluation/engine/rules/wrist_curl_rules.dart test/features/pose_evaluation/engine/rules/wrist_curl_rules_test.dart && git commit -m "feat: WristCurlRules 5개 평가 기준 구현"
```

---

### Task 5: PhaseDetector에 리스트컬 페이즈 감지 추가

**Files:**
- Modify: `rexx_app/lib/features/pose_evaluation/engine/phase_detector.dart`

- [ ] **Step 1: 구현 — detectWristCurlPhases 메서드 추가**

`phase_detector.dart`에 `detectDeadliftPhases` 다음에 추가:

```dart
/// 리스트컬 단계 감지: 손목 각도 기반 (elbow→wrist→index)
static List<MapEntry<ExercisePhase, int>> detectWristCurlPhases(List<PoseFrame> frames) {
  final phases = <MapEntry<ExercisePhase, int>>[];
  final wristAngles = <double>[];

  for (final frame in frames) {
    final elbow = frame.getLandmark(PoseFrame.leftElbow);
    final wrist = frame.getLandmark(PoseFrame.leftWrist);
    final index = frame.getLandmark(PoseFrame.leftIndex);

    if (elbow == null || wrist == null || index == null || index.likelihood < 0.5) {
      wristAngles.add(180);
      continue;
    }

    wristAngles.add(AngleCalculator.calculateAngle(elbow, wrist, index));
  }

  if (wristAngles.isEmpty) return phases;

  // 최소 손목 각도 = 최대 수축 (bottom)
  double minAngle = 180;
  int bottomIndex = 0;
  for (int i = 0; i < wristAngles.length; i++) {
    if (wristAngles[i] < minAngle) {
      minAngle = wristAngles[i];
      bottomIndex = i;
    }
  }

  for (int i = 0; i < frames.length; i++) {
    ExercisePhase phase;
    if (i < bottomIndex * 0.3) {
      phase = ExercisePhase.setup;
    } else if (i < bottomIndex) {
      phase = ExercisePhase.descent;
    } else if (i == bottomIndex) {
      phase = ExercisePhase.bottom;
    } else if (i < frames.length * 0.9) {
      phase = ExercisePhase.ascent;
    } else {
      phase = ExercisePhase.lockout;
    }
    phases.add(MapEntry(phase, i));
  }

  return phases;
}
```

import 추가 확인: `PoseFrame`에서 `leftIndex`를 사용하므로 기존 import로 충분.

- [ ] **Step 2: flutter analyze 확인**

Run: `cd rexx_app && flutter analyze lib/features/pose_evaluation/engine/phase_detector.dart`
Expected: No issues found

- [ ] **Step 3: 커밋**

```bash
cd rexx_app && git add lib/features/pose_evaluation/engine/phase_detector.dart && git commit -m "feat: PhaseDetector에 리스트컬 페이즈 감지 추가"
```

---

### Task 6: ExerciseClassifier에 wristCurl 분류 완성

Task 2에서 스코어링 case는 추가되었으나, wrist ROM 추출 로직과 motionRatio 안정화가 빠져있다. 이 Task에서 완성한다.

**Files:**
- Modify: `rexx_app/lib/features/pose_evaluation/engine/classifier/exercise_classifier.dart`
- Modify: `rexx_app/test/features/pose_evaluation/engine/classifier/exercise_classifier_test.dart`

- [ ] **Step 1: 테스트 작성 — wristCurl 분류 + 기존 회귀 테스트**

`exercise_classifier_test.dart` 상단에 `import 'dart:math';` 추가.

`_wristCurlFrames()` 헬퍼 함수 추가 (올바른 기하학 사용):

```dart
/// 리스트컬 시뮬레이션: 직립, 손목 ROM 큼, 팔꿈치/무릎/힙 ROM 최소
List<PoseFrame> _wristCurlFrames() {
  final frames = <PoseFrame>[];
  final wristAngles = [170.0, 155.0, 135.0, 120.0, 135.0, 155.0, 170.0, 155.0, 135.0, 120.0];

  // elbow→wrist 방향각
  final elbowX = 0.5, elbowY = 0.40;
  final wristX = 0.5, wristY = 0.55;
  final baseAngle = atan2(wristY - elbowY, wristX - elbowX);

  for (int i = 0; i < 10; i++) {
    final targetRad = wristAngles[i] * pi / 180;
    final indexAngle = baseAngle + (pi - targetRad);
    final indexX = wristX + 0.1 * cos(indexAngle);
    final indexY = wristY + 0.1 * sin(indexAngle);

    frames.add(PoseFrame(
      frameIndex: i,
      timestamp: i / 5.0,
      landmarks: [
        _lm(PoseFrame.leftShoulder, 0.5, 0.25),
        _lm(PoseFrame.rightShoulder, 0.5, 0.25, likelihood: 0.5),
        _lm(PoseFrame.leftElbow, elbowX, elbowY),
        _lm(PoseFrame.rightElbow, elbowX, elbowY, likelihood: 0.5),
        _lm(PoseFrame.leftWrist, wristX, wristY),
        _lm(PoseFrame.rightWrist, wristX, wristY, likelihood: 0.5),
        _lm(19, indexX, indexY),        // leftIndex
        _lm(20, indexX, indexY, likelihood: 0.5),  // rightIndex
        _lm(PoseFrame.leftHip, 0.5, 0.60),
        _lm(PoseFrame.rightHip, 0.5, 0.60, likelihood: 0.5),
        _lm(PoseFrame.leftKnee, 0.5, 0.75),
        _lm(PoseFrame.rightKnee, 0.5, 0.75, likelihood: 0.5),
        _lm(PoseFrame.leftAnkle, 0.5, 0.90),
        _lm(PoseFrame.rightAnkle, 0.5, 0.90, likelihood: 0.5),
      ],
    ));
  }
  return frames;
}
```

테스트 추가 (기존 `ExerciseClassifier` 그룹 내):

```dart
test('리스트컬 프레임을 wristCurl로 분류한다', () {
  final result = classifier.classify(_wristCurlFrames());
  expect(result.bestMatch, ExerciseType.wristCurl);
});
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

Run: `cd rexx_app && flutter test test/features/pose_evaluation/engine/classifier/exercise_classifier_test.dart -v`
Expected: FAIL — wrist ROM 추출 로직 미구현

- [ ] **Step 3: 구현 — classifier wrist ROM 추출 완성**

Task 2에서 스코어링 case와 균등 확률 fallback은 이미 추가됨. 이 Step에서는 실제 wrist ROM 추출과 motionRatio 안정화를 구현한다.

`exercise_classifier.dart` 수정사항:

**3a. `chooseSide()` — index finger 랜드마크 추가 (line ~61-68)**

leftIndices 리스트에 `PoseFrame.leftIndex` 추가, rightIndices에 `PoseFrame.rightIndex` 추가.

**3b. `_extractROMs()` — wrist ROM 추출 추가**

기존 변수 선언 후에 추가:

```dart
final indexIdx = useLeft ? PoseFrame.leftIndex : PoseFrame.rightIndex;

double wristMin = 180, wristMax = 0;
```

루프 내에 추가:

```dart
final indexFinger = frame.getLandmark(indexIdx);
if (elbow != null && wrist != null && indexFinger != null && indexFinger.likelihood >= 0.5) {
  final wristAngle = AngleCalculator.calculateAngle(elbow, wrist, indexFinger);
  wristMin = min(wristMin, wristAngle);
  wristMax = max(wristMax, wristAngle);
}
```

return map에 추가:

```dart
'wrist': wristMax > wristMin ? wristMax - wristMin : 0,
```

**3c. `_extractMotionRatio()` — wrist ROM 반영**

`upperMotion` 계산에 wrist ROM 추가:

```dart
final wristRom = roms['wrist'] ?? 0.0;
final upperMotion = roms['elbow']! + wristRom + normalizedShoulderMove;
```

- [ ] **Step 4: 테스트 실행 — 통과 확인**

Run: `cd rexx_app && flutter test test/features/pose_evaluation/engine/classifier/exercise_classifier_test.dart -v`
Expected: ALL PASS (기존 3개 + 리스트컬 분류 + 확률합 + 균등확률)

- [ ] **Step 5: 커밋**

```bash
cd rexx_app && git add lib/features/pose_evaluation/engine/classifier/exercise_classifier.dart test/features/pose_evaluation/engine/classifier/exercise_classifier_test.dart && git commit -m "feat: ExerciseClassifier에 wristCurl 자동 분류 추가"
```

---

### Task 7: UI 업데이트 — ExerciseSelectScreen + ClassificationDialogs

**Files:**
- Modify: `rexx_app/lib/features/pose_evaluation/screens/exercise_select_screen.dart:73-93`
- Modify: `rexx_app/lib/features/pose_evaluation/widgets/classification_dialogs.dart:96`

- [ ] **Step 1: ExerciseSelectScreen에 리스트컬 카드 추가**

`exercise_select_screen.dart`의 데드리프트 카드 다음에 추가:

```dart
const SizedBox(height: 12),
_buildExerciseCard(
  context,
  exerciseType: ExerciseType.wristCurl,
  icon: Icons.front_hand,
  description: '전완 강화, 손목 가동범위와 팔꿈치 고정을 분석합니다.',
),
```

- [ ] **Step 2: ClassificationDialogs 지원 운동 텍스트 업데이트**

`classification_dialogs.dart` line 96:

변경 전:
```dart
'현재 지원: 스쿼트 · 벤치프레스 · 데드리프트',
```

변경 후:
```dart
'현재 지원: 스쿼트 · 벤치프레스 · 데드리프트 · 리스트컬',
```

- [ ] **Step 3: flutter analyze 확인**

Run: `cd rexx_app && flutter analyze`
Expected: No issues found

- [ ] **Step 4: 커밋**

```bash
cd rexx_app && git add lib/features/pose_evaluation/screens/exercise_select_screen.dart lib/features/pose_evaluation/widgets/classification_dialogs.dart && git commit -m "feat: UI에 리스트컬 운동 카드 및 지원 텍스트 추가"
```

---

### Task 8: 전체 테스트 통과 확인

- [ ] **Step 1: 전체 테스트 실행**

Run: `cd rexx_app && flutter test`
Expected: ALL PASS

- [ ] **Step 2: 정적 분석**

Run: `cd rexx_app && flutter analyze`
Expected: No issues found

- [ ] **Step 3: 최종 확인 후 feature 브랜치 정리**

모든 테스트와 분석이 통과하면 완료.
