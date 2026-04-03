import 'dart:math';
import '../../models/pose_frame.dart';
import '../../models/evaluation_result.dart';
import '../angle_calculator.dart';
import 'exercise_rule.dart';

/// 팔씨름 보조 운동 - 사이드프레셔 평가 규칙
class SidePressureRules implements ExerciseRule {
  @override
  String get name => '사이드프레셔';

  // ── likelihood 임계값 ─────────────────────────────────────────────────
  // 주요 관절 (어깨/팔꿈치/손목): 비교적 잘 잡히므로 0.5 유지
  static const double _mainLandmarkThreshold = 0.5;
  // 손가락 (엄지/소지): 카메라 각도에 따라 잘 안 잡히므로 낮게 설정
  static const double _fingerLandmarkThreshold = 0.2;
  // 손가락 유효 프레임이 전체의 이 비율 이상이어야 회내 점수 신뢰
  static const double _pronationMinFrameRatio = 0.3;

  @override
  List<CriterionResult> evaluate(List<PoseFrame> frames) {
    return [
      _evaluateWristPronation(frames),
      _evaluateElbowAngle(frames),
      _evaluateShoulderAbduction(frames),
      _evaluateTrunkLean(frames),
      _evaluateSymmetry(frames),
    ];
  }

  // ── 1. 손목 회내 (Wrist Pronation) — 30% ─────────────────────────────
  //
  // ML Kit에서 엄지(thumb)와 소지(pinky)의 Y좌표 차이로 회내 정도를 측정.
  // 화면 좌표계: Y는 아래로 갈수록 증가.
  //   - thumb.y > pinky.y  → 엄지가 아래 (회내) ✅
  //   - thumb.y < pinky.y  → 엄지가 위 (회외) ❌
  //
  // [변경사항]
  // - 손가락 likelihood 임계값: 0.5 → 0.2 (카메라 각도 영향 대응)
  // - likelihood를 가중치로 사용 → 신뢰도 높은 프레임에 더 큰 비중
  // - 유효 프레임이 전체의 30% 미만이면 중립값 70점 반환 (오탐 방지)
  CriterionResult _evaluateWristPronation(List<PoseFrame> frames) {
    double weightedScoreSum = 0.0;
    double weightSum = 0.0;
    int validFrameCount = 0;

    for (final frame in frames) {
      final wrist = frame.getLandmark(PoseFrame.rightWrist);
      final elbow = frame.getLandmark(PoseFrame.rightElbow);

      // 주요 관절은 기존 임계값 유지
      if (wrist == null || elbow == null) continue;
      if (wrist.likelihood < _mainLandmarkThreshold) continue;
      if (elbow.likelihood < _mainLandmarkThreshold) continue;

      final thumb = frame.getLandmark(PoseFrame.rightThumb);
      final pinky = frame.getLandmark(PoseFrame.rightPinky);

      // 손가락은 낮은 임계값 적용 (0.2)
      if (thumb == null || pinky == null) continue;
      if (thumb.likelihood < _fingerLandmarkThreshold) continue;
      if (pinky.likelihood < _fingerLandmarkThreshold) continue;

      validFrameCount++;

      // 엄지-소지 Y 차이 (양수 = 엄지가 아래 = 회내)
      final pronationDiff = thumb.y - pinky.y;

      // 손목-팔꿈치 거리로 정규화
      final wristElbowDist = sqrt(
        pow(wrist.x - elbow.x, 2) + pow(wrist.y - elbow.y, 2),
      );
      if (wristElbowDist < 1e-6) continue;

      final pronationRatio = pronationDiff / wristElbowDist;

      double score;
      if (pronationRatio >= 0.15) {
        score = 100.0;
      } else if (pronationRatio >= 0.0) {
        score = AngleCalculator.rangeScore(
          pronationRatio * 100,
          idealMin: 15,
          idealMax: 100,
          tolerance: 15,
        );
      } else {
        // 회외: 최대 -0.2까지 0점으로
        score = (1 + pronationRatio / 0.2).clamp(0.0, 1.0) * 50.0;
      }

      // likelihood를 가중치로 사용 — 신뢰도 높은 프레임에 더 큰 비중
      final weight = (thumb.likelihood + pinky.likelihood) / 2.0;
      weightedScoreSum += score.clamp(0.0, 100.0) * weight;
      weightSum += weight;
    }

    // 유효 프레임이 전체의 30% 미만 → 측정 신뢰도 부족
    // 중립값 70점 반환 (회내 오탐 방지)
    final frameRatio = frames.isEmpty ? 0.0 : validFrameCount / frames.length;
    if (weightSum < 1e-6 || frameRatio < _pronationMinFrameRatio) {
      return CriterionResult(
        name: '손목 회내',
        description: '손목 회내 측정값 부족 (카메라 각도 영향)',
        score: 70.0,
        weight: 0.30,
        grade: CriterionGrade.fromScore(70.0),
      );
    }

    final avgScore = weightedScoreSum / weightSum;

    return CriterionResult(
      name: '손목 회내',
      description: '손목 회내 (엄지 아래 방향)',
      score: avgScore,
      weight: 0.30,
      grade: CriterionGrade.fromScore(avgScore),
    );
  }

