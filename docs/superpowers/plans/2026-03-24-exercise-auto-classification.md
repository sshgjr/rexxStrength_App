# Exercise Auto-Classification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ML Kit 포즈 랜드마크 기반으로 3대 운동(스쿼트, 벤치프레스, 데드리프트)을 자동 분류하여, 사용자가 운동 종류를 직접 선택하지 않아도 영상 분석이 가능하게 한다.

**Architecture:** 포즈 감지 후 `ExerciseClassifier`가 전체 프레임의 ROM/상하체 비율/torso orientation 3가지 특징으로 운동을 분류한다. 확신도에 따라 자동 확정/사용자 선택 다이얼로그/실패 플로우를 분기한다. 기존 수동 선택 경로도 유지한다.

**Tech Stack:** Flutter, google_mlkit_pose_detection, shared_preferences

**Spec:** `docs/superpowers/specs/2026-03-24-exercise-auto-classification-design.md`

---

## File Map

### New Files
| File | Responsibility |
|------|---------------|
| `lib/features/pose_evaluation/models/classification_result.dart` | `ClassificationResult` 모델, `ClassificationConfidence` enum |
| `lib/features/pose_evaluation/engine/classifier/exercise_classifier.dart` | 3가지 특징 추출 + 스코어링 + confidence 판정 |
| `lib/features/pose_evaluation/widgets/classification_dialogs.dart` | ambiguous/failed 다이얼로그 함수 (showDialog 기반) |
| `test/features/pose_evaluation/models/classification_result_test.dart` | ClassificationResult 모델 유닛 테스트 |
| `test/features/pose_evaluation/engine/classifier/exercise_classifier_test.dart` | 분류 알고리즘 유닛 테스트 |
| `test/features/pose_evaluation/widgets/classification_dialogs_test.dart` | 다이얼로그 위젯 테스트 |

### Modified Files
| File | Changes |
|------|---------|
| `lib/features/pose_evaluation/engine/pose_analyzer.dart` | `exerciseType` optional로 변경, `onClassificationNeeded` 콜백 추가, 분류 단계 삽입 |
| `lib/features/pose_evaluation/screens/exercise_select_screen.dart` | "영상으로 자동 분석" 버튼 추가, 레이아웃 재구성 |
| `lib/features/pose_evaluation/screens/video_upload_screen.dart` | `exerciseType` optional, 분류 콜백 처리 로직 |

---

## Task 1: ClassificationResult 모델

**Files:**
- Create: `rexx_app/lib/features/pose_evaluation/models/classification_result.dart`
- Test: `rexx_app/test/features/pose_evaluation/models/classification_result_test.dart`

- [ ] **Step 1: Write the test**

```dart
// test/features/pose_evaluation/models/classification_result_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rexx_app/features/pose_evaluation/models/classification_result.dart';
import 'package:rexx_app/features/pose_evaluation/models/exercise_phase.dart';

void main() {
  group('ClassificationResult', () {
    test('sortedTypes는 확률 내림차순으로 정렬된다', () {
      final result = ClassificationResult(
        probabilities: {
          ExerciseType.squat: 0.2,
          ExerciseType.benchPress: 0.5,
          ExerciseType.deadlift: 0.3,
        },
      );
      expect(result.sortedTypes, [
        ExerciseType.benchPress,
        ExerciseType.deadlift,
        ExerciseType.squat,
      ]);
    });

    test('bestProb >= 0.60이면 high confidence', () {
      final result = ClassificationResult(
        probabilities: {
          ExerciseType.squat: 0.70,
          ExerciseType.benchPress: 0.20,
          ExerciseType.deadlift: 0.10,
        },
      );
      expect(result.confidence, ClassificationConfidence.high);
      expect(result.bestMatch, ExerciseType.squat);
    });

    test('0.40~0.60이고 차이 >= 0.10이면 moderate', () {
      final result = ClassificationResult(
        probabilities: {
          ExerciseType.squat: 0.50,
          ExerciseType.benchPress: 0.30,
          ExerciseType.deadlift: 0.20,
        },
      );
      expect(result.confidence, ClassificationConfidence.moderate);
    });

    test('0.40~0.60이고 차이 < 0.10이면 ambiguous', () {
      final result = ClassificationResult(
        probabilities: {
          ExerciseType.squat: 0.45,
          ExerciseType.benchPress: 0.40,
          ExerciseType.deadlift: 0.15,
        },
      );
      expect(result.confidence, ClassificationConfidence.ambiguous);
      expect(result.secondMatch, ExerciseType.benchPress);
    });

    test('bestProb < 0.40이면 failed', () {
      final result = ClassificationResult(
        probabilities: {
          ExerciseType.squat: 0.35,
          ExerciseType.benchPress: 0.33,
          ExerciseType.deadlift: 0.32,
        },
      );
      expect(result.confidence, ClassificationConfidence.failed);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd rexx_app && flutter test test/features/pose_evaluation/models/classification_result_test.dart`
Expected: FAIL — file not found

- [ ] **Step 3: Write the model**

```dart
// lib/features/pose_evaluation/models/classification_result.dart
import 'exercise_phase.dart';

enum ClassificationConfidence { high, moderate, ambiguous, failed }

class ClassificationResult {
  final Map<ExerciseType, double> probabilities;

  ClassificationResult({required this.probabilities});

  /// 확률 내림차순 정렬된 운동 타입 리스트
  List<ExerciseType> get sortedTypes {
    final entries = probabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList();
  }

  /// 최고 확률 운동
  ExerciseType get bestMatch => sortedTypes.first;

  /// 두 번째 확률 운동
  ExerciseType? get secondMatch =>
      sortedTypes.length > 1 ? sortedTypes[1] : null;

  double get _bestProb => probabilities[bestMatch]!;
  double get _secondProb =>
      secondMatch != null ? probabilities[secondMatch]! : 0.0;

  /// confidence 판정 (스펙 1.3 기준)
  ClassificationConfidence get confidence {
    if (_bestProb >= 0.60) return ClassificationConfidence.high;
    if (_bestProb >= 0.40) {
      if (_bestProb - _secondProb >= 0.10) {
        return ClassificationConfidence.moderate;
      }
      return ClassificationConfidence.ambiguous;
    }
    return ClassificationConfidence.failed;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd rexx_app && flutter test test/features/pose_evaluation/models/classification_result_test.dart`
Expected: All 5 tests PASS

- [ ] **Step 5: Commit**

```bash
git add rexx_app/lib/features/pose_evaluation/models/classification_result.dart rexx_app/test/features/pose_evaluation/models/classification_result_test.dart
git commit -m "feat: ClassificationResult 모델 및 confidence 판정 로직 추가"
```

---

## Task 2: ExerciseClassifier 분류 알고리즘

