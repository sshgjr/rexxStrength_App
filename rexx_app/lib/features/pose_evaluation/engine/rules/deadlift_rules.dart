import '../../models/pose_frame.dart';
import '../../models/evaluation_result.dart';
import '../angle_calculator.dart';
import 'exercise_rule.dart';

/// 데드리프트 평가 규칙
class DeadliftRules implements ExerciseRule {
  @override
  String get name => '데드리프트';

  @override
  List<CriterionResult> evaluate(List<PoseFrame> frames) {
    return [
      _evaluateHipHingePattern(frames),
      _evaluateBackAngle(frames),
      _evaluateLockout(frames),
      _evaluateKneeAngle(frames),
      _evaluateSymmetry(frames),
    ];
  }

  /// 힙 힌지 패턴 — 25%
  /// 고관절 각도 변화량 > 무릎 각도 변화량인지 확인
  CriterionResult _evaluateHipHingePattern(List<PoseFrame> frames) {
    final hipAngles = <double>[];
    final kneeAngles = <double>[];

    for (final frame in frames) {
      final shoulder = frame.getLandmark(PoseFrame.leftShoulder);
      final hip = frame.getLandmark(PoseFrame.leftHip);
      final knee = frame.getLandmark(PoseFrame.leftKnee);
      final ankle = frame.getLandmark(PoseFrame.leftAnkle);
      if (shoulder == null || hip == null || knee == null || ankle == null) continue;

      hipAngles.add(AngleCalculator.calculateAngle(shoulder, hip, knee));
      kneeAngles.add(AngleCalculator.calculateAngle(hip, knee, ankle));
    }

    if (hipAngles.length < 2) {
      return CriterionResult(
        name: '힙 힌지 패턴',
        description: '힙 힌지 패턴',
        score: 50.0,
        weight: 0.25,
        grade: CriterionGrade.warning,
      );
    }

    // 각도 변화량 (최대 - 최소)
    final hipRange = hipAngles.reduce((a, b) => a > b ? a : b) -
        hipAngles.reduce((a, b) => a < b ? a : b);
    final kneeRange = kneeAngles.reduce((a, b) => a > b ? a : b) -
        kneeAngles.reduce((a, b) => a < b ? a : b);

    // 힙 변화량이 무릎 변화량보다 커야 좋음
    double score;
    if (kneeRange == 0) {
      score = 100.0;
    } else {
      final ratio = hipRange / kneeRange;
      if (ratio >= 1.5) {
        score = 100.0;
      } else if (ratio >= 1.0) {
        score = 70.0 + 30.0 * ((ratio - 1.0) / 0.5);
      } else {
        score = 70.0 * ratio;
      }
    }

    return CriterionResult(
      name: '힙 힌지 패턴',
      description: '힙 힌지 패턴',
      score: score.clamp(0.0, 100.0),
      weight: 0.25,
      grade: CriterionGrade.fromScore(score),
    );
  }

  /// 등 각도 (시작 자세) — 25%
  CriterionResult _evaluateBackAngle(List<PoseFrame> frames) {
    if (frames.isEmpty) {
      return CriterionResult(
        name: '등 각도',
        description: '등 각도',
        score: 50.0,
        weight: 0.25,
        grade: CriterionGrade.warning,
      );
    }

    // 초반 프레임에서 등 각도 측정
    double bestScore = 0;
    final earlyFrames = frames.take((frames.length * 0.3).ceil());

    for (final frame in earlyFrames) {
      final shoulder = frame.getLandmark(PoseFrame.leftShoulder);
      final hip = frame.getLandmark(PoseFrame.leftHip);
      if (shoulder == null || hip == null) continue;

      final angle = AngleCalculator.calculateVerticalAngle(shoulder, hip);
      final score = AngleCalculator.rangeScore(
        angle,
        idealMin: 30,
        idealMax: 50,
        tolerance: 20,
      );
      if (score > bestScore) bestScore = score;
    }

    return CriterionResult(
      name: '등 각도',
      description: '등 각도',
      score: bestScore,
      weight: 0.25,
      grade: CriterionGrade.fromScore(bestScore),
    );
  }