  // ── 2. 팔꿈치 각도 (Elbow Angle) — 25% ──────────────────────────────
  CriterionResult _evaluateElbowAngle(List<PoseFrame> frames) {
    final scores = <double>[];

    for (final frame in frames) {
      final shoulder = frame.getLandmark(PoseFrame.rightShoulder);
      final elbow = frame.getLandmark(PoseFrame.rightElbow);
      final wrist = frame.getLandmark(PoseFrame.rightWrist);

      if (shoulder == null || elbow == null || wrist == null) continue;
      if (shoulder.likelihood < _mainLandmarkThreshold) continue;
      if (elbow.likelihood < _mainLandmarkThreshold) continue;
      if (wrist.likelihood < _mainLandmarkThreshold) continue;

      final angle = AngleCalculator.calculateAngle(shoulder, elbow, wrist);

      final score = AngleCalculator.rangeScore(
        angle,
        idealMin: 80,
        idealMax: 100,
        tolerance: 20,
      );
      scores.add(score);
    }

    final avgScore =
        scores.isEmpty ? 50.0 : scores.reduce((a, b) => a + b) / scores.length;

    return CriterionResult(
      name: '팔꿈치 각도',
      description: '팔꿈치 각도 (80~100도)',
      score: avgScore,
      weight: 0.25,
      grade: CriterionGrade.fromScore(avgScore),
    );
  }

  // ── 3. 어깨 외전 (Shoulder Abduction) — 25% ─────────────────────────
  CriterionResult _evaluateShoulderAbduction(List<PoseFrame> frames) {
    final scores = <double>[];

    for (final frame in frames) {
      final hip = frame.getLandmark(PoseFrame.rightHip);
      final shoulder = frame.getLandmark(PoseFrame.rightShoulder);
      final elbow = frame.getLandmark(PoseFrame.rightElbow);

      if (hip == null || shoulder == null || elbow == null) continue;
      if (hip.likelihood < _mainLandmarkThreshold) continue;
      if (shoulder.likelihood < _mainLandmarkThreshold) continue;
      if (elbow.likelihood < _mainLandmarkThreshold) continue;

      final angle = AngleCalculator.calculateAngle(hip, shoulder, elbow);

      final score = AngleCalculator.rangeScore(
        angle,
        idealMin: 75,
        idealMax: 95,
        tolerance: 20,
      );
      scores.add(score);
    }

    final avgScore =
        scores.isEmpty ? 50.0 : scores.reduce((a, b) => a + b) / scores.length;

    return CriterionResult(
      name: '어깨 외전',
      description: '어깨 외전 (수평 가압 각도)',
      score: avgScore,
      weight: 0.25,
      grade: CriterionGrade.fromScore(avgScore),
    );
  }