**Files:**
- Create: `rexx_app/lib/features/pose_evaluation/engine/classifier/exercise_classifier.dart`
- Test: `rexx_app/test/features/pose_evaluation/engine/classifier/exercise_classifier_test.dart`
- Depends on: Task 1

- [ ] **Step 1: Write test helper — mock PoseFrame 생성 함수**

테스트에서 각 운동의 대표적 랜드마크 패턴을 생성하는 헬퍼가 필요하다. 기존 테스트 패턴(`_lm()` 헬퍼)을 따른다.

```dart
// test/features/pose_evaluation/engine/classifier/exercise_classifier_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rexx_app/features/pose_evaluation/models/pose_frame.dart';
import 'package:rexx_app/features/pose_evaluation/models/exercise_phase.dart';
import 'package:rexx_app/features/pose_evaluation/models/classification_result.dart';
import 'package:rexx_app/features/pose_evaluation/engine/classifier/exercise_classifier.dart';

// 기존 angle_calculator_test.dart의 _lm과 다른 시그니처:
// 분류기 테스트에서는 landmark index와 likelihood 제어가 필요하므로 확장된 헬퍼를 사용한다.
PoseLandmark _lm(int index, double x, double y, {double z = 0, double likelihood = 0.9}) {
  return PoseLandmark(index: index, x: x, y: y, z: z, likelihood: likelihood);
}

/// 스쿼트 시뮬레이션: 직립 상태에서 무릎이 크게 굽혀짐
/// - torso: 거의 수직 (shoulder와 hip의 x 차이 작음)
/// - knee ROM: 큼 (170° → 80° → 170°)
/// - elbow ROM: 거의 없음
/// - hip ROM: 중간
List<PoseFrame> _squatFrames() {
  final frames = <PoseFrame>[];
  // 10프레임: standing → bottom → standing
  final kneeAngles = [170.0, 150.0, 120.0, 100.0, 80.0, 80.0, 100.0, 120.0, 150.0, 170.0];

  for (int i = 0; i < 10; i++) {
    // 직립 torso: shoulder 위, hip 아래, x 거의 동일
    final shoulderY = 0.3;
    final hipY = 0.55;
    final kneeY = 0.75 + (170.0 - kneeAngles[i]) / 170.0 * 0.1; // 무릎 굽힘에 따라 변화
    final ankleY = 0.9;

    frames.add(PoseFrame(
      frameIndex: i,
      timestamp: i / 5.0,
      landmarks: [
        // Left side (used for classification)
        _lm(PoseFrame.leftShoulder, 0.5, shoulderY),
        _lm(PoseFrame.rightShoulder, 0.5, shoulderY, likelihood: 0.5),
        _lm(PoseFrame.leftElbow, 0.45, 0.42),  // 팔 거의 고정
        _lm(PoseFrame.rightElbow, 0.55, 0.42, likelihood: 0.5),
        _lm(PoseFrame.leftWrist, 0.45, 0.45),
        _lm(PoseFrame.rightWrist, 0.55, 0.45, likelihood: 0.5),
        _lm(PoseFrame.leftHip, 0.5, hipY),
        _lm(PoseFrame.rightHip, 0.5, hipY, likelihood: 0.5),
        _lm(PoseFrame.leftKnee, 0.5, kneeY),
        _lm(PoseFrame.rightKnee, 0.5, kneeY, likelihood: 0.5),
        _lm(PoseFrame.leftAnkle, 0.5, ankleY),
        _lm(PoseFrame.rightAnkle, 0.5, ankleY, likelihood: 0.5),
      ],
    ));
  }
  return frames;
}

/// 벤치프레스 시뮬레이션: 누운 상태에서 팔꿈치가 크게 굽혀짐
/// - torso: 수평 (shoulder와 hip의 y 차이 작음, x 차이 큼)
/// - elbow ROM: 큼 (170° → 85° → 170°)
/// - knee ROM: 거의 없음
/// - hip ROM: 거의 없음
List<PoseFrame> _benchPressFrames() {
  final frames = <PoseFrame>[];
  final elbowAngles = [170.0, 150.0, 120.0, 100.0, 85.0, 85.0, 100.0, 120.0, 150.0, 170.0];

  for (int i = 0; i < 10; i++) {
    // 누운 자세: shoulder와 hip의 y 비슷, x로 펼쳐짐
    final wristX = 0.3 + (170.0 - elbowAngles[i]) / 170.0 * 0.15;

    frames.add(PoseFrame(
      frameIndex: i,
      timestamp: i / 5.0,
      landmarks: [
        _lm(PoseFrame.leftShoulder, 0.3, 0.5),
        _lm(PoseFrame.rightShoulder, 0.3, 0.5, likelihood: 0.5),
        _lm(PoseFrame.leftElbow, 0.35, 0.35),
        _lm(PoseFrame.rightElbow, 0.35, 0.65, likelihood: 0.5),
        _lm(PoseFrame.leftWrist, wristX, 0.25),
        _lm(PoseFrame.rightWrist, wristX, 0.75, likelihood: 0.5),
        _lm(PoseFrame.leftHip, 0.7, 0.5),
        _lm(PoseFrame.rightHip, 0.7, 0.5, likelihood: 0.5),
        _lm(PoseFrame.leftKnee, 0.8, 0.45),  // 다리 거의 고정
        _lm(PoseFrame.rightKnee, 0.8, 0.55, likelihood: 0.5),
        _lm(PoseFrame.leftAnkle, 0.9, 0.45),
        _lm(PoseFrame.rightAnkle, 0.9, 0.55, likelihood: 0.5),
      ],
    ));
  }
  return frames;
}

/// 데드리프트 시뮬레이션: 전방 경사에서 힙이 크게 변화
/// - torso: 전방 경사 (30~55° 수직 기준)
/// - hip ROM: 큼 (80° → 170°)
/// - knee ROM: 적음 (150° → 170°)
/// - elbow ROM: 거의 없음
List<PoseFrame> _deadliftFrames() {
  final frames = <PoseFrame>[];
  // 바닥에서 올라오는 동작
  final hipAngles = [80.0, 95.0, 110.0, 125.0, 140.0, 155.0, 165.0, 170.0, 170.0, 170.0];

  for (int i = 0; i < 10; i++) {
    // 전방 경사: shoulder이 hip보다 x가 작음 (앞으로 기울어짐)
    final lean = (170.0 - hipAngles[i]) / 170.0 * 0.2; // 각도 작을수록 더 기울어짐
    final shoulderX = 0.4 - lean;
    final shoulderY = 0.35 + lean * 0.3;

    frames.add(PoseFrame(
      frameIndex: i,
      timestamp: i / 5.0,
      landmarks: [
        _lm(PoseFrame.leftShoulder, shoulderX, shoulderY),
        _lm(PoseFrame.rightShoulder, shoulderX, shoulderY, likelihood: 0.5),
        _lm(PoseFrame.leftElbow, shoulderX - 0.02, shoulderY + 0.1),
        _lm(PoseFrame.rightElbow, shoulderX - 0.02, shoulderY + 0.1, likelihood: 0.5),
        _lm(PoseFrame.leftWrist, shoulderX - 0.03, shoulderY + 0.2),
        _lm(PoseFrame.rightWrist, shoulderX - 0.03, shoulderY + 0.2, likelihood: 0.5),
        _lm(PoseFrame.leftHip, 0.5, 0.55),
        _lm(PoseFrame.rightHip, 0.5, 0.55, likelihood: 0.5),
        _lm(PoseFrame.leftKnee, 0.5, 0.75),  // 무릎 약간만 변화
        _lm(PoseFrame.rightKnee, 0.5, 0.75, likelihood: 0.5),
        _lm(PoseFrame.leftAnkle, 0.5, 0.9),
        _lm(PoseFrame.rightAnkle, 0.5, 0.9, likelihood: 0.5),
      ],
    ));
  }
  return frames;
}

void main() {
  group('ExerciseClassifier', () {
    late ExerciseClassifier classifier;

    setUp(() {
      classifier = ExerciseClassifier();
    });

    test('스쿼트 프레임을 squat으로 분류한다', () {
      final result = classifier.classify(_squatFrames());
      expect(result.bestMatch, ExerciseType.squat);
      expect(result.confidence, isIn([ClassificationConfidence.high, ClassificationConfidence.moderate]));
    });

    test('벤치프레스 프레임을 benchPress로 분류한다', () {
      final result = classifier.classify(_benchPressFrames());
      expect(result.bestMatch, ExerciseType.benchPress);
      expect(result.confidence, isIn([ClassificationConfidence.high, ClassificationConfidence.moderate]));
    });

    test('데드리프트 프레임을 deadlift로 분류한다', () {
      final result = classifier.classify(_deadliftFrames());
      expect(result.bestMatch, ExerciseType.deadlift);
      expect(result.confidence, isIn([ClassificationConfidence.high, ClassificationConfidence.moderate]));
    });

    test('확률의 합은 1.0이다', () {
      final result = classifier.classify(_squatFrames());
      final sum = result.probabilities.values.reduce((a, b) => a + b);
      expect(sum, closeTo(1.0, 0.01));
    });

    test('프레임이 부족하면 모든 확률이 균등하다', () {
      final frames = <PoseFrame>[
        PoseFrame(frameIndex: 0, timestamp: 0, landmarks: [
          _lm(PoseFrame.leftShoulder, 0.5, 0.3),
          _lm(PoseFrame.rightShoulder, 0.5, 0.3),
          _lm(PoseFrame.leftElbow, 0.5, 0.4),
          _lm(PoseFrame.rightElbow, 0.5, 0.4),
          _lm(PoseFrame.leftWrist, 0.5, 0.5),
          _lm(PoseFrame.rightWrist, 0.5, 0.5),
          _lm(PoseFrame.leftHip, 0.5, 0.55),
          _lm(PoseFrame.rightHip, 0.5, 0.55),
          _lm(PoseFrame.leftKnee, 0.5, 0.75),
          _lm(PoseFrame.rightKnee, 0.5, 0.75),
          _lm(PoseFrame.leftAnkle, 0.5, 0.9),
          _lm(PoseFrame.rightAnkle, 0.5, 0.9),
        ]),
      ];
      final result = classifier.classify(frames);
      // 1프레임으로는 ROM 계산 불가 → failed
      expect(result.confidence, ClassificationConfidence.failed);
    });
  });

  group('ExerciseClassifier.chooseSide', () {
    test('likelihood가 높은 쪽을 선택한다', () {
      final frames = <PoseFrame>[
        PoseFrame(frameIndex: 0, timestamp: 0, landmarks: [
          _lm(PoseFrame.leftShoulder, 0.5, 0.3, likelihood: 0.9),
          _lm(PoseFrame.rightShoulder, 0.5, 0.3, likelihood: 0.3),
          _lm(PoseFrame.leftHip, 0.5, 0.55, likelihood: 0.9),
          _lm(PoseFrame.rightHip, 0.5, 0.55, likelihood: 0.3),
          _lm(PoseFrame.leftKnee, 0.5, 0.75, likelihood: 0.9),
          _lm(PoseFrame.rightKnee, 0.5, 0.75, likelihood: 0.3),
          _lm(PoseFrame.leftElbow, 0.5, 0.4, likelihood: 0.9),
          _lm(PoseFrame.rightElbow, 0.5, 0.4, likelihood: 0.3),
          _lm(PoseFrame.leftWrist, 0.5, 0.5, likelihood: 0.9),
          _lm(PoseFrame.rightWrist, 0.5, 0.5, likelihood: 0.3),
          _lm(PoseFrame.leftAnkle, 0.5, 0.9, likelihood: 0.9),
          _lm(PoseFrame.rightAnkle, 0.5, 0.9, likelihood: 0.3),
        ]),
      ];
      // left side의 likelihood가 더 높으므로 left 선택
      expect(ExerciseClassifier.chooseSide(frames), true); // true = left
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd rexx_app && flutter test test/features/pose_evaluation/engine/classifier/exercise_classifier_test.dart`
Expected: FAIL — import not found

