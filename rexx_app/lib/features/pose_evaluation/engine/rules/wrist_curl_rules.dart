import 'dart:math';
import '../../models/pose_frame.dart';
import '../../models/evaluation_result.dart';
import '../angle_calculator.dart';
import 'exercise_rule.dart';

/// 리스트컬 평가 규칙 (Full ROM: 핑거롤 신전 ~ 최대 굴곡)
class WristCurlRules implements ExerciseRule {
  static const double _likelihoodThreshold = 0.5;

  // ── 각도 기준 상수 ──────────────────────────────────────
  // 전완 벡터(elbow→wrist) 기준 손목 굴곡각
  // 양수 = 굴곡(올리기), 음수 = 신전(내리기/핑거롤)
  static const double _extensionIdealMin  = -45.0; // 최대 신전(핑거롤) 하한
  static const double _extensionIdealMax  = -20.0; // 최대 신전 목표 상한
  static const double _flexionIdealMin    =  60.0; // 최대 굴곡 목표 하한
  static const double _flexionIdealMax    =  80.0; // 최대 굴곡 목표 상한
  static const double _fullRomIdealMin    = 100.0; // Full ROM 하한 (신전폭+굴곡폭)
  static const double _fullRomIdealMax    = 130.0; // Full ROM 상한

  @override
  String get name => '리스트컬';

  @override
  List<CriterionResult> evaluate(List<PoseFrame> frames) {
    return [
      _evaluateFullROM(frames),
      _evaluateForearmStability(frames),
      _evaluateRepConsistency(frames),
      _evaluatePeakFlexion(frames),
      _evaluateSymmetry(frames),
    ];
  }

  // ── 핵심 각도 계산 ────────────────────────────────────────
  // 전완 벡터(elbow→wrist)를 기준으로 손(wrist→index)의
  // 굴곡/신전 각도를 부호 포함해 반환한다.
  //   양수 → 굴곡(손목을 위로)
  //   음수 → 신전(손가락 끝까지 내리는 핑거롤)
  double? _wristAngleSigned(PoseFrame frame, {bool left = true}) {
    final elbowIdx = left ? PoseFrame.leftElbow  : PoseFrame.rightElbow;
    final wristIdx = left ? PoseFrame.leftWrist  : PoseFrame.rightWrist;
    final indexIdx = left ? PoseFrame.leftIndex  : PoseFrame.rightIndex;

    final elbow = frame.getLandmark(elbowIdx);
    final wrist = frame.getLandmark(wristIdx);
    final index = frame.getLandmark(indexIdx);

    if (elbow == null || wrist == null || index == null) return null;
    if (wrist.likelihood < _likelihoodThreshold) return null;
    if (index.likelihood < _likelihoodThreshold) return null;

    // 전완 방향 벡터 (elbow → wrist)
    final fDx = wrist.x - elbow.x;
    final fDy = wrist.y - elbow.y;

    // 손 방향 벡터 (wrist → index)
    final hDx = index.x - wrist.x;
    final hDy = index.y - wrist.y;

    final magF = sqrt(fDx * fDx + fDy * fDy);
    final magH = sqrt(hDx * hDx + hDy * hDy);
    if (magF < 1e-6 || magH < 1e-6) return null;

    // 부호 없는 내각
    final cosA   = ((fDx * hDx + fDy * hDy) / (magF * magH)).clamp(-1.0, 1.0);
    final absAngle = acos(cosA) * 180.0 / pi; // 0°~180°

    // 부호 판단: 외적(z성분)으로 굴곡/신전 구분
    // 외적 z > 0 → 손이 전완 대비 반시계(굴곡), < 0 → 시계(신전)
    // 카메라 뷰(y축 아래 증가) 기준으로 좌손/우손 부호 반전
    final cross = fDx * hDy - fDy * hDx;
    final sign  = left ? (cross > 0 ? 1.0 : -1.0)
                       : (cross < 0 ? 1.0 : -1.0);

    // 전완과 손이 일직선(180°)일 때를 0°로 재정의
    // 굴곡 방향이 양수가 되도록 (180° - absAngle) * sign
    return (180.0 - absAngle) * sign;
  }

