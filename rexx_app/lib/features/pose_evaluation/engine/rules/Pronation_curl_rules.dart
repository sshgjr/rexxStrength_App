import 'dart:math';
import '../../models/pose_frame.dart';
import '../../models/evaluation_result.dart';
import '../angle_calculator.dart';
import 'exercise_rule.dart';

/// 팔씨름 보조 운동 - 프로네이션컬 평가 규칙
///
/// [프로네이션컬이란?]
/// 케이블/덤벨/원판을 손으로 잡고 컬 동작을 수행하면서
/// 동시에 손목을 회외(supination) → 회내(pronation)로 회전시키는 운동.
/// 팔씨름 훅/탑롤 전환 시 필요한 전완 회내근 강화가 목적.
///
/// [평가 철학]
/// - 팔꿈치를 몸에 붙여 고립하는 운동이 아님
/// - 손으로 중량을 뽑는 궤적(컬 호)이 핵심
/// - 엄지에 하중이 걸리면서 회내가 진행되는지가 가장 중요
///
/// [핵심 분석 항목]
/// 1. 손목 회내 변화량 (35%) — 동작 중 엄지가 위→아래로 얼마나 회전했는지
/// 2. 중량 컨트롤 안정성 (25%) — 손목/손 궤적의 흔들림 (과중량 감지)
/// 3. 컬 궤적 완성도 (20%) — 손목이 일정한 호를 그리며 올라오는지
/// 4. 손목 안정성 (10%) — 회내 시 손목이 과도하게 꺾이지 않는지
/// 5. 좌우 대칭 (10%) — 양팔 어깨 높이 균형
class PronationCurlRules implements ExerciseRule {
  @override
  String get name => '프로네이션컬';

  // ── likelihood 임계값 ─────────────────────────────────────────────────
  static const double _mainThreshold = 0.5;    // 주요 관절
  static const double _fingerThreshold = 0.2;  // 손가락 (측면 촬영 시 잘 안 잡힘)
  static const double _minFrameRatio = 0.3;    // 유효 프레임 최소 비율

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

  // ── 1. 손목 회내 변화량 (Pronation Change) — 35% ─────────────────────
  //
  // 프로네이션컬의 핵심: 동작 시작(하단)과 끝(상단)에서
  // 엄지 방향이 얼마나 바뀌었는지 (회외→회내 변화량)를 측정.
  //
  // 측면 촬영 기준:
  //   - 엄지(thumb)와 소지(pinky)의 Y좌표 차이로 회내 정도 측정
  //   - 시작: thumb.y < pinky.y (엄지 위 = 회외) 또는 중립
  //   - 끝:   thumb.y > pinky.y (엄지 아래 = 회내)
  //
  // 평가:
  //   - 변화량이 클수록 (회외→회내 전환) 좋은 점수
  //   - 처음부터 끝까지 회내 상태 유지도 긍정 평가 (의도된 수행)
  CriterionResult _evaluatePronationChange(List<PoseFrame> frames) {
    final pronationRatios = <double>[];  // 프레임별 회내 비율
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

      // 양수 = 엄지 아래 = 회내, 음수 = 엄지 위 = 회외
      final pronationRatio = (thumb.y - pinky.y) / wristElbowDist;
      pronationRatios.add(pronationRatio);
    }

    // 유효 프레임 부족 시 중립값
    final frameRatio = frames.isEmpty ? 0.0 : validFrames / frames.length;
    if (pronationRatios.length < 3 || frameRatio < _minFrameRatio) {
      return CriterionResult(
        name: '손목 회내',
        description: '손목 회내 측정값 부족 (카메라 각도 영향)',
        score: 65.0,
        weight: 0.35,
        grade: CriterionGrade.fromScore(65.0),
      );
    }

    // 동작 구간 분리: 하단(첫 30%), 상단(마지막 30%)
    final bottomCount = (pronationRatios.length * 0.3).ceil();
    final topCount = (pronationRatios.length * 0.3).ceil();

    final bottomRatios = pronationRatios.take(bottomCount).toList();
    final topRatios = pronationRatios
        .skip(pronationRatios.length - topCount)
        .toList();

    final bottomAvg = bottomRatios.reduce((a, b) => a + b) / bottomRatios.length;
    final topAvg = topRatios.reduce((a, b) => a + b) / topRatios.length;

    // 회내 변화량: 상단 - 하단 (클수록 좋음)
    final pronationChange = topAvg - bottomAvg;

    // 동작 전체의 최대 회내 값 (얼마나 깊게 회내했는지)
    final maxPronation = pronationRatios.reduce((a, b) => a > b ? a : b);

    double score;