- [ ] **Step 3: Write ExerciseClassifier**

```dart
// lib/features/pose_evaluation/engine/classifier/exercise_classifier.dart
import 'dart:math';
import '../../models/pose_frame.dart';
import '../../models/exercise_phase.dart';
import '../../models/classification_result.dart';
import '../angle_calculator.dart';

/// ML Kit 포즈 랜드마크 기반 운동 자동 분류기
class ExerciseClassifier {
  // Feature weights (스펙 1.2)
  static const double _w1 = 0.35; // ROM
  static const double _w2 = 0.25; // 상하체 비율
  static const double _w3 = 0.40; // torso orientation

  /// 포즈 프레임 리스트로 운동 종류를 분류한다
  ClassificationResult classify(List<PoseFrame> frames) {
    if (frames.length < 5) {
      // 프레임 부족 시 균등 확률 (스펙 섹션 8: < 5프레임이면 에러)
      return ClassificationResult(probabilities: {
        ExerciseType.squat: 1.0 / 3,
        ExerciseType.benchPress: 1.0 / 3,
        ExerciseType.deadlift: 1.0 / 3,
      });
    }

    final useLeft = chooseSide(frames);

    // 특징 추출
    final roms = _extractROMs(frames, useLeft);
    final ratio = _extractMotionRatio(frames, useLeft, roms);
    final avgOrientation = _extractTorsoOrientation(frames, useLeft);

    // 각 운동별 스코어 계산
    final scores = <ExerciseType, double>{};
    for (final type in ExerciseType.values) {
      final romScore = _romScore(type, roms);
      final ratioScore = _ratioScore(type, ratio);
      final orientationScore = _orientationScore(type, avgOrientation);
      scores[type] = _w1 * romScore + _w2 * ratioScore + _w3 * orientationScore;
    }

    // 정규화 → 확률
    final totalScore = scores.values.reduce((a, b) => a + b);
    final probabilities = <ExerciseType, double>{};
    if (totalScore > 0) {
      for (final entry in scores.entries) {
        probabilities[entry.key] = entry.value / totalScore;
      }
    } else {
      for (final type in ExerciseType.values) {
        probabilities[type] = 1.0 / 3;
      }
    }

    return ClassificationResult(probabilities: probabilities);
  }

  /// 좌/우 중 likelihood가 높은 쪽 선택. true = left, false = right
  static bool chooseSide(List<PoseFrame> frames) {
    int leftWins = 0;
    for (final frame in frames) {
      final leftIndices = [
        PoseFrame.leftShoulder, PoseFrame.leftHip, PoseFrame.leftKnee,
        PoseFrame.leftElbow, PoseFrame.leftWrist, PoseFrame.leftAnkle,
      ];
      final rightIndices = [
        PoseFrame.rightShoulder, PoseFrame.rightHip, PoseFrame.rightKnee,
        PoseFrame.rightElbow, PoseFrame.rightWrist, PoseFrame.rightAnkle,
      ];

      double leftSum = 0, rightSum = 0;
      int leftCount = 0, rightCount = 0;
      for (final idx in leftIndices) {
        final lm = frame.getLandmark(idx);
        if (lm != null) { leftSum += lm.likelihood; leftCount++; }
      }
      for (final idx in rightIndices) {
        final lm = frame.getLandmark(idx);
        if (lm != null) { rightSum += lm.likelihood; rightCount++; }
      }

      final leftAvg = leftCount > 0 ? leftSum / leftCount : 0;
      final rightAvg = rightCount > 0 ? rightSum / rightCount : 0;
      if (leftAvg >= rightAvg) leftWins++;
    }
    return leftWins >= (frames.length / 2).ceil();
  }

  /// ROM 추출: {knee, elbow, hip}
  Map<String, double> _extractROMs(List<PoseFrame> frames, bool useLeft) {
    final shoulderIdx = useLeft ? PoseFrame.leftShoulder : PoseFrame.rightShoulder;
    final elbowIdx = useLeft ? PoseFrame.leftElbow : PoseFrame.rightElbow;
    final wristIdx = useLeft ? PoseFrame.leftWrist : PoseFrame.rightWrist;
    final hipIdx = useLeft ? PoseFrame.leftHip : PoseFrame.rightHip;
    final kneeIdx = useLeft ? PoseFrame.leftKnee : PoseFrame.rightKnee;
    final ankleIdx = useLeft ? PoseFrame.leftAnkle : PoseFrame.rightAnkle;

    double kneeMin = 180, kneeMax = 0;
    double elbowMin = 180, elbowMax = 0;
    double hipMin = 180, hipMax = 0;

    for (final frame in frames) {
      final shoulder = frame.getLandmark(shoulderIdx);
      final elbow = frame.getLandmark(elbowIdx);
      final wrist = frame.getLandmark(wristIdx);
      final hip = frame.getLandmark(hipIdx);
      final knee = frame.getLandmark(kneeIdx);
      final ankle = frame.getLandmark(ankleIdx);

      if (hip != null && knee != null && ankle != null) {
        final kneeAngle = AngleCalculator.calculateAngle(hip, knee, ankle);
        kneeMin = min(kneeMin, kneeAngle);
        kneeMax = max(kneeMax, kneeAngle);
      }
      if (shoulder != null && elbow != null && wrist != null) {
        final elbowAngle = AngleCalculator.calculateAngle(shoulder, elbow, wrist);
        elbowMin = min(elbowMin, elbowAngle);
        elbowMax = max(elbowMax, elbowAngle);
      }
      if (shoulder != null && hip != null && knee != null) {
        final hipAngle = AngleCalculator.calculateAngle(shoulder, hip, knee);
        hipMin = min(hipMin, hipAngle);
        hipMax = max(hipMax, hipAngle);
      }
    }

    return {
      'knee': kneeMax > kneeMin ? kneeMax - kneeMin : 0,
      'elbow': elbowMax > elbowMin ? elbowMax - elbowMin : 0,
      'hip': hipMax > hipMin ? hipMax - hipMin : 0,
    };
  }

  /// 상하체 동작 비율 추출
  double _extractMotionRatio(
    List<PoseFrame> frames,
    bool useLeft,
    Map<String, double> roms,
  ) {
    final shoulderIdx = useLeft ? PoseFrame.leftShoulder : PoseFrame.rightShoulder;
    final hipIdx = useLeft ? PoseFrame.leftHip : PoseFrame.rightHip;
    final ankleIdx = useLeft ? PoseFrame.leftAnkle : PoseFrame.rightAnkle;

    double shoulderYMin = double.infinity, shoulderYMax = -double.infinity;
    double hipYMin = double.infinity, hipYMax = -double.infinity;
    double bodyHeight = 1.0; // 정규화 기준

    for (final frame in frames) {
      final shoulder = frame.getLandmark(shoulderIdx);
      final hip = frame.getLandmark(hipIdx);
      final ankle = frame.getLandmark(ankleIdx);

      if (shoulder != null) {
        shoulderYMin = min(shoulderYMin, shoulder.y);
        shoulderYMax = max(shoulderYMax, shoulder.y);
      }
      if (hip != null) {
        hipYMin = min(hipYMin, hip.y);
        hipYMax = max(hipYMax, hip.y);
      }
      if (shoulder != null && ankle != null) {
        final h = (shoulder.y - ankle.y).abs();
        if (h > 0) bodyHeight = max(bodyHeight, h);
      }
    }

    final normalizedShoulderMove = shoulderYMax > shoulderYMin
        ? (shoulderYMax - shoulderYMin) / bodyHeight * 100
        : 0.0;
    final normalizedHipMove = hipYMax > hipYMin
        ? (hipYMax - hipYMin) / bodyHeight * 100
        : 0.0;

    final upperMotion = roms['elbow']! + normalizedShoulderMove;
    final lowerMotion = roms['knee']! + normalizedHipMove;
    final total = upperMotion + lowerMotion;

    return total > 0 ? upperMotion / total : 0.5;
  }

  /// 평균 torso orientation (수직 기준 각도)
  double _extractTorsoOrientation(List<PoseFrame> frames, bool useLeft) {
    final shoulderIdx = useLeft ? PoseFrame.leftShoulder : PoseFrame.rightShoulder;
    final hipIdx = useLeft ? PoseFrame.leftHip : PoseFrame.rightHip;

    double sum = 0;
    int count = 0;

    for (final frame in frames) {
      final shoulder = frame.getLandmark(shoulderIdx);
      final hip = frame.getLandmark(hipIdx);
      if (shoulder != null && hip != null) {
        sum += AngleCalculator.calculateVerticalAngle(shoulder, hip);
        count++;
      }
    }

    return count > 0 ? sum / count : 45.0; // 기본값: 중간
  }

  /// ROM 기반 스코어 (스펙 1.2 romScore)
  double _romScore(ExerciseType type, Map<String, double> roms) {
    switch (type) {
      case ExerciseType.squat:
        return AngleCalculator.rangeScore(roms['knee']!, idealMin: 60, idealMax: 120, tolerance: 30);
      case ExerciseType.benchPress:
        return AngleCalculator.rangeScore(roms['elbow']!, idealMin: 50, idealMax: 110, tolerance: 30);
      case ExerciseType.deadlift:
        return AngleCalculator.rangeScore(roms['hip']!, idealMin: 50, idealMax: 100, tolerance: 30);
    }
  }

  /// 상하체 비율 스코어 (스펙 1.2 ratioScore)
  double _ratioScore(ExerciseType type, double ratio) {
    switch (type) {
      case ExerciseType.squat:
        return AngleCalculator.rangeScore(ratio, idealMin: 0.15, idealMax: 0.40, tolerance: 0.20);
      case ExerciseType.benchPress:
        return AngleCalculator.rangeScore(ratio, idealMin: 0.60, idealMax: 0.90, tolerance: 0.20);
      case ExerciseType.deadlift:
        return AngleCalculator.rangeScore(ratio, idealMin: 0.35, idealMax: 0.60, tolerance: 0.20);
    }
  }

  /// torso orientation 스코어 (스펙 1.2 orientationScore)
  double _orientationScore(ExerciseType type, double avgAngle) {
    switch (type) {
      case ExerciseType.squat:
        return AngleCalculator.rangeScore(avgAngle, idealMin: 10, idealMax: 30, tolerance: 20);
      case ExerciseType.benchPress:
        return AngleCalculator.rangeScore(avgAngle, idealMin: 70, idealMax: 90, tolerance: 20);
      case ExerciseType.deadlift:
        return AngleCalculator.rangeScore(avgAngle, idealMin: 30, idealMax: 55, tolerance: 20);
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd rexx_app && flutter test test/features/pose_evaluation/engine/classifier/exercise_classifier_test.dart`
Expected: All 6 tests PASS