  // ── 4. 상체 기울기 (Trunk Lean) — 10% ───────────────────────────────
  CriterionResult _evaluateTrunkLean(List<PoseFrame> frames) {
    final scores = <double>[];

    for (final frame in frames) {
      final lShoulder = frame.getLandmark(PoseFrame.leftShoulder);
      final rShoulder = frame.getLandmark(PoseFrame.rightShoulder);
      final lHip = frame.getLandmark(PoseFrame.leftHip);
      final rHip = frame.getLandmark(PoseFrame.rightHip);

      if (lShoulder == null || rShoulder == null ||
          lHip == null || rHip == null) continue;
      if (lShoulder.likelihood < _mainLandmarkThreshold) continue;
      if (rShoulder.likelihood < _mainLandmarkThreshold) continue;
      if (lHip.likelihood < _mainLandmarkThreshold) continue;
      if (rHip.likelihood < _mainLandmarkThreshold) continue;

      final shoulderMidX = (lShoulder.x + rShoulder.x) / 2;
      final shoulderMidY = (lShoulder.y + rShoulder.y) / 2;
      final hipMidX = (lHip.x + rHip.x) / 2;
      final hipMidY = (lHip.y + rHip.y) / 2;

      final dx = (shoulderMidX - hipMidX).abs();
      final dy = (shoulderMidY - hipMidY).abs();

      if (dy < 1e-6) continue;

      final leanDeg = atan2(dx, dy) * 180 / pi;

      final score = AngleCalculator.rangeScore(
        leanDeg,
        idealMin: 0,
        idealMax: 10,
        tolerance: 15,
      );
      scores.add(score);
    }

    final avgScore =
        scores.isEmpty ? 50.0 : scores.reduce((a, b) => a + b) / scores.length;

    return CriterionResult(
      name: '상체 기울기',
      description: '상체 기울기 (10도 이내)',
      score: avgScore,
      weight: 0.10,
      grade: CriterionGrade.fromScore(avgScore),
    );
  }

  // ── 5. 좌우 대칭 (Symmetry) — 10% ───────────────────────────────────
  CriterionResult _evaluateSymmetry(List<PoseFrame> frames) {
    final scores = <double>[];

    for (final frame in frames) {
      final lShoulder = frame.getLandmark(PoseFrame.leftShoulder);
      final rShoulder = frame.getLandmark(PoseFrame.rightShoulder);
      final lHip = frame.getLandmark(PoseFrame.leftHip);
      final rHip = frame.getLandmark(PoseFrame.rightHip);

      if (lShoulder == null || rShoulder == null ||
          lHip == null || rHip == null) continue;
      if (lShoulder.likelihood < _mainLandmarkThreshold) continue;
      if (rShoulder.likelihood < _mainLandmarkThreshold) continue;
      if (lHip.likelihood < _mainLandmarkThreshold) continue;
      if (rHip.likelihood < _mainLandmarkThreshold) continue;

      final shoulderDiff = AngleCalculator.yDifference(lShoulder, rShoulder);
      final hipDiff = AngleCalculator.yDifference(lHip, rHip);

      final shoulderScore =
          (1 - (shoulderDiff / 0.08).clamp(0.0, 1.0)) * 100;
      final hipScore =
          (1 - (hipDiff / 0.08).clamp(0.0, 1.0)) * 100;

      scores.add((shoulderScore + hipScore) / 2);
    }

    final avgScore =
        scores.isEmpty ? 50.0 : scores.reduce((a, b) => a + b) / scores.length;

    return CriterionResult(
      name: '좌우 대칭',
      description: '좌우 대칭',
      score: avgScore,
      weight: 0.10,
      grade: CriterionGrade.fromScore(avgScore),
    );
  }
}