  /// 락아웃 — 20%
  CriterionResult _evaluateLockout(List<PoseFrame> frames) {
    double maxHipAngle = 0;

    for (final frame in frames) {
      final shoulder = frame.getLandmark(PoseFrame.leftShoulder);
      final hip = frame.getLandmark(PoseFrame.leftHip);
      final knee = frame.getLandmark(PoseFrame.leftKnee);
      if (shoulder == null || hip == null || knee == null) continue;

      final angle = AngleCalculator.calculateAngle(shoulder, hip, knee);
      if (angle > maxHipAngle) maxHipAngle = angle;
    }

    double score;
    if (maxHipAngle >= 170) {
      score = 100.0;
    } else {
      score = AngleCalculator.rangeScore(
        maxHipAngle,
        idealMin: 170,
        idealMax: 180,
        tolerance: 30,
      );
    }

    return CriterionResult(
      name: '락아웃',
      description: '락아웃',
      score: score,
      weight: 0.20,
      grade: CriterionGrade.fromScore(score),
    );
  }

  /// 무릎 각도 (시작) — 15%
  CriterionResult _evaluateKneeAngle(List<PoseFrame> frames) {
    if (frames.isEmpty) {
      return CriterionResult(
        name: '무릎 각도',
        description: '무릎 각도 (시작)',
        score: 50.0,
        weight: 0.15,
        grade: CriterionGrade.warning,
      );
    }

    double bestScore = 0;
    final earlyFrames = frames.take((frames.length * 0.3).ceil());

    for (final frame in earlyFrames) {
      final hip = frame.getLandmark(PoseFrame.leftHip);
      final knee = frame.getLandmark(PoseFrame.leftKnee);
      final ankle = frame.getLandmark(PoseFrame.leftAnkle);
      if (hip == null || knee == null || ankle == null) continue;

      final angle = AngleCalculator.calculateAngle(hip, knee, ankle);
      final score = AngleCalculator.rangeScore(
        angle,
        idealMin: 140,
        idealMax: 160,
        tolerance: 20,
      );
      if (score > bestScore) bestScore = score;
    }

    return CriterionResult(
      name: '무릎 각도',
      description: '무릎 각도 (시작)',
      score: bestScore,
      weight: 0.15,
      grade: CriterionGrade.fromScore(bestScore),
    );
  }

  /// 좌우 대칭 — 15%
  CriterionResult _evaluateSymmetry(List<PoseFrame> frames) {
    final scores = <double>[];

    for (final frame in frames) {
      final lShoulder = frame.getLandmark(PoseFrame.leftShoulder);
      final rShoulder = frame.getLandmark(PoseFrame.rightShoulder);
      final lHip = frame.getLandmark(PoseFrame.leftHip);
      final rHip = frame.getLandmark(PoseFrame.rightHip);

      if (lShoulder == null || rShoulder == null || lHip == null || rHip == null) continue;

      // 어깨 높이 차이
      final shoulderDiff = AngleCalculator.yDifference(lShoulder, rShoulder);
      // 힙 높이 차이
      final hipDiff = AngleCalculator.yDifference(lHip, rHip);

      // 차이가 작을수록 좋음 (0.03 이내면 만점)
      final shoulderScore = (1 - (shoulderDiff / 0.08).clamp(0.0, 1.0)) * 100;
      final hipScore = (1 - (hipDiff / 0.08).clamp(0.0, 1.0)) * 100;

      scores.add((shoulderScore + hipScore) / 2);
    }

    final avgScore = scores.isEmpty ? 50.0 : scores.reduce((a, b) => a + b) / scores.length;

    return CriterionResult(
      name: '좌우 대칭',
      description: '좌우 대칭',
      score: avgScore,
      weight: 0.15,
      grade: CriterionGrade.fromScore(avgScore),
    );
  }
}