- [ ] **Step 5: Commit**

```bash
git add rexx_app/lib/features/pose_evaluation/engine/classifier/exercise_classifier.dart rexx_app/test/features/pose_evaluation/engine/classifier/exercise_classifier_test.dart
git commit -m "feat: ExerciseClassifier 분류 알고리즘 구현 (ROM/비율/orientation 기반)"
```

---

## Task 3: PoseAnalyzer에 분류 단계 삽입

**Files:**
- Modify: `rexx_app/lib/features/pose_evaluation/engine/pose_analyzer.dart`
- Depends on: Task 2

- [ ] **Step 1: import 추가**

`pose_analyzer.dart` 상단에 추가:

```dart
import 'classifier/exercise_classifier.dart';
import '../models/classification_result.dart';
```

- [ ] **Step 2: `analyze()` 메서드 전체 교체**

기존 `analyze()` 메서드 (line 39~88)를 다음으로 교체한다:

```dart
  /// 영상 파일에서 프레임 추출 → 포즈 분석 → (자동 분류) → 규칙 평가
  /// [exerciseType]이 null이면 자동 분류 수행
  /// [onClassificationNeeded] 분류 confidence가 낮을 때 사용자 선택을 요청하는 콜백
  /// [onAutoClassified] moderate 확정 시 호출 (토스트 표시용)
  /// [onProgress] 콜백: 0.0 ~ 1.0
  Future<EvaluationResult> analyze({
    required String videoPath,
    ExerciseType? exerciseType,
    Future<ExerciseType> Function(ClassificationResult)? onClassificationNeeded,
    void Function(ExerciseType)? onAutoClassified,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.0);

    // 1. 프레임 추출
    final frames = await _extractFrames(videoPath);
    onProgress?.call(0.3);

    // 2. 포즈 감지
    final List<PoseFrame> poseFrames;
    if (isSimulatorMode) {
      poseFrames = await _stub!.detectPoses(frames);
    } else {
      poseFrames = await _detectPoses(frames);
    }
    onProgress?.call(0.7);

    // 2.5. 운동 종류 결정
    final ExerciseType resolvedType;
    if (exerciseType != null) {
      resolvedType = exerciseType;
    } else {
      final classifier = ExerciseClassifier();
      final classification = classifier.classify(poseFrames);

      if (classification.confidence == ClassificationConfidence.high) {
        resolvedType = classification.bestMatch;
      } else if (classification.confidence == ClassificationConfidence.moderate) {
        resolvedType = classification.bestMatch;
        onAutoClassified?.call(resolvedType);
      } else if (onClassificationNeeded != null) {
        resolvedType = await onClassificationNeeded(classification);
      } else {
        resolvedType = classification.bestMatch;
      }
    }

    // 3. 규칙 기반 평가
    final rule = _getRule(resolvedType);
    final criteria = rule.evaluate(poseFrames);

    // 4. 총점 계산 (가중 평균)
    double totalScore = 0;
    for (final c in criteria) {
      totalScore += c.score * c.weight;
    }

    // 5. 이슈 감지
    final issues = criteria
        .where((c) => c.grade != CriterionGrade.good)
        .map((c) =>
            '${c.description}: ${c.grade.displayName} (${c.score.round()}점)')
        .toList();

    onProgress?.call(1.0);

    // 6. 임시 파일 정리
    await _cleanup(frames);

    return EvaluationResult(
      exerciseType: resolvedType,
      totalScore: totalScore.round(),
      criteria: criteria,
      detectedIssues: issues,
      evaluatedAt: DateTime.now(),
    );
  }
```

