import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:rexx_app/features/pose_evaluation/models/pose_frame.dart';
import 'package:rexx_app/features/pose_evaluation/models/exercise_phase.dart';
import 'package:rexx_app/features/pose_evaluation/models/classification_result.dart';
import 'package:rexx_app/features/pose_evaluation/engine/classifier/exercise_classifier.dart';

PoseLandmark _lm(int index, double x, double y, {double z = 0, double likelihood = 0.9}) {
  return PoseLandmark(index: index, x: x, y: y, z: z, likelihood: likelihood);
}

/// 스쿼트 시뮬레이션: 직립 상태에서 무릎이 전방으로 이동하며 굽혀짐
/// hip=(0.5,0.55), ankle=(0.5,0.9) 고정. knee X 오프셋으로 실제 무릎 각도 생성.
/// knee X: 0.50(180°) → 0.33(~92°) → 0.50(180°), ROM≈88°
List<PoseFrame> _squatFrames() {
  final frames = <PoseFrame>[];
  // knee X 위치: 서 있을 때 0.50, 깊은 스쿼트 시 0.33 (측면에서 봤을 때 무릎이 앞으로 이동)
  final kneeXValues = [0.50, 0.47, 0.43, 0.39, 0.33, 0.33, 0.39, 0.43, 0.47, 0.50];

  for (int i = 0; i < 10; i++) {
    final kx = kneeXValues[i];

    frames.add(PoseFrame(
      frameIndex: i,
      timestamp: i / 5.0,
      landmarks: [
        _lm(PoseFrame.leftShoulder,  0.50, 0.30),
        _lm(PoseFrame.rightShoulder, 0.50, 0.30, likelihood: 0.5),
        _lm(PoseFrame.leftElbow,     0.45, 0.42),
        _lm(PoseFrame.rightElbow,    0.55, 0.42, likelihood: 0.5),
        _lm(PoseFrame.leftWrist,     0.45, 0.45),
        _lm(PoseFrame.rightWrist,    0.55, 0.45, likelihood: 0.5),
        // 중립 손목: elbow→wrist 방향(아래쪽)으로 연장 → wrist ROM ≈ 0
        _lm(19, 0.45, 0.55),
        _lm(20, 0.55, 0.55, likelihood: 0.5),
        _lm(PoseFrame.leftHip,   0.50, 0.55),
        _lm(PoseFrame.rightHip,  0.50, 0.55, likelihood: 0.5),
        _lm(PoseFrame.leftKnee,  kx,   0.73),
        _lm(PoseFrame.rightKnee, kx,   0.73, likelihood: 0.5),
        _lm(PoseFrame.leftAnkle,  0.50, 0.90),
        _lm(PoseFrame.rightAnkle, 0.50, 0.90, likelihood: 0.5),
      ],
    ));
  }
  return frames;
}

/// 벤치프레스 시뮬레이션: 누운 상태에서 팔꿈치가 크게 굽혀짐
List<PoseFrame> _benchPressFrames() {
  final frames = <PoseFrame>[];
  final elbowAngles = [170.0, 150.0, 120.0, 100.0, 85.0, 85.0, 100.0, 120.0, 150.0, 170.0];

  for (int i = 0; i < 10; i++) {
    final wristX = 0.3 + (170.0 - elbowAngles[i]) / 170.0 * 0.15;
    // 중립 손목(~180°): 손목-손가락이 팔꿈치→손목 방향과 동일한 직선상에 위치
    final elbowToWristDx = wristX - 0.35;
    final elbowToWristDy = 0.25 - 0.35;
    final len = sqrt(elbowToWristDx * elbowToWristDx + elbowToWristDy * elbowToWristDy);
    final indexX = wristX + (elbowToWristDx / len) * 0.1;
    final indexY = 0.25 + (elbowToWristDy / len) * 0.1;

    frames.add(PoseFrame(
      frameIndex: i,
      timestamp: i / 5.0,
      landmarks: [
        _lm(PoseFrame.leftShoulder, 0.3, 0.5),
        _lm(PoseFrame.rightShoulder, 0.3, 0.5, likelihood: 0.5),
        _lm(PoseFrame.leftElbow, 0.35, 0.35),
        _lm(PoseFrame.rightElbow, 0.35, 0.65, likelihood: 0.5),
        _lm(PoseFrame.leftWrist, wristX, 0.25),
        _lm(PoseFrame.rightWrist, wristX, 0.75, likelihood: 0.5),
        _lm(19, indexX, indexY),
        _lm(20, indexX, 0.75 + (indexY - 0.25), likelihood: 0.5),
        _lm(PoseFrame.leftHip, 0.7, 0.5),
        _lm(PoseFrame.rightHip, 0.7, 0.5, likelihood: 0.5),
        _lm(PoseFrame.leftKnee, 0.8, 0.45),
        _lm(PoseFrame.rightKnee, 0.8, 0.55, likelihood: 0.5),
        _lm(PoseFrame.leftAnkle, 0.9, 0.45),
        _lm(PoseFrame.rightAnkle, 0.9, 0.55, likelihood: 0.5),
      ],
    ));
  }
  return frames;
}

