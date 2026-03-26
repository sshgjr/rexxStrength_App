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
      final count = ExerciseType.values.length;
      return ClassificationResult(probabilities: {
        for (final type in ExerciseType.values) type: 1.0 / count,
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
      final count = ExerciseType.values.length;
      for (final type in ExerciseType.values) {
        probabilities[type] = 1.0 / count;
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
    double bodyHeight = 1.0;

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

    return count > 0 ? sum / count : 45.0;
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
      case ExerciseType.wristCurl:
        return AngleCalculator.rangeScore(roms['wrist'] ?? 0, idealMin: 20, idealMax: 60, tolerance: 20);
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
      case ExerciseType.wristCurl:
        return AngleCalculator.rangeScore(ratio, idealMin: 0.70, idealMax: 0.95, tolerance: 0.20);
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
      case ExerciseType.wristCurl:
        return AngleCalculator.rangeScore(avgAngle, idealMin: 10, idealMax: 40, tolerance: 20);
    }
  }
}
