import 'dart:math';
import '../../models/pose_frame.dart';
import '../../models/evaluation_result.dart';
import '../angle_calculator.dart';
import 'exercise_rule.dart';

/// 팔씨름 보조 운동 - 사이드프레셔 평가 규칙
///
/// [사이드프레셔란?]
/// 팔씨름 사이드프레셔 기술을 모방한 웨이트 운동.
/// 덤벨/케이블을 잡고 팔꿈치를 약간 굽힌 상태에서
/// 손목을 회내(pronation)하며 몸 옆으로 수평 가압하는 동작.
/// 어깨 외전 + 전완 회내의 복합 움직임.
///
/// [핵심 분석 항목]
/// 1. 손목 회내 (30%) — 사이드프레셔의 핵심. 엄지가 아래를 향하는지
/// 2. 팔꿈치 각도 (25%) — 70~110도 유지 여부
/// 3. 어깨 외전 (25%) — 팔이 수평에 가까운지
/// 4. 상체 기울기 (10%) — 과도한 몸 기울임 여부
/// 5. 좌우 대칭 (10%) — 어깨 높이 균형
class SidePressureRules implements ExerciseRule {
  @override
  String get name => '사이드프레셔';

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
  // 팔씨름 사이드프레셔의 핵심 동작.
  // ML Kit에서 엄지(thumb)와 소지(pinky)의 Y좌표 차이로 회내 정도를 측정.
  // 화면 좌표계: Y는 아래로 갈수록 증가.
  //   - thumb.y > pinky.y  → 엄지가 아래 (회내) ✅
  //   - thumb.y < pinky.y  → 엄지가 위 (회외) ❌
  //
  // 팔씨름 관점: 완벽한 고립이 아니어도 회내가 충분하면 긍정 평가.
  CriterionResult _evaluateWristPronation(List<PoseFrame> frames) {
    final scores = <double>[];

    for (final frame in frames) {
      // 오른팔 기준 (주도 팔) — 추후 side 파라미터로 분기 가능
      final wrist = frame.getLandmark(PoseFrame.rightWrist);
      final thumb = frame.getLandmark(PoseFrame.rightThumb);
      final pinky = frame.getLandmark(PoseFrame.rightPinky);
      final elbow = frame.getLandmark(PoseFrame.rightElbow);

      if (wrist == null || thumb == null || pinky == null || elbow == null) {
        continue;
      }

      // 엄지-소지 Y 차이 (양수 = 엄지가 아래 = 회내)
      final pronationDiff = thumb.y - pinky.y;

      // 손목-팔꿈치 거리로 정규화
      final wristElbowDist = sqrt(
        pow(wrist.x - elbow.x, 2) + pow(wrist.y - elbow.y, 2),
      );
      if (wristElbowDist < 1e-6) continue;

      final pronationRatio = pronationDiff / wristElbowDist;

      // 채점:
      //   pronationRatio >= 0.15 (충분한 회내) → 100점
      //   pronationRatio 0.0~0.15 (약한 회내)  → 선형 증가
      //   pronationRatio < 0.0 (회외)           → 0점 방향 감점
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

      scores.add(score.clamp(0.0, 100.0));
    }

    final avgScore =
        scores.isEmpty ? 50.0 : scores.reduce((a, b) => a + b) / scores.length;

    return CriterionResult(
      name: '손목 회내',
      description: '손목 회내 (엄지 아래 방향)',
      score: avgScore,
      weight: 0.30,
      grade: CriterionGrade.fromScore(avgScore),
    );
  }