/// 데드리프트 시뮬레이션: shoulder X 이동으로 실제 힙 각도 변화 생성
/// shoulder X: 0.20(전방경사, hip≈124°) → 0.50(직립, hip=180°), ROM≈56°
/// hip=(0.5,0.55), knee=(0.5,0.75), ankle=(0.5,0.9) 고정
/// torso 평균 ≈ 37° (deadlift 이상 범위 30-55° 내)
List<PoseFrame> _deadliftFrames() {
  final frames = <PoseFrame>[];
  // shoulderX: 전방 경사(0.20)에서 직립(0.50)으로 천천히 이동 (평균 torso ≈ 34°)
  final shoulderXValues = [0.20, 0.22, 0.25, 0.28, 0.32, 0.36, 0.40, 0.44, 0.48, 0.50];

  for (int i = 0; i < 10; i++) {
    final sx = shoulderXValues[i];
    // elbow/wrist는 shoulder에서 아래 방향으로 고정 오프셋
    final ex = sx;
    final wx = sx;
    // 중립 손목: elbow→wrist 방향(순수 아래)으로 연장 → wrist ROM ≈ 0
    frames.add(PoseFrame(
      frameIndex: i,
      timestamp: i / 5.0,
      landmarks: [
        _lm(PoseFrame.leftShoulder,  sx,   0.35),
        _lm(PoseFrame.rightShoulder, sx,   0.35, likelihood: 0.5),
        _lm(PoseFrame.leftElbow,     ex,   0.45),
        _lm(PoseFrame.rightElbow,    ex,   0.45, likelihood: 0.5),
        _lm(PoseFrame.leftWrist,     wx,   0.55),
        _lm(PoseFrame.rightWrist,    wx,   0.55, likelihood: 0.5),
        // 중립 손목: elbow→wrist가 수직 → index를 아래 방향으로 배치
        _lm(19, wx, 0.65),
        _lm(20, wx, 0.65, likelihood: 0.5),
        _lm(PoseFrame.leftHip,   0.50, 0.55),
        _lm(PoseFrame.rightHip,  0.50, 0.55, likelihood: 0.5),
        _lm(PoseFrame.leftKnee,  0.50, 0.75),
        _lm(PoseFrame.rightKnee, 0.50, 0.75, likelihood: 0.5),
        _lm(PoseFrame.leftAnkle,  0.50, 0.90),
        _lm(PoseFrame.rightAnkle, 0.50, 0.90, likelihood: 0.5),
      ],
    ));
  }
  return frames;
}

/// 리스트컬 시뮬레이션: 직립, 손목 ROM 큼, 팔꿈치/무릎/힙 ROM 최소
List<PoseFrame> _wristCurlFrames() {
  final frames = <PoseFrame>[];
  final wristAngles = [170.0, 155.0, 135.0, 120.0, 135.0, 155.0, 170.0, 155.0, 135.0, 120.0];

  final elbowX = 0.5, elbowY = 0.40;
  final wristX = 0.5, wristY = 0.55;
  final baseAngle = atan2(wristY - elbowY, wristX - elbowX);

  for (int i = 0; i < 10; i++) {
    final targetRad = wristAngles[i] * pi / 180;
    final indexAngle = baseAngle + (pi - targetRad);
    final indexX = wristX + 0.1 * cos(indexAngle);
    final indexY = wristY + 0.1 * sin(indexAngle);

    frames.add(PoseFrame(
      frameIndex: i,
      timestamp: i / 5.0,
      landmarks: [
        _lm(PoseFrame.leftShoulder, 0.5, 0.25),
        _lm(PoseFrame.rightShoulder, 0.5, 0.25, likelihood: 0.5),
        _lm(PoseFrame.leftElbow, elbowX, elbowY),
        _lm(PoseFrame.rightElbow, elbowX, elbowY, likelihood: 0.5),
        _lm(PoseFrame.leftWrist, wristX, wristY),
        _lm(PoseFrame.rightWrist, wristX, wristY, likelihood: 0.5),
        _lm(19, indexX, indexY),
        _lm(20, indexX, indexY, likelihood: 0.5),
        _lm(PoseFrame.leftHip, 0.5, 0.60),
        _lm(PoseFrame.rightHip, 0.5, 0.60, likelihood: 0.5),
        _lm(PoseFrame.leftKnee, 0.5, 0.75),
        _lm(PoseFrame.rightKnee, 0.5, 0.75, likelihood: 0.5),
        _lm(PoseFrame.leftAnkle, 0.5, 0.90),
        _lm(PoseFrame.rightAnkle, 0.5, 0.90, likelihood: 0.5),
      ],
    ));
  }
  return frames;
}

