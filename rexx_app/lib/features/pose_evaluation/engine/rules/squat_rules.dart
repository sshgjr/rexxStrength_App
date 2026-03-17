import '../../models/pose_frame.dart';
import '../../models/evaluation_result.dart';
import '../angle_calculator.dart';
import 'exercise_rule.dart';

/// 스쿼트 평가 규칙
class SquatRules implements ExerciseRule {
  @override
  String get name => '스쿼트';

  @override
  List<CriterionResult> evaluate(List<PoseFrame> frames) {
    final results = <CriterionResult>[];

    results.add(_evaluateKneeAngle(frames));
    results.add(_evaluateHipHinge(frames));
    results.add(_evaluateKneeToeAlignment(frames));
    results.add(_evaluateSpineAngle(frames));
    results.add(_evaluateSymmetry(frames));

    return results;
  }

  /// 무릎 각도 (바텀) — 30%
  CriterionResult _evaluateKneeAngle(List<PoseFrame> frames) {
    double minKneeAngle = 180;

    for (final frame in frames) {
      final hip = frame.getLandmark(PoseFrame.leftHip);
      final knee = frame.getLandmark(PoseFrame.leftKnee);
      final ankle = frame.getLandmark(PoseFrame.leftAnkle);
      if (hip == null || knee == null || ankle == null) continue;

      final angle = AngleCalculator.calculateAngle(hip, knee, ankle);
      if (angle < minKneeAngle) minKneeAngle = angle;
    }

    // 90도 이하면 만점, 그 이상이면 감점
    double score;
    if (minKneeAngle <= 90) {
      score = 100.0;
    } else {
      score = AngleCalculator.rangeScore(
        minKneeAngle,
        idealMin: 0,
        idealMax: 90,
        tolerance: 40,
      );
    }

    return CriterionResult(
      name: '무릎 각도',
      description: '무릎 각도 (바텀)',
      score: score,
      weight: 0.30,
      grade: CriterionGrade.fromScore(score),
    );
  }

  /// 힙 힌지 — 20%
  CriterionResult _evaluateHipHinge(List<PoseFrame> frames) {
    double bestScore = 0;

    for (final frame in frames) {
      final shoulder = frame.getLandmark(PoseFrame.leftShoulder);
      final hip = frame.getLandmark(PoseFrame.leftHip);
      final knee = frame.getLandmark(PoseFrame.leftKnee);
      if (shoulder == null || hip == null || knee == null) continue;

      final angle = AngleCalculator.calculateAngle(shoulder, hip, knee);
      final score = AngleCalculator.rangeScore(
        angle,
        idealMin: 70,
        idealMax: 90,
        tolerance: 25,
      );
      if (score > bestScore) bestScore = score;
    }

    return CriterionResult(
      name: '힙 힌지',
      description: '힙 힌지 각도',
      score: bestScore,
      weight: 0.20,
      grade: CriterionGrade.fromScore(bestScore),
    );
  }

  /// 무릎-발끝 정렬 — 20%
  CriterionResult _evaluateKneeToeAlignment(List<PoseFrame> frames) {
    final scores = <double>[];

    for (final frame in frames) {
      final knee = frame.getLandmark(PoseFrame.leftKnee);
      final foot = frame.getLandmark(PoseFrame.leftFootIndex);
      if (knee == null || foot == null) continue;

      final xDiff = AngleCalculator.xDifference(knee, foot);
      // X 차이가 작을수록 좋음 (정규화: 0.05 이내면 만점)
      final score = (1 - (xDiff / 0.15).clamp(0.0, 1.0)) * 100;
      scores.add(score);
    }

    final avgScore = scores.isEmpty ? 50.0 : scores.reduce((a, b) => a + b) / scores.length;

    return CriterionResult(
      name: '무릎-발끝 정렬',
      description: '무릎-발끝 정렬',
      score: avgScore,
      weight: 0.20,
      grade: CriterionGrade.fromScore(avgScore),
    );
  }

  /// 척추 각도 — 15%
  CriterionResult _evaluateSpineAngle(List<PoseFrame> frames) {
    double bestScore = 0;

    for (final frame in frames) {
      final shoulder = frame.getLandmark(PoseFrame.leftShoulder);
      final hip = frame.getLandmark(PoseFrame.leftHip);
      if (shoulder == null || hip == null) continue;

      final angle = AngleCalculator.calculateVerticalAngle(shoulder, hip);
      final score = AngleCalculator.rangeScore(
        angle,
        idealMin: 60,
        idealMax: 80,
        tolerance: 25,
      );
      if (score > bestScore) bestScore = score;
    }

    return CriterionResult(
      name: '척추 각도',
      description: '척추 각도',
      score: bestScore,
      weight: 0.15,
      grade: CriterionGrade.fromScore(bestScore),
    );
  }

  /// 좌우 대칭 — 15%
  CriterionResult _evaluateSymmetry(List<PoseFrame> frames) {
    final scores = <double>[];

    for (final frame in frames) {
      final lHip = frame.getLandmark(PoseFrame.leftHip);
      final lKnee = frame.getLandmark(PoseFrame.leftKnee);
      final lAnkle = frame.getLandmark(PoseFrame.leftAnkle);
      final rHip = frame.getLandmark(PoseFrame.rightHip);
      final rKnee = frame.getLandmark(PoseFrame.rightKnee);
      final rAnkle = frame.getLandmark(PoseFrame.rightAnkle);

      if (lHip == null || lKnee == null || lAnkle == null ||
          rHip == null || rKnee == null || rAnkle == null) continue;

      final leftAngle = AngleCalculator.calculateAngle(lHip, lKnee, lAnkle);
      final rightAngle = AngleCalculator.calculateAngle(rHip, rKnee, rAnkle);

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
