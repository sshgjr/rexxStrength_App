import 'dart:math';
import '../../models/pose_frame.dart';
import '../../models/evaluation_result.dart';
import '../angle_calculator.dart';
import 'exercise_rule.dart';

/// 팔씨름 보조 운동 - 프로네이션컬 평가 규칙
class PronationCurlRules implements ExerciseRule {
  @override
  String get name => '프로네이션컬';

  static const double _mainThreshold = 0.5;
  static const double _fingerThreshold = 0.2;
  static const double _minFrameRatio = 0.3;

  @override
  List<CriterionResult> evaluate(List<PoseFrame> frames) {
    return [
      _evaluatePronationChange(frames),
      _evaluateWeightControl(frames),
      _evaluateCurlArc(frames),
      _evaluateWristStability(frames),
      _evaluateSymmetry(frames),
    ];
  }

  // ── 1. 엄지 방향 전환 (Pronation Change) — 35% ──────────────────────
  CriterionResult _evaluatePronationChange(List<PoseFrame> frames) {
    final pronationRatios = <double>[];
    int validFrames = 0;

    for (final frame in frames) {
      final wrist = frame.getLandmark(PoseFrame.rightWrist);
      final elbow = frame.getLandmark(PoseFrame.rightElbow);
      final thumb = frame.getLandmark(PoseFrame.rightThumb);
      final pinky = frame.getLandmark(PoseFrame.rightPinky);

      if (wrist == null || elbow == null) continue;
      if (wrist.likelihood < _mainThreshold) continue;
      if (elbow.likelihood < _mainThreshold) continue;
      if (thumb == null || pinky == null) continue;
      if (thumb.likelihood < _fingerThreshold) continue;
      if (pinky.likelihood < _fingerThreshold) continue;

      validFrames++;

      final wristElbowDist = sqrt(
        pow(wrist.x - elbow.x, 2) + pow(wrist.y - elbow.y, 2),
      );
      if (wristElbowDist < 1e-6) continue;

      final pronationRatio = (thumb.y - pinky.y) / wristElbowDist;
      pronationRatios.add(pronationRatio);
    }

    final frameRatio = frames.isEmpty ? 0.0 : validFrames / frames.length;
    if (pronationRatios.length < 3 || frameRatio < _minFrameRatio) {
      return CriterionResult(
        name: '엄지 방향 전환',
        description: '측정값 부족 (카메라 각도 영향) | 엄지 방향 측정 불가 | 측면 촬영 권장',
        score: 65.0,
        weight: 0.35,
        grade: CriterionGrade.fromScore(65.0),
      );
    }

    final bottomCount = (pronationRatios.length * 0.3).ceil();
    final topCount = (pronationRatios.length * 0.3).ceil();
    final bottomRatios = pronationRatios.take(bottomCount).toList();
    final topRatios = pronationRatios.skip(pronationRatios.length - topCount).toList();

    final bottomAvg = bottomRatios.reduce((a, b) => a + b) / bottomRatios.length;
    final topAvg = topRatios.reduce((a, b) => a + b) / topRatios.length;
    final pronationChange = topAvg - bottomAvg;
    final maxPronation = pronationRatios.reduce((a, b) => a > b ? a : b);

    // 퍼센트로 변환 (0~100 스케일)
    final changePercent = (pronationChange * 100).clamp(-100.0, 100.0).round();
    final maxPercent = (maxPronation * 100).clamp(-100.0, 100.0).round();

    double score;
    if (pronationChange >= 0.2 && maxPronation >= 0.15) {
      score = 100.0;
    } else if (pronationChange >= 0.1 || maxPronation >= 0.15) {
      score = 70.0 + (pronationChange.clamp(0.0, 0.2) / 0.2) * 30.0;
    } else if (pronationChange >= 0.0) {
      score = 40.0 + (pronationChange / 0.1) * 30.0;
    } else {
      score = (1 + pronationChange / 0.2).clamp(0.0, 1.0) * 40.0;
    }

    // LLM이 활용할 수 있는 풍부한 detail
    final String detail;
    if (maxPronation >= 0.15 && pronationChange >= 0.15) {
      detail = '엄지 방향 전환 충분 | 시작~끝 변화량 $changePercent% | 최대 엄지 아래 방향 $maxPercent% | '
          '컬 올라가면서 엄지가 바닥을 잘 향하고 있음 | 팔씨름 훅 전환 패턴과 일치 | '
          '추천: 현재 중량 유지, 엄지가 완전히 바닥을 향한 지점에서 3초 버티기 추가';
    } else if (maxPronation >= 0.15) {
      detail = '엄지 최대 방향은 나오지만 전환 타이밍 늦음 | 변화량 $changePercent% | 최대 $maxPercent% | '
          '컬 끝 부분에서만 엄지가 아래를 향함 | 컬 시작할 때부터 엄지를 돌려야 함 | '
          '추천: 중량 유지, 컬 시작 순간부터 엄지 돌리기 의식적으로 연습';
    } else if (pronationChange >= 0.1) {
      detail = '엄지 방향 전환 약함 | 변화량 $changePercent% | 최대 $maxPercent% | '
          '엄지가 중간 정도만 아래를 향함 | 엄지를 더 바닥 방향으로 돌리는 힘이 부족 | '
          '추천: 중량 10~20% 감소, 엄지 바닥 방향 집중 훈련';
    } else {
      detail = '엄지 방향 전환 거의 없음 | 변화량 $changePercent% | 최대 $maxPercent% | '
          '컬 동작 중 엄지가 위 또는 옆을 향한 채로 끝남 | '
          '엄지를 바닥 방향으로 돌리는 근육이 거의 쓰이지 않음 | '
          '추천: 중량 30% 이상 감소, 손목 45도 안쪽 굽힌 후 엄지 바닥 방향 전환 집중';
    }

    return CriterionResult(
      name: '엄지 방향 전환',
      description: detail,
      score: score.clamp(0.0, 100.0),
      weight: 0.35,
      grade: CriterionGrade.fromScore(score),
    );
  }