- [ ] **Step 3: `analyzeWithDebug()` 메서드 전체 교체**

기존 `analyzeWithDebug()` 메서드 (line 91~139)를 다음으로 교체한다:

```dart
  /// 디버그용 분석 — 프레임 이미지를 삭제하지 않고 반환
  Future<DebugAnalysisData> analyzeWithDebug({
    required String videoPath,
    ExerciseType? exerciseType,
    Future<ExerciseType> Function(ClassificationResult)? onClassificationNeeded,
    void Function(ExerciseType)? onAutoClassified,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.0);

    final frames = await _extractFrames(videoPath);
    onProgress?.call(0.3);

    final List<PoseFrame> poseFrames;
    if (isSimulatorMode) {
      poseFrames = await _stub!.detectPoses(frames);
    } else {
      poseFrames = await _detectPoses(frames);
    }
    onProgress?.call(0.7);

    // 운동 종류 결정 (analyze()와 동일 로직)
    final ExerciseType resolvedType;
    if (exerciseType != null) {
      resolvedType = exerciseType;
    } else {
      final classifier = ExerciseClassifier();
      final classification = classifier.classify(poseFrames);

      if (classification.confidence == ClassificationConfidence.high) {
        resolvedType = classification.bestMatch;
      } else if (classification.confidence == ClassificationConfidence.moderate) {
        resolvedType = classification.bestMatch;
        onAutoClassified?.call(resolvedType);
      } else if (onClassificationNeeded != null) {
        resolvedType = await onClassificationNeeded(classification);
      } else {
        resolvedType = classification.bestMatch;
      }
    }

    final rule = _getRule(resolvedType);
    final criteria = rule.evaluate(poseFrames);

    double totalScore = 0;
    for (final c in criteria) {
      totalScore += c.score * c.weight;
    }

    final issues = criteria
        .where((c) => c.grade != CriterionGrade.good)
        .map((c) =>
            '${c.description}: ${c.grade.displayName} (${c.score.round()}점)')
        .toList();

    onProgress?.call(1.0);

    // _cleanup 생략 — 프레임 경로를 디버그 화면에서 사용
    final result = EvaluationResult(
      exerciseType: resolvedType,
      totalScore: totalScore.round(),
      criteria: criteria,
      detectedIssues: issues,
      evaluatedAt: DateTime.now(),
    );

    return DebugAnalysisData(
      framePaths: frames,
      poseFrames: poseFrames,
      result: result,
    );
  }
```

