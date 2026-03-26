import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:rexx_app/features/pose_evaluation/models/pose_frame.dart';
import 'package:rexx_app/features/pose_evaluation/models/exercise_phase.dart';
import 'package:rexx_app/features/pose_evaluation/models/classification_result.dart';
import 'package:rexx_app/features/pose_evaluation/engine/classifier/exercise_classifier.dart';

PoseLandmark _lm(int index, double x, double y, {double z = 0, double likelihood = 0.9}) {
  return PoseLandmark(index: index, x: x, y: y, z: z, likelihood: likelihood);
}

/// 스쿼트 시뮬레이션: 직립 상태에서 무릎이 크게 굽혀짐
List<PoseFrame> _squatFrames() {
  final frames = <PoseFrame>[];
  final kneeAngles = [170.0, 150.0, 120.0, 100.0, 80.0, 80.0, 100.0, 120.0, 150.0, 170.0];

  for (int i = 0; i < 10; i++) {
    final shoulderY = 0.3;
    final hipY = 0.55;
    final kneeY = 0.75 + (170.0 - kneeAngles[i]) / 170.0 * 0.1;
    final ankleY = 0.9;

    frames.add(PoseFrame(
      frameIndex: i,
      timestamp: i / 5.0,
      landmarks: [
        _lm(PoseFrame.leftShoulder, 0.5, shoulderY),
        _lm(PoseFrame.rightShoulder, 0.5, shoulderY, likelihood: 0.5),
        _lm(PoseFrame.leftElbow, 0.45, 0.42),
        _lm(PoseFrame.rightElbow, 0.55, 0.42, likelihood: 0.5),
        _lm(PoseFrame.leftWrist, 0.45, 0.45),
        _lm(PoseFrame.rightWrist, 0.55, 0.45, likelihood: 0.5),
        _lm(PoseFrame.leftHip, 0.5, hipY),
        _lm(PoseFrame.rightHip, 0.5, hipY, likelihood: 0.5),
        _lm(PoseFrame.leftKnee, 0.5, kneeY),
        _lm(PoseFrame.rightKnee, 0.5, kneeY, likelihood: 0.5),
        _lm(PoseFrame.leftAnkle, 0.5, ankleY),
        _lm(PoseFrame.rightAnkle, 0.5, ankleY, likelihood: 0.5),
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

/// 데드리프트 시뮬레이션: 전방 경사에서 힙이 크게 변화
List<PoseFrame> _deadliftFrames() {
  final frames = <PoseFrame>[];
  final hipAngles = [80.0, 95.0, 110.0, 125.0, 140.0, 155.0, 165.0, 170.0, 170.0, 170.0];

  for (int i = 0; i < 10; i++) {
    final lean = (170.0 - hipAngles[i]) / 170.0 * 0.2;
    final shoulderX = 0.4 - lean;
    final shoulderY = 0.35 + lean * 0.3;

    frames.add(PoseFrame(
      frameIndex: i,
      timestamp: i / 5.0,
      landmarks: [
        _lm(PoseFrame.leftShoulder, shoulderX, shoulderY),
        _lm(PoseFrame.rightShoulder, shoulderX, shoulderY, likelihood: 0.5),
        _lm(PoseFrame.leftElbow, shoulderX - 0.02, shoulderY + 0.1),
        _lm(PoseFrame.rightElbow, shoulderX - 0.02, shoulderY + 0.1, likelihood: 0.5),
        _lm(PoseFrame.leftWrist, shoulderX - 0.03, shoulderY + 0.2),
        _lm(PoseFrame.rightWrist, shoulderX - 0.03, shoulderY + 0.2, likelihood: 0.5),
        _lm(PoseFrame.leftHip, 0.5, 0.55),
        _lm(PoseFrame.rightHip, 0.5, 0.55, likelihood: 0.5),
        _lm(PoseFrame.leftKnee, 0.5, 0.75),
        _lm(PoseFrame.rightKnee, 0.5, 0.75, likelihood: 0.5),
        _lm(PoseFrame.leftAnkle, 0.5, 0.9),
        _lm(PoseFrame.rightAnkle, 0.5, 0.9, likelihood: 0.5),
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