  // ── 2. 팔꿈치 각도 (Elbow Angle) — 25% ──────────────────────────────
  //
  // 사이드프레셔에서 팔꿈치는 70~110도를 유지해야 함.
  //   - 너무 펴면(>120도): 어깨 관절 부담 증가, 레버리지 손실
  //   - 너무 굽히면(<60도): 전완 회내 가동범위 제한
  // 이상: 80~100도 / 허용 범위: 70~110도
  CriterionResult _evaluateElbowAngle(List<PoseFrame> frames) {
    final scores = <double>[];

    for (final frame in frames) {
      final shoulder = frame.getLandmark(PoseFrame.rightShoulder);
      final elbow = frame.getLandmark(PoseFrame.rightElbow);
      final wrist = frame.getLandmark(PoseFrame.rightWrist);

      if (shoulder == null || elbow == null || wrist == null) continue;

      final angle = AngleCalculator.calculateAngle(shoulder, elbow, wrist);

      // 이상 80~100도, tolerance 20 (60도 이하 / 120도 이상에서 0점)
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
  //
  // 사이드프레셔는 팔을 몸 옆으로 수평 가압하는 동작.
  // 어깨-팔꿈치 라인이 수평에 가까울수록 힘 전달 효율이 높음.
  // 힙-어깨-팔꿈치 각도로 측정: 이상 75~95도.
  CriterionResult _evaluateShoulderAbduction(List<PoseFrame> frames) {
    final scores = <double>[];

    for (final frame in frames) {
      final hip = frame.getLandmark(PoseFrame.rightHip);
      final shoulder = frame.getLandmark(PoseFrame.rightShoulder);
      final elbow = frame.getLandmark(PoseFrame.rightElbow);

      if (hip == null || shoulder == null || elbow == null) continue;

      // 힙→어깨→팔꿈치 각도: 수직(힙-어깨) 대비 팔의 벌어짐 정도
      final angle = AngleCalculator.calculateAngle(hip, shoulder, elbow);

      // 이상 75~95도, tolerance 20
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
  //
  // 과도한 상체 기울임은 허리 부담 + 힘 분산.
  // 어깨 중심-힙 중심 연결선의 수직 기울기로 측정.
  // 이상: 10도 이내 / 허용: 20도 이내 / 25도 이상: 감점
  CriterionResult _evaluateTrunkLean(List<PoseFrame> frames) {
    final scores = <double>[];

    for (final frame in frames) {
      final lShoulder = frame.getLandmark(PoseFrame.leftShoulder);
      final rShoulder = frame.getLandmark(PoseFrame.rightShoulder);
      final lHip = frame.getLandmark(PoseFrame.leftHip);
      final rHip = frame.getLandmark(PoseFrame.rightHip);

      if (lShoulder == null || rShoulder == null ||
          lHip == null || rHip == null) continue;

      // 어깨 중심 / 힙 중심
      final shoulderMidX = (lShoulder.x + rShoulder.x) / 2;
      final shoulderMidY = (lShoulder.y + rShoulder.y) / 2;
      final hipMidX = (lHip.x + rHip.x) / 2;
      final hipMidY = (lHip.y + rHip.y) / 2;

      final dx = (shoulderMidX - hipMidX).abs();
      final dy = (shoulderMidY - hipMidY).abs();

      if (dy < 1e-6) continue;

      final leanDeg = atan2(dx, dy) * 180 / pi;

      // 이상 0~10도, tolerance 15 (25도에서 0점)
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
  //
  // 어깨 높이 차이로 좌우 균형 측정.
  // DeadliftRules의 대칭 평가와 동일한 방식.
  CriterionResult _evaluateSymmetry(List<PoseFrame> frames) {
    final scores = <double>[];

    for (final frame in frames) {
      final lShoulder = frame.getLandmark(PoseFrame.leftShoulder);
      final rShoulder = frame.getLandmark(PoseFrame.rightShoulder);
      final lHip = frame.getLandmark(PoseFrame.leftHip);
      final rHip = frame.getLandmark(PoseFrame.rightHip);

      if (lShoulder == null || rShoulder == null ||
          lHip == null || rHip == null) continue;

      final shoulderDiff = AngleCalculator.yDifference(lShoulder, rShoulder);
      final hipDiff = AngleCalculator.yDifference(lHip, rHip);

      // 차이가 0.03 이내면 만점, 0.08 이상이면 0점
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