- [ ] **Step 4: 기존 테스트가 여전히 통과하는지 확인**

Run: `cd rexx_app && flutter test`
Expected: 기존 테스트 모두 PASS

> **참고:** `video_upload_screen.dart`의 기존 호출부(`analyzer.analyze(videoPath: ..., exerciseType: widget.exerciseType)`)는 named parameter이므로 `exerciseType`이 optional로 바뀌어도 변경 없이 동작한다. `widget.exerciseType`은 아직 `ExerciseType` (non-nullable)이므로 컴파일 문제 없음.

- [ ] **Step 5: Commit**

```bash
git add rexx_app/lib/features/pose_evaluation/engine/pose_analyzer.dart
git commit -m "feat: PoseAnalyzer에 자동 분류 단계 삽입 — exerciseType optional, onAutoClassified 콜백"
```

---

## Task 4: Classification 다이얼로그 위젯

**Files:**
- Create: `rexx_app/lib/features/pose_evaluation/widgets/classification_dialogs.dart`
- Test: `rexx_app/test/features/pose_evaluation/widgets/classification_dialogs_test.dart`
- Depends on: Task 1

- [ ] **Step 1: Write widget tests**

```dart
// test/features/pose_evaluation/widgets/classification_dialogs_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rexx_app/features/pose_evaluation/models/exercise_phase.dart';
import 'package:rexx_app/features/pose_evaluation/models/classification_result.dart';
import 'package:rexx_app/features/pose_evaluation/widgets/classification_dialogs.dart';

void main() {
  setUp(() {
    // SharedPreferences 테스트용 mock 초기화
    SharedPreferences.setMockInitialValues({});
  });

  group('showAmbiguousDialog', () {
    testWidgets('상위 2개 운동 버튼이 표시된다', (tester) async {
      ExerciseType? selected;
      final result = ClassificationResult(probabilities: {
        ExerciseType.squat: 0.45,
        ExerciseType.deadlift: 0.40,
        ExerciseType.benchPress: 0.15,
      });

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              selected = await showAmbiguousDialog(context, result);
            },
            child: const Text('open'),
          );
        }),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 제목
      expect(find.text('운동 종류를 확인해 주세요'), findsOneWidget);
      // 상위 2개 운동 표시
      expect(find.text('스쿼트'), findsOneWidget);
      expect(find.text('데드리프트'), findsOneWidget);

      // 첫 번째 선택
      await tester.tap(find.text('스쿼트'));
      await tester.pumpAndSettle();
      expect(selected, ExerciseType.squat);
    });
  });

  group('showClassificationFailedDialog', () {
    testWidgets('"예" 선택 시 3개 운동이 확률순으로 표시된다', (tester) async {
      ExerciseType? selected;
      final result = ClassificationResult(probabilities: {
        ExerciseType.deadlift: 0.35,
        ExerciseType.squat: 0.33,
        ExerciseType.benchPress: 0.32,
      });

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              selected = await showClassificationFailedDialog(context, result);
            },
            child: const Text('open'),
          );
        }),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 지원 운동 목록 표시
      expect(find.textContaining('스쿼트'), findsOneWidget);
      // "예" 버튼
      await tester.tap(find.text('예'));
      await tester.pumpAndSettle();

      // 3개 운동 확률순 선택지
      expect(find.text('데드리프트'), findsOneWidget);
      await tester.tap(find.text('데드리프트'));
      await tester.pumpAndSettle();
      expect(selected, ExerciseType.deadlift);
    });

    testWidgets('"아니오" 선택 시 텍스트 입력 + 감사 메시지 표시', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              await showClassificationFailedDialog(
                context,
                ClassificationResult(probabilities: {
                  ExerciseType.squat: 0.35,
                  ExerciseType.benchPress: 0.33,
                  ExerciseType.deadlift: 0.32,
                }),
              );
            },
            child: const Text('open'),
          );
        }),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('아니오'));
      await tester.pumpAndSettle();

      // 텍스트 입력 필드
      expect(find.byType(TextField), findsOneWidget);

      // 입력 후 제출
      await tester.enterText(find.byType(TextField), '오버헤드프레스');
      await tester.tap(find.text('제출'));
      await tester.pumpAndSettle();

      // 감사 메시지
      expect(find.textContaining('감사합니다'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd rexx_app && flutter test test/features/pose_evaluation/widgets/classification_dialogs_test.dart`
Expected: FAIL — import not found

- [ ] **Step 3: Write the dialog functions**