    if (pronationChange >= 0.2 && maxPronation >= 0.15) {
      // 이상적: 회외→회내 전환이 충분하고 최대 회내도 좋음
      score = 100.0;
    } else if (pronationChange >= 0.1 || maxPronation >= 0.15) {
      // 양호: 어느 정도 변화 있거나 회내 자체는 충분
      score = 70.0 + (pronationChange.clamp(0.0, 0.2) / 0.2) * 30.0;
    } else if (pronationChange >= 0.0) {
      // 약한 변화: 회내가 일어나긴 하지만 부족
      score = 40.0 + (pronationChange / 0.1) * 30.0;
    } else {
      // 변화 없음 또는 역방향: 회내가 안 일어남
      score = (1 + pronationChange / 0.2).clamp(0.0, 1.0) * 40.0;
    }

    // 디테일 문구 생성
    final String detail;
    if (maxPronation >= 0.15 && pronationChange >= 0.15) {
      detail = '회내 전환 충분 — 엄지가 아래를 향하며 전완 회내근이 잘 활성화되고 있어요';
    } else if (maxPronation >= 0.15) {
      detail = '회내 자세는 나오지만 전환 타이밍이 늦어요 — 컬 시작 시점부터 회내를 시작해보세요';
    } else if (pronationChange >= 0.1) {
      detail = '회내 변화는 있지만 충분하지 않아요 — 엄지를 더 아래로 돌려보세요';
    } else {
      detail = '손목 회내 변화가 거의 없어요 — 동작 중 엄지를 바닥 방향으로 돌리는 게 핵심이에요';
    }

