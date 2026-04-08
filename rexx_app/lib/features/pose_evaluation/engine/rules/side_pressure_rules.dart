import 'dart:math';
import '../../models/pose_frame.dart';
import '../../models/evaluation_result.dart';
import '../angle_calculator.dart';
import 'exercise_rule.dart';

/// 팔씨름 보조 운동 - 사이드프레셔 평가 규칙
class SidePressureRules implements ExerciseRule {
  @override
  String get name => '사이드프레셔';

  static const double _mainLandmarkThreshold = 0.5;
  static const double _fingerLandmarkThreshold = 0.2;
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

  // ── 1. 엄지 방향 (Wrist Pronation) — 30% ────────────────────────────
  CriterionResult _evaluateWristPronation(List<PoseFrame> frames) {
    double weightedScoreSum = 0.0;
    double weightSum = 0.0;
    int validFrameCount = 0;
    final pronationRatios = <double>[];

    for (final frame in frames) {
      final wrist = frame.getLandmark(PoseFrame.rightWrist);
      final elbow = frame.getLandmark(PoseFrame.rightElbow);

      if (wrist == null || elbow == null) continue;
      if (wrist.likelihood < _mainLandmarkThreshold) continue;
      if (elbow.likelihood < _mainLandmarkThreshold) continue;

      final thumb = frame.getLandmark(PoseFrame.rightThumb);
      final pinky = frame.getLandmark(PoseFrame.rightPinky);

      if (thumb == null || pinky == null) continue;
      if (thumb.likelihood < _fingerLandmarkThreshold) continue;
      if (pinky.likelihood < _fingerLandmarkThreshold) continue;

      validFrameCount++;

      final wristElbowDist = sqrt(
        pow(wrist.x - elbow.x, 2) + pow(wrist.y - elbow.y, 2),
      );
      if (wristElbowDist < 1e-6) continue;

      final pronationRatio = (thumb.y - pinky.y) / wristElbowDist;
      pronationRatios.add(pronationRatio);

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
        score = (1 + pronationRatio / 0.2).clamp(0.0, 1.0) * 50.0;
      }

      final weight = (thumb.likelihood + pinky.likelihood) / 2.0;
      weightedScoreSum += score.clamp(0.0, 100.0) * weight;
      weightSum += weight;
    }

    final frameRatio = frames.isEmpty ? 0.0 : validFrameCount / frames.length;
    if (weightSum < 1e-6 || frameRatio < _pronationMinFrameRatio) {
      return CriterionResult(
        name: '엄지 방향',
        description: '측정값 부족 (카메라 각도 영향) | 엄지 방향 측정 불가 | 측면 촬영 권장',
        score: 70.0,
        weight: 0.30,
        grade: CriterionGrade.fromScore(70.0),
      );
    }

    final avgScore = weightedScoreSum / weightSum;
    final avgRatio = pronationRatios.isEmpty
        ? 0.0
        : pronationRatios.reduce((a, b) => a + b) / pronationRatios.length;
    final avgPercent = (avgRatio * 100).clamp(-100.0, 100.0).round();

    final String detail;
    if (avgRatio >= 0.15) {
      detail = '엄지 방향 좋음 | 평균 엄지 아래 방향 $avgPercent% | '
          '엄지가 바닥을 잘 향하고 있어요 | 팔씨름 사이드 힘 전달 방향과 일치 | '
          '추천: 현재 자세에서 3~5초 버티기 세트 추가';
    } else if (avgRatio >= 0.05) {
      detail = '엄지 방향 약간 부족 | 평균 엄지 아래 방향 $avgPercent% | '
          '엄지가 옆을 향하는 수준 — 바닥 방향으로 더 돌려야 함 | '
          '힘이 사이드 방향 대신 위쪽으로 일부 빠지고 있음 | '
          '추천: 동작 전 엄지를 완전히 아래로 돌린 상태에서 시작';
    } else if (avgRatio >= -0.05) {
      detail = '엄지 방향 부족 | 평균 엄지 방향 거의 중립 ($avgPercent%) | '
          '엄지가 옆을 향하고 있어요 | 엄지를 아래로 돌리는 근육이 비활성화 | '
          '사이드 방향으로 미는 힘이 절반 이하로 줄어든 상태 | '
          '추천: 중량 20% 감소, 엄지를 완전히 바닥 방향으로 돌리는 연습 먼저';
    } else {
      detail = '엄지 방향 반대 | 평균 엄지 위 방향 ${(-avgPercent)}% | '
          '엄지가 위를 향하고 있어요 — 완전히 반대 방향 | '
          '힘이 위쪽으로 새어 사이드 압박이 발휘되지 않음 | '
          '추천: 중량 30% 이상 감소, 엄지 바닥 방향 자세부터 재확립';
    }