  // ── 2. 중량 컨트롤 (Weight Control) — 25% ───────────────────────────
  CriterionResult _evaluateWeightControl(List<PoseFrame> frames) {
    if (frames.length < 3) {
      return CriterionResult(
        name: '중량 컨트롤',
        description: '프레임 부족으로 측정 불가 | 영상 길이 부족',
        score: 50.0,
        weight: 0.25,
        grade: CriterionGrade.warning,
      );
    }

    double bodyHeight = 1.0;
    for (final frame in frames) {
      final shoulder = frame.getLandmark(PoseFrame.rightShoulder);
      final hip = frame.getLandmark(PoseFrame.rightHip);
      if (shoulder != null && hip != null &&
          shoulder.likelihood >= _mainThreshold &&
          hip.likelihood >= _mainThreshold) {
        final h = (shoulder.y - hip.y).abs();
        if (h > bodyHeight) bodyHeight = h;
      }
    }

    final wristPositions = <List<double>>[];
    for (final frame in frames) {
      final wrist = frame.getLandmark(PoseFrame.rightWrist);
      if (wrist != null && wrist.likelihood >= _mainThreshold) {
        wristPositions.add([wrist.x, wrist.y]);
      }
    }

    if (wristPositions.length < 3) {
      return CriterionResult(
        name: '중량 컨트롤',
        description: '손목 랜드마크 부족으로 측정 불가',
        score: 50.0,
        weight: 0.25,
        grade: CriterionGrade.warning,
      );
    }

    final velocities = <double>[];
    for (int i = 1; i < wristPositions.length; i++) {
      final dx = wristPositions[i][0] - wristPositions[i - 1][0];
      final dy = wristPositions[i][1] - wristPositions[i - 1][1];
      velocities.add(sqrt(dx * dx + dy * dy) / bodyHeight);
    }

    final accelerations = <double>[];
    for (int i = 1; i < velocities.length; i++) {
      accelerations.add((velocities[i] - velocities[i - 1]).abs());
    }

    if (accelerations.isEmpty) {
      return CriterionResult(
        name: '중량 컨트롤',
        description: '가속도 계산 불가',
        score: 50.0,
        weight: 0.25,
        grade: CriterionGrade.warning,
      );
    }

    final avgAcceleration =
        accelerations.reduce((a, b) => a + b) / accelerations.length;

    final stabilityScore = AngleCalculator.rangeScore(
      avgAcceleration * 1000,
      idealMin: 0,
      idealMax: 10,
      tolerance: 40,
    );

    final String detail;
    if (avgAcceleration < 0.01) {
      detail = '중량 컨트롤 매우 안정적 | 손목 궤적 흔들림 없음 | '
          '현재 중량이 적절하거나 여유 있음 | 중량 증가 가능 | '
          '추천: 현재 중량에서 엄지 방향 전환 완성 후 중량 5~10% 증가';
    } else if (avgAcceleration < 0.03) {
      detail = '중량 컨트롤 양호 | 약간의 손목 궤적 흔들림 있지만 허용 범위 | '
          '현재 중량이 적절한 수준 | '
          '추천: 현재 중량 유지하며 엄지 방향 전환에 집중';
    } else if (avgAcceleration < 0.05) {
      detail = '중량이 다소 무거움 | 손목 궤적 흔들림 감지 | '
          '엄지 방향 전환 동작을 수행할 여유가 줄어드는 상태 | '
          '추천: 중량 15~20% 감소 후 엄지 방향 전환 패턴 먼저 확립';
    } else {
      detail = '중량이 과함 | 손목 궤적 심한 흔들림 | '
          '엄지를 바닥 방향으로 돌리는 동작 자체가 불가능한 중량 | '
          '추천: 중량 30% 이상 감소 필수, 가벼운 무게로 패턴 재확립';
    }

    return CriterionResult(
      name: '중량 컨트롤',
      description: detail,
      score: stabilityScore,
      weight: 0.25,
      grade: CriterionGrade.fromScore(stabilityScore),
    );
  }