```dart
// lib/features/pose_evaluation/widgets/classification_dialogs.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/exercise_phase.dart';
import '../models/classification_result.dart';

const Color _bg = Color(0xFF0B0F0C);
const Color _card = Color(0xFF0F1612);
const Color _primary = Color(0xFF16A34A);
const Color _textMain = Color(0xFFE9F5EF);
const Color _textSub = Color(0xFFA7B9B0);

/// ambiguous 분류 시 상위 2개 운동 선택 다이얼로그
/// 반환: 사용자가 선택한 ExerciseType
Future<ExerciseType?> showAmbiguousDialog(
  BuildContext context,
  ClassificationResult result,
) {
  final top2 = result.sortedTypes.take(2).toList();

  return showDialog<ExerciseType>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: _card,
      title: const Text(
        '운동 종류를 확인해 주세요',
        style: TextStyle(color: _textMain, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '두 운동이 비슷하게 감지되었습니다.\n어떤 운동인지 선택해 주세요.',
            style: TextStyle(color: _textSub, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 20),
          for (final type in top2) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, type),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  type.displayName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            if (type != top2.last) const SizedBox(height: 10),
          ],
        ],
      ),
    ),
  );
}

/// 분류 실패 플로우 다이얼로그
/// 반환: 사용자가 선택한 ExerciseType, 또는 null (비지원 운동 피드백 후)
Future<ExerciseType?> showClassificationFailedDialog(
  BuildContext context,
  ClassificationResult result,
) async {
  // Step 1: 지원 운동인지 확인
  final isSupportedExercise = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: _card,
      title: const Text(
        '운동을 판별하지 못했어요',
        style: TextStyle(color: _textMain, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '분석 가능한 운동 영상이 맞나요?',
            style: TextStyle(color: _textMain, fontSize: 15),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '현재 지원: 스쿼트 · 벤치프레스 · 데드리프트',
              style: TextStyle(color: _textSub, fontSize: 12),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('아니오', style: TextStyle(color: _textSub)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('예'),
        ),
      ],
    ),
  );

  if (!context.mounted) return null;

  if (isSupportedExercise == true) {
    // Step 2a: 3개 운동 확률순 선택
    return showDialog<ExerciseType>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        title: const Text(
          '운동을 선택해 주세요',
          style: TextStyle(color: _textMain, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final type in result.sortedTypes) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, type),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    type.displayName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (type != result.sortedTypes.last) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  } else {
    // Step 2b: 비지원 운동 피드백
    await _showUnsupportedExerciseFeedback(context);
    return null;
  }
}

/// 비지원 운동 피드백 입력 → 감사 메시지 → 네비게이션 선택
Future<void> _showUnsupportedExerciseFeedback(BuildContext context) async {
  final controller = TextEditingController();

  final submitted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: _card,
      title: const Text(
        '어떤 운동인가요?',
        style: TextStyle(color: _textMain, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '운동 종류를 입력해 주시면\n추후 기능 추가에 참고하겠습니다.',
            style: TextStyle(color: _textSub, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            style: const TextStyle(color: _textMain),
            decoration: InputDecoration(
              hintText: '예: 오버헤드프레스',
              hintStyle: const TextStyle(color: _textSub),
              filled: true,
              fillColor: _bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('건너뛰기', style: TextStyle(color: _textSub)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('제출'),
        ),
      ],
    ),
  );

  // 피드백 저장
  if (submitted == true && controller.text.trim().isNotEmpty) {
    await _saveFeedback(controller.text.trim());
  }
  controller.dispose();

  if (!context.mounted) return;

  // 감사 메시지 + 네비게이션 선택
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: _card,
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '소중한 의견 감사합니다!',
            style: TextStyle(
              color: _textMain,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '더 다양한 운동을 지원할 수 있도록\n참고하겠습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSub, fontSize: 14, height: 1.5),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx); // 다이얼로그 닫기
            // 메인으로 돌아가기: 현재 화면 스택을 모두 팝
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          child: const Text('메인으로 돌아가기', style: TextStyle(color: _textSub)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx); // 다이얼로그 닫기
            Navigator.pop(context); // VideoUploadScreen → ExerciseSelectScreen
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('다른 영상 분석하기'),
        ),
      ],
    ),
  );
}

/// SharedPreferences에 비지원 운동 요청 저장
Future<void> _saveFeedback(String exerciseName) async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'unsupported_exercise_requests';
  final existing = prefs.getString(key);
  final list = existing != null ? jsonDecode(existing) as List : [];
  list.add({
    'exercise': exerciseName,
    'timestamp': DateTime.now().toIso8601String(),
  });
  await prefs.setString(key, jsonEncode(list));
}
```

- [ ] **Step 4: Run tests**

Run: `cd rexx_app && flutter test test/features/pose_evaluation/widgets/classification_dialogs_test.dart`
Expected: All 3 widget tests PASS

- [ ] **Step 5: Commit**

```bash
git add rexx_app/lib/features/pose_evaluation/widgets/classification_dialogs.dart rexx_app/test/features/pose_evaluation/widgets/classification_dialogs_test.dart
git commit -m "feat: 운동 분류 다이얼로그 위젯 — ambiguous/failed/피드백 플로우"
```

---

## Task 5: VideoUploadScreen 분류 콜백 연동

**Files:**
- Modify: `rexx_app/lib/features/pose_evaluation/screens/video_upload_screen.dart`
- Depends on: Task 3, Task 4

- [ ] **Step 1: `exerciseType`을 optional로 변경**

`VideoUploadScreen` 생성자:

```dart
class VideoUploadScreen extends StatefulWidget {
  final ExerciseType? exerciseType;  // null이면 자동 분류
  final String? token;

  const VideoUploadScreen({
    super.key,
    this.exerciseType,  // required 제거
    this.token,
  });
```

- [ ] **Step 2: `_startAnalysis()`에서 분류 콜백 연결**

import 추가:

```dart
import '../models/classification_result.dart';
import '../widgets/classification_dialogs.dart';
```

`_startAnalysis()` 내 `analyzer.analyze()` 호출부 수정:

```dart
      // 분류 필요 시 사용자에게 다이얼로그 표시하는 콜백
      Future<ExerciseType> onClassificationNeeded(ClassificationResult classification) async {
        ExerciseType? selected;

        if (classification.confidence == ClassificationConfidence.ambiguous) {
          selected = await showAmbiguousDialog(context, classification);
        } else {
          // failed
          selected = await showClassificationFailedDialog(context, classification);
        }

        if (selected == null) {
          // 사용자가 "아니오" → 피드백 제출 → 네비게이션 처리됨
          // 분석을 중단하기 위해 예외 throw
          throw _ClassificationCancelledException();
        }
        return selected;
      }

      // moderate 자동 확정 시 토스트 표시
      void onAutoClassified(ExerciseType type) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${type.displayName}(으)로 분석합니다'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
```