  // ── 1. Full ROM 평가 (핵심 지표) ────────────────────────
  // 신전(핑거롤 최저점) ~ 굴곡(최고점) 전체 범위를 본다.
  CriterionResult _evaluateFullROM(List<PoseFrame> frames) {
    double minAngle =  999.0; // 가장 많이 신전된 값(음수에서 가장 작은)
    double maxAngle = -999.0; // 가장 많이 굴곡된 값

    for (final frame in frames) {
      final angle = _wristAngleSigned(frame);
      if (angle == null) continue;
      if (angle < minAngle) minAngle = angle;
      if (angle > maxAngle) maxAngle = angle;
    }

    if (minAngle == 999.0 || maxAngle == -999.0) {
      return CriterionResult(
        name: '전체 가동범위',
        description: '핑거롤 신전 ~ 최대 굴곡 Full ROM',
        score: 50.0,
        weight: 0.30,
        grade: CriterionGrade.fromScore(50.0),
      );
    }

    final totalRom = maxAngle - minAngle; // 신전폭 + 굴곡폭

    // Full ROM 기준: 100~130도가 이상적
    final score = AngleCalculator.rangeScore(
      totalRom,
      idealMin: _fullRomIdealMin,
      idealMax: _fullRomIdealMax,
      tolerance: 25,
    );

    return CriterionResult(
      name: '전체 가동범위',
      description: '핑거롤 신전 ~ 최대 굴곡 Full ROM',
      score: score,
      weight: 0.30,
      grade: CriterionGrade.fromScore(score),
    );
  }

  // ── 2. 전완 고정도 ───────────────────────────────────────
  // elbow ~ wrist 중간점의 흔들림을 신체 높이 대비로 측정
  CriterionResult _evaluateForearmStability(List<PoseFrame> frames) {
  final midXList = <double>[];
  final midYList = <double>[];
  double bodyHeight = 0.6;

  for (final frame in frames) {
    final elbow    = frame.getLandmark(PoseFrame.leftElbow);
    final wrist    = frame.getLandmark(PoseFrame.leftWrist);
    final shoulder = frame.getLandmark(PoseFrame.leftShoulder);
    final ankle    = frame.getLandmark(PoseFrame.leftAnkle);

    if (elbow != null && wrist != null) {
      midXList.add((elbow.x + wrist.x) / 2);
      midYList.add((elbow.y + wrist.y) / 2);
    }
    if (shoulder != null && ankle != null) {
      final h = (shoulder.y - ankle.y).abs();
      if (h > bodyHeight) bodyHeight = h;
    }
  }

  double score = 70.0;
  if (midXList.length >= 2 && bodyHeight > 0) {
    final meanX = midXList.reduce((a, b) => a + b) / midXList.length;
    final meanY = midYList.reduce((a, b) => a + b) / midYList.length;
    final varX  = midXList.fold(0.0, (s, x) => s + (x - meanX) * (x - meanX)) / midXList.length;
    final varY  = midYList.fold(0.0, (s, y) => s + (y - meanY) * (y - meanY)) / midYList.length;
    final std   = sqrt(varX + varY) / bodyHeight;
    score = (100.0 * (1.0 - std / 0.05)).clamp(0.0, 100.0);
  }

  return CriterionResult(
    name: '전완 고정도',
    description: '운동 중 전완 안정성 (흔들림 최소화)',
    score: score,
    weight: 0.20,
    grade: CriterionGrade.fromScore(score),
  );
}