  // ── 3. 컬 궤적 완성도 (Curl Arc) — 20% ─────────────────────────────
  CriterionResult _evaluateCurlArc(List<PoseFrame> frames) {
    final wristYPositions = <double>[];

    for (final frame in frames) {
      final wrist = frame.getLandmark(PoseFrame.rightWrist);
      if (wrist != null && wrist.likelihood >= _mainThreshold) {
        wristYPositions.add(wrist.y);
      }
    }

    if (wristYPositions.length < 4) {
      return CriterionResult(
        name: '컬 궤적',
        description: '프레임 부족으로 컬 궤적 측정 불가',
        score: 50.0,
        weight: 0.20,
        grade: CriterionGrade.warning,
      );
    }

    double bodyHeight = 1.0;
    for (final frame in frames) {
      final shoulder = frame.getLandmark(PoseFrame.rightShoulder);
      final hip = frame.getLandmark(PoseFrame.rightHip);
      if (shoulder != null && hip != null &&
          shoulder.likelihood >= _mainThreshold &&
          hip.likelihood >= _mainThreshold) {
        final h = (shoulder.y - hip.y).abs();
        if (h > bodyHeight) bodyHeight = h;
      }
    }

    final maxY = wristYPositions.reduce((a, b) => a > b ? a : b);
    final minY = wristYPositions.reduce((a, b) => a < b ? a : b);
    final curlRom = (maxY - minY) / bodyHeight;
    final curlRomPercent = (curlRom * 100).round();

    int directionChanges = 0;
    for (int i = 1; i < wristYPositions.length - 1; i++) {
      final prev = wristYPositions[i] - wristYPositions[i - 1];
      final next = wristYPositions[i + 1] - wristYPositions[i];
      if (prev * next < 0 && prev.abs() > 0.005 && next.abs() > 0.005) {
        directionChanges++;
      }
    }

    final romScore = AngleCalculator.rangeScore(
      curlRom * 100,
      idealMin: 15,
      idealMax: 40,
      tolerance: 15,
    );
    final reversalPenalty = (directionChanges * 10).clamp(0, 40).toDouble();
    final finalScore = (romScore - reversalPenalty).clamp(0.0, 100.0);

    final String detail;
    if (curlRom >= 0.15 && directionChanges <= 2) {
      detail = '컬 궤적 안정적 | 손목 이동 범위 신체 대비 $curlRomPercent% | 반동 횟수 $directionChanges회 | '
          '손목이 일정한 호를 그리며 올라옴 | 중량 컨트롤 여유 있음 | '
          '추천: 현재 컬 궤적 유지하며 엄지 방향 전환 추가';
    } else if (curlRom >= 0.15 && directionChanges > 2) {
      detail = '컬 범위는 충분하지만 반동 과다 | 이동 범위 $curlRomPercent% | 반동 $directionChanges회 감지 | '
          '반동으로 중량을 올리는 경향 있음 | 엄지 방향 전환 동작 방해 | '
          '추천: 천천히 컨트롤하며 올리기, 반동 없이 순수 근력으로 수행';
    } else if (curlRom < 0.10) {
      detail = '컬 가동범위 매우 짧음 | 이동 범위 $curlRomPercent% | '
          '부분 가동범위 수행 — 팔씨름 실전 패턴과 유사 | '
          '이 구간에서 엄지 방향 전환이 완성되면 실전 훅 힘에 직접 연결 | '
          '추천: 현재 구간 유지하며 엄지 방향 전환 폭발적으로 반복';
    } else {
      detail = '컬 가동범위 부족 | 이동 범위 $curlRomPercent% | '
          '손목을 더 높이 끌어올리면 전완 전체가 동원됨 | '
          '추천: 손목을 끝까지 끌어올리는 연습 추가';
    }

    return CriterionResult(
      name: '컬 궤적',
      description: detail,
      score: finalScore,
      weight: 0.20,
      grade: CriterionGrade.fromScore(finalScore),
    );
  }