    return CriterionResult(
      name: '손목 회내',
      description: detail,
      score: score.clamp(0.0, 100.0),
      weight: 0.35,
      grade: CriterionGrade.fromScore(score),
    );
  }

  // ── 2. 중량 컨트롤 안정성 (Weight Control) — 25% ─────────────────────
  //
  // 손목 위치의 궤적 안정성으로 중량 컨트롤 여부를 측정.
  // 과중량이면 손목 궤적이 흔들리거나 비선형적으로 움직임.
  //
  // 측정 방법:
  //   - 연속 프레임 간 손목 속도 변화량 (가속도) 계산
  //   - 신체 높이 대비 정규화
  //   - 급격한 변화 = 컨트롤 부족 = 과중량 신호
  CriterionResult _evaluateWeightControl(List<PoseFrame> frames) {
    if (frames.length < 3) {
      return CriterionResult(
        name: '중량 컨트롤',
        description: '중량 컨트롤 측정을 위한 프레임 부족',
        score: 50.0,
        weight: 0.25,
        grade: CriterionGrade.warning,
      );
    }

    // 신체 높이 계산 (어깨-힙 거리)
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

    // 손목 위치 수집
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
        description: '손목 랜드마크 부족',
        score: 50.0,
        weight: 0.25,
        grade: CriterionGrade.warning,
      );
    }

    // 연속 프레임 간 속도 계산
    final velocities = <double>[];
    for (int i = 1; i < wristPositions.length; i++) {
      final dx = wristPositions[i][0] - wristPositions[i - 1][0];
      final dy = wristPositions[i][1] - wristPositions[i - 1][1];
      velocities.add(sqrt(dx * dx + dy * dy) / bodyHeight);
    }

    // 속도 변화량 (가속도) — 급격한 변화 = 컨트롤 부족
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
    final maxAcceleration = accelerations.reduce((a, b) => a > b ? a : b);

    // 정규화된 가속도 기반 점수
    // avgAcceleration < 0.01: 매우 안정적 → 100점
    // avgAcceleration > 0.05: 불안정 → 0점
    final stabilityScore = AngleCalculator.rangeScore(
      avgAcceleration * 1000,
      idealMin: 0,
      idealMax: 10,
      tolerance: 40,
    );

    final String detail;
    if (avgAcceleration < 0.01) {
      detail = '중량 컨트롤 안정적 — 손목 궤적이 일정해요';
    } else if (avgAcceleration < 0.03) {
      detail = '중량 컨트롤 양호 — 약간의 흔들림이 있지만 허용 범위예요';
    } else if (avgAcceleration < 0.05) {
      detail = '중량이 다소 무거워 보여요 — 손목 궤적이 흔들리고 있어요';
    } else {
      detail = '중량이 너무 무거워요 — 손목이 흔들려서 회내 동작이 제대로 안 나올 수 있어요';
    }

    return CriterionResult(
      name: '중량 컨트롤',
      description: detail,
      score: stabilityScore,
      weight: 0.25,
      grade: CriterionGrade.fromScore(stabilityScore),
    );
  }

  // ── 3. 컬 궤적 완성도 (Curl Arc) — 20% ──────────────────────────────
  //
  // 손목이 일정한 호를 그리며 올라오는지 측정.
  // 측면 촬영 기준: 손목의 Y좌표가 꾸준히 감소(위로)해야 함.
  //
  // 평가:
  //   - 손목 Y좌표의 최저점 → 최고점 이동량 (컬 ROM)
  //   - 중간에 역방향 움직임이 있으면 감점 (반동 신호)
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
        description: '컬 궤적 측정을 위한 프레임 부족',
        score: 50.0,
        weight: 0.20,
        grade: CriterionGrade.warning,
      );
    }

    // 신체 높이 (정규화용)
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

    // 컬 가동범위 (신체 높이 대비)
    final curlRom = (maxY - minY) / bodyHeight;

    // 역방향 움직임 횟수 계산 (반동 감지)
    int directionChanges = 0;
    for (int i = 1; i < wristYPositions.length - 1; i++) {
      final prev = wristYPositions[i] - wristYPositions[i - 1];
      final next = wristYPositions[i + 1] - wristYPositions[i];
      // 방향이 바뀌고 변화량이 유의미한 경우
      if (prev * next < 0 && prev.abs() > 0.005 && next.abs() > 0.005) {
        directionChanges++;
      }
    }

    // ROM 점수 (신체 대비 15% 이상 움직임이면 충분)
    final romScore = AngleCalculator.rangeScore(
      curlRom * 100,
      idealMin: 15,
      idealMax: 40,
      tolerance: 15,
    );

    // 반동 페널티
    final reversalPenalty = (directionChanges * 10).clamp(0, 40).toDouble();
    final finalScore = (romScore - reversalPenalty).clamp(0.0, 100.0);

    final String detail;
    if (curlRom >= 0.15 && directionChanges <= 2) {
      detail = '컬 궤적이 부드럽고 안정적이에요 — 손목이 일정한 호를 그리고 있어요';
    } else if (curlRom >= 0.15 && directionChanges > 2) {
      detail = '컬 범위는 충분하지만 중간에 반동이 감지돼요 — 천천히 컨트롤하며 올려보세요';
    } else if (curlRom < 0.15) {
      detail = '컬 가동범위가 짧아요 — 손목을 더 높이 끌어올려 Full ROM으로 수행해보세요';
    } else {
      detail = '컬 궤적이 불규칙해요 — 중량을 줄이고 일정한 속도로 올려보세요';
    }

    return CriterionResult(
      name: '컬 궤적',
      description: detail,
      score: finalScore,
      weight: 0.20,
      grade: CriterionGrade.fromScore(finalScore),
    );
  }

  // ── 4. 손목 안정성 (Wrist Stability) — 10% ───────────────────────────
  //
  // 회내 동작 중 손목이 과도하게 꺾이지 않는지 측정.
  // 팔꿈치-손목-손가락(index) 각도로 손목 굴곡/신전 여부 확인.
  // 엄지에 하중이 걸릴 때 손목이 뒤로 꺾이면 부상 위험.
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

      // 팔꿈치-손목-검지 각도 (180도에 가까울수록 손목이 중립)
      final angle = AngleCalculator.calculateAngle(elbow, wrist, index);
      wristAngles.add(angle);
    }

    if (wristAngles.isEmpty) {
      return CriterionResult(
        name: '손목 안정성',
        description: '손목 안정성 측정값 부족',
        score: 65.0,
        weight: 0.10,
        grade: CriterionGrade.fromScore(65.0),
      );
    }

    // 손목 각도의 표준편차 (변동이 클수록 불안정)
    final avg = wristAngles.reduce((a, b) => a + b) / wristAngles.length;
    final variance = wristAngles
        .map((a) => pow(a - avg, 2))
        .reduce((a, b) => a + b) / wristAngles.length;
    final stdDev = sqrt(variance);

    // 평균 각도 기반 점수 (150~180도가 이상적)
    final angleScore = AngleCalculator.rangeScore(
      avg,
      idealMin: 150,
      idealMax: 180,
      tolerance: 30,
    );

    // 변동성 페널티 (표준편차 20 이상이면 불안정)
    final stabilityScore = AngleCalculator.rangeScore(
      stdDev,
      idealMin: 0,
      idealMax: 10,
      tolerance: 20,
    );

    final finalScore = (angleScore * 0.6 + stabilityScore * 0.4).clamp(0.0, 100.0);

    final String detail;
    if (avg >= 150 && stdDev <= 15) {
      detail = '손목이 중립을 잘 유지하고 있어요 — 엄지에 하중이 안정적으로 걸리고 있어요';
    } else if (avg < 150) {
      detail = '손목이 뒤로 꺾이는 경향이 있어요 — 손목을 중립으로 세우고 엄지 방향으로 힘을 실어보세요';
    } else {
      detail = '손목 각도가 불규칙하게 변하고 있어요 — 중량을 줄이고 손목을 고정해보세요';
    }

    return CriterionResult(
      name: '손목 안정성',
      description: detail,
      score: finalScore,
      weight: 0.10,
      grade: CriterionGrade.fromScore(finalScore),
    );
  }

  // ── 5. 좌우 대칭 (Symmetry) — 10% ───────────────────────────────────
  //
  // 어깨/힙 높이 차이로 좌우 균형 측정.
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

    return CriterionResult(
      name: '좌우 대칭',
      description: '좌우 대칭',
      score: avgScore,
      weight: 0.10,
      grade: CriterionGrade.fromScore(avgScore),
    );
  }
}