    return CriterionResult(
      name: '엄지 방향',
      description: detail,
      score: avgScore,
      weight: 0.30,
      grade: CriterionGrade.fromScore(avgScore),
    );
  }

  // ── 2. 팔꿈치 각도 (Elbow Angle) — 25% ──────────────────────────────
  CriterionResult _evaluateElbowAngle(List<PoseFrame> frames) {
    final angles = <double>[];

    for (final frame in frames) {
      final shoulder = frame.getLandmark(PoseFrame.rightShoulder);
      final elbow = frame.getLandmark(PoseFrame.rightElbow);
      final wrist = frame.getLandmark(PoseFrame.rightWrist);

      if (shoulder == null || elbow == null || wrist == null) continue;
      if (shoulder.likelihood < _mainLandmarkThreshold) continue;
      if (elbow.likelihood < _mainLandmarkThreshold) continue;
      if (wrist.likelihood < _mainLandmarkThreshold) continue;

      angles.add(AngleCalculator.calculateAngle(shoulder, elbow, wrist));
    }

    if (angles.isEmpty) {
      return CriterionResult(
        name: '팔꿈치 각도',
        description: '팔꿈치 각도 측정 불가 | 랜드마크 신뢰도 부족',
        score: 50.0,
        weight: 0.25,
        grade: CriterionGrade.warning,
      );
    }

    final avgAngle = angles.reduce((a, b) => a + b) / angles.length;
    final avgAngleRound = avgAngle.round();

    final score = AngleCalculator.rangeScore(
      avgAngle,
      idealMin: 80,
      idealMax: 100,
      tolerance: 20,
    );

    final String detail;
    if (avgAngle >= 80 && avgAngle <= 100) {
      detail = '팔꿈치 각도 좋음 | 평균 $avgAngleRound도 (이상 80~100도) | '
          '힘 전달 효율이 가장 높은 각도 | '
          '추천: 이 각도에서 3~5초 버티기 세트 추가';
    } else if (avgAngle > 100 && avgAngle <= 120) {
      detail = '팔꿈치 약간 펴짐 | 평균 $avgAngleRound도 (이상보다 ${avgAngleRound - 90}도 더 펴짐) | '
          '팔꿈치가 펴질수록 어깨 쪽으로 힘이 분산됨 | '
          '옆으로 미는 힘 감소 + 어깨 부담 증가 | '
          '추천: 팔꿈치를 몸쪽으로 당겨 90도에 맞추기';
    } else if (avgAngle > 120) {
      detail = '팔꿈치 많이 펴짐 | 평균 $avgAngleRound도 (이상보다 ${avgAngleRound - 90}도 초과) | '
          '힘이 대부분 어깨로 분산되어 사이드 압박력이 크게 감소 | '
          '추천: 중량 줄이고 팔꿈치를 90도로 굽혀서 재시작';
    } else if (avgAngle < 80 && avgAngle >= 60) {
      detail = '팔꿈치 약간 굽힘 | 평균 $avgAngleRound도 (이상보다 ${90 - avgAngleRound}도 더 굽힘) | '
          '팔꿈치가 너무 굽으면 엄지를 아래로 돌리는 가동범위가 줄어듦 | '
          '추천: 팔꿈치를 살짝 펴서 90도에 맞추기';
    } else {
      detail = '팔꿈치 많이 굽힘 | 평균 $avgAngleRound도 | '
          '엄지 방향 전환 가동범위 제한 | '
          '추천: 팔꿈치를 펴서 90도 구간에서 수행';
    }

    return CriterionResult(
      name: '팔꿈치 각도',
      description: detail,
      score: score,
      weight: 0.25,
      grade: CriterionGrade.fromScore(score),
    );
  }

  // ── 3. 팔 방향 (Shoulder Abduction) — 25% ───────────────────────────
  CriterionResult _evaluateShoulderAbduction(List<PoseFrame> frames) {
    final angles = <double>[];

    for (final frame in frames) {
      final hip = frame.getLandmark(PoseFrame.rightHip);
      final shoulder = frame.getLandmark(PoseFrame.rightShoulder);
      final elbow = frame.getLandmark(PoseFrame.rightElbow);

      if (hip == null || shoulder == null || elbow == null) continue;
      if (hip.likelihood < _mainLandmarkThreshold) continue;
      if (shoulder.likelihood < _mainLandmarkThreshold) continue;
      if (elbow.likelihood < _mainLandmarkThreshold) continue;

      angles.add(AngleCalculator.calculateAngle(hip, shoulder, elbow));
    }

    if (angles.isEmpty) {
      return CriterionResult(
        name: '팔 방향',
        description: '팔 방향 측정 불가 | 랜드마크 신뢰도 부족',
        score: 50.0,
        weight: 0.25,
        grade: CriterionGrade.warning,
      );
    }

    final avgAngle = angles.reduce((a, b) => a + b) / angles.length;
    final avgAngleRound = avgAngle.round();

    final score = AngleCalculator.rangeScore(
      avgAngle,
      idealMin: 75,
      idealMax: 95,
      tolerance: 20,
    );

    final String detail;
    if (avgAngle >= 75 && avgAngle <= 95) {
      detail = '팔 방향 좋음 | 평균 $avgAngleRound도 (수평에 가까운 이상 범위) | '
          '어깨-팔꿈치-손 프레임이 수평 가압에 적합 | '
          '체중을 실어 누르면 강한 사이드 압박이 나옴 | '
          '추천: 이 자세에서 버티기 세트 추가';
    } else if (avgAngle < 75 && avgAngle >= 55) {
      detail = '팔이 몸에 너무 붙음 | 평균 $avgAngleRound도 (이상보다 ${75 - avgAngleRound}도 아래) | '
          '팔이 아래쪽을 향하면서 수평 가압 방향이 안 나옴 | '
          '힘이 아래로 빠지고 사이드 압박력 감소 | '
          '추천: 팔꿈치를 옆으로 더 벌려서 수평에 가깝게';
    } else if (avgAngle < 55) {
      detail = '팔이 너무 아래로 처짐 | 평균 $avgAngleRound도 | '
          '사이드프레셔 가압 방향이 전혀 나오지 않는 상태 | '
          '추천: 팔꿈치를 어깨 높이까지 들어올려 수평 유지';
    } else if (avgAngle > 95 && avgAngle <= 115) {
      detail = '팔이 약간 위로 올라감 | 평균 $avgAngleRound도 | '
          '힘이 위로 분산 + 어깨 충돌 위험 증가 | '
          '추천: 팔꿈치를 어깨 높이로 낮추기';
    } else {
      detail = '팔이 너무 위로 올라감 | 평균 $avgAngleRound도 | '
          '어깨 충돌 위험 높음 | '
          '추천: 팔꿈치를 어깨 높이로 내리고 수평 방향 유지';
    }

    return CriterionResult(
      name: '팔 방향',
      description: detail,
      score: score,
      weight: 0.25,
      grade: CriterionGrade.fromScore(score),
    );
  }

  // ── 4. 상체 기울기 (Trunk Lean) — 10% ───────────────────────────────
  CriterionResult _evaluateTrunkLean(List<PoseFrame> frames) {
    final leanAngles = <double>[];

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
      leanAngles.add(atan2(dx, dy) * 180 / pi);
    }

    if (leanAngles.isEmpty) {
      return CriterionResult(
        name: '상체 기울기',
        description: '상체 기울기 측정 불가 | 랜드마크 신뢰도 부족',
        score: 50.0,
        weight: 0.10,
        grade: CriterionGrade.warning,
      );
    }

    final avgLean = leanAngles.reduce((a, b) => a + b) / leanAngles.length;
    final avgLeanRound = avgLean.round();

    final score = AngleCalculator.rangeScore(
      avgLean,
      idealMin: 0,
      idealMax: 10,
      tolerance: 15,
    );

    final String detail;
    if (avgLean <= 10) {
      detail = '상체 안정적 | 평균 기울기 $avgLeanRound도 (이상 10도 이내) | '
          '체중을 안정적으로 실어 누를 수 있는 자세 | '
          '추천: 이 자세 유지하며 가압 강도 높이기';
    } else if (avgLean <= 20) {
      detail = '상체 약간 기울어짐 | 평균 기울기 $avgLeanRound도 | '
          '허리 부담 증가 + 체중 전달 효율 감소 | '
          '추천: 허리에 힘 주고 상체 세우기, 중량이 무거우면 줄이기';
    } else {
      detail = '상체 많이 기울어짐 | 평균 기울기 $avgLeanRound도 | '
          '중량이 너무 무거워 몸이 기울어지는 상태 | '
          '허리 부상 위험 + 사이드 가압 방향 손실 | '
          '추천: 중량 20~30% 감소 + 코어에 힘 주고 상체 세우기';
    }

    return CriterionResult(
      name: '상체 기울기',
      description: detail,
      score: score,
      weight: 0.10,
      grade: CriterionGrade.fromScore(score),
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

    final String detail;
    if (avgScore >= 80) {
      detail = '좌우 균형 좋음 | 어깨 높이 차이 최소 | '
          '균형 잡힌 자세로 힘 전달 효율 좋음 | '
          '추천: 현재 자세 유지';
    } else if (avgScore >= 60) {
      detail = '좌우 약간 불균형 | 한쪽 어깨가 올라가는 경향 | '
          '한쪽으로 힘이 쏠려 가압 방향이 틀어질 수 있음 | '
          '추천: 거울 보며 어깨 높이 맞추기';
    } else {
      detail = '좌우 불균형 심함 | 어깨 높이 차이 큼 | '
          '한쪽에 과도한 보상 움직임 — 부상 위험 | '
          '추천: 중량 줄이고 양쪽 어깨 높이 균등하게 맞추기';
    }

    return CriterionResult(
      name: '좌우 대칭',
      description: detail,
      score: avgScore,
      weight: 0.10,
      grade: CriterionGrade.fromScore(avgScore),
    );
  }
}