  // ── 4. 손목 안정성 (Wrist Stability) — 10% ──────────────────────────
  CriterionResult _evaluateWristStability(List<PoseFrame> frames) {
    final wristAngles = <double>[];

    for (final frame in frames) {
      final elbow = frame.getLandmark(PoseFrame.rightElbow);
      final wrist = frame.getLandmark(PoseFrame.rightWrist);
      final index = frame.getLandmark(PoseFrame.rightIndex);

      if (elbow == null || wrist == null || index == null) continue;
      if (elbow.likelihood < _mainThreshold) continue;
      if (wrist.likelihood < _mainThreshold) continue;
      if (index.likelihood < _fingerThreshold) continue;

      final angle = AngleCalculator.calculateAngle(elbow, wrist, index);
      wristAngles.add(angle);
    }

    if (wristAngles.isEmpty) {
      return CriterionResult(
        name: '손목 안정성',
        description: '손목 안정성 측정값 부족 | 카메라 각도 영향',
        score: 65.0,
        weight: 0.10,
        grade: CriterionGrade.fromScore(65.0),
      );
    }

    final avg = wristAngles.reduce((a, b) => a + b) / wristAngles.length;
    final variance = wristAngles
        .map((a) => pow(a - avg, 2))
        .reduce((a, b) => a + b) / wristAngles.length;
    final stdDev = sqrt(variance);
    final avgRound = avg.round();

    final angleScore = AngleCalculator.rangeScore(avg, idealMin: 150, idealMax: 180, tolerance: 30);
    final stabilityScore = AngleCalculator.rangeScore(stdDev, idealMin: 0, idealMax: 10, tolerance: 20);
    final finalScore = (angleScore * 0.6 + stabilityScore * 0.4).clamp(0.0, 100.0);

    final String detail;
    if (avg >= 150 && stdDev <= 15) {
      detail = '손목 안정적 | 평균 손목 각도 $avgRound도 (중립) | 변동폭 ${stdDev.round()}도 | '
          '엄지에 하중이 안정적으로 걸리고 있음 | 손목 꺾임 없음 | '
          '추천: 현재 손목 자세 유지하며 엄지 방향 전환에 집중';
    } else if (avg < 140) {
      detail = '손목 뒤로 꺾임 | 평균 손목 각도 $avgRound도 | '
          '엄지에 하중이 제대로 안 걸리고 손목 부상 위험 | '
          '손목을 중립으로 세운 후 엄지 방향으로 힘을 실어야 함 | '
          '추천: 중량 감소 후 손목 45도 안쪽으로 굽힌 중립 자세에서 시작';
    } else {
      detail = '손목 각도 불규칙 | 평균 $avgRound도 | 변동폭 ${stdDev.round()}도 (큰 편) | '
          '중량이 무거워 손목이 흔들리는 상태 | '
          '추천: 중량 감소 후 손목 고정 연습';
    }

    return CriterionResult(
      name: '손목 안정성',
      description: detail,
      score: finalScore,
      weight: 0.10,
      grade: CriterionGrade.fromScore(finalScore),
    );
  }

  // ── 5. 좌우 대칭 (Symmetry) — 10% ──────────────────────────────────
  CriterionResult _evaluateSymmetry(List<PoseFrame> frames) {
    final scores = <double>[];

    for (final frame in frames) {
      final lShoulder = frame.getLandmark(PoseFrame.leftShoulder);
      final rShoulder = frame.getLandmark(PoseFrame.rightShoulder);
      final lHip = frame.getLandmark(PoseFrame.leftHip);
      final rHip = frame.getLandmark(PoseFrame.rightHip);

      if (lShoulder == null || rShoulder == null ||
          lHip == null || rHip == null) continue;
      if (lShoulder.likelihood < _mainThreshold) continue;
      if (rShoulder.likelihood < _mainThreshold) continue;
      if (lHip.likelihood < _mainThreshold) continue;
      if (rHip.likelihood < _mainThreshold) continue;

      final shoulderDiff = AngleCalculator.yDifference(lShoulder, rShoulder);
      final hipDiff = AngleCalculator.yDifference(lHip, rHip);

      final shoulderScore = (1 - (shoulderDiff / 0.08).clamp(0.0, 1.0)) * 100;
      final hipScore = (1 - (hipDiff / 0.08).clamp(0.0, 1.0)) * 100;
      scores.add((shoulderScore + hipScore) / 2);
    }

    final avgScore =
        scores.isEmpty ? 50.0 : scores.reduce((a, b) => a + b) / scores.length;

    final String detail;
    if (avgScore >= 80) {
      detail = '좌우 균형 좋음 | 어깨 높이 차이 최소 | 양팔 균형 훈련 유지';
    } else if (avgScore >= 60) {
      detail = '좌우 약간 불균형 | 한쪽 어깨가 올라가는 경향 | '
          '추천: 거울 보며 수행하거나 양팔 교대 훈련';
    } else {
      detail = '좌우 불균형 | 어깨 높이 차이 큼 | '
          '한쪽에 과도한 보상 움직임 발생 | '
          '추천: 단팔로 교대 훈련, 약한 쪽 집중 강화';
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