  // ── 3. 동작 일관성 ───────────────────────────────────────
  // 각 렙의 ROM 편차(표준편차)로 일관성 측정
  CriterionResult _evaluateRepConsistency(List<PoseFrame> frames) {
    final angles = <double>[];
    for (final frame in frames) {
      final a = _wristAngleSigned(frame);
      if (a != null) angles.add(a);
    }

    if (angles.length < 3) {
      return CriterionResult(
        name: '동작 일관성',
        description: '렙 간 가동범위 균일도',
        score: 70.0,
        weight: 0.20,
        grade: CriterionGrade.fromScore(70.0),
      );
    }

    // 각 렙의 peak(굴곡 최대) ~ valley(신전 최대) 진폭 추출
    final reps = <double>[];
    double? lastPeak;
    double? lastValley;
    bool? wasIncreasing;

    for (int i = 1; i < angles.length; i++) {
      final increasing = angles[i] > angles[i - 1];

      if (wasIncreasing == true && !increasing) {
        // 굴곡 정점 감지
        lastPeak = angles[i - 1];
        if (lastValley != null) {
          reps.add((lastPeak - lastValley).abs());
        }
      } else if (wasIncreasing == false && increasing) {
        // 신전 저점 감지
        lastValley = angles[i - 1];
        if (lastPeak != null) {
          reps.add((lastPeak - lastValley).abs());
        }
      }

      if (angles[i] != angles[i - 1]) wasIncreasing = increasing;
    }

    if (reps.length < 2) {
      return CriterionResult(
        name: '동작 일관성',
        description: '렙 간 가동범위 균일도',
        score: 70.0,
        weight: 0.20,
        grade: CriterionGrade.fromScore(70.0),
      );
    }

    final mean = reps.reduce((a, b) => a + b) / reps.length;
    final variance = reps.fold(0.0, (s, r) => s + (r - mean) * (r - mean)) / reps.length;
    final std = sqrt(variance);

    // Full ROM 운동이므로 허용 편차를 넉넉하게(±8도) 설정
    double score;
    if (std <= 8) {
      score = 100.0;
    } else if (std >= 25) {
      score = 0.0;
    } else {
      score = 100.0 * (1 - (std - 8) / 17);
    }

    return CriterionResult(
      name: '동작 일관성',
      description: '렙 간 가동범위 균일도',
      score: score.clamp(0.0, 100.0),
      weight: 0.20,
      grade: CriterionGrade.fromScore(score),
    );
  }

  // ── 4. 최대 굴곡 + 핑거롤 신전 평가 ─────────────────────
  // 굴곡(올리기)과 신전(핑거롤) 각각을 별도 채점 후 평균
  CriterionResult _evaluatePeakFlexion(List<PoseFrame> frames) {
    double maxFlexion  = -999.0; // 최대 굴곡(양수 최대)
    double maxExtension =  999.0; // 최대 신전(음수 최소)

    for (final frame in frames) {
      final angle = _wristAngleSigned(frame);
      if (angle == null) continue;
      if (angle > maxFlexion)   maxFlexion  = angle;
      if (angle < maxExtension) maxExtension = angle;
    }

    // 굴곡 점수: 60~80도 이상적
    final flexScore = maxFlexion > -999.0
        ? AngleCalculator.rangeScore(maxFlexion,
            idealMin: _flexionIdealMin, idealMax: _flexionIdealMax, tolerance: 20)
        : 50.0;

    // 핑거롤 신전 점수: -20 ~ -45도 이상적
    // rangeScore는 양수 기준이므로 절댓값으로 변환해 평가
    final extScore = maxExtension < 999.0
        ? AngleCalculator.rangeScore(maxExtension.abs(),
            idealMin: 20, idealMax: 45, tolerance: 15)
        : 50.0;

    // 굴곡 60% + 신전(핑거롤) 40% 가중 평균
    final combined = flexScore * 0.6 + extScore * 0.4;

    return CriterionResult(
      name: '최대 굴곡 / 핑거롤',
      description: '최대 굴곡 각도 및 핑거롤 신전 깊이',
      score: combined.clamp(0.0, 100.0),
      weight: 0.20,
      grade: CriterionGrade.fromScore(combined),
    );
  }

  // ── 5. 좌우 대칭 ─────────────────────────────────────────
  CriterionResult _evaluateSymmetry(List<PoseFrame> frames) {
    final scores = <double>[];

    for (final frame in frames) {
      final left  = _wristAngleSigned(frame, left: true);
      final right = _wristAngleSigned(frame, left: false);
      if (left == null || right == null) continue;

      // 부호 포함 대칭: 절댓값 차이가 작을수록 좋음
      scores.add(AngleCalculator.symmetryScore(left.abs(), right.abs()));
    }

    final avg = scores.isEmpty
        ? 70.0
        : scores.reduce((a, b) => a + b) / scores.length;

    return CriterionResult(
      name: '좌우 대칭',
      description: '양손 손목 굴곡/신전 좌우 대칭',
      score: avg,
      weight: 0.10,
      grade: CriterionGrade.fromScore(avg),
    );
  }
}
