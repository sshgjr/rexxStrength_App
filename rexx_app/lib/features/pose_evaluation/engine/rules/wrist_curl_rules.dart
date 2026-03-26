import 'dart:math';
import '../../models/pose_frame.dart';
import '../../models/evaluation_result.dart';
import '../angle_calculator.dart';
import 'exercise_rule.dart';

/// 리스트컬 평가 규칙
class WristCurlRules implements ExerciseRule {
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

  CriterionResult _evaluateElbowStability(List<PoseFrame> frames) {
    final elbowPositions = <PoseLandmark>[];
    double bodyHeight = 0.6;

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

  CriterionResult _evaluateRepConsistency(List<PoseFrame> frames) {
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

    final reps = <double>[];
    double? lastPeak;
    double? lastValley;
    bool? wasIncreasing;

    for (int i = 1; i < angles.length; i++) {
      final increasing = angles[i] > angles[i - 1];

      if (wasIncreasing == true && !increasing) {
        lastPeak = angles[i - 1];
        if (lastValley != null) {
          reps.add((lastPeak - lastValley).abs());
        }
      } else if (wasIncreasing == false && increasing) {
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

    final mean = reps.reduce((a, b) => a + b) / reps.length;
    final variance = reps.fold(0.0, (sum, r) => sum + (r - mean) * (r - mean)) / reps.length;
    final std = sqrt(variance);

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