void main() {
  group('ExerciseClassifier', () {
    late ExerciseClassifier classifier;

    setUp(() {
      classifier = ExerciseClassifier();
    });

    test('스쿼트 프레임을 squat으로 분류한다', () {
      final result = classifier.classify(_squatFrames());
      expect(result.bestMatch, ExerciseType.squat);
      expect(result.confidence, isIn([ClassificationConfidence.high, ClassificationConfidence.moderate]));
    });

    test('벤치프레스 프레임을 benchPress로 분류한다', () {
      final result = classifier.classify(_benchPressFrames());
      expect(result.bestMatch, ExerciseType.benchPress);
      expect(result.confidence, isIn([ClassificationConfidence.high, ClassificationConfidence.moderate]));
    });

    test('데드리프트 프레임을 deadlift로 분류한다', () {
      final result = classifier.classify(_deadliftFrames());
      expect(result.bestMatch, ExerciseType.deadlift);
      expect(result.confidence, isIn([ClassificationConfidence.high, ClassificationConfidence.moderate]));
    });

    test('확률의 합은 1.0이다', () {
      final result = classifier.classify(_squatFrames());
      final sum = result.probabilities.values.reduce((a, b) => a + b);
      expect(sum, closeTo(1.0, 0.01));
    });

    test('리스트컬 프레임을 wristCurl로 분류한다', () {
      final result = classifier.classify(_wristCurlFrames());
      expect(result.bestMatch, ExerciseType.wristCurl);
    });

    test('프레임이 부족하면 모든 확률이 균등하다', () {
      final frames = <PoseFrame>[
        PoseFrame(frameIndex: 0, timestamp: 0, landmarks: [
          _lm(PoseFrame.leftShoulder, 0.5, 0.3),
          _lm(PoseFrame.rightShoulder, 0.5, 0.3),
          _lm(PoseFrame.leftElbow, 0.5, 0.4),
          _lm(PoseFrame.rightElbow, 0.5, 0.4),
          _lm(PoseFrame.leftWrist, 0.5, 0.5),
          _lm(PoseFrame.rightWrist, 0.5, 0.5),
          _lm(PoseFrame.leftHip, 0.5, 0.55),
          _lm(PoseFrame.rightHip, 0.5, 0.55),
          _lm(PoseFrame.leftKnee, 0.5, 0.75),
          _lm(PoseFrame.rightKnee, 0.5, 0.75),
          _lm(PoseFrame.leftAnkle, 0.5, 0.9),
          _lm(PoseFrame.rightAnkle, 0.5, 0.9),
        ]),
      ];
      final result = classifier.classify(frames);
      expect(result.confidence, ClassificationConfidence.failed);
    });
  });

  group('ExerciseClassifier.chooseSide', () {
    test('likelihood가 높은 쪽을 선택한다', () {
      final frames = <PoseFrame>[
        PoseFrame(frameIndex: 0, timestamp: 0, landmarks: [
          _lm(PoseFrame.leftShoulder, 0.5, 0.3, likelihood: 0.9),
          _lm(PoseFrame.rightShoulder, 0.5, 0.3, likelihood: 0.3),
          _lm(PoseFrame.leftHip, 0.5, 0.55, likelihood: 0.9),
          _lm(PoseFrame.rightHip, 0.5, 0.55, likelihood: 0.3),
          _lm(PoseFrame.leftKnee, 0.5, 0.75, likelihood: 0.9),
          _lm(PoseFrame.rightKnee, 0.5, 0.75, likelihood: 0.3),
          _lm(PoseFrame.leftElbow, 0.5, 0.4, likelihood: 0.9),
          _lm(PoseFrame.rightElbow, 0.5, 0.4, likelihood: 0.3),
          _lm(PoseFrame.leftWrist, 0.5, 0.5, likelihood: 0.9),
          _lm(PoseFrame.rightWrist, 0.5, 0.5, likelihood: 0.3),
          _lm(PoseFrame.leftAnkle, 0.5, 0.9, likelihood: 0.9),
          _lm(PoseFrame.rightAnkle, 0.5, 0.9, likelihood: 0.3),
        ]),
      ];
      expect(ExerciseClassifier.chooseSide(frames), true); // true = left
    });
  });
}
