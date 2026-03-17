import '../../models/pose_frame.dart';
import '../../models/evaluation_result.dart';
import '../angle_calculator.dart';
import 'exercise_rule.dart';

/// 벤치프레스 평가 규칙
class BenchPressRules implements ExerciseRule {
  @override
  String get name => '벤치프레스';

  @override
  List<CriterionResult> evaluate(List<PoseFrame> frames) {
    return [
      _evaluateElbowAngle(frames),
      _evaluateElbowFlare(frames),
      _evaluateBarPath(frames),
      _evaluateLockout(frames),
      _evaluateSymmetry(frames),
    ];
  }

  /// 팔꿈치 각도 (바텀) — 25%
  CriterionResult _evaluateElbowAngle(List<PoseFrame> frames) {
    double bestScore = 0;

    for (final frame in frames) {
      final shoulder = frame.getLandmark(PoseFrame.leftShoulder);
      final elbow = frame.getLandmark(PoseFrame.leftElbow);
      final wrist = frame.getLandmark(PoseFrame.leftWrist);
      if (shoulder == null || elbow == null || wrist == null) continue;

      final angle = AngleCalculator.calculateAngle(shoulder, elbow, wrist);
      final score = AngleCalculator.rangeScore(
        angle,
        idealMin: 85,
        idealMax: 95,
        tolerance: 25,
      );
      if (score > bestScore) bestScore = score;
    }

    return CriterionResult(
      name: '팔꿈치 각도',
      description: '팔꿈치 각도 (바텀)',
      score: bestScore,
      weight: 0.25,
      grade: CriterionGrade.fromScore(bestScore),
    );
  }

  /// 팔꿈치 벌어짐 — 25%
  CriterionResult _evaluateElbowFlare(List<PoseFrame> frames) {
    final scores = <double>[];

    for (final frame in frames) {
      final shoulder = frame.getLandmark(PoseFrame.leftShoulder);
      final elbow = frame.getLandmark(PoseFrame.leftElbow);
      final hip = frame.getLandmark(PoseFrame.leftHip);
      if (shoulder == null || elbow == null || hip == null) continue;

      // 어깨-팔꿈치 벡터와 어깨-힙 벡터 사이 각도 (45도 이내가 이상적)
      final angle = AngleCalculator.calculateAngle(elbow, shoulder, hip);
      final score = AngleCalculator.rangeScore(
        angle,
        idealMin: 30,
        idealMax: 55,
        tolerance: 25,
      );
      scores.add(score);
    }

    final avgScore = scores.isEmpty ? 50.0 : scores.reduce((a, b) => a + b) / scores.length;

    return CriterionResult(
      name: '팔꿈치 벌어짐',
      description: '팔꿈치 벌어짐',
      score: avgScore,
      weight: 0.25,
      grade: CriterionGrade.fromScore(avgScore),
    );
  }

  /// 바 경로 (손목 X 일관성) — 20%
  CriterionResult _evaluateBarPath(List<PoseFrame> frames) {
    final wristXPositions = <double>[];

    for (final frame in frames) {
      final wrist = frame.getLandmark(PoseFrame.leftWrist);
      if (wrist == null) continue;
      wristXPositions.add(wrist.x);
    }

    if (wristXPositions.length < 2) {
      return CriterionResult(
        name: '바 경로',
        description: '바 경로 일관성',
        score: 50.0,
        weight: 0.20,
        grade: CriterionGrade.warning,
      );
    }

    // X 좌표의 표준편차 계산
    final mean = wristXPositions.reduce((a, b) => a + b) / wristXPositions.length;
    final variance = wristXPositions
        .map((x) => (x - mean) * (x - mean))
        .reduce((a, b) => a + b) / wristXPositions.length;
    final stdDev = variance > 0 ? variance : 0.0;

    // 표준편차가 작을수록 좋음 (0.02 이내면 만점)
    final score = (1 - (stdDev / 0.01).clamp(0.0, 1.0)) * 100;

    return CriterionResult(
      name: '바 경로',
      description: '바 경로 일관성',
      score: score.clamp(0.0, 100.0),
      weight: 0.20,
      grade: CriterionGrade.fromScore(score),
    );
  }

  /// 락아웃 — 15%
  CriterionResult _evaluateLockout(List<PoseFrame> frames) {
    double maxElbowAngle = 0;

    for (final frame in frames) {
      final shoulder = frame.getLandmark(PoseFrame.leftShoulder);
      final elbow = frame.getLandmark(PoseFrame.leftElbow);
      final wrist = frame.getLandmark(PoseFrame.leftWrist);
      if (shoulder == null || elbow == null || wrist == null) continue;

      final angle = AngleCalculator.calculateAngle(shoulder, elbow, wrist);
      if (angle > maxElbowAngle) maxElbowAngle = angle;
    }

    // 170도 이상이면 만점
    double score;
    if (maxElbowAngle >= 170) {
      score = 100.0;
    } else {
      score = AngleCalculator.rangeScore(
        maxElbowAngle,
        idealMin: 170,
        idealMax: 180,
        tolerance: 30,
      );
    }

    return CriterionResult(
      name: '락아웃',
      description: '락아웃',
      score: score,
      weight: 0.15,
      grade: CriterionGrade.fromScore(score),
    );
  }

  /// 좌우 대칭 — 15%
  CriterionResult _evaluateSymmetry(List<PoseFrame> frames) {
    final scores = <double>[];

    for (final frame in frames) {
      final lShoulder = frame.getLandmark(PoseFrame.leftShoulder);
      final lElbow = frame.getLandmark(PoseFrame.leftElbow);
      final lWrist = frame.getLandmark(PoseFrame.leftWrist);
      final rShoulder = frame.getLandmark(PoseFrame.rightShoulder);
      final rElbow = frame.getLandmark(PoseFrame.rightElbow);
      final rWrist = frame.getLandmark(PoseFrame.rightWrist);

      if (lShoulder == null || lElbow == null || lWrist == null ||
          rShoulder == null || rElbow == null || rWrist == null) continue;

      final leftAngle = AngleCalculator.calculateAngle(lShoulder, lElbow, lWrist);
      final rightAngle = AngleCalculator.calculateAngle(rShoulder, rElbow, rWrist);

      scores.add(AngleCalculator.symmetryScore(leftAngle, rightAngle));
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