`analyzer.analyze()` 호출:

```dart
      final result = await analyzer.analyze(
        videoPath: _videoPath!,
        exerciseType: widget.exerciseType,
        onClassificationNeeded: widget.exerciseType == null ? onClassificationNeeded : null,
        onProgress: onProgress,
      );
```

`catch` 블록에 `_ClassificationCancelledException` 처리 추가:

```dart
    } on _ClassificationCancelledException {
      setState(() {
        _isAnalyzing = false;
        _statusText = '';
      });
      return; // 네비게이션은 다이얼로그에서 이미 처리됨
    } catch (e) {
```

파일 하단에 예외 클래스:

```dart
class _ClassificationCancelledException implements Exception {}
```

- [ ] **Step 3: 앱 타이틀 동적으로 변경**

`exerciseType`이 null일 때 타이틀을 "영상 분석"으로 표시:

```dart
Text(
  widget.exerciseType != null
      ? '${widget.exerciseType!.displayName} 영상 업로드'
      : '영상 분석',
  style: const TextStyle(fontWeight: FontWeight.w800),
),
```

- [ ] **Step 4: 디버그 모드에도 동일 패턴 적용**

`_debugMode` 블록의 `analyzer.analyzeWithDebug()` 호출에도 같은 optional exerciseType + 콜백 패턴 적용.

- [ ] **Step 5: `analyzer.analyze()` 호출에 `onAutoClassified` 콜백 연결**

> **참고:** `onAutoClassified` 콜백은 Task 3에서 이미 `PoseAnalyzer`에 추가되었으므로 여기서는 VideoUploadScreen의 호출부만 수정한다.

`analyzer.analyze()` 호출을 최종적으로 다음과 같이 변경:

```dart
      final result = await analyzer.analyze(
        videoPath: _videoPath!,
        exerciseType: widget.exerciseType,
        onClassificationNeeded: widget.exerciseType == null ? onClassificationNeeded : null,
        onAutoClassified: widget.exerciseType == null ? (type) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${type.displayName}(으)로 분석합니다'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } : null,
        onProgress: onProgress,
      );
```

디버그 모드의 `analyzer.analyzeWithDebug()` 호출도 동일하게 콜백을 전달한다.

- [ ] **Step 6: Commit**

```bash
git add rexx_app/lib/features/pose_evaluation/screens/video_upload_screen.dart
git commit -m "feat: VideoUploadScreen 분류 콜백 연동 — 자동/ambiguous/failed 플로우 처리"
```

---

## Task 6: ExerciseSelectScreen 재설계

**Files:**
- Modify: `rexx_app/lib/features/pose_evaluation/screens/exercise_select_screen.dart`
- Depends on: Task 5

> **참고:** 이 화면은 `StatelessWidget`으로 유지한다. 상태 관리가 필요하지 않으므로 변환 불필요.

- [ ] **Step 1: "영상으로 자동 분석" 버튼 추가**

`build()` 메서드의 `Column children`을 재구성한다:

```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: textMain,
        title: const Text(
          '자세 평가',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '운동 영상을 분석해보세요',
              style: TextStyle(
                color: textMain,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'AI가 운동 종류를 자동으로 판별하고 자세를 분석합니다.',
              style: TextStyle(color: textSub, fontSize: 14),
            ),
            const SizedBox(height: 24),
            // 자동 분석 버튼
            _buildAutoAnalyzeButton(context),
            const SizedBox(height: 32),
            // 구분선 + 안내 문구
            Row(
              children: [
                Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '또는',
                    style: TextStyle(color: textSub, fontSize: 13),
                  ),
                ),
                Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
              ],
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                '더 빠른 분석을 원하시면 직접 선택하세요',
                style: TextStyle(color: textSub, fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),
            // 기존 3개 운동 카드
            _buildExerciseCard(
              context,
              exerciseType: ExerciseType.squat,
              icon: Icons.fitness_center,
              description: '하체 근력의 기본, 올바른 깊이와 자세를 확인하세요.',
            ),
            const SizedBox(height: 12),
            _buildExerciseCard(
              context,
              exerciseType: ExerciseType.benchPress,
              icon: Icons.airline_seat_flat,
              description: '상체 푸시의 핵심, 팔꿈치 각도와 바 경로를 분석합니다.',
            ),
            const SizedBox(height: 12),
            _buildExerciseCard(
              context,
              exerciseType: ExerciseType.deadlift,
              icon: Icons.height,
              description: '후면 사슬 강화, 힙 힌지와 등 각도를 평가합니다.',
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 2: 자동 분석 버튼 위젯**

```dart
  Widget _buildAutoAnalyzeButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (_) => VideoUploadScreen(token: token),
            // exerciseType 생략 → null → 자동 분류
          ),
        );
        if (result != null && context.mounted) {
          Navigator.pop(context, result);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primary, primary.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Column(
          children: [
            Icon(Icons.auto_awesome, color: Colors.white, size: 36),
            SizedBox(height: 12),
            Text(
              '영상으로 자동 분석',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '영상을 업로드하면 운동 종류를 자동으로 판별합니다',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 3: `_buildExerciseCard` 운동 카드 크기 축소**

기존 카드의 padding을 `20` → `16`으로, 아이콘 크기를 `56` → `48`로, 폰트를 `18` → `16`으로 줄여 시각적 위계를 조정한다:

```dart
  Widget _buildExerciseCard(
    BuildContext context, {
    required ExerciseType exerciseType,
    required IconData icon,
    required String description,
  }) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (_) => VideoUploadScreen(
              exerciseType: exerciseType,
              token: token,
            ),
          ),
        );
        if (result != null && context.mounted) {
          Navigator.pop(context, result);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exerciseType.displayName,
                    style: const TextStyle(
                      color: textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      color: textSub,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: textSub, size: 22),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 4: Verify app compiles**

Run: `cd rexx_app && flutter analyze`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add rexx_app/lib/features/pose_evaluation/screens/exercise_select_screen.dart
git commit -m "feat: ExerciseSelectScreen 재설계 — 자동 분석 버튼 추가, 수동 선택 병존"
```

---

## Task 7: 전체 통합 테스트 및 정리

**Files:**
- All modified files
- Depends on: Task 1-6

- [ ] **Step 1: 전체 유닛 테스트 실행**

Run: `cd rexx_app && flutter test`
Expected: All tests PASS

- [ ] **Step 2: 정적 분석**

Run: `cd rexx_app && flutter analyze`
Expected: No issues found

- [ ] **Step 3: 미사용 import 정리**

analyze 결과에서 unused import 경고가 있다면 정리한다.

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "chore: 운동 자동 분류 기능 통합 정리 — 미사용 import 제거, lint 수정"
```
